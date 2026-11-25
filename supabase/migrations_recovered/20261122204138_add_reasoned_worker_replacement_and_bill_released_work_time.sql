
create or replace function public.srk_admin_release_booking_worker(p_assignment_id uuid,p_reason text)
returns public.srk_booking_workers
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.srk_booking_workers%rowtype;
begin
  if not public.srk_has_admin_permission('bookings.manage') then raise exception 'Booking management permission required'; end if;
  if length(coalesce(p_reason,''))<10 then raise exception 'Release reason must be at least 10 characters'; end if;
  select * into v from public.srk_booking_workers where id=p_assignment_id for update;
  if not found then raise exception 'Booking worker assignment not found'; end if;
  if exists(select 1 from public.srk_worker_work_sessions where booking_worker_id=p_assignment_id and session_status='running') then
    raise exception 'Pause or complete the active timer before releasing this worker';
  end if;
  update public.srk_booking_workers set assignment_status='released',released_at=clock_timestamp(),
    admin_note=p_reason,updated_at=clock_timestamp()
  where id=p_assignment_id returning * into v;
  update public.srk_worker_schedule_blocks set block_status='cancelled',updated_at=clock_timestamp()
  where booking_worker_id=p_assignment_id and block_status in ('reserved','confirmed','in_progress');
  update public.srk_booking_matching_queue set queue_status='pending',next_attempt_at=clock_timestamp(),updated_at=clock_timestamp()
  where booking_id=v.booking_id and queue_status<>'cancelled';
  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  select user_id,'assignment_released','Booking assignment updated','Your assignment was released by Admin. Reason: '||p_reason,v.booking_id
  from public.srk_worker_profiles where id=v.worker_id;
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
  v_existing public.srk_booking_final_bills%rowtype; v_next_revision integer;
begin
  if not public.srk_has_admin_permission('bookings.manage') then raise exception 'Booking management permission required'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_booking.payment_status='paid' then raise exception 'Paid booking cannot be rebilled'; end if;
  if not exists(
    select 1 from public.srk_booking_workers bw
    where bw.booking_id=p_booking_id and bw.worker_role='technician'
      and bw.assignment_status in ('completed','released')
      and exists(select 1 from public.srk_worker_work_sessions s where s.booking_worker_id=bw.id and s.billable_seconds>0)
  ) then raise exception 'At least one Technician must have billable completed work'; end if;
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
    where bw.booking_id=p_booking_id and bw.assignment_status in ('completed','released')
    group by bw.id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot
    having coalesce(sum(s.billable_seconds),0)>0
  loop
    if v_worker.hourly_rate_snapshot is null then raise exception 'Worker rate snapshot missing'; end if;
    if v_worker.seconds>coalesce(v_booking.requested_duration_hours,1440)*3600 then
      raise exception 'Worker actual billable time exceeds booked maximum duration';
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
    where bw.booking_id=p_booking_id and bw.assignment_status in ('completed','released')
    group by bw.id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot
    having coalesce(sum(s.billable_seconds),0)>0
  loop
    v_worker_gross:=round((v_worker.seconds::numeric/3600)*v_worker.hourly_rate_snapshot,2);
    insert into public.srk_worker_earnings(booking_id,booking_worker_id,worker_id,worker_role,bill_id,billable_seconds,
      gross_service_earning,company_commission_rate,company_commission,net_earning,payment_method,payout_status,settlement_status)
    values(p_booking_id,v_worker.booking_worker_id,v_worker.worker_id,v_worker.worker_role,v_bill.id,v_worker.seconds,
      v_worker_gross,15.00,round(v_worker_gross*0.15,2),v_worker_gross-round(v_worker_gross*0.15,2),
      case when lower(v_booking.payment_method) in ('upi','card') then 'online' else lower(v_booking.payment_method) end,'pending','pending')
    on conflict(booking_worker_id) do update set bill_id=excluded.bill_id,billable_seconds=excluded.billable_seconds,
      gross_service_earning=excluded.gross_service_earning,company_commission_rate=excluded.company_commission_rate,
      company_commission=excluded.company_commission,net_earning=excluded.net_earning,payment_method=excluded.payment_method,
      payout_status='pending',settlement_status='pending',updated_at=clock_timestamp();
  end loop;
  return v_bill;
end $$;

revoke all on function public.srk_admin_release_booking_worker(uuid,text) from public,anon;
grant execute on function public.srk_admin_release_booking_worker(uuid,text) to authenticated;
