-- Keep booking details and phone numbers hidden from offered workers.
-- Mobile apps use these narrowly scoped RPCs; contacts are returned only after acceptance.
drop policy if exists srk_booking_participant_read on public.service_bookings;
create policy srk_booking_participant_read
on public.service_bookings
for select
to authenticated
using (
  is_srk_admin()
  or srk_has_admin_permission('bookings.manage')
  or customer_user_id = (select auth.uid())
);

create or replace function public.srk_worker_get_my_assignments()
returns table (
  assignment_id uuid,
  booking_id uuid,
  worker_role text,
  assignment_status text,
  offer_expires_at timestamptz,
  service_type text,
  booking_status text,
  state text,
  district text,
  pincode text,
  address text,
  booking_latitude double precision,
  booking_longitude double precision,
  requested_duration_hours integer,
  pricing_unit_snapshot text,
  work_start_approval_status text,
  work_start_requested_at timestamptz,
  completion_approval_status text,
  completion_requested_at timestamptz,
  payment_method text,
  payment_status text,
  final_bill_id uuid,
  final_bill_number text,
  final_bill_total numeric,
  final_bill_status text
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v_worker_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;

  select w.id into v_worker_id
  from public.srk_worker_profiles w
  where w.user_id = auth.uid()
    and w.verification_status = 'approved'
    and w.is_active = true
  limit 1;

  if v_worker_id is null then
    raise exception 'Approved active Worker profile required' using errcode='42501';
  end if;

  return query
  select
    bw.id,
    b.id,
    bw.worker_role,
    bw.assignment_status,
    bw.offer_expires_at,
    b.service_type,
    b.status,
    b.state,
    b.district,
    b.pincode,
    case when bw.assignment_status in ('accepted','assigned','working','paused','completed')
      then b.address else null end,
    case when bw.assignment_status in ('accepted','assigned','working','paused','completed')
      then b.booking_latitude else null end,
    case when bw.assignment_status in ('accepted','assigned','working','paused','completed')
      then b.booking_longitude else null end,
    b.requested_duration_hours,
    b.pricing_unit_snapshot,
    b.work_start_approval_status,
    b.work_start_requested_at,
    b.completion_approval_status,
    b.completion_requested_at,
    case when bw.assignment_status in ('accepted','assigned','working','paused','completed')
      then b.payment_method else null end,
    case when bw.assignment_status in ('accepted','assigned','working','paused','completed')
      then b.payment_status else null end,
    case when bw.assignment_status in ('accepted','assigned','working','paused','completed')
      then fb.id else null end,
    case when bw.assignment_status in ('accepted','assigned','working','paused','completed')
      then fb.bill_number else null end,
    case when bw.assignment_status in ('accepted','assigned','working','paused','completed')
      then fb.total_amount else null end,
    case when bw.assignment_status in ('accepted','assigned','working','paused','completed')
      then fb.status else null end
  from public.srk_booking_workers bw
  join public.service_bookings b on b.id = bw.booking_id
  left join lateral (
    select f.id, f.bill_number, f.total_amount, f.status
    from public.srk_booking_final_bills f
    where f.booking_id = b.id
    order by f.revision_no desc, f.created_at desc
    limit 1
  ) fb on true
  where bw.worker_id = v_worker_id
    and bw.assignment_status in ('offered','accepted','assigned','working','paused','completed')
  order by bw.assigned_at desc;
end
$function$;

create or replace function public.srk_worker_get_my_booking_customer_contacts()
returns table (
  booking_id uuid,
  booking_worker_id uuid,
  customer_name text,
  customer_phone text,
  assignment_status text
)
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
  select b.id, bw.id, b.customer_name, b.phone, bw.assignment_status
  from public.srk_booking_workers bw
  join public.srk_worker_profiles w on w.id = bw.worker_id
  join public.service_bookings b on b.id = bw.booking_id
  where auth.uid() is not null
    and w.user_id = auth.uid()
    and bw.assignment_status in ('accepted','assigned','working','paused','completed')
    and b.status <> 'cancelled'
  order by bw.assigned_at desc
  limit 100;
$function$;

create or replace function public.srk_customer_get_my_booking_worker_contacts()
returns table (
  booking_id uuid,
  booking_worker_id uuid,
  worker_role text,
  worker_name text,
  worker_phone text,
  assignment_status text
)
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
  select b.id, bw.id, bw.worker_role, w.full_name, w.phone, bw.assignment_status
  from public.service_bookings b
  join public.srk_booking_workers bw on bw.booking_id = b.id
  join public.srk_worker_profiles w on w.id = bw.worker_id
  where auth.uid() is not null
    and b.customer_user_id = auth.uid()
    and bw.assignment_status in ('accepted','assigned','working','paused','completed')
    and b.status <> 'cancelled'
  order by bw.assigned_at desc
  limit 100;
$function$;

revoke all on function public.srk_worker_get_my_assignments() from public, anon;
revoke all on function public.srk_worker_get_my_booking_customer_contacts() from public, anon;
revoke all on function public.srk_customer_get_my_booking_worker_contacts() from public, anon;
grant execute on function public.srk_worker_get_my_assignments() to authenticated;
grant execute on function public.srk_worker_get_my_booking_customer_contacts() to authenticated;
grant execute on function public.srk_customer_get_my_booking_worker_contacts() to authenticated;
