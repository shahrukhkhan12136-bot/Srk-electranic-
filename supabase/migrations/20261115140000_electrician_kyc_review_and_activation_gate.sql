-- Complete the private electrician KYC document lifecycle and gate activation on required evidence.
-- Feature Branch source only; do not apply to Production without the approved rollout.

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values(
  'srk-electrician-verification',
  'srk-electrician-verification',
  false,
  5242880,
  array['application/pdf','image/jpeg','image/png']::text[]
)
on conflict(id) do update
set name=excluded.name,
    public=false,
    file_size_limit=excluded.file_size_limit,
    allowed_mime_types=excluded.allowed_mime_types;

create table if not exists public.srk_electrician_verification_documents(
  id uuid primary key default gen_random_uuid(),
  electrician_profile_id uuid not null references public.electrician_profiles(id) on delete restrict,
  uploaded_by uuid not null references auth.users(id) on delete restrict,
  document_type text not null check(document_type in ('identity_proof','address_proof','skill_certificate')),
  storage_path text not null unique check(length(storage_path) between 10 and 255),
  file_name text not null check(length(btrim(file_name)) between 1 and 180),
  mime_type text not null check(mime_type in ('application/pdf','image/jpeg','image/png')),
  file_size_bytes bigint not null check(file_size_bytes between 1 and 5242880),
  review_status text not null default 'pending'
    check(review_status in ('pending','approved','rejected','needs_resubmission')),
  admin_note text check(admin_note is null or length(admin_note)<=1000),
  uploaded_at timestamptz not null default clock_timestamp(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete restrict,
  constraint srk_electrician_kyc_review_fields_check check(
    (review_status='pending' and reviewed_at is null and reviewed_by is null)
    or (review_status<>'pending' and reviewed_at is not null and reviewed_by is not null)
  )
);
create index if not exists srk_electrician_kyc_profile_type_latest_idx
  on public.srk_electrician_verification_documents(electrician_profile_id,document_type,uploaded_at desc,id desc);
create index if not exists srk_electrician_kyc_review_queue_idx
  on public.srk_electrician_verification_documents(review_status,uploaded_at desc);

alter table public.srk_electrician_verification_documents enable row level security;
revoke all on public.srk_electrician_verification_documents from public,anon,authenticated;

create table if not exists public.srk_electrician_verification_document_events(
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.srk_electrician_verification_documents(id) on delete restrict,
  electrician_profile_id uuid not null references public.electrician_profiles(id) on delete restrict,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  actor_role text not null check(actor_role in ('electrician','admin')),
  event_type text not null check(event_type in ('submitted','approved','rejected','needs_resubmission')),
  note text check(note is null or length(note)<=1000),
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists srk_electrician_kyc_events_document_idx
  on public.srk_electrician_verification_document_events(document_id,created_at desc,id desc);
alter table public.srk_electrician_verification_document_events enable row level security;
revoke all on public.srk_electrician_verification_document_events from public,anon,authenticated;

create or replace function public.srk_reject_electrician_kyc_event_mutation()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  raise exception 'ELECTRICIAN_KYC_EVENT_HISTORY_IS_APPEND_ONLY' using errcode='55000';
end;
$function$;
revoke all on function public.srk_reject_electrician_kyc_event_mutation() from public,anon,authenticated;
drop trigger if exists srk_electrician_kyc_events_append_only on public.srk_electrician_verification_document_events;
create trigger srk_electrician_kyc_events_append_only
before update or delete on public.srk_electrician_verification_document_events
for each row execute function public.srk_reject_electrician_kyc_event_mutation();

create or replace function public.srk_electrician_can_delete_unregistered_kyc_object(p_path text)
returns boolean
language sql stable security definer set search_path=''
as $function$
  select auth.uid() is not null
    and p_path is not null
    and p_path like auth.uid()::text||'/%'
    and exists(
      select 1 from public.electrician_profiles p
      where p.user_id=auth.uid() and p.auth_user_id=auth.uid()
    )
    and not exists(
      select 1 from public.srk_electrician_verification_documents d
      where d.storage_path=p_path
    );
$function$;
revoke all on function public.srk_electrician_can_delete_unregistered_kyc_object(text) from public,anon;
grant execute on function public.srk_electrician_can_delete_unregistered_kyc_object(text) to authenticated;

-- Storage is private. Electricians can upload only into their own UID/type folder;
-- Admin can create short-lived signed previews, but no public object access exists.
drop policy if exists srk_electrician_kyc_owner_upload on storage.objects;
create policy srk_electrician_kyc_owner_upload on storage.objects
for insert to authenticated
with check(
  bucket_id='srk-electrician-verification'
  and (storage.foldername(name))[1]=auth.uid()::text
  and (storage.foldername(name))[2] in ('identity_proof','address_proof','skill_certificate')
  and exists(
    select 1 from public.electrician_profiles p
    where p.user_id=auth.uid() and p.auth_user_id=auth.uid()
  )
);

drop policy if exists srk_electrician_kyc_owner_or_admin_read on storage.objects;
create policy srk_electrician_kyc_owner_or_admin_read on storage.objects
for select to authenticated
using(
  bucket_id='srk-electrician-verification'
  and (
    public.is_srk_admin()
    or (
      (storage.foldername(name))[1]=auth.uid()::text
      and exists(
        select 1 from public.electrician_profiles p
        where p.user_id=auth.uid() and p.auth_user_id=auth.uid()
      )
    )
  )
);

drop policy if exists srk_electrician_kyc_owner_delete_unregistered on storage.objects;
create policy srk_electrician_kyc_owner_delete_unregistered on storage.objects
for delete to authenticated
using(
  bucket_id='srk-electrician-verification'
  and (storage.foldername(name))[1]=auth.uid()::text
  and exists(
    select 1 from public.electrician_profiles p
    where p.user_id=auth.uid() and p.auth_user_id=auth.uid()
  )
  and public.srk_electrician_can_delete_unregistered_kyc_object(storage.objects.name)
);

create or replace function public.srk_electrician_submit_verification_document(
  p_document_type text,
  p_storage_path text,
  p_file_name text,
  p_mime_type text,
  p_file_size_bytes bigint
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_profile_id uuid;
  v_document public.srk_electrician_verification_documents%rowtype;
begin
  if v_uid is null then
    raise exception 'ELECTRICIAN_LOGIN_REQUIRED' using errcode='42501';
  end if;
  if p_document_type is null or p_document_type not in ('identity_proof','address_proof','skill_certificate')
     or p_storage_path is null
     or length(p_storage_path)>255
     or p_storage_path not like v_uid::text||'/'||p_document_type||'/%'
     or position('..' in p_storage_path)>0
     or position(E'\\' in p_storage_path)>0
     or p_storage_path ~ '[[:cntrl:]]'
     or p_file_name is null or length(btrim(p_file_name)) not between 1 and 180
     or p_file_name ~ '[[:cntrl:]]'
     or p_mime_type is null or p_mime_type not in ('application/pdf','image/jpeg','image/png')
     or p_file_size_bytes is null or p_file_size_bytes not between 1 and 5242880 then
    raise exception 'INVALID_KYC_DOCUMENT_METADATA_OR_PATH' using errcode='22023';
  end if;

  select p.id into v_profile_id
  from public.electrician_profiles p
  where p.user_id=v_uid and p.auth_user_id=v_uid
  order by p.created_at desc nulls last,p.id
  limit 1
  for update;
  if v_profile_id is null then
    raise exception 'LINKED_ELECTRICIAN_PROFILE_REQUIRED' using errcode='42501';
  end if;

  if not exists(
    select 1 from storage.objects o
    where o.bucket_id='srk-electrician-verification'
      and o.name=p_storage_path
  ) then
    raise exception 'UPLOADED_KYC_OBJECT_NOT_FOUND' using errcode='55000';
  end if;

  insert into public.srk_electrician_verification_documents(
    electrician_profile_id,uploaded_by,document_type,storage_path,file_name,
    mime_type,file_size_bytes,review_status
  ) values(
    v_profile_id,v_uid,p_document_type,p_storage_path,btrim(p_file_name),
    p_mime_type,p_file_size_bytes,'pending'
  ) returning * into v_document;

  insert into public.srk_electrician_verification_document_events(
    document_id,electrician_profile_id,actor_user_id,actor_role,event_type,note
  ) values(v_document.id,v_profile_id,v_uid,'electrician','submitted',null);

  return jsonb_build_object('success',true,'document_id',v_document.id,'review_status',v_document.review_status);
end;
$function$;
revoke all on function public.srk_electrician_submit_verification_document(text,text,text,text,bigint) from public,anon;
grant execute on function public.srk_electrician_submit_verification_document(text,text,text,text,bigint) to authenticated;

create or replace function public.srk_electrician_list_my_verification_documents()
returns table(
  id uuid,document_type text,file_name text,mime_type text,file_size_bytes bigint,
  review_status text,admin_note text,uploaded_at timestamptz,reviewed_at timestamptz
)
language plpgsql stable security definer set search_path=''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_profile_id uuid;
begin
  if v_uid is null then raise exception 'ELECTRICIAN_LOGIN_REQUIRED' using errcode='42501'; end if;
  select p.id into v_profile_id from public.electrician_profiles p
  where p.user_id=v_uid and p.auth_user_id=v_uid
  order by p.created_at desc nulls last,p.id limit 1;
  if v_profile_id is null then raise exception 'LINKED_ELECTRICIAN_PROFILE_REQUIRED' using errcode='42501'; end if;

  return query
  select d.id,d.document_type,d.file_name,d.mime_type,d.file_size_bytes,
         d.review_status,d.admin_note,d.uploaded_at,d.reviewed_at
  from public.srk_electrician_verification_documents d
  where d.electrician_profile_id=v_profile_id
  order by d.uploaded_at desc,d.id desc;
end;
$function$;
revoke all on function public.srk_electrician_list_my_verification_documents() from public,anon;
grant execute on function public.srk_electrician_list_my_verification_documents() to authenticated;

create or replace function public.srk_admin_list_electrician_verification_documents(p_limit integer default 300)
returns table(
  id uuid,electrician_profile_id uuid,electrician_name text,electrician_phone text,
  district text,state text,pincode text,document_type text,storage_path text,
  file_name text,mime_type text,file_size_bytes bigint,review_status text,
  admin_note text,uploaded_at timestamptz,reviewed_at timestamptz,activity jsonb
)
language plpgsql stable security definer set search_path=''
as $function$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501';
  end if;
  return query
  select d.id,p.id,p.display_name,p.phone,p.district,p.state,p.pincode,
         d.document_type,d.storage_path,d.file_name,d.mime_type,d.file_size_bytes,
         d.review_status,d.admin_note,d.uploaded_at,d.reviewed_at,
         coalesce((
           select jsonb_agg(jsonb_build_object(
             'actor_role',e.actor_role,'event_type',e.event_type,
             'note',e.note,'created_at',e.created_at
           ) order by e.created_at desc,e.id desc)
           from public.srk_electrician_verification_document_events e
           where e.document_id=d.id
         ),'[]'::jsonb)
  from public.srk_electrician_verification_documents d
  join public.electrician_profiles p on p.id=d.electrician_profile_id
  order by d.uploaded_at desc,d.id desc
  limit greatest(1,least(coalesce(p_limit,100),300));
end;
$function$;
revoke all on function public.srk_admin_list_electrician_verification_documents(integer) from public,anon;
grant execute on function public.srk_admin_list_electrician_verification_documents(integer) to authenticated;

create or replace function public.srk_admin_review_electrician_document(
  p_document_id uuid,p_review_status text,p_admin_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_document public.srk_electrician_verification_documents%rowtype;
  v_note text:=btrim(coalesce(p_admin_note,''));
  v_booking_id uuid;
  v_closed integer:=0;
  v_previous_available boolean:=false;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501';
  end if;
  if p_document_id is null
     or p_review_status is null
     or p_review_status not in ('approved','rejected','needs_resubmission')
     or (p_review_status in ('rejected','needs_resubmission') and length(v_note) not between 5 and 1000)
     or length(v_note)>1000 then
    raise exception 'INVALID_KYC_REVIEW_DECISION_OR_NOTE' using errcode='22023';
  end if;

  select * into v_document
  from public.srk_electrician_verification_documents d
  where d.id=p_document_id
  for update;
  if not found then raise exception 'KYC_DOCUMENT_NOT_FOUND' using errcode='P0002'; end if;
  if v_document.review_status<>'pending' then
    raise exception 'ONLY_PENDING_KYC_DOCUMENTS_CAN_BE_REVIEWED' using errcode='55000';
  end if;

  update public.srk_electrician_verification_documents
  set review_status=p_review_status,admin_note=nullif(v_note,''),
      reviewed_at=clock_timestamp(),reviewed_by=auth.uid()
  where id=v_document.id;

  insert into public.srk_electrician_verification_document_events(
    document_id,electrician_profile_id,actor_user_id,actor_role,event_type,note
  ) values(
    v_document.id,v_document.electrician_profile_id,auth.uid(),'admin',p_review_status,nullif(v_note,'')
  );

  -- If the latest required proof is no longer approved, immediately deactivate the
  -- partner and close only unaccepted offers. Accepted bookings remain assigned.
  if exists(
    select 1 from public.electrician_profiles p
    where p.id=v_document.electrician_profile_id and p.active=true
  ) and (
    (select d.review_status from public.srk_electrician_verification_documents d
      where d.electrician_profile_id=v_document.electrician_profile_id and d.document_type='identity_proof'
      order by d.uploaded_at desc,d.id desc limit 1) is distinct from 'approved'
    or
    (select d.review_status from public.srk_electrician_verification_documents d
      where d.electrician_profile_id=v_document.electrician_profile_id and d.document_type='address_proof'
      order by d.uploaded_at desc,d.id desc limit 1) is distinct from 'approved'
  ) then
    select p.available_for_work into v_previous_available
    from public.electrician_profiles p
    where p.id=v_document.electrician_profile_id and p.active=true
    for update;
    if found then
      update public.electrician_profiles
        set active=false,available_for_work=false
        where id=v_document.electrician_profile_id and active=true;
      if coalesce(v_previous_available,false) then
        insert into public.srk_electrician_availability_events(
          electrician_profile_id,actor_user_id,available_for_work
        ) values(v_document.electrician_profile_id,auth.uid(),false);
      end if;
      for v_booking_id in
        update public.job_offers
        set status='declined',responded_at=clock_timestamp()
        where electrician_id=v_document.electrician_profile_id and status='offered'
        returning booking_id
      loop
        perform private.srk_dispatch_next_booking_offer(v_booking_id);
        v_closed:=v_closed+1;
      end loop;
    end if;
  end if;

  return jsonb_build_object('success',true,'document_id',v_document.id,
    'review_status',p_review_status,'closed_offers_advanced',v_closed);
end;
$function$;
revoke all on function public.srk_admin_review_electrician_document(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_review_electrician_document(uuid,text,text) to authenticated;

-- Require latest identity and address evidence before changing the approved rate tier.
create or replace function public.srk_guard_electrician_rate_tier_activation()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare
  v_authorized boolean:=false;
  v_identity_status text;
  v_address_status text;
begin
  if tg_op='INSERT' then
    if new.approved_rate_tier is not null or new.approved_rate_card_version is not null
       or new.rate_tier_approved_by is not null or new.rate_tier_approved_at is not null then
      raise exception 'RATE_TIER_MUST_BE_ASSIGNED_THROUGH_AUDITED_ADMIN_RPC' using errcode='42501';
    end if;
  elsif new.approved_rate_tier is distinct from old.approved_rate_tier
     or new.approved_rate_card_version is distinct from old.approved_rate_card_version
     or new.rate_tier_approved_by is distinct from old.rate_tier_approved_by
     or new.rate_tier_approved_at is distinct from old.rate_tier_approved_at then
    select exists(
      select 1 from srk_private.electrician_rate_tier_authorizations a
      where a.transaction_id=pg_catalog.txid_current()
        and a.electrician_profile_id=new.id and a.actor_id=auth.uid()
    ) into v_authorized;
    if not v_authorized then
      raise exception 'RATE_TIER_CHANGES_REQUIRE_AUDITED_ADMIN_RPC' using errcode='42501';
    end if;
    if new.verification_status is distinct from 'approved' then
      raise exception 'ELECTRICIAN_APPLICATION_MUST_BE_APPROVED_BEFORE_RATE_TIER' using errcode='23514';
    end if;
    select d.review_status into v_identity_status
    from public.srk_electrician_verification_documents d
    where d.electrician_profile_id=new.id and d.document_type='identity_proof'
    order by d.uploaded_at desc,d.id desc limit 1;
    select d.review_status into v_address_status
    from public.srk_electrician_verification_documents d
    where d.electrician_profile_id=new.id and d.document_type='address_proof'
    order by d.uploaded_at desc,d.id desc limit 1;
    if v_identity_status is distinct from 'approved'
       or v_address_status is distinct from 'approved' then
      raise exception 'LATEST_IDENTITY_AND_ADDRESS_KYC_DOCUMENTS_MUST_BE_APPROVED_BEFORE_RATE_TIER' using errcode='23514';
    end if;
  end if;
  if new.active is true and (
    new.approved_rate_tier is null or new.approved_rate_card_version is null
    or new.rate_tier_approved_by is null or new.rate_tier_approved_at is null
  ) then
    raise exception 'ADMIN_APPROVED_RATE_TIER_REQUIRED_BEFORE_ACTIVATION' using errcode='23514';
  end if;
  return new;
end;
$function$;
revoke all on function public.srk_guard_electrician_rate_tier_activation() from public,anon,authenticated;

-- A trigger protects direct profile-table writes as well as the Admin RPC.
create or replace function public.srk_guard_electrician_kyc_before_activation()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare
  v_identity_status text;
  v_address_status text;
begin
  if new.active is true then
    if new.verification_status is distinct from 'approved'
       or new.user_id is null or new.auth_user_id is distinct from new.user_id
       or not exists(
         select 1 from auth.users u
         where u.id=new.user_id and u.phone_confirmed_at is not null
           and right(regexp_replace(coalesce(u.phone,''),'[^0-9]','','g'),10)
               =right(regexp_replace(coalesce(new.phone,''),'[^0-9]','','g'),10)
       ) then
      raise exception 'ELECTRICIAN_APPLICATION_PHONE_OTP_AND_APPROVAL_REQUIRED' using errcode='23514';
    end if;
    select d.review_status into v_identity_status
    from public.srk_electrician_verification_documents d
    where d.electrician_profile_id=new.id and d.document_type='identity_proof'
    order by d.uploaded_at desc,d.id desc limit 1;
    select d.review_status into v_address_status
    from public.srk_electrician_verification_documents d
    where d.electrician_profile_id=new.id and d.document_type='address_proof'
    order by d.uploaded_at desc,d.id desc limit 1;
    if v_identity_status is distinct from 'approved'
       or v_address_status is distinct from 'approved' then
      raise exception 'LATEST_IDENTITY_AND_ADDRESS_KYC_DOCUMENTS_MUST_BE_APPROVED' using errcode='23514';
    end if;
    if new.approved_rate_tier is null or new.approved_rate_card_version is null
       or new.rate_tier_approved_by is null or new.rate_tier_approved_at is null then
      raise exception 'ADMIN_APPROVED_RATE_TIER_REQUIRED_BEFORE_ACTIVATION' using errcode='23514';
    end if;
  end if;
  return new;
end;
$function$;
revoke all on function public.srk_guard_electrician_kyc_before_activation() from public,anon,authenticated;
drop trigger if exists srk_guard_electrician_kyc_before_activation on public.electrician_profiles;
create trigger srk_guard_electrician_kyc_before_activation
before insert or update of active,verification_status,user_id,auth_user_id,phone,approved_rate_tier,approved_rate_card_version,rate_tier_approved_by,rate_tier_approved_at
on public.electrician_profiles
for each row execute function public.srk_guard_electrician_kyc_before_activation();

create or replace function public.srk_admin_set_electrician_active(p_profile_id uuid,p_active boolean)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_profile public.electrician_profiles%rowtype;
  v_identity_status text;
  v_address_status text;
  v_booking_id uuid;
  v_closed integer:=0;
  v_previous_available boolean;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501';
  end if;
  if p_profile_id is null or p_active is null then
    raise exception 'PROFILE_ID_AND_ACTIVE_STATE_REQUIRED' using errcode='22023';
  end if;

  select * into v_profile
  from public.electrician_profiles p
  where p.id=p_profile_id
  for update;
  if not found then raise exception 'ELECTRICIAN_PROFILE_NOT_FOUND' using errcode='P0002'; end if;

  if p_active then
    if v_profile.active is true then
      return jsonb_build_object('success',true,'active',true,'already_in_state',true);
    end if;
    if v_profile.verification_status is distinct from 'approved'
       or v_profile.user_id is null or v_profile.auth_user_id is distinct from v_profile.user_id
       or not exists(
         select 1 from auth.users u
         where u.id=v_profile.user_id and u.phone_confirmed_at is not null
           and right(regexp_replace(coalesce(u.phone,''),'[^0-9]','','g'),10)
               =right(regexp_replace(coalesce(v_profile.phone,''),'[^0-9]','','g'),10)
       ) then
      raise exception 'ELECTRICIAN_APPLICATION_PHONE_OTP_AND_APPROVAL_REQUIRED' using errcode='55000';
    end if;
    select d.review_status into v_identity_status
    from public.srk_electrician_verification_documents d
    where d.electrician_profile_id=v_profile.id and d.document_type='identity_proof'
    order by d.uploaded_at desc,d.id desc limit 1;
    select d.review_status into v_address_status
    from public.srk_electrician_verification_documents d
    where d.electrician_profile_id=v_profile.id and d.document_type='address_proof'
    order by d.uploaded_at desc,d.id desc limit 1;
    if v_identity_status is distinct from 'approved'
       or v_address_status is distinct from 'approved' then
      raise exception 'LATEST_IDENTITY_AND_ADDRESS_KYC_DOCUMENTS_MUST_BE_APPROVED' using errcode='55000';
    end if;
    if v_profile.approved_rate_tier is null
       or v_profile.approved_rate_card_version is null
       or v_profile.rate_tier_approved_by is null
       or v_profile.rate_tier_approved_at is null then
      raise exception 'ADMIN_APPROVED_RATE_TIER_REQUIRED_BEFORE_ACTIVATION' using errcode='55000';
    end if;

    update public.electrician_profiles set active=true where id=v_profile.id;
    return jsonb_build_object('success',true,'active',true,'closed_offers_advanced',0);
  end if;

  v_previous_available:=coalesce(v_profile.available_for_work,false);
  update public.electrician_profiles
    set active=false,available_for_work=false
    where id=v_profile.id and (active is distinct from false or available_for_work is distinct from false);

  if v_previous_available then
    insert into public.srk_electrician_availability_events(
      electrician_profile_id,actor_user_id,available_for_work
    ) values(v_profile.id,auth.uid(),false);
  end if;

  for v_booking_id in
    update public.job_offers
    set status='declined',responded_at=clock_timestamp()
    where electrician_id=v_profile.id and status='offered'
    returning booking_id
  loop
    perform private.srk_dispatch_next_booking_offer(v_booking_id);
    v_closed:=v_closed+1;
  end loop;

  return jsonb_build_object('success',true,'active',false,
    'available_for_work',false,'closed_offers_advanced',v_closed);
end;
$function$;
revoke all on function public.srk_admin_set_electrician_active(uuid,boolean) from public,anon;
grant execute on function public.srk_admin_set_electrician_active(uuid,boolean) to authenticated;

comment on table public.srk_electrician_verification_documents is
  'Private electrician KYC documents. Direct client table access is revoked; use owner/Admin projections and signed private storage URLs.';
comment on table public.srk_electrician_verification_document_events is
  'Append-only KYC submission and Admin review history; no direct client access.';
