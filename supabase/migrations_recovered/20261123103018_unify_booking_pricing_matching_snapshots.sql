
create or replace function public.srk_customer_create_booking(
 p_category_id uuid,p_service_type_id uuid,p_skill_id uuid,
 p_technician_count integer,p_helper_count integer,p_duration_hours integer,
 p_state text,p_district text,p_pincode text,p_address text,
 p_booking_latitude double precision,p_booking_longitude double precision,
 p_current_gps_latitude double precision default null,
 p_current_gps_longitude double precision default null
) returns public.service_bookings
language plpgsql security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
 v_customer public.srk_customer_profiles%rowtype;
 v_service public.srk_service_types%rowtype;
 v_booking public.service_bookings%rowtype;
 v_rule public.srk_service_pricing_rules%rowtype;
 v_unit text;
begin
 if auth.uid() is null then raise exception 'OTP login required'; end if;
 select * into v_customer from public.srk_customer_profiles where user_id=auth.uid();
 if not found then raise exception 'Complete customer profile before booking'; end if;
 if v_customer.account_status<>'active' then raise exception 'Customer account is restricted from new bookings'; end if;
 if p_technician_count not between 1 and 20 or p_helper_count not between 0 and 20 then raise exception 'Invalid worker count'; end if;
 if p_duration_hours not between 1 and 1440 then raise exception 'Duration must be 1 hour to 60 days'; end if;
 if p_pincode !~ '^[0-9]{6}$' or nullif(btrim(p_state),'') is null or nullif(btrim(p_district),'') is null or nullif(btrim(p_address),'') is null then
  raise exception 'Complete valid booking address required';
 end if;
 if p_booking_latitude is null or p_booking_longitude is null or p_booking_latitude not between -90 and 90 or p_booking_longitude not between -180 and 180 then
  raise exception 'Booking Address GPS coordinates required';
 end if;
 if (p_current_gps_latitude is null)<>(p_current_gps_longitude is null) then raise exception 'Current GPS coordinates must be supplied together'; end if;
 select * into v_service from public.srk_service_types where id=p_service_type_id and category_id=p_category_id and is_active;
 if not found then raise exception 'Service does not belong to active category'; end if;
 if not exists(select 1 from public.srk_service_skills where id=p_skill_id and service_type_id=p_service_type_id and is_active) then
  raise exception 'Work/skill does not belong to selected service';
 end if;
 select * into v_rule from public.srk_service_pricing_rules
 where category_id=p_category_id and service_type_id=p_service_type_id
   and effective_from<=clock_timestamp() and (effective_to is null or effective_to>clock_timestamp())
 order by effective_from desc limit 1;
 if found then
   v_unit:=v_rule.pricing_unit;
   if v_unit='motor_hp' then
     raise exception 'Motor/Pump HP pricing needs the approved HP increment rule before customer booking can be enabled';
   end if;
   if v_unit='per_item' and (v_rule.technician_rate is null or v_rule.technician_rate<=0) then
     raise exception 'Approved fixed per-item Technician price is missing';
   end if;
 else
   v_unit:='hour';
 end if;
 insert into public.service_bookings(
  customer_name,phone,state,district,pincode,address,service_type,payment_method,status,
  commission_rate,materials_amount,customer_user_id,customer_id,category_id,service_type_id,selected_skill_id,
  requested_technician_count,requested_helper_count,requested_duration_hours,booking_latitude,booking_longitude,
  location_lat,location_lng,booking_address_confirmed_at,
  pricing_unit_snapshot,pricing_quantity,pricing_rule_id,motor_hp
 ) values(
  v_customer.full_name,v_customer.phone,btrim(p_state),btrim(p_district),p_pincode,btrim(p_address),v_service.service_name,
  'Unselected','new',15.00,0,auth.uid(),v_customer.id,p_category_id,p_service_type_id,p_skill_id,
  p_technician_count,p_helper_count,p_duration_hours,p_booking_latitude,p_booking_longitude,
  p_current_gps_latitude,p_current_gps_longitude,clock_timestamp(),
  v_unit,case when v_unit='per_item' then 1 else null end,case when v_rule.id is not null then v_rule.id else null end,null
 ) returning * into v_booking;
 insert into public.srk_booking_matching_queue(booking_id,queue_status) values(v_booking.id,'pending');
 return v_booking;
