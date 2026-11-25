
alter table public.srk_booking_workers
  add column if not exists rate_id uuid references public.srk_service_rates(id) on delete restrict,
  add column if not exists hourly_rate_snapshot numeric(10,2),
  add column if not exists skill_level_snapshot_id uuid references public.srk_skill_levels(id) on delete restrict;

alter table public.srk_booking_workers
  add constraint srk_booking_worker_rate_snapshot_nonnegative
  check(hourly_rate_snapshot is null or hourly_rate_snapshot>=0);

create or replace function public.srk_admin_offer_worker_to_booking(
  p_booking_id uuid,p_worker_id uuid,p_worker_role text
) returns public.srk_booking_workers
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare
  v_booking public.service_bookings%rowtype;
  v_worker public.srk_worker_profiles%rowtype;
  v_existing integer;
  v_limit integer;
  v_assignment public.srk_booking_workers%rowtype;
  v_skill_level uuid;
  v_rate_id uuid;
  v_rate numeric(10,2);
begin
  if not coalesce(public.is_srk_admin(),false) then raise exception 'Admin permission required'; end if;
  if p_worker_role not in ('technician','helper') then raise exception 'Invalid worker role'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  select * into v_worker from public.srk_worker_profiles where id=p_worker_id for update;
  if not found then raise exception 'Worker not found'; end if;
  if v_worker.worker_type<>p_worker_role or v_worker.category_id is distinct from v_booking.category_id then
    raise exception 'Worker category or role does not match booking';
  end if;
  if v_worker.verification_status<>'approved' or not v_worker.is_active or not v_worker.is_online then
    raise exception 'Worker must be approved, active and online';
  end if;

  select ws.skill_level_id into v_skill_level
  from public.srk_worker_skills ws
  where ws.worker_id=p_worker_id and ws.skill_id=v_booking.selected_skill_id and ws.verification_status='approved'
  limit 1;
  if v_skill_level is null then raise exception 'Worker does not have the required Admin-approved skill'; end if;

  select r.id,
    case when p_worker_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end
  into v_rate_id,v_rate
  from public.srk_service_rates r
  where r.category_id=v_worker.category_id and r.skill_level_id=v_skill_level
    and (r.service_type_id is null or r.service_type_id=v_booking.service_type_id)
    and r.rate_status='approved' and r.effective_from<=clock_timestamp()
    and (r.effective_to is null or r.effective_to>clock_timestamp())
    and (case when p_worker_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end) is not null
  order by (r.service_type_id is not null) desc,r.effective_from desc limit 1;
  if v_rate is null then raise exception 'Approved hourly rate is not configured for this worker skill'; end if;

  if exists(select 1 from public.srk_worker_work_sessions s join public.srk_booking_workers bw on bw.id=s.booking_worker_id
    where bw.worker_id=p_worker_id and s.session_status='running') then
    raise exception 'Worker is already working at another booking';
  end if;

  v_limit:=case when p_worker_role='technician' then v_booking.requested_technician_count else v_booking.requested_helper_count end;
  select count(*) into v_existing from public.srk_booking_workers
  where booking_id=p_booking_id and worker_role=p_worker_role
    and assignment_status not in ('rejected','cancelled','released');
  if v_existing>=v_limit then raise exception 'Requested worker count already fulfilled'; end if;

  insert into public.srk_booking_workers
    (booking_id,worker_id,worker_role,assignment_status,offered_by,rate_id,hourly_rate_snapshot,skill_level_snapshot_id)
  values(p_booking_id,p_worker_id,p_worker_role,'offered',auth.uid(),v_rate_id,v_rate,v_skill_level)
  returning * into v_assignment;
  return v_assignment;
end $$;

