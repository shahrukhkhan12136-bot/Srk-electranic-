
alter table public.srk_worker_id_counters enable row level security;

create or replace function public.srk_log_admin_entity_change()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
declare
  v_old jsonb;
  v_new jsonb;
  v_id uuid;
  v_booking uuid;
  v_changed text[];
  v_actor_role text;
  v_reason text;
  v_key text;
begin
  if auth.uid() is null then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  if not exists(select 1 from public.srk_admin_users where user_id=auth.uid())
     and not exists(select 1 from public.srk_admin_staff_members where user_id=auth.uid() and is_active) then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;

  v_old:=case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else '{}'::jsonb end;
  v_new:=case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else '{}'::jsonb end;
  v_id:=coalesce(nullif(v_new->>'id','')::uuid,nullif(v_old->>'id','')::uuid);
  v_booking:=coalesce(nullif(v_new->>'booking_id','')::uuid,nullif(v_old->>'booking_id','')::uuid);
  v_actor_role:=case when exists(select 1 from public.srk_admin_users where user_id=auth.uid()) then 'super_admin' else 'staff' end;
  v_reason:=coalesce(v_new->>'admin_note',v_new->>'reason','Admin panel change');

  select coalesce(array_agg(k),array[]::text[]) into v_changed
  from (
    select key k from jsonb_object_keys(v_new) key
    union
    select key k from jsonb_object_keys(v_old) key
  ) keys
  where v_old->k is distinct from v_new->k;

  insert into public.srk_admin_audit_events
    (entity_type,entity_id,booking_id,action,actor_user_id,actor_role,changed_fields,before_data,after_data)
  values(tg_argv[0],v_id,v_booking,tg_op,auth.uid(),v_actor_role,v_changed,v_old,v_new);

  if v_booking is not null then
    insert into public.srk_booking_admin_changes
      (booking_id,admin_user_id,entity_type,entity_id,action,reason,old_values,new_values)
    values(v_booking,auth.uid(),tg_argv[0],v_id,tg_op,v_reason,v_old,v_new);
  end if;

  if tg_op='DELETE' then return old; else return new; end if;
end $$;

drop trigger if exists srk_audit_service_booking_admin on public.service_bookings;
create trigger srk_audit_service_booking_admin after insert or update or delete on public.service_bookings
for each row execute function public.srk_log_admin_entity_change('service_booking');

drop trigger if exists srk_audit_booking_worker_admin on public.srk_booking_workers;
create trigger srk_audit_booking_worker_admin after insert or update or delete on public.srk_booking_workers
for each row execute function public.srk_log_admin_entity_change('booking_worker');

drop trigger if exists srk_audit_worker_profile_admin on public.srk_worker_profiles;
create trigger srk_audit_worker_profile_admin after insert or update or delete on public.srk_worker_profiles
for each row execute function public.srk_log_admin_entity_change('worker_profile');

drop trigger if exists srk_audit_worker_application_admin on public.srk_worker_applications;
create trigger srk_audit_worker_application_admin after insert or update or delete on public.srk_worker_applications
for each row execute function public.srk_log_admin_entity_change('worker_application');

drop trigger if exists srk_audit_service_rate_admin on public.srk_service_rates;
create trigger srk_audit_service_rate_admin after insert or update or delete on public.srk_service_rates
for each row execute function public.srk_log_admin_entity_change('service_rate');

drop trigger if exists srk_audit_worker_payout_admin on public.srk_worker_payout_requests;
create trigger srk_audit_worker_payout_admin after insert or update or delete on public.srk_worker_payout_requests
for each row execute function public.srk_log_admin_entity_change('worker_payout');

drop trigger if exists srk_audit_support_case_admin on public.srk_support_cases;
create trigger srk_audit_support_case_admin after insert or update or delete on public.srk_support_cases
for each row execute function public.srk_log_admin_entity_change('support_case');

drop trigger if exists srk_audit_emergency_alert_admin on public.srk_emergency_alerts;
create trigger srk_audit_emergency_alert_admin after insert or update or delete on public.srk_emergency_alerts
for each row execute function public.srk_log_admin_entity_change('emergency_alert');

create or replace function public.srk_admin_review_worker_skill(
  p_worker_skill_id uuid,p_decision text,p_skill_level_id uuid,p_note text default null
) returns public.srk_worker_skills
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_skill public.srk_worker_skills%rowtype;
begin
  if not public.srk_has_admin_permission('workers.verify') then raise exception 'Worker verification permission required'; end if;
  if p_decision not in ('approved','rejected','pending') then raise exception 'Invalid skill decision'; end if;
  if p_decision='approved' and p_skill_level_id is null then raise exception 'Approved skill requires skill level'; end if;
  update public.srk_worker_skills set verification_status=p_decision,
    skill_level_id=coalesce(p_skill_level_id,skill_level_id),reviewed_by=auth.uid(),
    reviewed_at=case when p_decision='pending' then null else clock_timestamp() end,
    admin_note=p_note,updated_at=clock_timestamp()
  where id=p_worker_skill_id returning * into v_skill;
  if not found then raise exception 'Worker skill not found'; end if;
  return v_skill;
