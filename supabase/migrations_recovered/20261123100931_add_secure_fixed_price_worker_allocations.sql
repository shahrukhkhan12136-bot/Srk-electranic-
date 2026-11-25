
create table if not exists public.srk_fixed_price_worker_allocations (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  booking_worker_id uuid not null references public.srk_booking_workers(id) on delete restrict,
  worker_id uuid not null references public.srk_worker_profiles(id) on delete restrict,
  gross_service_earning numeric(12,2) not null,
  allocation_reason text not null,
  allocated_by uuid not null,
  allocated_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  constraint srk_fixed_alloc_amount_nonnegative check (gross_service_earning >= 0),
  constraint srk_fixed_alloc_reason_valid check (length(btrim(allocation_reason)) between 10 and 2000),
  constraint srk_fixed_alloc_booking_worker_unique unique (booking_worker_id),
  constraint srk_fixed_alloc_id_booking_worker_unique unique (id, booking_worker_id)
);

create table if not exists public.srk_fixed_price_worker_allocation_events (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  event_type text not null check (event_type in ('created','replaced')),
  previous_allocations jsonb not null default '[]'::jsonb,
  new_allocations jsonb not null,
  reason text not null,
  actor_user_id uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  constraint srk_fixed_alloc_event_reason_valid check (length(btrim(reason)) between 10 and 2000),
  constraint srk_fixed_alloc_event_new_array check (jsonb_typeof(new_allocations) = 'array'),
  constraint srk_fixed_alloc_event_previous_array check (jsonb_typeof(previous_allocations) = 'array')
);

alter table public.srk_fixed_price_worker_allocations enable row level security;
alter table public.srk_fixed_price_worker_allocation_events enable row level security;
revoke all on public.srk_fixed_price_worker_allocations from public, anon, authenticated;
revoke all on public.srk_fixed_price_worker_allocation_events from public, anon, authenticated;

create or replace function public.srk_admin_set_fixed_price_worker_allocations(
  p_booking_id uuid,
  p_allocations jsonb,
  p_reason text
)
returns integer
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
  v_booking public.service_bookings%rowtype;
  v_rule public.srk_service_pricing_rules%rowtype;
  v_expected numeric(12,2);
  v_total numeric(12,2);
  v_count integer;
  v_old jsonb;
  v_new jsonb;
  v_event_type text;
begin
  if auth.uid() is null or not public.srk_has_admin_permission('bookings.manage') then
    raise exception 'Booking management permission required' using errcode='42501';
  end if;
  if p_booking_id is null
     or p_allocations is null
     or jsonb_typeof(p_allocations) <> 'array'
     or jsonb_array_length(p_allocations) = 0
     or p_reason is null
     or length(btrim(p_reason)) not between 10 and 2000 then
    raise exception 'Booking, non-empty allocation array and reason (10-2000 characters) are required'
      using errcode='22023';
  end if;

  select * into v_booking
  from public.service_bookings
  where id=p_booking_id
  for update;
  if not found then raise exception 'Booking not found'; end if;

  if v_booking.status is distinct from 'in_progress'
     or v_booking.completion_approval_status is distinct from 'pending'
     or v_booking.completion_requested_at is null
     or coalesce(v_booking.work_timer_running,false) then
    raise exception 'Allocations are allowed only after work completion is submitted for Customer review';
  end if;

  if v_booking.pricing_unit_snapshot is distinct from 'per_item'
     or v_booking.pricing_rule_id is null
     or v_booking.pricing_quantity is null
     or v_booking.pricing_quantity <= 0 then
    raise exception 'This allocation RPC currently supports only valid per-item fixed-price bookings';
  end if;

  select * into v_rule
  from public.srk_service_pricing_rules
  where id=v_booking.pricing_rule_id
    and pricing_unit='per_item'
    and effective_to is null
  for share;
  if not found or v_rule.technician_rate is null or v_rule.technician_rate <= 0 then
    raise exception 'Current per-item pricing snapshot is missing or invalid';
  end if;

  v_expected := round(v_rule.technician_rate * v_booking.pricing_quantity,2);
  if v_expected <= 0 then raise exception 'Expected fixed service amount must be positive'; end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid, gross_amount numeric)
    where x.booking_worker_id is null or x.gross_amount is null
       or x.gross_amount < 0 or x.gross_amount <> round(x.gross_amount,2)
  ) then
    raise exception 'Each allocation requires a booking_worker_id and a non-negative two-decimal gross_amount';
  end if;

  select count(*),coalesce(sum(x.gross_amount),0)
    into v_count,v_total
  from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid, gross_amount numeric);

  if v_count <> jsonb_array_length(p_allocations)
     or (select count(distinct x.booking_worker_id)
         from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid, gross_amount numeric)) <> v_count then
    raise exception 'Duplicate or malformed worker allocation entries are not allowed';
  end if;

  if v_total <> v_expected then
    raise exception 'Worker allocation total (%) must exactly equal fixed service amount (%)',v_total,v_expected;
  end if;

  if exists (
    select 1
    from public.srk_booking_workers bw
    where bw.booking_id=p_booking_id
      and bw.assignment_status in ('completed','released')
      and not exists (
        select 1
        from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid, gross_amount numeric)
        where x.booking_worker_id=bw.id
      )
  ) or exists (
    select 1
    from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid, gross_amount numeric)
    left join public.srk_booking_workers bw
      on bw.id=x.booking_worker_id and bw.booking_id=p_booking_id
     and bw.assignment_status in ('completed','released')
    where bw.id is null
  ) then
    raise exception 'Allocation must include every completed/released assigned worker and no other worker';
  end if;

  select coalesce(jsonb_agg(to_jsonb(a) order by a.booking_worker_id),'[]'::jsonb)
    into v_old
  from public.srk_fixed_price_worker_allocations a
  where a.booking_id=p_booking_id;

  select case when count(*)=0 then 'created' else 'replaced' end
    into v_event_type
  from public.srk_fixed_price_worker_allocations
  where booking_id=p_booking_id;

  delete from public.srk_fixed_price_worker_allocations
  where booking_id=p_booking_id;

  insert into public.srk_fixed_price_worker_allocations(
    booking_id,booking_worker_id,worker_id,gross_service_earning,
    allocation_reason,allocated_by
  )
  select p_booking_id,bw.id,bw.worker_id,x.gross_amount,
    btrim(p_reason),auth.uid()
  from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid, gross_amount numeric)
  join public.srk_booking_workers bw
    on bw.id=x.booking_worker_id and bw.booking_id=p_booking_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'booking_worker_id',a.booking_worker_id,
    'worker_id',a.worker_id,
    'worker_role',bw.worker_role,
    'gross_service_earning',a.gross_service_earning
  ) order by a.booking_worker_id),'[]'::jsonb)
  into v_new
  from public.srk_fixed_price_worker_allocations a
  join public.srk_booking_workers bw on bw.id=a.booking_worker_id
  where a.booking_id=p_booking_id;

  insert into public.srk_fixed_price_worker_allocation_events(
    booking_id,event_type,previous_allocations,new_allocations,reason,actor_user_id
  ) values (
    p_booking_id,v_event_type,v_old,v_new,btrim(p_reason),auth.uid()
  );

  return v_count;
end;
$function$;

revoke all on function public.srk_admin_set_fixed_price_worker_allocations(uuid,jsonb,text) from public,anon;
grant execute on function public.srk_admin_set_fixed_price_worker_allocations(uuid,jsonb,text) to authenticated;
