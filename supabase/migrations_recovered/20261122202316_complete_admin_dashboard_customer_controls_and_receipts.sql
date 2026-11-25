
alter table public.srk_customer_profiles
  add column if not exists account_status text not null default 'active',
  add column if not exists restriction_reason text,
  add column if not exists restricted_at timestamptz,
  add constraint srk_customer_account_status_valid
  check(account_status in ('active','restricted','suspended'));

create table if not exists public.srk_booking_receipts (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null unique references public.srk_booking_final_bills(id) on delete restrict,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  storage_path text not null,
  file_name text not null,
  generated_at timestamptz not null default now(),
  generated_by uuid
);
alter table public.srk_booking_receipts enable row level security;
create policy srk_booking_receipts_participant on public.srk_booking_receipts
for select to authenticated using(
  public.is_srk_admin()
  or exists(select 1 from public.service_bookings b where b.id=booking_id and b.customer_user_id=auth.uid())
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.booking_id=booking_id and w.user_id=auth.uid())
);

create or replace function public.srk_admin_operational_dashboard()
returns jsonb
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_result jsonb;
begin
  if not public.srk_has_admin_permission('dashboard.read') then raise exception 'Dashboard permission required'; end if;
  select jsonb_build_object(
    'customers',(select count(*) from public.srk_customer_profiles),
    'technicians',(select count(*) from public.srk_worker_profiles where worker_type='technician'),
    'helpers',(select count(*) from public.srk_worker_profiles where worker_type='helper'),
    'pending_worker_applications',(select count(*) from public.srk_worker_applications where status in ('pending','under_review','more_info')),
    'approved_workers',(select count(*) from public.srk_worker_profiles where verification_status='approved' and is_active),
    'active_bookings',(select count(*) from public.service_bookings where status in ('new','confirmed','assigned','in_progress')),
    'completed_bookings',(select count(*) from public.service_bookings where status='completed'),
    'cancelled_bookings',(select count(*) from public.service_bookings where status='cancelled'),
    'unpaid_bookings',(select count(*) from public.service_bookings where payment_status in ('unpaid','pending','failed')),
    'paid_bookings',(select count(*) from public.service_bookings where payment_status='paid'),
    'pending_worker_payouts',(select count(*) from public.srk_worker_payout_requests where status in ('requested','under_review','approved')),
    'open_support_cases',(select count(*) from public.srk_support_cases where status not in ('resolved','closed')),
    'open_emergency_alerts',(select count(*) from public.srk_emergency_alerts where status not in ('resolved','false_alarm')),
    'open_payment_disputes',(select count(*) from public.srk_booking_payment_disputes where status not in ('resolved','rejected')),
    'pending_ratings',(select count(*) from public.srk_booking_ratings where moderation_status='pending')
  ) into v_result;
  return v_result;
end $$;

create or replace function public.srk_admin_set_customer_status(
  p_customer_id uuid,p_status text,p_reason text
) returns public.srk_customer_profiles
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.srk_customer_profiles%rowtype;
begin
  if not public.srk_has_admin_permission('customers.manage') then raise exception 'Customer management permission required'; end if;
  if p_status not in ('active','restricted','suspended') then raise exception 'Invalid customer status'; end if;
  update public.srk_customer_profiles set account_status=p_status,restriction_reason=p_reason,
    restricted_at=case when p_status='active' then null else clock_timestamp() end,updated_at=clock_timestamp()
  where id=p_customer_id returning * into v;
  if not found then raise exception 'Customer not found'; end if;
  insert into public.srk_app_notifications(user_id,notification_type,title,body)
  values(v.user_id,'account_status','Account status updated','Your account status is now: '||p_status);
  return v;
end $$;

create or replace function public.srk_admin_set_worker_status(
  p_worker_id uuid,p_status text,p_reason text
) returns public.srk_worker_profiles
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.srk_worker_profiles%rowtype;
begin
  if not public.srk_has_admin_permission('workers.manage') then raise exception 'Worker management permission required'; end if;
  if p_status not in ('approved','under_review','rejected','suspended') then raise exception 'Invalid worker status'; end if;
  update public.srk_worker_profiles set verification_status=p_status,is_active=(p_status='approved'),
    is_online=case when p_status='approved' then is_online else false end,
    location_lat=case when p_status='approved' then location_lat else null end,
    location_lng=case when p_status='approved' then location_lng else null end,updated_at=clock_timestamp()
  where id=p_worker_id returning * into v;
  if not found then raise exception 'Worker not found'; end if;
  insert into public.srk_app_notifications(user_id,notification_type,title,body)
  values(v.user_id,'worker_status','Worker account status updated','Your account status is now: '||p_status);
  return v;
