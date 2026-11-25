CREATE OR REPLACE FUNCTION public.srk_customer_create_booking(
 p_category_id uuid,p_service_type_id uuid,p_skill_id uuid,
 p_technician_count integer,p_helper_count integer,p_duration_hours integer,
 p_state text,p_district text,p_pincode text,p_address text,
 p_booking_latitude double precision,p_booking_longitude double precision,
 p_current_gps_latitude double precision,p_current_gps_longitude double precision,
 p_motor_hp numeric,p_skill_level_id uuid,p_unit_count integer
) RETURNS public.service_bookings
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_customer public.srk_customer_profiles%rowtype;
 v_service public.srk_service_types%rowtype;
 v_booking public.service_bookings%rowtype;
 v_rule public.srk_service_pricing_rules%rowtype;
 v_unit text;
 v_max_tech integer;
 v_max_helper integer;
 v_min_duration integer;
 v_max_duration integer;
 v_location_source text;
 v_requested_level public.srk_skill_levels%rowtype;
 v_settings_snapshot jsonb;
 v_pending_fee_amount numeric(12,2):=0;
 v_user_settings_snapshot jsonb:='{}'::jsonb;
begin
 if auth.uid() is null then raise exception 'OTP login required' using errcode='42501'; end if;
 select * into v_customer from public.srk_customer_profiles where user_id=auth.uid();
 if not found then raise exception 'Complete customer profile before booking'; end if;
 if v_customer.account_status<>'active' then raise exception 'Customer account is restricted from new bookings'; end if;

 select coalesce((select (setting_value #>> '{}')::integer from public.srk_system_settings where setting_key='max_technicians_per_booking'),10),
        coalesce((select (setting_value #>> '{}')::integer from public.srk_system_settings where setting_key='max_helpers_per_booking'),10),
        coalesce((select (setting_value #>> '{}')::integer from public.srk_system_settings where setting_key='minimum_booking_duration_hours'),1),
        coalesce((select (setting_value #>> '{}')::integer from public.srk_system_settings where setting_key='maximum_booking_duration_hours'),1440)
 into v_max_tech,v_max_helper,v_min_duration,v_max_duration;
 select coalesce(jsonb_object_agg(setting_key,setting_value),'{}'::jsonb) into v_settings_snapshot
 from public.srk_system_settings
 where setting_key in ('max_technicians_per_booking','max_helpers_per_booking','minimum_booking_duration_hours','maximum_booking_duration_hours',
 'normal_daily_billable_hours','overtime_multiplier','initial_matching_radius_km','matching_radius_expansion_step_km','maximum_matching_radius_km',
 'offer_timeout_seconds','max_matching_attempts','no_show_wait_minutes','cancellation_free_window_minutes','cancellation_technician_on_way_fee',
 'cancellation_technician_arrived_fee','lunch_pause_minimum_minutes','other_pause_minimum_minutes','pause_auto_resume_distance_meters');
 select coalesce(jsonb_object_agg(setting_key,setting_value),'{}'::jsonb)
 into v_user_settings_snapshot
 from public.srk_user_custom_settings
 where user_id=auth.uid() and account_role='customer';

 if p_technician_count is null or p_helper_count is null
  or p_technician_count not between 1 and greatest(1,least(v_max_tech,20))
  or p_helper_count not between 0 and greatest(0,least(v_max_helper,20)) then
  raise exception 'Requested Technician/Helper count exceeds the configured booking limit';
 end if;
 if p_duration_hours is null or p_duration_hours not between greatest(1,v_min_duration) and least(1440,v_max_duration) then
  raise exception 'Duration must be within the configured booking duration limits';
 end if;
 if p_pincode !~ '^[0-9]{6}$' or nullif(btrim(p_state),'') is null
  or nullif(btrim(p_district),'') is null or nullif(btrim(p_address),'') is null then
  raise exception 'Complete valid booking address required';
 end if;
 if (p_booking_latitude is null)<>(p_booking_longitude is null) then raise exception 'Booking GPS coordinates must be supplied together'; end if;
 if p_booking_latitude is not null and
  (p_booking_latitude not between -90 and 90 or p_booking_longitude not between -180 and 180) then
  raise exception 'Invalid booking GPS coordinates';
 end if;
 v_location_source:=case when p_booking_latitude is null then 'manual' else 'gps' end;
 if (p_current_gps_latitude is null)<>(p_current_gps_longitude is null) then raise exception 'Current GPS coordinates must be supplied together'; end if;
 if p_current_gps_latitude is not null and
  (p_current_gps_latitude not between -90 and 90 or p_current_gps_longitude not between -180 and 180) then
  raise exception 'Invalid current GPS coordinates';
 end if;

 select * into v_service from public.srk_service_types
 where id=p_service_type_id and category_id=p_category_id and is_active;
 if not found then raise exception 'Service does not belong to active category'; end if;
 if not exists(select 1 from public.srk_service_skills
  where id=p_skill_id and service_type_id=p_service_type_id and is_active) then
  raise exception 'Work/skill does not belong to selected service';
 end if;
 if p_skill_level_id is not null then
  select * into v_requested_level from public.srk_skill_levels
  where id=p_skill_level_id and category_id=p_category_id and is_active;
  if not found then raise exception 'Selected qualification level is not active for this category'; end if;
 else
  select * into v_requested_level from public.srk_skill_levels
  where category_id=p_category_id and is_active order by sort_order limit 1;
  p_skill_level_id:=v_requested_level.id;
 end if;

 select * into v_rule from public.srk_service_pricing_rules
 where category_id=p_category_id and service_type_id=p_service_type_id
  and effective_from<=clock_timestamp() and (effective_to is null or effective_to>clock_timestamp())
 order by effective_from desc limit 1;
 if found then
  v_unit:=v_rule.pricing_unit;
  if v_unit='motor_hp' then
   if p_motor_hp is null or p_motor_hp<0.5 or p_motor_hp*2<>trunc(p_motor_hp*2) then
    raise exception 'Motor HP must be selected in 0.5 HP increments, starting at 0.5 HP';
   end if;
   if not exists(select 1 from public.srk_service_pricing_hp_tiers t
    where t.pricing_rule_id=v_rule.id and t.motor_hp=p_motor_hp) then
    raise exception 'No approved fixed price exists for this Motor/Pump HP';
   end if;
  elsif p_motor_hp is not null then
   raise exception 'Motor HP must only be supplied for Motor/Pump HP-priced services';
  end if;
  if v_unit='per_item' and (v_rule.technician_rate is null or v_rule.technician_rate<=0) then
   raise exception 'Approved fixed per-item Technician price is missing';
  end if;
 else
  v_unit:='hour';
  if p_motor_hp is not null then raise exception 'Motor HP is not applicable to this service'; end if;
 end if;

 if v_unit='hour' and p_helper_count>0 then
  if v_rule.id is not null and v_rule.pricing_unit='hour' then
   if v_rule.helper_rate is null or v_rule.helper_rate<=0 then
    raise exception 'Helper service is not available for this work because no approved Helper hourly rate is published';
   end if;
  elsif not exists(
   select 1 from public.srk_service_rates sr
   where sr.category_id=p_category_id and sr.service_type_id=p_service_type_id
    and sr.skill_level_id=v_requested_level.id and sr.rate_status='approved'
    and sr.effective_from<=clock_timestamp() and (sr.effective_to is null or sr.effective_to>clock_timestamp())
    and sr.helper_hourly_rate>0
  ) then
   raise exception 'Helper service is not available for this work because no approved Helper hourly rate is published';
  end if;
 end if;

 if p_unit_count is null or p_unit_count<1 then raise exception 'Unit count must be at least one'; end if;
 if v_unit<>'per_item' and p_unit_count<>1 then raise exception 'Unit count is only selectable for per-item services'; end if;

 insert into public.service_bookings(
  customer_name,phone,state,district,pincode,address,service_type,payment_method,status,
  commission_rate,materials_amount,customer_user_id,customer_id,category_id,service_type_id,selected_skill_id,
  requested_technician_count,requested_helper_count,requested_duration_hours,booking_latitude,booking_longitude,requested_skill_level_id,
  location_lat,location_lng,booking_address_confirmed_at,booking_location_source,
  pricing_unit_snapshot,pricing_quantity,pricing_rule_id,motor_hp,operational_settings_snapshot,user_custom_settings_snapshot
 ) values(
  v_customer.full_name,v_customer.phone,btrim(p_state),btrim(p_district),p_pincode,btrim(p_address),v_service.service_name,
  'Unselected','new',15.00,0,auth.uid(),v_customer.id,p_category_id,p_service_type_id,p_skill_id,
  p_technician_count,p_helper_count,p_duration_hours,p_booking_latitude,p_booking_longitude,p_skill_level_id,
  p_current_gps_latitude,p_current_gps_longitude,clock_timestamp(),v_location_source,
  v_unit,case when v_unit='per_item' then p_unit_count when v_unit='motor_hp' then 1 else null end,
  case when v_rule.id is not null then v_rule.id else null end,p_motor_hp,v_settings_snapshot,v_user_settings_snapshot
 ) returning * into v_booking;

 insert into public.srk_booking_matching_queue(booking_id,queue_status) values(v_booking.id,'pending');
 if v_booking.requested_skill_level_id is not null then
  insert into public.srk_booking_skill_level_events(booking_id,actor_user_id,event_type,to_skill_level_id,reason)
  values(v_booking.id,auth.uid(),'requested_level_selected',v_booking.requested_skill_level_id,
   'Qualification level selected/defaulted at booking creation');
 end if;
 update public.srk_booking_cancellation_fees
 set status='added_to_next_booking',next_booking_id=v_booking.id,added_to_next_booking_at=clock_timestamp()
 where customer_user_id=auth.uid() and status='pending';
 select coalesce(sum(fee_amount),0) into v_pending_fee_amount
 from public.srk_booking_cancellation_fees
 where next_booking_id=v_booking.id and status='added_to_next_booking';
 if v_pending_fee_amount>0 then
  update public.service_bookings set pending_cancellation_fee_amount=v_pending_fee_amount
  where id=v_booking.id returning * into v_booking;
 end if;
 return v_booking;
end
$function$;