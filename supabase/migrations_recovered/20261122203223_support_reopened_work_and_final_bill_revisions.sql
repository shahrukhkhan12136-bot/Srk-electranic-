
-- Allow multiple completed work segments on the same day, but only one open segment per worker/booking/day.
alter table public.srk_worker_work_sessions
  drop constraint if exists srk_worker_work_sessions_booking_worker_id_work_date_key;
create unique index if not exists srk_worker_one_open_session_per_day
  on public.srk_worker_work_sessions(booking_worker_id,work_date)
  where session_status in ('not_started','running','paused');

alter table public.srk_booking_final_bills
  drop constraint if exists srk_booking_final_bills_booking_id_key,
  add column if not exists revision_no integer not null default 1;

create unique index if not exists srk_booking_one_current_final_bill
  on public.srk_booking_final_bills(booking_id)
  where status in ('issued','approved','disputed');

create table if not exists public.srk_booking_final_bill_revisions (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references public.srk_booking_final_bills(id) on delete restrict,
  revision_no integer not null,
  previous_bill_data jsonb not null,
  previous_items jsonb not null default '[]'::jsonb,
  reason text,
  archived_by uuid,
  archived_at timestamptz not null default now(),
  constraint srk_booking_bill_revision_unique unique(bill_id,revision_no)
);
alter table public.srk_booking_final_bill_revisions enable row level security;
create policy srk_booking_bill_revisions_admin_read on public.srk_booking_final_bill_revisions
for select to authenticated using(public.is_srk_admin());

create or replace function public.srk_worker_open_work_session(
 p_booking_worker_id uuid,p_work_date date default (now() at time zone 'Asia/Kolkata')::date
) returns public.srk_worker_work_sessions
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_session public.srk_worker_work_sessions%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_work_date<>(now() at time zone 'Asia/Kolkata')::date then
    raise exception 'Live timer session must use current India date; use offline sync for past events';
  end if;
  if not exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles wp on wp.id=bw.worker_id
    where bw.id=p_booking_worker_id and wp.user_id=auth.uid()
      and bw.assignment_status in ('accepted','assigned','working','paused')) then
    raise exception 'You do not have an accepted assignment';
  end if;
  select * into v_session from public.srk_worker_work_sessions
  where booking_worker_id=p_booking_worker_id and work_date=p_work_date
    and session_status in ('not_started','running','paused')
  order by created_at desc limit 1;
  if found then return v_session; end if;

  insert into public.srk_worker_work_sessions(booking_worker_id,work_date)
  values(p_booking_worker_id,p_work_date) returning * into v_session;
  return v_session;
end $$;

create or replace function public.srk_admin_reopen_booking_work(
 p_booking_id uuid,p_booking_worker_id uuid,p_reason text
) returns public.srk_booking_workers
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_booking public.service_bookings%rowtype; v_assignment public.srk_booking_workers%rowtype;
begin
  if not public.srk_has_admin_permission('bookings.manage') then raise exception 'Booking management permission required'; end if;
  if length(coalesce(p_reason,''))<10 then raise exception 'Reopen reason must be at least 10 characters'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_booking.payment_status='paid' then raise exception 'Paid booking cannot be reopened; use refund/dispute workflow'; end if;
  if v_booking.completion_approval_status not in ('rejected','disputed') then
    raise exception 'Only rejected or disputed completion can be reopened';
  end if;
  select * into v_assignment from public.srk_booking_workers
  where id=p_booking_worker_id and booking_id=p_booking_id and assignment_status='completed'
  for update;
  if not found then raise exception 'Completed worker assignment not found'; end if;

  update public.srk_booking_final_bills set status='void',updated_at=clock_timestamp()
  where booking_id=p_booking_id and status in ('issued','disputed');

  update public.srk_worker_earnings set payout_status='held',settlement_status='held',updated_at=clock_timestamp()
  where booking_id=p_booking_id;

  update public.srk_booking_workers set assignment_status='assigned',released_at=null,
    admin_note=p_reason,updated_at=clock_timestamp()
  where id=p_booking_worker_id returning * into v_assignment;

  update public.service_bookings set status='in_progress',completion_approval_status='rejected',
    completion_requested_at=null,work_timer_running=false
  where id=p_booking_id;

  insert into public.srk_booking_admin_changes(booking_id,admin_user_id,entity_type,entity_id,action,reason,
    old_values,new_values)
  values(p_booking_id,auth.uid(),'booking_worker',p_booking_worker_id,'reopen_work',p_reason,
    jsonb_build_object('assignment_status','completed'),
    jsonb_build_object('assignment_status','assigned'));

  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  select w.user_id,'work_reopened','Work reopened by Admin','Admin reopened your work assignment. Reason: '||p_reason,p_booking_id
  from public.srk_worker_profiles w where w.id=v_assignment.worker_id;
  return v_assignment;