end $$;

create or replace function public.srk_admin_finalize_booking_bill(p_booking_id uuid)
returns public.srk_booking_final_bills
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare
  v_booking public.service_bookings%rowtype; v_bill public.srk_booking_final_bills%rowtype;
  v_labour numeric(12,2):=0; v_material numeric(12,2); v_worker record; v_worker_gross numeric(12,2);
begin
  if not public.srk_has_admin_permission('bookings.manage') then raise exception 'Booking management permission required'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if not exists(select 1 from public.srk_booking_workers where booking_id=p_booking_id and worker_role='technician' and assignment_status='completed') then
    raise exception 'At least one Technician must complete work';
  end if;
  if exists(select 1 from public.srk_booking_workers where booking_id=p_booking_id and assignment_status not in ('completed','released','cancelled','rejected')) then
    raise exception 'All assigned workers must complete or be released before final billing';
  end if;
  if exists(select 1 from public.srk_worker_work_sessions s join public.srk_booking_workers bw on bw.id=s.booking_worker_id
    where bw.booking_id=p_booking_id and s.session_status not in ('completed','cancelled')) then
    raise exception 'Every work session must be completed or cancelled before final billing';
  end if;
  if exists(select 1 from public.srk_booking_final_bills where booking_id=p_booking_id and status in ('issued','approved')) then
    raise exception 'Final bill already issued';
  end if;
  for v_worker in
    select bw.id booking_worker_id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot,
      coalesce(sum(s.billable_seconds),0)::bigint seconds
    from public.srk_booking_workers bw left join public.srk_worker_work_sessions s on s.booking_worker_id=bw.id
    where bw.booking_id=p_booking_id and bw.assignment_status='completed'
    group by bw.id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot
  loop
    if v_worker.hourly_rate_snapshot is null then raise exception 'Worker rate snapshot missing'; end if;
    v_worker_gross:=round((v_worker.seconds::numeric/3600)*v_worker.hourly_rate_snapshot,2);
    v_labour:=v_labour+v_worker_gross;
  end loop;
  v_material:=coalesce(v_booking.materials_amount,0);
  insert into public.srk_booking_final_bills(booking_id,bill_number,service_amount,materials_amount,status,prepared_at)
  values(p_booking_id,'SRK-BILL-'||lpad(nextval('public.srk_bill_number_seq')::text,6,'0'),v_labour,v_material,'issued',clock_timestamp())
  returning * into v_bill;
  insert into public.srk_booking_final_bill_items(bill_id,item_type,description,quantity,unit,unit_price)
  values(v_bill.id,'labour','Actual worker timer-based labour charges',1,'booking',v_labour);
  if v_material>0 then
    insert into public.srk_booking_final_bill_items(bill_id,item_type,description,quantity,unit,unit_price)
    values(v_bill.id,'material','Materials supplied (separate from commission)',1,'booking',v_material);
  end if;
  for v_worker in
    select bw.id booking_worker_id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot,
      coalesce(sum(s.billable_seconds),0)::bigint seconds
    from public.srk_booking_workers bw left join public.srk_worker_work_sessions s on s.booking_worker_id=bw.id
    where bw.booking_id=p_booking_id and bw.assignment_status='completed'
    group by bw.id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot
  loop
    v_worker_gross:=round((v_worker.seconds::numeric/3600)*v_worker.hourly_rate_snapshot,2);
    insert into public.srk_worker_earnings(booking_id,booking_worker_id,worker_id,worker_role,bill_id,billable_seconds,
      gross_service_earning,company_commission_rate,company_commission,net_earning,payment_method)
    values(p_booking_id,v_worker.booking_worker_id,v_worker.worker_id,v_worker.worker_role,v_bill.id,v_worker.seconds,
      v_worker_gross,15.00,round(v_worker_gross*0.15,2),v_worker_gross-round(v_worker_gross*0.15,2),
      case when lower(v_booking.payment_method) in ('upi','card') then 'online' else lower(v_booking.payment_method) end);
  end loop;
  return v_bill;
end $$;

revoke all on function public.srk_admin_operational_dashboard() from public,anon;
revoke all on function public.srk_admin_set_customer_status(uuid,text,text) from public,anon;
revoke all on function public.srk_admin_set_worker_status(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_operational_dashboard() to authenticated;
grant execute on function public.srk_admin_set_customer_status(uuid,text,text) to authenticated;
grant execute on function public.srk_admin_set_worker_status(uuid,text,text) to authenticated;