end
$function$;

create or replace function public.srk_process_booking_matching_queue()
returns integer language plpgsql security definer
set search_path to 'pg_catalog','public'
as $function$
declare
 v_queue record; v_booking public.service_bookings%rowtype; v_timeout integer;
 v_tech_count integer; v_helper_count integer; v_tech_offered integer; v_helper_offered integer;
 v_candidate record; v_level uuid; v_rate_id uuid; v_rate numeric(10,2); v_role text;
 v_inserted integer:=0; v_offered boolean; v_rule public.srk_service_pricing_rules%rowtype;
begin
 select nullif(setting_value::text,'null')::integer into v_timeout
 from public.srk_system_settings where setting_key='offer_timeout_seconds';
 if v_timeout is not null then
  update public.srk_booking_workers set assignment_status='rejected',rejected_at=clock_timestamp(),
   admin_note='Offer timed out',updated_at=clock_timestamp()
  where assignment_status='offered' and offer_expires_at is not null and offer_expires_at<=clock_timestamp();
 end if;
 for v_queue in
  select q.* from public.srk_booking_matching_queue q
  where q.queue_status in ('pending','searching','waiting') and q.next_attempt_at<=clock_timestamp()
  order by q.created_at for update skip locked limit 25
 loop
  select * into v_booking from public.service_bookings where id=v_queue.booking_id for update;
  if not found or v_booking.status='cancelled' then
   update public.srk_booking_matching_queue set queue_status='cancelled',updated_at=clock_timestamp() where booking_id=v_queue.booking_id;
   continue;
  end if;
  select count(*) into v_tech_count from public.srk_booking_workers
   where booking_id=v_booking.id and worker_role='technician' and assignment_status in ('accepted','assigned','working','paused','completed');
  select count(*) into v_helper_count from public.srk_booking_workers
   where booking_id=v_booking.id and worker_role='helper' and assignment_status in ('accepted','assigned','working','paused','completed');
  select count(*) into v_tech_offered from public.srk_booking_workers
   where booking_id=v_booking.id and worker_role='technician' and assignment_status='offered';
  select count(*) into v_helper_offered from public.srk_booking_workers
   where booking_id=v_booking.id and worker_role='helper' and assignment_status='offered';
  if v_tech_count>=v_booking.requested_technician_count and v_helper_count>=v_booking.requested_helper_count then
   update public.srk_booking_workers set assignment_status='assigned',updated_at=clock_timestamp()
    where booking_id=v_booking.id and assignment_status='accepted';
   update public.srk_booking_matching_queue set queue_status='fulfilled',completed_at=coalesce(completed_at,clock_timestamp()),updated_at=clock_timestamp()
    where booking_id=v_booking.id;
   update public.service_bookings set status='confirmed' where id=v_booking.id and status='new';
   continue;
  end if;
  v_role:=case when v_tech_count<v_booking.requested_technician_count then 'technician' else 'helper' end;
  if (v_role='technician' and v_tech_offered>0) or (v_role='helper' and v_helper_offered>0) then
   update public.srk_booking_matching_queue set queue_status='searching',next_attempt_at=clock_timestamp()+interval '1 minute',updated_at=clock_timestamp()
   where booking_id=v_booking.id;
   continue;
  end if;
  select * into v_rule from public.srk_service_pricing_rules where id=v_booking.pricing_rule_id;
  v_offered:=false;
  for v_candidate in
   select c.* from public.srk_find_eligible_workers(v_booking.id,v_role) c
   where not exists(select 1 from public.srk_booking_workers bw where bw.booking_id=v_booking.id and bw.worker_id=c.worker_id)
   order by c.distance_km
  loop
   select ws.skill_level_id into v_level from public.srk_worker_skills ws
    where ws.worker_id=v_candidate.worker_id and ws.skill_id=v_booking.selected_skill_id and ws.verification_status='approved' limit 1;
   v_rate_id:=null; v_rate:=null;
   if v_booking.pricing_unit_snapshot='per_item' then
    if v_rule.id is null or v_rule.pricing_unit<>'per_item' then continue; end if;
    if v_role='technician' then v_rate:=v_rule.technician_rate; else v_rate:=v_rule.helper_rate; end if;
    if v_role='technician' and (v_rate is null or v_rate<=0) then continue; end if;
   else
    if v_booking.pricing_rule_id is not null and v_rule.pricing_unit='hour' then
     if v_role='technician' then v_rate:=v_rule.technician_rate; else v_rate:=v_rule.helper_rate; end if;
     if v_rate is null then continue; end if;
    else
     select r.id,case when v_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end
      into v_rate_id,v_rate from public.srk_service_rates r
      where r.category_id=v_booking.category_id and r.skill_level_id=v_level
       and (r.service_type_id is null or r.service_type_id=v_booking.service_type_id)
       and r.rate_status='approved' and r.effective_from<=clock_timestamp()
       and (r.effective_to is null or r.effective_to>clock_timestamp())
       and (case when v_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end) is not null
      order by (r.service_type_id is not null) desc,r.effective_from desc limit 1;
     if v_rate is null then continue; end if;
    end if;
   end if;
   insert into public.srk_booking_workers(booking_id,worker_id,worker_role,assignment_status,
    rate_id,hourly_rate_snapshot,skill_level_snapshot_id,offer_expires_at)
   values(v_booking.id,v_candidate.worker_id,v_role,'offered',v_rate_id,
    case when v_booking.pricing_unit_snapshot='per_item' then null else v_rate end,v_level,
    case when v_timeout is null then null else clock_timestamp()+make_interval(secs=>v_timeout) end);
   update public.srk_booking_matching_queue set queue_status='searching',attempts=attempts+1,
    last_attempt_at=clock_timestamp(),next_attempt_at=clock_timestamp()+interval '1 minute',
    last_error=null,updated_at=clock_timestamp() where booking_id=v_booking.id;
   v_inserted:=v_inserted+1; v_offered:=true; exit;
  end loop;
  if not v_offered then
   update public.srk_booking_matching_queue set queue_status='waiting',attempts=attempts+1,
    last_attempt_at=clock_timestamp(),next_attempt_at=clock_timestamp()+interval '1 minute',
    last_error='No eligible online approved worker with an approved pricing rule/rate',updated_at=clock_timestamp()
   where booking_id=v_booking.id;
  end if;
 end loop;
 return v_inserted;