end $$;

create or replace function public.srk_admin_finalize_booking_bill(p_booking_id uuid)
returns public.srk_booking_final_bills
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare
  v_booking public.service_bookings%rowtype; v_bill public.srk_booking_final_bills%rowtype;
  v_labour numeric(12,2):=0; v_material numeric(12,2); v_worker record; v_worker_gross numeric(12,2);
  v_existing public.srk_booking_final_bills%rowtype; v_next_revision integer;
begin
  if not public.srk_has_admin_permission('bookings.manage') then raise exception 'Booking management permission required'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_booking.payment_status='paid' then raise exception 'Paid booking cannot be rebilled'; end if;
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

  for v_worker in
    select bw.id booking_worker_id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot,
      coalesce(sum(s.billable_seconds),0)::bigint seconds
    from public.srk_booking_workers bw left join public.srk_worker_work_sessions s on s.booking_worker_id=bw.id
    where bw.booking_id=p_booking_id and bw.assignment_status='completed'
    group by bw.id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot
  loop
    if v_worker.hourly_rate_snapshot is null then raise exception 'Worker rate snapshot missing'; end if;
    if v_worker.seconds>coalesce(v_booking.requested_duration_hours,1440)*3600 then
      raise exception 'Worker actual billable time exceeds the booked maximum duration';
    end if;
    v_worker_gross:=round((v_worker.seconds::numeric/3600)*v_worker.hourly_rate_snapshot,2);
    v_labour:=v_labour+v_worker_gross;
  end loop;
  v_material:=coalesce(v_booking.materials_amount,0);

  select * into v_existing from public.srk_booking_final_bills where booking_id=p_booking_id for update;
  if found then
    if v_existing.status in ('issued','approved','disputed') then raise exception 'An active final bill already exists'; end if;
    v_next_revision:=v_existing.revision_no+1;
    insert into public.srk_booking_final_bill_revisions(bill_id,revision_no,previous_bill_data,previous_items,reason,archived_by)
    values(v_existing.id,v_existing.revision_no,to_jsonb(v_existing),
      coalesce((select jsonb_agg(to_jsonb(i) order by i.created_at) from public.srk_booking_final_bill_items i where i.bill_id=v_existing.id),'[]'::jsonb),
      'Reissued after work reopening',auth.uid());
    delete from public.srk_booking_final_bill_items where bill_id=v_existing.id;
    update public.srk_booking_final_bills set bill_number='SRK-BILL-'||lpad(nextval('public.srk_bill_number_seq')::text,6,'0'),
      revision_no=v_next_revision,service_amount=v_labour,materials_amount=v_material,discount_amount=0,tax_amount=0,
      status='issued',prepared_at=clock_timestamp(),updated_at=clock_timestamp()
    where id=v_existing.id returning * into v_bill;
  else
    insert into public.srk_booking_final_bills(booking_id,bill_number,revision_no,service_amount,materials_amount,status,prepared_at)
    values(p_booking_id,'SRK-BILL-'||lpad(nextval('public.srk_bill_number_seq')::text,6,'0'),1,
      v_labour,v_material,'issued',clock_timestamp()) returning * into v_bill;
  end if;

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
      gross_service_earning,company_commission_rate,company_commission,net_earning,payment_method,payout_status,settlement_status)
    values(p_booking_id,v_worker.booking_worker_id,v_worker.worker_id,v_worker.worker_role,v_bill.id,v_worker.seconds,
      v_worker_gross,15.00,round(v_worker_gross*0.15,2),v_worker_gross-round(v_worker_gross*0.15,2),
      case when lower(v_booking.payment_method) in ('upi','card') then 'online' else lower(v_booking.payment_method) end,'pending','pending')
    on conflict(booking_worker_id) do update set bill_id=excluded.bill_id,billable_seconds=excluded.billable_seconds,
      gross_service_earning=excluded.gross_service_earning,company_commission_rate=excluded.company_commission_rate,
      company_commission=excluded.company_commission,net_earning=excluded.net_earning,
      payment_method=excluded.payment_method,payout_status='pending',settlement_status='pending',updated_at=clock_timestamp();
  end loop;
  return v_bill;
end $$;

revoke all on function public.srk_admin_reopen_booking_work(uuid,uuid,text) from public,anon;
grant execute on function public.srk_admin_reopen_booking_work(uuid,uuid,text) to authenticated;
