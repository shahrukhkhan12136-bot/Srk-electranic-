
create or replace function public.srk_customer_create_booking(
 p_category_id uuid,p_service_type_id uuid,p_skill_id uuid,
 p_technician_count integer,p_helper_count integer,p_duration_hours integer,
 p_state text,p_district text,p_pincode text,p_address text,
 p_booking_latitude double precision,p_booking_longitude double precision,
 p_current_gps_latitude double precision,p_current_gps_longitude double precision,
 p_motor_hp numeric
) returns public.service_bookings
language plpgsql security definer
set search_path=pg_catalog,public,auth
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
   if p_motor_hp is null or p_motor_hp<0.5 or p_motor_hp*2<>trunc(p_motor_hp*2) then
    raise exception 'Motor HP must be selected in 0.5 HP increments, starting at 0.5 HP';
   end if;
   if not exists(select 1 from public.srk_service_pricing_hp_tiers t where t.pricing_rule_id=v_rule.id and t.motor_hp=p_motor_hp) then
    raise exception 'No approved fixed price exists for this motor HP';
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
  v_unit,case when v_unit in ('per_item','motor_hp') then 1 else null end,
  case when v_rule.id is not null then v_rule.id else null end,p_motor_hp
 ) returning * into v_booking;
 insert into public.srk_booking_matching_queue(booking_id,queue_status) values(v_booking.id,'pending');
 return v_booking;
end
$function$;
revoke all on function public.srk_customer_create_booking(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision,numeric) from public,anon;
grant execute on function public.srk_customer_create_booking(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision,numeric) to authenticated;