create or replace function public.srk_find_eligible_workers(p_booking_id uuid,p_worker_type text)
returns table(worker_id uuid,worker_code text,worker_type text,distance_km numeric)
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_booking public.service_bookings%rowtype;
begin
  if p_worker_type not in ('technician','helper') then raise exception 'Invalid worker type'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id;
  if not found then raise exception 'Booking not found'; end if;
  if v_booking.booking_latitude is null or v_booking.booking_longitude is null then
    raise exception 'Booking Address GPS coordinates are required for 30 KM matching';
  end if;
  return query
  select w.id,w.worker_code,w.worker_type,
    round((6371*acos(least(1,greatest(-1,
      cos(radians(v_booking.booking_latitude))*cos(radians(w.location_lat))*
      cos(radians(w.location_lng)-radians(v_booking.booking_longitude))+
      sin(radians(v_booking.booking_latitude))*sin(radians(w.location_lat))
    ))))::numeric,2) as distance_km
  from public.srk_worker_profiles w
  where w.worker_type=p_worker_type
    and w.category_id=v_booking.category_id
    and w.verification_status='approved' and w.is_active and w.is_online
    and w.location_lat is not null and w.location_lng is not null
    and w.service_radius_km<=30
    and (6371*acos(least(1,greatest(-1,
      cos(radians(v_booking.booking_latitude))*cos(radians(w.location_lat))*
      cos(radians(w.location_lng)-radians(v_booking.booking_longitude))+
      sin(radians(v_booking.booking_latitude))*sin(radians(w.location_lat))
    ))))<=30
    and exists(select 1 from public.srk_worker_skills ws
      where ws.worker_id=w.id and ws.skill_id=v_booking.selected_skill_id
        and ws.verification_status='approved')
    and not exists(select 1 from public.srk_worker_work_sessions s
      join public.srk_booking_workers bw on bw.id=s.booking_worker_id
      where bw.worker_id=w.id and s.session_status='running')
    and not exists(select 1 from public.srk_worker_schedule_blocks sb
      where sb.worker_id=w.id and sb.block_status in ('reserved','confirmed','in_progress')
        and sb.starts_at<=clock_timestamp() + make_interval(hours=>coalesce(v_booking.requested_duration_hours,1))
        and sb.ends_at>clock_timestamp())
  order by distance_km,w.created_at;
end $$;

create or replace function public.srk_admin_finalize_booking_bill(p_booking_id uuid)
returns public.srk_booking_final_bills
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare
  v_booking public.service_bookings%rowtype;
  v_bill public.srk_booking_final_bills%rowtype;
  v_labour numeric(12,2):=0;
  v_material numeric(12,2);
  v_worker record;
  v_worker_gross numeric(12,2);
begin
  if not coalesce(public.is_srk_admin(),false) then raise exception 'Admin permission required'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
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
    select bw.id as booking_worker_id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot,
      coalesce(sum(s.billable_seconds),0)::bigint as seconds
    from public.srk_booking_workers bw
    left join public.srk_worker_work_sessions s on s.booking_worker_id=bw.id
    where bw.booking_id=p_booking_id and bw.assignment_status='completed'
    group by bw.id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot
  loop
    if v_worker.hourly_rate_snapshot is null then raise exception 'Worker rate snapshot is missing'; end if;
    v_worker_gross:=round((v_worker.seconds::numeric/3600)*v_worker.hourly_rate_snapshot,2);
    v_labour:=v_labour+v_worker_gross;
  end loop;

  v_material:=coalesce(v_booking.materials_amount,0);
  insert into public.srk_booking_final_bills(booking_id,bill_number,service_amount,materials_amount,status,prepared_at)
  values(p_booking_id,'SRK-BILL-'||lpad(nextval('public.srk_bill_number_seq')::text,6,'0'),
    v_labour,v_material,'issued',clock_timestamp()) returning * into v_bill;

  insert into public.srk_booking_final_bill_items(bill_id,item_type,description,quantity,unit,unit_price)
  values(v_bill.id,'labour','Actual worker timer-based labour charges',1,'booking',v_labour);
  if v_material>0 then
    insert into public.srk_booking_final_bill_items(bill_id,item_type,description,quantity,unit,unit_price)
    values(v_bill.id,'material','Materials supplied (separate from commission)',1,'booking',v_material);
  end if;

  for v_worker in
    select bw.id as booking_worker_id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot,
      coalesce(sum(s.billable_seconds),0)::bigint as seconds
    from public.srk_booking_workers bw
    left join public.srk_worker_work_sessions s on s.booking_worker_id=bw.id
    where bw.booking_id=p_booking_id and bw.assignment_status='completed'
    group by bw.id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot
  loop
    v_worker_gross:=round((v_worker.seconds::numeric/3600)*v_worker.hourly_rate_snapshot,2);
    insert into public.srk_worker_earnings
      (booking_id,booking_worker_id,worker_id,worker_role,bill_id,billable_seconds,
       gross_service_earning,company_commission_rate,company_commission,net_earning,payment_method)
    values(p_booking_id,v_worker.booking_worker_id,v_worker.worker_id,v_worker.worker_role,v_bill.id,
      v_worker.seconds,v_worker_gross,15.00,round(v_worker_gross*0.15,2),
      v_worker_gross-round(v_worker_gross*0.15,2),
      case when lower(v_booking.payment_method) in ('upi','card') then 'online' else lower(v_booking.payment_method) end);
  end loop;
  return v_bill;
end $$;

revoke all on function public.srk_find_eligible_workers(uuid,text) from public,anon,authenticated;
grant execute on function public.srk_find_eligible_workers(uuid,text) to service_role;