end $$;

create or replace function public.srk_admin_finalize_booking_bill(p_booking_id uuid)
returns public.srk_booking_final_bills
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare
  v_booking public.service_bookings%rowtype;
  v_bill public.srk_booking_final_bills%rowtype;
  v_labour numeric(12,2):=0;
  v_material numeric(12,2);
  v_worker record;
  v_worker_gross numeric(12,2);
begin
  if not public.srk_has_admin_permission('bookings.manage') then raise exception 'Booking management permission required'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if not exists(select 1 from public.srk_booking_workers where booking_id=p_booking_id and worker_role='technician' and assignment_status='completed') then
    raise exception 'At least one Technician must complete work before final billing';
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
  values(p_booking_id,'SRK-BILL-'||lpad(nextval('public.srk_bill_number_seq')::text,6,'0'),
    v_labour,v_material,'issued',clock_timestamp()) returning * into v_bill;
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

create or replace function public.srk_admin_offer_worker_to_booking(p_booking_id uuid,p_worker_id uuid,p_worker_role text)
returns public.srk_booking_workers
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare
  v_booking public.service_bookings%rowtype; v_worker public.srk_worker_profiles%rowtype;
  v_existing integer; v_limit integer; v_assignment public.srk_booking_workers%rowtype;
  v_skill_level uuid; v_rate_id uuid; v_rate numeric(10,2); v_distance numeric;
begin
  if not public.srk_has_admin_permission('bookings.manage') then raise exception 'Booking management permission required'; end if;
  if p_worker_role not in ('technician','helper') then raise exception 'Invalid worker role'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  select * into v_worker from public.srk_worker_profiles where id=p_worker_id for update;
  if not found then raise exception 'Worker not found'; end if;
  if v_worker.worker_type<>p_worker_role or v_worker.category_id is distinct from v_booking.category_id then raise exception 'Worker category or role mismatch'; end if;
  if v_worker.verification_status<>'approved' or not v_worker.is_active or not v_worker.is_online then raise exception 'Worker must be approved, active and online'; end if;
  if v_booking.booking_latitude is null or v_worker.location_lat is null then raise exception 'Booking and worker GPS locations are required'; end if;
  v_distance:=6371*acos(least(1,greatest(-1,
    cos(radians(v_booking.booking_latitude))*cos(radians(v_worker.location_lat))*
    cos(radians(v_worker.location_lng)-radians(v_booking.booking_longitude))+
    sin(radians(v_booking.booking_latitude))*sin(radians(v_worker.location_lat))
  )));
  if v_distance>30 or v_distance>v_worker.service_radius_km then raise exception 'Worker is outside their 30 KM service range'; end if;
  select ws.skill_level_id into v_skill_level from public.srk_worker_skills ws
    where ws.worker_id=p_worker_id and ws.skill_id=v_booking.selected_skill_id and ws.verification_status='approved' limit 1;
  if v_skill_level is null then raise exception 'Admin-approved required skill missing'; end if;
  select r.id,case when p_worker_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end
    into v_rate_id,v_rate from public.srk_service_rates r
    where r.category_id=v_worker.category_id and r.skill_level_id=v_skill_level
      and (r.service_type_id is null or r.service_type_id=v_booking.service_type_id)
      and r.rate_status='approved' and r.effective_from<=clock_timestamp()
      and (r.effective_to is null or r.effective_to>clock_timestamp())
      and (case when p_worker_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end) is not null
    order by (r.service_type_id is not null) desc,r.effective_from desc limit 1;
  if v_rate is null then raise exception 'Approved hourly rate not configured'; end if;
  if exists(select 1 from public.srk_worker_work_sessions s join public.srk_booking_workers bw on bw.id=s.booking_worker_id
    where bw.worker_id=p_worker_id and s.session_status='running') then raise exception 'Worker already working at another booking'; end if;
  v_limit:=case when p_worker_role='technician' then v_booking.requested_technician_count else v_booking.requested_helper_count end;
  select count(*) into v_existing from public.srk_booking_workers where booking_id=p_booking_id and worker_role=p_worker_role
    and assignment_status not in ('rejected','cancelled','released');
  if v_existing>=v_limit then raise exception 'Requested worker count fulfilled'; end if;
  insert into public.srk_booking_workers(booking_id,worker_id,worker_role,assignment_status,offered_by,rate_id,hourly_rate_snapshot,skill_level_snapshot_id)
  values(p_booking_id,p_worker_id,p_worker_role,'offered',auth.uid(),v_rate_id,v_rate,v_skill_level)
  returning * into v_assignment;
  return v_assignment;
end $$;

revoke all on function public.srk_admin_review_worker_skill(uuid,text,uuid,text) from public,anon;
revoke all on function public.srk_admin_offer_worker_to_booking(uuid,uuid,text) from public,anon;
grant execute on function public.srk_admin_review_worker_skill(uuid,text,uuid,text) to authenticated,service_role;
grant execute on function public.srk_admin_offer_worker_to_booking(uuid,uuid,text) to authenticated,service_role;
