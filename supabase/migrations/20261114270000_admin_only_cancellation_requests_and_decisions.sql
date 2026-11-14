-- Customer cancellation requests and Admin-only final decisions.
-- Source-only migration: do not apply to production without approved staging verification.

create table if not exists public.srk_booking_cancellation_requests (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  customer_user_id uuid not null references auth.users(id) on delete restrict,
  customer_note text not null default '',
  request_status text not null default 'pending'
    check (request_status in ('pending','approved','rejected')),
  verified_stage text
    check (verified_stage is null or verified_stage in ('not_departed','en_route','arrived')),
  fee_amount numeric(10,2)
    check (fee_amount is null or fee_amount in (0,49,99)),
  stage_evidence text,
  admin_reason text,
  decided_by uuid references auth.users(id),
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_booking_cancellation_decision_fields check (
    (request_status = 'pending' and verified_stage is null and fee_amount is null and stage_evidence is null and admin_reason is null and decided_by is null and decided_at is null)
    or
    (request_status = 'approved' and verified_stage is not null and fee_amount is not null and length(btrim(coalesce(stage_evidence,''))) >= 10 and length(btrim(coalesce(admin_reason,''))) >= 10 and decided_by is not null and decided_at is not null)
    or
    (request_status = 'rejected' and verified_stage is null and fee_amount is null and length(btrim(coalesce(admin_reason,''))) >= 10 and decided_by is not null and decided_at is not null)
  )
);
create unique index if not exists srk_one_pending_cancellation_per_booking
  on public.srk_booking_cancellation_requests(booking_id) where request_status='pending';
create index if not exists srk_cancellation_requests_customer_created
  on public.srk_booking_cancellation_requests(customer_user_id,created_at desc);
create index if not exists srk_cancellation_requests_status_created
  on public.srk_booking_cancellation_requests(request_status,created_at);

