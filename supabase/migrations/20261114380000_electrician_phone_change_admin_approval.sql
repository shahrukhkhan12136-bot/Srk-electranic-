-- Two-stage electrician phone change: OTP first, Admin final approval second.
-- Source-only until the final consolidated test/release gate.

create table if not exists public.srk_electrician_phone_change_requests (
  id uuid primary key,
  electrician_user_id uuid not null references auth.users(id) on delete cascade,
  electrician_profile_id uuid not null references public.electrician_profiles(id) on delete cascade,
  old_phone text not null,
  new_phone text not null,
  reason text not null,
  otp_hash text,
  otp_expires_at timestamptz,
  otp_attempts integer not null default 0 check (otp_attempts between 0 and 5),
  otp_verified_at timestamptz,
  status text not null default 'otp_pending'
    check (status in ('otp_pending','pending_admin','processing','approved','rejected','expired','sync_error')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_phone_change_reason_length check (char_length(btrim(reason)) between 10 and 500),
  constraint srk_phone_change_note_length check (admin_note is null or char_length(admin_note) <= 1000),
  constraint srk_phone_change_phones_differ check (old_phone <> new_phone)
);

create unique index if not exists srk_phone_change_one_open_per_electrician
  on public.srk_electrician_phone_change_requests(electrician_user_id)
  where status in ('otp_pending','pending_admin','processing','sync_error');

create unique index if not exists srk_phone_change_one_open_new_phone
  on public.srk_electrician_phone_change_requests(new_phone)
  where status in ('otp_pending','pending_admin','processing','sync_error');

create index if not exists srk_phone_change_admin_queue_idx
  on public.srk_electrician_phone_change_requests(status, created_at desc);

alter table public.srk_electrician_phone_change_requests enable row level security;
revoke all on public.srk_electrician_phone_change_requests from public, anon, authenticated;
grant select, insert, update, delete on public.srk_electrician_phone_change_requests to service_role;

create or replace function public.srk_phone_change_prepare(
  p_request_id uuid,
  p_user_id uuid,
  p_new_phone text,
  p_reason text,
  p_otp_hash text,
  p_otp_expires_at timestamptz
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.electrician_profiles%rowtype;
  v_old_phone text;
  v_new_digits text;
  v_count integer;
begin
  if p_request_id is null or p_user_id is null
     or p_new_phone !~ '^\+91[6-9][0-9]{9}$'
     or p_otp_hash is null or length(p_otp_hash) < 32
     or p_otp_expires_at <= now() or p_otp_expires_at > now() + interval '6 minutes'
     or char_length(btrim(coalesce(p_reason,''))) not between 10 and 500 then
    raise exception 'कृपया सही मोबाइल नंबर और 10 से 500 अक्षरों का कारण दें।';
  end if;

  select * into v_profile
  from public.electrician_profiles ep
  where ep.user_id = p_user_id or ep.auth_user_id = p_user_id
  order by (ep.user_id = p_user_id) desc nulls last
  limit 1
  for update;

  if not found then
    raise exception 'इलेक्ट्रिशियन प्रोफ़ाइल नहीं मिली।';
  end if;

  select u.phone into v_old_phone from auth.users u where u.id = p_user_id and u.phone_confirmed_at is not null;
  if v_old_phone is null or v_old_phone = '' then
    raise exception 'मौजूदा सत्यापित लॉगिन मोबाइल नंबर उपलब्ध नहीं है।';
  end if;
  if regexp_replace(v_old_phone,'[^0-9]','','g') = regexp_replace(p_new_phone,'[^0-9]','','g') then
    raise exception 'नया नंबर मौजूदा नंबर से अलग होना चाहिए।';
  end if;

  v_new_digits := regexp_replace(p_new_phone,'[^0-9]','','g');
  if exists (
    select 1 from auth.users u
    where u.id <> p_user_id
      and regexp_replace(coalesce(u.phone,''),'[^0-9]','','g') = v_new_digits
  ) or exists (
    select 1 from public.electrician_profiles ep
    where ep.id <> v_profile.id
      and regexp_replace(coalesce(ep.phone,''),'[^0-9]','','g') = v_new_digits
  ) then
    raise exception 'यह मोबाइल नंबर पहले से किसी दूसरे अकाउंट में जुड़ा है।';
  end if;

  if exists (
    select 1 from public.srk_electrician_phone_change_requests r
    where r.electrician_user_id = p_user_id
      and r.status in ('otp_pending','pending_admin','processing','sync_error')
  ) then
    raise exception 'आपकी एक मोबाइल नंबर रिक्वेस्ट पहले से लंबित है।';
  end if;

  select count(*) into v_count
  from public.srk_electrician_phone_change_requests r
  where r.electrician_user_id = p_user_id
    and r.created_at > now() - interval '1 hour';
  if v_count >= 3 then
    raise exception 'बहुत अधिक OTP अनुरोध हुए हैं। एक घंटे बाद फिर प्रयास करें।';
  end if;

  if exists (
    select 1 from public.srk_electrician_phone_change_requests r
    where r.electrician_user_id = p_user_id
      and r.created_at > now() - interval '60 seconds'
  ) then
    raise exception 'दोबारा OTP भेजने से पहले 60 सेकंड प्रतीक्षा करें।';
  end if;

  insert into public.srk_electrician_phone_change_requests(
    id,electrician_user_id,electrician_profile_id,old_phone,new_phone,reason,
    otp_hash,otp_expires_at,status
  ) values (
    p_request_id,p_user_id,v_profile.id,v_old_phone,p_new_phone,btrim(p_reason),
    p_otp_hash,p_otp_expires_at,'otp_pending'
  );

  return jsonb_build_object('success',true,'request_id',p_request_id);
end;
$$;

create or replace function public.srk_phone_change_cancel_send(
  p_request_id uuid, p_user_id uuid
) returns void
language sql
security definer
set search_path = ''
as $$
  update public.srk_electrician_phone_change_requests
  set status='expired', otp_hash=null, updated_at=now()
  where id=p_request_id and electrician_user_id=p_user_id and status='otp_pending';
$$;

create or replace function public.srk_phone_change_verify(
  p_request_id uuid,
  p_user_id uuid,
  p_otp_hash text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.srk_electrician_phone_change_requests%rowtype;
begin
  select * into v_row
  from public.srk_electrician_phone_change_requests
  where id=p_request_id and electrician_user_id=p_user_id
  for update;

  if not found or v_row.status <> 'otp_pending' then
    return jsonb_build_object('success',false,'message','OTP अनुरोध उपलब्ध नहीं है या पहले ही उपयोग हो चुका है।');
  end if;
  if v_row.otp_expires_at is null or v_row.otp_expires_at <= now() or v_row.otp_attempts >= 5 then
    update public.srk_electrician_phone_change_requests
    set status='expired',otp_hash=null,updated_at=now()
    where id=p_request_id;
    return jsonb_build_object('success',false,'message','OTP समाप्त हो गया है। नया OTP लेकर फिर प्रयास करें।');
  end if;
  if v_row.otp_hash is distinct from p_otp_hash then
    update public.srk_electrician_phone_change_requests
    set otp_attempts=otp_attempts+1,
        status=case when otp_attempts+1 >= 5 then 'expired' else status end,
        otp_hash=case when otp_attempts+1 >= 5 then null else otp_hash end,
        updated_at=now()
    where id=p_request_id;
    return jsonb_build_object('success',false,'message','OTP गलत है। कृपया फिर जाँचें।');
  end if;

  update public.srk_electrician_phone_change_requests
  set status='pending_admin',otp_hash=null,otp_expires_at=null,
      otp_verified_at=now(),updated_at=now()
  where id=p_request_id;

  return jsonb_build_object('success',true,'status','pending_admin');
end;
$$;

create or replace function public.srk_phone_change_my_requests(p_user_id uuid)
returns table(
  id uuid, old_phone text, new_phone text, reason text, status text,
  otp_verified_at timestamptz, otp_expires_at timestamptz,
  created_at timestamptz, reviewed_at timestamptz, admin_note text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.srk_electrician_phone_change_requests r
  set status='expired',otp_hash=null,updated_at=now()
  where r.electrician_user_id=p_user_id and r.status='otp_pending'
    and r.otp_expires_at <= now();

  return query
  select r.id,r.old_phone,r.new_phone,r.reason,r.status,r.otp_verified_at,
         r.otp_expires_at,r.created_at,r.reviewed_at,r.admin_note
  from public.srk_electrician_phone_change_requests r
  where r.electrician_user_id=p_user_id
  order by r.created_at desc
  limit 20;
end;
$$;

create or replace function public.srk_admin_list_electrician_phone_change_requests()
returns table(
  id uuid, electrician_user_id uuid, electrician_profile_id uuid,
  electrician_name text, old_phone text, new_phone text, reason text,
  otp_verified_at timestamptz, created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  select r.id,r.electrician_user_id,r.electrician_profile_id,
         ep.display_name,r.old_phone,r.new_phone,r.reason,r.otp_verified_at,r.created_at
  from public.srk_electrician_phone_change_requests r
  join public.electrician_profiles ep on ep.id=r.electrician_profile_id
  where r.status='pending_admin'
  order by r.created_at asc;
end;
$$;

create or replace function public.srk_admin_claim_electrician_phone_change(
  p_request_id uuid,p_admin_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.srk_electrician_phone_change_requests%rowtype;
declare v_digits text;
begin
  if not exists(select 1 from public.srk_admin_users a where a.user_id=p_admin_id) then
    raise exception 'Admin अनुमति आवश्यक है।';
  end if;
  select * into v_row from public.srk_electrician_phone_change_requests
  where id=p_request_id for update;
  if not found or v_row.status not in ('pending_admin','sync_error') or v_row.otp_verified_at is null then
    raise exception 'यह रिक्वेस्ट अब लंबित या OTP-सत्यापित नहीं है।';
  end if;
  v_digits:=regexp_replace(v_row.new_phone,'[^0-9]','','g');
  if exists(select 1 from auth.users u where u.id<>v_row.electrician_user_id
            and regexp_replace(coalesce(u.phone,''),'[^0-9]','','g')=v_digits)
     or exists(select 1 from public.electrician_profiles ep
               where ep.id<>v_row.electrician_profile_id
                 and regexp_replace(coalesce(ep.phone,''),'[^0-9]','','g')=v_digits) then
    raise exception 'नया मोबाइल नंबर अब किसी दूसरे अकाउंट में जुड़ा हुआ है।';
  end if;
  update public.srk_electrician_phone_change_requests
  set status='processing',reviewed_by=p_admin_id,reviewed_at=now(),updated_at=now()
  where id=p_request_id;
  return jsonb_build_object(
    'success',true,'request_id',v_row.id,'user_id',v_row.electrician_user_id,
    'profile_id',v_row.electrician_profile_id,'old_phone',v_row.old_phone,
    'new_phone',v_row.new_phone
  );
end;
$$;

create or replace function public.srk_admin_finalize_electrician_phone_change(
  p_request_id uuid,p_admin_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.srk_electrician_phone_change_requests%rowtype;
begin
  if not exists(select 1 from public.srk_admin_users a where a.user_id=p_admin_id) then
    raise exception 'Admin अनुमति आवश्यक है।';
  end if;
  select * into v_row from public.srk_electrician_phone_change_requests
  where id=p_request_id for update;
  if not found or v_row.status <> 'processing' or v_row.reviewed_by<>p_admin_id then
    raise exception 'मोबाइल अपडेट की प्रक्रिया की स्थिति मेल नहीं खाती।';
  end if;
  update public.electrician_profiles
  set phone=v_row.new_phone
  where id=v_row.electrician_profile_id
    and (user_id=v_row.electrician_user_id or auth_user_id=v_row.electrician_user_id);
  if not found then
    raise exception 'इलेक्ट्रिशियन प्रोफ़ाइल अपडेट नहीं हो सकी।';
  end if;
  update public.srk_electrician_phone_change_requests
  set status='approved',admin_note=null,updated_at=now()
  where id=p_request_id;
  return jsonb_build_object('success',true,'status','approved');
end;
$$;

create or replace function public.srk_admin_release_electrician_phone_change(
  p_request_id uuid,p_admin_id uuid,p_sync_error boolean default false
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists(select 1 from public.srk_admin_users a where a.user_id=p_admin_id) then
    raise exception 'Admin अनुमति आवश्यक है।';
  end if;
  update public.srk_electrician_phone_change_requests
  set status=case when p_sync_error then 'sync_error' else 'pending_admin' end,
      reviewed_by=null,reviewed_at=null,updated_at=now()
  where id=p_request_id and status='processing' and reviewed_by=p_admin_id;
end;
$$;

create or replace function public.srk_admin_reject_electrician_phone_change(
  p_request_id uuid,p_admin_id uuid,p_note text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists(select 1 from public.srk_admin_users a where a.user_id=p_admin_id) then
    raise exception 'Admin अनुमति आवश्यक है।';
  end if;
  if char_length(btrim(coalesce(p_note,''))) not between 5 and 1000 then
    raise exception 'अस्वीकृति का कारण कम से कम 5 अक्षरों का लिखें।';
  end if;
  update public.srk_electrician_phone_change_requests
  set status='rejected',reviewed_by=p_admin_id,reviewed_at=now(),
      admin_note=btrim(p_note),otp_hash=null,updated_at=now()
  where id=p_request_id and status in ('pending_admin','sync_error') and otp_verified_at is not null;
  if not found then raise exception 'यह रिक्वेस्ट अब लंबित नहीं है।'; end if;
  return jsonb_build_object('success',true,'status','rejected');
end;
$$;

revoke all on function public.srk_phone_change_prepare(uuid,uuid,text,text,text,timestamptz) from public,anon,authenticated;
revoke all on function public.srk_phone_change_cancel_send(uuid,uuid) from public,anon,authenticated;
revoke all on function public.srk_phone_change_verify(uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.srk_phone_change_my_requests(uuid) from public,anon,authenticated;
revoke all on function public.srk_admin_list_electrician_phone_change_requests() from public,anon,authenticated;
revoke all on function public.srk_admin_claim_electrician_phone_change(uuid,uuid) from public,anon,authenticated;
revoke all on function public.srk_admin_finalize_electrician_phone_change(uuid,uuid) from public,anon,authenticated;
revoke all on function public.srk_admin_release_electrician_phone_change(uuid,uuid,boolean) from public,anon,authenticated;
revoke all on function public.srk_admin_reject_electrician_phone_change(uuid,uuid,text) from public,anon,authenticated;

grant execute on function public.srk_phone_change_prepare(uuid,uuid,text,text,text,timestamptz) to service_role;
grant execute on function public.srk_phone_change_cancel_send(uuid,uuid) to service_role;
grant execute on function public.srk_phone_change_verify(uuid,uuid,text) to service_role;
grant execute on function public.srk_phone_change_my_requests(uuid) to service_role;
grant execute on function public.srk_admin_list_electrician_phone_change_requests() to service_role;
grant execute on function public.srk_admin_claim_electrician_phone_change(uuid,uuid) to service_role;
grant execute on function public.srk_admin_finalize_electrician_phone_change(uuid,uuid) to service_role;
grant execute on function public.srk_admin_release_electrician_phone_change(uuid,uuid,boolean) to service_role;
grant execute on function public.srk_admin_reject_electrician_phone_change(uuid,uuid,text) to service_role;