end
$function$;

create or replace function public.srk_admin_offer_worker_to_booking(
 p_booking_id uuid,p_worker_id uuid,p_worker_role text,p_reason text
) returns public.srk_booking_workers
language plpgsql security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
 v_booking public.service_bookings%rowtype; v_worker public.srk_worker_profiles%rowtype;
 v_existing integer; v_limit integer; v_assignment public.srk_booking_workers%rowtype;
 v_skill_level uuid; v_rate_id uuid; v_rate numeric(10,2); v_distance numeric;
 v_rule public.srk_service_pricing_rules%rowtype;
begin
 if not public.srk_has_admin_permission('bookings.manage') then raise exception 'Booking management permission required'; end if;
 if length(btrim(coalesce(p_reason,'')))<10 then raise exception 'Admin assignment reason must be at least 10 characters'; end if;
 if p_worker_role not in ('technician','helper') then raise exception 'Invalid worker role'; end if;
 select * into v_booking from public.service_bookings where id=p_booking_id for update;
 if not found then raise exception 'Booking not found'; end if;
 select * into v_worker from public.srk_worker_profiles where id=p_worker_id for update;
 if not found then raise exception 'Worker not found'; end if;
 if v_worker.worker_type<>p_worker_role or v_worker.category_id is distinct from v_booking.category_id then raise exception 'Worker category or role mismatch'; end if;
 if v_worker.verification_status<>'approved' or not v_worker.is_active or not v_worker.is_online then raise exception 'Worker must be approved, active and online'; end if;
 if v_booking.booking_latitude is null or v_booking.booking_longitude is null or v_worker.location_lat is null or v_worker.location_lng is null then raise exception 'Booking and worker GPS locations required'; end if;
 v_distance:=6371*acos(least(1,greatest(-1,
  cos(radians(v_booking.booking_latitude))*cos(radians(v_worker.location_lat))*cos(radians(v_worker.location_lng)-radians(v_booking.booking_longitude))+
  sin(radians(v_booking.booking_latitude))*sin(radians(v_worker.location_lat))
 )));
 if v_distance>30 or v_distance>v_worker.service_radius_km then raise exception 'Worker outside 30 KM service range'; end if;
 select ws.skill_level_id into v_skill_level from public.srk_worker_skills ws
  where ws.worker_id=p_worker_id and ws.skill_id=v_booking.selected_skill_id and ws.verification_status='approved' limit 1;
 if v_skill_level is null then raise exception 'Admin-approved required skill missing'; end if;
 v_rate_id:=null; v_rate:=null;
 select * into v_rule from public.srk_service_pricing_rules where id=v_booking.pricing_rule_id;
 if v_booking.pricing_unit_snapshot='per_item' then
  if v_rule.id is null or v_rule.pricing_unit<>'per_item' then raise exception 'Booking fixed-price snapshot is missing'; end if;
  if p_worker_role='technician' then v_rate:=v_rule.technician_rate; else v_rate:=v_rule.helper_rate; end if;
  if p_worker_role='technician' and (v_rate is null or v_rate<=0) then raise exception 'Approved fixed service price missing'; end if;
 else
  if v_booking.pricing_rule_id is not null and v_rule.pricing_unit='hour' then
   if p_worker_role='technician' then v_rate:=v_rule.technician_rate; else v_rate:=v_rule.helper_rate; end if;
   if v_rate is null then raise exception 'Hourly rate not configured for this worker role'; end if;
  else
   select r.id,case when p_worker_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end
    into v_rate_id,v_rate from public.srk_service_rates r
    where r.category_id=v_worker.category_id and r.skill_level_id=v_skill_level
     and (r.service_type_id is null or r.service_type_id=v_booking.service_type_id)
     and r.rate_status='approved' and r.effective_from<=clock_timestamp()
     and (r.effective_to is null or r.effective_to>clock_timestamp())
     and (case when p_worker_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end) is not null
    order by (r.service_type_id is not null) desc,r.effective_from desc limit 1;
   if v_rate is null then raise exception 'Approved hourly rate not configured'; end if;
  end if;
 end if;
 if exists(select 1 from public.srk_worker_work_sessions s join public.srk_booking_workers bw on bw.id=s.booking_worker_id
  where bw.worker_id=p_worker_id and s.session_status='running') then raise exception 'Worker already working at another booking'; end if;
 v_limit:=case when p_worker_role='technician' then v_booking.requested_technician_count else v_booking.requested_helper_count end;
 select count(*) into v_existing from public.srk_booking_workers where booking_id=p_booking_id and worker_role=p_worker_role
  and assignment_status not in ('rejected','cancelled','released');
 if v_existing>=v_limit then raise exception 'Requested worker count fulfilled'; end if;
 insert into public.srk_booking_workers(booking_id,worker_id,worker_role,assignment_status,offered_by,
  rate_id,hourly_rate_snapshot,skill_level_snapshot_id,admin_note)
 values(p_booking_id,p_worker_id,p_worker_role,'offered',auth.uid(),v_rate_id,
  case when v_booking.pricing_unit_snapshot='per_item' then null else v_rate end,v_skill_level,p_reason)
 returning * into v_assignment;
 return v_assignment;
end
$function$;

revoke all on function public.srk_customer_create_booking(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision) from public,anon;
grant execute on function public.srk_customer_create_booking(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision) to authenticated;
revoke all on function public.srk_process_booking_matching_queue() from public,anon,authenticated;
revoke all on function public.srk_admin_offer_worker_to_booking(uuid,uuid,text,text) from public,anon;
grant execute on function public.srk_admin_offer_worker_to_booking(uuid,uuid,text,text) to authenticated;