create table if not exists public.srk_booking_cancellation_events (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.srk_booking_cancellation_requests(id) on delete restrict,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  actor_user_id uuid,
  actor_role text not null check (actor_role in ('customer','admin','system')),
  event_type text not null check (event_type in ('requested','approved','rejected')),
  event_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists srk_booking_cancellation_events_request_created
  on public.srk_booking_cancellation_events(request_id,created_at);

alter table public.srk_booking_cancellation_requests enable row level security;
alter table public.srk_booking_cancellation_events enable row level security;
revoke all on public.srk_booking_cancellation_requests from anon, authenticated;
revoke all on public.srk_booking_cancellation_events from anon, authenticated;

create or replace function public.srk_guard_direct_booking_cancellation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id text;
begin
  if old.status is distinct from new.status and new.status = 'cancelled' then
    v_request_id := current_setting('srk.cancel_request_id', true);
    if v_request_id is null or not exists (
      select 1 from public.srk_booking_cancellation_requests r
      where r.id::text = v_request_id
        and r.booking_id = new.id
        and r.request_status = 'approved'
    ) then
      raise exception 'CANCELLATION_REQUIRES_ADMIN_DECISION';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists srk_guard_direct_booking_cancellation on public.service_bookings;
create trigger srk_guard_direct_booking_cancellation
before update of status on public.service_bookings
for each row execute function public.srk_guard_direct_booking_cancellation();

create or replace function public.srk_guard_cancellation_event_immutable()
returns trigger language plpgsql set search_path = ''
as $$
begin
  raise exception 'CANCELLATION_EVENT_HISTORY_IS_APPEND_ONLY';
end;
$$;
drop trigger if exists srk_booking_cancellation_events_no_mutation on public.srk_booking_cancellation_events;
create trigger srk_booking_cancellation_events_no_mutation
before update or delete or truncate on public.srk_booking_cancellation_events
for each statement execute function public.srk_guard_cancellation_event_immutable();

create or replace function public.srk_customer_request_booking_cancellation(
  p_booking_id uuid,
  p_customer_note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_booking public.service_bookings%rowtype;
  v_request public.srk_booking_cancellation_requests%rowtype;
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED'; end if;
  if length(btrim(coalesce(p_customer_note,''))) > 1000 then raise exception 'CUSTOMER_NOTE_TOO_LONG'; end if;

  select * into v_booking
  from public.service_bookings
  where id=p_booking_id and customer_user_id=v_uid
  for update;
  if not found then raise exception 'BOOKING_NOT_FOUND_OR_NOT_OWNED'; end if;
  if v_booking.status in ('completed','cancelled') then raise exception 'BOOKING_NOT_CANCELLABLE'; end if;

  select * into v_request from public.srk_booking_cancellation_requests
  where booking_id=p_booking_id and request_status='pending'
  order by created_at desc limit 1;
  if found then
    return jsonb_build_object('success',true,'request_id',v_request.id,'request_status','pending','already_pending',true);
  end if;

  insert into public.srk_booking_cancellation_requests(booking_id,customer_user_id,customer_note)
  values(p_booking_id,v_uid,btrim(coalesce(p_customer_note,'')))
  returning * into v_request;

  insert into public.srk_booking_cancellation_events(request_id,booking_id,actor_user_id,actor_role,event_type,event_data)
  values(v_request.id,p_booking_id,v_uid,'customer','requested',
    jsonb_build_object('customer_note',v_request.customer_note,'booking_status_at_request',v_booking.status,
      'assigned_electrician_id_present',v_booking.assigned_electrician_id is not null));

  return jsonb_build_object('success',true,'request_id',v_request.id,'request_status','pending','already_pending',false);
exception when unique_violation then
  select * into v_request from public.srk_booking_cancellation_requests
  where booking_id=p_booking_id and request_status='pending'
  order by created_at desc limit 1;
  if found then return jsonb_build_object('success',true,'request_id',v_request.id,'request_status','pending','already_pending',true); end if;
  raise;
end;
$$;

create or replace function public.srk_customer_list_booking_cancellation_requests()
returns setof jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id',r.id,'booking_id',r.booking_id,'request_status',r.request_status,
    'verified_stage',r.verified_stage,'fee_amount',r.fee_amount,
    'stage_evidence',r.stage_evidence,'admin_reason',r.admin_reason,
    'customer_note',r.customer_note,'created_at',r.created_at,'decided_at',r.decided_at
  )
  from public.srk_booking_cancellation_requests r
  where r.customer_user_id=auth.uid()
  order by r.created_at desc;
$$;

create or replace function public.srk_admin_list_booking_cancellation_requests()
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_srk_admin() then raise exception 'ADMIN_ONLY'; end if;
  return query
  select jsonb_build_object(
    'id',r.id,'booking_id',r.booking_id,'customer_user_id',r.customer_user_id,
    'customer_note',r.customer_note,'request_status',r.request_status,
    'verified_stage',r.verified_stage,'fee_amount',r.fee_amount,
    'stage_evidence',r.stage_evidence,'admin_reason',r.admin_reason,
    'created_at',r.created_at,'decided_at',r.decided_at,
    'booking',jsonb_build_object('customer_name',b.customer_name,'phone',b.phone,
      'service_type',b.service_type,'address',b.address,'district',b.district,
      'state',b.state,'pincode',b.pincode,'status',b.status,
      'assigned_electrician_id',b.assigned_electrician_id,
      'preferred_date',b.preferred_date,'preferred_time',b.preferred_time)
  )
  from public.srk_booking_cancellation_requests r
  join public.service_bookings b on b.id=r.booking_id
  order by case when r.request_status='pending' then 0 else 1 end, r.created_at desc
  limit 500;
end;
$$;

create or replace function public.srk_admin_decide_booking_cancellation(
  p_request_id uuid,
  p_decision text,
  p_verified_stage text default null,
  p_stage_evidence text default null,
  p_admin_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.srk_booking_cancellation_requests%rowtype;
  v_fee numeric(10,2);
  v_reason text := btrim(coalesce(p_admin_reason,''));
  v_evidence text := btrim(coalesce(p_stage_evidence,''));
begin
  if not public.is_srk_admin() then raise exception 'ADMIN_ONLY'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'INVALID_DECISION'; end if;
  if length(v_reason)<10 or length(v_reason)>1000 then raise exception 'ADMIN_REASON_REQUIRED_10_TO_1000'; end if;

  select * into v_request from public.srk_booking_cancellation_requests
  where id=p_request_id for update;
  if not found then raise exception 'CANCELLATION_REQUEST_NOT_FOUND'; end if;
  if v_request.request_status <> 'pending' then raise exception 'CANCELLATION_REQUEST_ALREADY_DECIDED'; end if;

  if p_decision='approved' then
    if p_verified_stage not in ('not_departed','en_route','arrived') then raise exception 'INVALID_VERIFIED_STAGE'; end if;
    if length(v_evidence)<10 or length(v_evidence)>1000 then raise exception 'STAGE_EVIDENCE_REQUIRED_10_TO_1000'; end if;
    v_fee := case p_verified_stage when 'not_departed' then 0 when 'en_route' then 49 when 'arrived' then 99 end;
    update public.srk_booking_cancellation_requests
      set request_status='approved',verified_stage=p_verified_stage,fee_amount=v_fee,
          stage_evidence=v_evidence,admin_reason=v_reason,decided_by=auth.uid(),
          decided_at=now(),updated_at=now()
      where id=p_request_id;

    perform set_config('srk.cancel_request_id',v_request.id::text,true);
    update public.service_bookings set status='cancelled' where id=v_request.booking_id;
    insert into public.srk_booking_cancellation_events(request_id,booking_id,actor_user_id,actor_role,event_type,event_data)
    values(v_request.id,v_request.booking_id,auth.uid(),'admin','approved',
      jsonb_build_object('verified_stage',p_verified_stage,'fee_amount',v_fee,
        'stage_evidence',v_evidence,'admin_reason',v_reason));
  else
    update public.srk_booking_cancellation_requests
      set request_status='rejected',admin_reason=v_reason,decided_by=auth.uid(),
          decided_at=now(),updated_at=now()
      where id=p_request_id;
    insert into public.srk_booking_cancellation_events(request_id,booking_id,actor_user_id,actor_role,event_type,event_data)
    values(v_request.id,v_request.booking_id,auth.uid(),'admin','rejected',
      jsonb_build_object('admin_reason',v_reason));
  end if;
  return jsonb_build_object('success',true,'request_id',v_request.id,'decision',p_decision,'fee_amount',v_fee);
end;
$$;

revoke all on function public.srk_customer_request_booking_cancellation(uuid,text) from public, anon;
revoke all on function public.srk_customer_list_booking_cancellation_requests() from public, anon;
revoke all on function public.srk_admin_list_booking_cancellation_requests() from public, anon;
revoke all on function public.srk_admin_decide_booking_cancellation(uuid,text,text,text,text) from public, anon;
grant execute on function public.srk_customer_request_booking_cancellation(uuid,text) to authenticated;
grant execute on function public.srk_customer_list_booking_cancellation_requests() to authenticated;
grant execute on function public.srk_admin_list_booking_cancellation_requests() to authenticated;
grant execute on function public.srk_admin_decide_booking_cancellation(uuid,text,text,text,text) to authenticated;
