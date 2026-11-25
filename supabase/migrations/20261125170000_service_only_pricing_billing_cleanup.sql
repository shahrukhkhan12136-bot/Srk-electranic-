-- Service-only pricing and billing cleanup; preserve historical migration files.

drop trigger if exists srk_exclude_materials_booking_guard on public.service_bookings;
drop trigger if exists srk_reject_material_bill_items_guard on public.srk_booking_final_bill_items;
drop trigger if exists srk_exclude_materials_final_bill_guard on public.srk_booking_final_bills;
drop trigger if exists srk_exclude_materials_legacy_payout_guard on public.srk_electrician_payouts;


drop function if exists public.srk_customer_preview_booking_price_v3(uuid,uuid,uuid,uuid,integer,integer,integer,numeric,integer,text,text);
drop function if exists srk_private.preview_booking_price_with_district(uuid,uuid,uuid,uuid,integer,integer,integer,numeric,integer,text,text);
drop function if exists public.srk_customer_preview_booking_price_v2(uuid,uuid,uuid,uuid,integer,integer,integer,numeric,integer);
drop function if exists public.srk_customer_preview_booking_price(uuid,uuid,uuid,uuid,integer,integer,integer,numeric,integer);


drop function if exists public.srk_get_my_assigned_booking_quote_details();
drop function if exists public.srk_get_my_offer_details();
drop function if exists public.srk_get_my_offer_price_details();


drop function if exists public.srk_admin_version_service_pricing_rule(uuid,text,numeric,numeric,numeric,numeric,numeric,boolean,boolean,boolean,text,jsonb,text);
drop function if exists public.srk_submit_booking_quote(uuid,numeric,numeric,text);
drop function if exists public.srk_create_electrician_payable();
drop function if exists public.srk_exclude_materials_from_legacy_electrician_payout();
drop function if exists public.srk_exclude_materials_from_new_bookings();
drop function if exists public.srk_exclude_materials_from_new_final_bills();
drop function if exists public.srk_reject_material_bill_items();


CREATE OR REPLACE FUNCTION srk_private.preview_booking_price_base(p_category_id uuid, p_service_type_id uuid, p_skill_id uuid, p_skill_level_id uuid, p_technician_count integer, p_helper_count integer, p_duration_hours integer, p_motor_hp numeric DEFAULT NULL::numeric, p_unit_count integer DEFAULT 1)
 RETURNS TABLE(pricing_unit text, qualification_level text, technician_rate numeric, helper_rate numeric, estimated_base_total numeric, estimated_company_commission numeric, estimated_worker_net numeric, overtime_may_apply boolean, price_note text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'srk_private'
AS $function$
declare
 v_rule public.srk_service_pricing_rules%rowtype;
 v_level public.srk_skill_levels%rowtype;
 v_tech_rate numeric(12,2);
 v_helper_rate numeric(12,2);
 v_total numeric(12,2);
 v_unit text:='hour';
 v_max_tech integer;
 v_max_helper integer;
 v_min_duration integer;
 v_max_duration integer;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if not exists(select 1 from public.srk_customer_profiles where user_id=auth.uid() and account_status='active') then
  raise exception 'Active customer profile required';
 end if;
 select coalesce((select (setting_value #>> '{}')::integer from public.srk_system_settings where setting_key='max_technicians_per_booking'),10),
        coalesce((select (setting_value #>> '{}')::integer from public.srk_system_settings where setting_key='max_helpers_per_booking'),10),
        coalesce((select (setting_value #>> '{}')::integer from public.srk_system_settings where setting_key='minimum_booking_duration_hours'),1),
        coalesce((select (setting_value #>> '{}')::integer from public.srk_system_settings where setting_key='maximum_booking_duration_hours'),1440)
 into v_max_tech,v_max_helper,v_min_duration,v_max_duration;
 if p_technician_count not between 1 and v_max_tech or p_helper_count not between 0 and v_max_helper
  or p_duration_hours not between v_min_duration and v_max_duration
  or p_unit_count not between 1 and 100 then
  raise exception 'Requested worker count, duration or unit count is outside configured limits';
 end if;
 if not exists(select 1 from public.srk_service_types s where s.id=p_service_type_id and s.category_id=p_category_id and s.is_active)
  or not exists(select 1 from public.srk_service_skills k where k.id=p_skill_id and k.service_type_id=p_service_type_id and k.is_active) then
  raise exception 'Selected category, service or work skill is invalid';
 end if;
 if p_skill_level_id is not null then
  select * into v_level from public.srk_skill_levels where id=p_skill_level_id and category_id=p_category_id and is_active;
  if not found then raise exception 'Selected qualification is not active for this category'; end if;
 else
  select * into v_level from public.srk_skill_levels where category_id=p_category_id and is_active order by sort_order limit 1;
 end if;
 select * into v_rule from public.srk_service_pricing_rules
 where category_id=p_category_id and service_type_id=p_service_type_id
  and effective_from<=clock_timestamp() and (effective_to is null or effective_to>clock_timestamp())
 order by effective_from desc limit 1;
 if found and v_rule.pricing_unit='motor_hp' then
  select t.fixed_price into v_tech_rate from public.srk_service_pricing_hp_tiers t
  where t.pricing_rule_id=v_rule.id and t.motor_hp=p_motor_hp;
  if v_tech_rate is null then raise exception 'No approved fixed price exists for this Motor/Pump HP'; end if;
  v_unit:='motor_hp'; v_helper_rate:=0; v_total:=v_tech_rate;
 elsif found and v_rule.pricing_unit='per_item' then
  v_tech_rate:=v_rule.technician_rate;
  if v_tech_rate is null then raise exception 'Approved per-item price is missing'; end if;
  v_unit:='per_item'; v_helper_rate:=0; v_total:=v_tech_rate*p_unit_count;
 else
  if v_level.id is null then raise exception 'Approved qualification level is missing'; end if;
  select r.technician_hourly_rate,r.helper_hourly_rate into v_tech_rate,v_helper_rate
  from public.srk_service_rates r
  where r.category_id=p_category_id and r.service_type_id=p_service_type_id
   and r.skill_level_id=v_level.id and r.rate_status='approved'
   and r.effective_from<=clock_timestamp() and (r.effective_to is null or r.effective_to>clock_timestamp())
  order by r.effective_from desc limit 1;
  if v_tech_rate is null then
   if v_rule.id is null or v_rule.technician_rate is null then
    raise exception 'No approved hourly rate exists for this service and qualification';
   end if;
   v_tech_rate:=v_rule.technician_rate; v_helper_rate:=coalesce(v_rule.helper_rate,0);
  end if;
  v_helper_rate:=coalesce(v_helper_rate,0);
  if p_helper_count>0 and v_helper_rate<=0 then
   raise exception 'Helper service is not available for this work because no approved Helper hourly rate is published';
  end if;
  v_unit:='hour';
  v_total:=round((v_tech_rate*p_technician_count+v_helper_rate*p_helper_count)*p_duration_hours,2);
 end if;
 return query select v_unit,v_level.level_name,v_tech_rate,v_helper_rate,
  v_total,round(v_total*0.15,2),round(v_total*0.85,2),
  v_unit='hour' and p_duration_hours>8,
  case when v_unit='hour' then 'Hourly service estimate; overtime may apply after 8 hours per worker per booking day.'
   when v_unit='motor_hp' then 'Fixed Motor/Pump HP service rate.'
   else 'Fixed per-item service rate.' end;
end
$function$
;
create or replace function srk_private.preview_booking_price_with_district(
  p_category_id uuid,p_service_type_id uuid,p_skill_id uuid,p_skill_level_id uuid,
  p_technician_count integer,p_helper_count integer,p_duration_hours integer,
  p_motor_hp numeric,p_unit_count integer,p_state text,p_district text
) returns table(
  pricing_unit text,qualification_level text,technician_rate numeric,helper_rate numeric,
  estimated_base_total numeric,estimated_company_commission numeric,estimated_worker_net numeric,
  overtime_may_apply boolean,price_note text,
  pending_cancellation_fee_amount numeric,estimated_customer_total numeric
)
language plpgsql stable security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
declare
  v_base record;
  v_district public.srk_india_districts%rowtype;
  v_rule public.srk_service_pricing_rules%rowtype;
  v_override public.srk_district_service_rate_overrides%rowtype;
  v_level uuid;
  v_service_rate_count integer:=0;
  v_tech numeric(12,2);
  v_helper numeric(12,2);
  v_total numeric(12,2);
  v_fixed numeric(12,2);
  v_commission numeric(5,2);
  v_pending numeric(12,2);
begin
  select * into v_base from srk_private.preview_booking_price_base(
    p_category_id,p_service_type_id,p_skill_id,p_skill_level_id,
    p_technician_count,p_helper_count,p_duration_hours,p_motor_hp,p_unit_count
  );
  if not found then raise exception 'Approved service price is unavailable'; end if;

  select * into v_district from public.srk_india_districts
  where is_active and lower(btrim(state_name))=lower(btrim(p_state))
    and lower(btrim(district_name))=lower(btrim(p_district))
  limit 1;
  if not found then raise exception 'सही State और District चुनें।'; end if;

  select * into v_rule from public.srk_service_pricing_rules
  where category_id=p_category_id and service_type_id=p_service_type_id
    and effective_from<=clock_timestamp() and (effective_to is null or effective_to>clock_timestamp())
  order by effective_from desc limit 1;

  select coalesce((setting_value #>> '{}')::numeric,15.00)
  into v_commission from public.srk_system_settings where setting_key='company_commission_rate';
  v_commission:=coalesce(v_commission,15.00);
  select coalesce(sum(cf.fee_amount),0) into v_pending from public.srk_booking_cancellation_fees cf where cf.customer_user_id=auth.uid() and cf.status='pending';

  if v_base.pricing_unit='hour' then
    v_level:=p_skill_level_id;
    if v_level is null then
      select id into v_level from public.srk_skill_levels
      where category_id=p_category_id and is_active order by sort_order limit 1;
    end if;
    select count(*) into v_service_rate_count from public.srk_service_rates sr
    where sr.category_id=p_category_id and sr.service_type_id=p_service_type_id
      and sr.rate_status='approved' and sr.effective_from<=clock_timestamp()
      and (sr.effective_to is null or sr.effective_to>clock_timestamp());

    if v_service_rate_count>0 then
      select o.* into v_override
      from public.srk_service_rates sr
      join public.srk_district_service_rate_overrides o
        on o.service_rate_id=sr.id and o.district_lgd_code=v_district.district_lgd_code
       and o.effective_to is null
      where sr.category_id=p_category_id and sr.service_type_id=p_service_type_id
        and sr.skill_level_id=v_level and sr.rate_status='approved'
        and sr.effective_from<=clock_timestamp() and (sr.effective_to is null or sr.effective_to>clock_timestamp())
      order by o.effective_from desc limit 1;
    else
      select * into v_override from public.srk_district_service_rate_overrides
      where district_lgd_code=v_district.district_lgd_code
        and pricing_rule_id=v_rule.id and effective_to is null
      order by effective_from desc limit 1;
    end if;
    if not found or coalesce(v_override.technician_rate,0)<=0 then
      raise exception 'इस जिले और चुनी गई सेवा/Skill के लिए Rate not configured है।';
    end if;
    v_tech:=v_override.technician_rate;
    v_helper:=coalesce(v_override.helper_rate,0);
    if p_helper_count>0 and v_helper<=0 then
      raise exception 'इस जिले और चुनी गई सेवा के लिए Helper Rate not configured है।';
    end if;
    v_total:=round((v_tech*p_technician_count+v_helper*p_helper_count)*p_duration_hours,2);
  elsif v_base.pricing_unit='per_item' then
    select * into v_override from public.srk_district_service_rate_overrides
    where district_lgd_code=v_district.district_lgd_code and pricing_rule_id=v_rule.id and effective_to is null
    order by effective_from desc limit 1;
    if not found or coalesce(v_override.fixed_price,0)<=0 then
      raise exception 'इस जिले और चुनी गई सेवा का Rate not configured है।';
    end if;
    v_tech:=v_override.fixed_price;v_helper:=0;
    v_total:=round(v_override.fixed_price*p_unit_count,2);
  elsif v_base.pricing_unit='motor_hp' then
    select * into v_override from public.srk_district_service_rate_overrides
    where district_lgd_code=v_district.district_lgd_code and pricing_rule_id=v_rule.id and effective_to is null
    order by effective_from desc limit 1;
    if not found then raise exception 'इस जिले के Motor/Pump HP Rates not configured हैं।'; end if;
    select (x->>'fixed_price')::numeric into v_fixed
    from jsonb_array_elements(coalesce(v_override.hp_tiers,'[]'::jsonb)) x
    where (x->>'motor_hp')::numeric=p_motor_hp limit 1;
    if v_fixed is null or v_fixed<=0 then raise exception 'इस जिले और चुने गए HP का Rate not configured है।'; end if;
    v_tech:=v_fixed;v_helper:=0;v_total:=v_fixed;
  else
    raise exception 'Unsupported pricing unit';
  end if;

  return query select v_base.pricing_unit,v_base.qualification_level,v_tech,v_helper,v_total,
    round(v_total*v_commission/100,2),v_total-round(v_total*v_commission/100,2),
    v_base.overtime_may_apply,
    'District-approved service rate · '||v_district.district_name||', '||v_district.state_name,
    v_pending,round(v_total+v_pending,2);
end;
$function$;;
create or replace function public.srk_customer_preview_booking_price_v3(
  p_category_id uuid,p_service_type_id uuid,p_skill_id uuid,p_skill_level_id uuid,
  p_technician_count integer,p_helper_count integer,p_duration_hours integer,
  p_motor_hp numeric default null,p_unit_count integer default 1,
  p_state text default null,p_district text default null
) returns table(
  pricing_unit text,qualification_level text,technician_rate numeric,helper_rate numeric,
  estimated_base_total numeric,estimated_company_commission numeric,estimated_worker_net numeric,
  overtime_may_apply boolean,price_note text,
  pending_cancellation_fee_amount numeric,estimated_customer_total numeric
)
language sql stable security invoker set search_path=pg_catalog,public
as $function$
  select * from srk_private.preview_booking_price_with_district(
    p_category_id,p_service_type_id,p_skill_id,p_skill_level_id,
    p_technician_count,p_helper_count,p_duration_hours,p_motor_hp,p_unit_count,p_state,p_district
  );
$function$;;
CREATE OR REPLACE FUNCTION public.srk_customer_create_booking(p_category_id uuid, p_service_type_id uuid, p_skill_id uuid, p_technician_count integer, p_helper_count integer, p_duration_hours integer, p_state text, p_district text, p_pincode text, p_address text, p_booking_latitude double precision, p_booking_longitude double precision, p_current_gps_latitude double precision, p_current_gps_longitude double precision, p_motor_hp numeric, p_skill_level_id uuid, p_unit_count integer)
 RETURNS service_bookings
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
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
  commission_rate,customer_user_id,customer_id,category_id,service_type_id,selected_skill_id,
  requested_technician_count,requested_helper_count,requested_duration_hours,booking_latitude,booking_longitude,requested_skill_level_id,
  location_lat,location_lng,booking_address_confirmed_at,booking_location_source,
  pricing_unit_snapshot,pricing_quantity,pricing_rule_id,motor_hp,operational_settings_snapshot,user_custom_settings_snapshot
 ) values(
  v_customer.full_name,v_customer.phone,btrim(p_state),btrim(p_district),p_pincode,btrim(p_address),v_service.service_name,
  'Unselected','new',15.00,auth.uid(),v_customer.id,p_category_id,p_service_type_id,p_skill_id,
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
$function$
;
;
CREATE OR REPLACE FUNCTION public.srk_submit_labour_quote(p_booking_id uuid, p_service_charge numeric, p_quote_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_worker_id uuid;
  v_booking_worker_id uuid;
  v_booking public.service_bookings%rowtype;
  v_total numeric(12,2);
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;

  if p_booking_id is null or p_service_charge is null
     or p_service_charge<=0 or p_service_charge>10000000
     or p_service_charge<>round(p_service_charge,2) then
    raise exception 'Invalid labour quote' using errcode='22023';
  end if;

  select id into v_worker_id
  from public.srk_worker_profiles
  where user_id=auth.uid()
    and verification_status='approved'
    and is_active=true
  order by created_at desc
  limit 1;

  if v_worker_id is null then
    raise exception 'Approved active Technician required' using errcode='42501';
  end if;

  select id into v_booking_worker_id
  from public.srk_booking_workers
  where booking_id=p_booking_id
    and worker_id=v_worker_id
    and assignment_status in ('accepted','assigned','working','paused')
  order by assigned_at desc
  limit 1
  for update;

  if v_booking_worker_id is null then
    raise exception 'Accepted booking assignment not found' using errcode='42501';
  end if;

  select * into v_booking
  from public.service_bookings
  where id=p_booking_id
  for update;

  if not found then
    raise exception 'Booking not found' using errcode='42501';
  end if;

  if v_booking.status not in ('confirmed','assigned','inspection','quote_rejected') then
    raise exception 'Booking is not ready for a labour quote' using errcode='22023';
  end if;

  v_total:=round(p_service_charge,2);

  update public.service_bookings
  set service_charge=v_total,

      quoted_amount=v_total,
      quote_note=left(coalesce(p_quote_note,''),1000),
      quote_status='pending',
      quote_submitted_at=pg_catalog.now(),
      quote_responded_at=null,
      status='awaiting_quote_approval'
  where id=p_booking_id;

  return pg_catalog.jsonb_build_object(
    'success',true,
    'labour_amount',v_total,
    'total',v_total,
    'quote_status','pending'
  );
end
$function$
;
CREATE OR REPLACE FUNCTION public.srk_capture_admin_audit_event()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_old jsonb := CASE WHEN TG_OP='INSERT' THEN '{}'::jsonb ELSE to_jsonb(OLD) END;
  v_new jsonb := CASE WHEN TG_OP='DELETE' THEN '{}'::jsonb ELSE to_jsonb(NEW) END;
  v_before jsonb := '{}'::jsonb;
  v_after jsonb := '{}'::jsonb;
  v_fields text[] := ARRAY[]::text[];
  v_key text;
  v_entity_type text;
  v_entity_id uuid;
  v_booking_id uuid;
  v_actor uuid := auth.uid();
  v_role text;
  v_allow text[];
BEGIN
  v_entity_type := CASE TG_TABLE_NAME
    WHEN 'service_bookings' THEN 'booking'
    WHEN 'electrician_profiles' THEN 'electrician_profile'
    WHEN 'electrician_applications' THEN 'electrician_application'
    WHEN 'srk_manual_payment_entries' THEN 'manual_payment'
    WHEN 'srk_manual_refund_entries' THEN 'manual_refund'
    WHEN 'srk_electrician_payouts' THEN 'electrician_payout'
    ELSE NULL END;
  IF v_entity_type IS NULL THEN
    IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  END IF;

  v_allow := CASE v_entity_type
    WHEN 'booking' THEN ARRAY['status','payment_status','payment_method','amount_paid','quoted_amount','quote_status','service_charge','assigned_electrician_id','commission_amount']
    WHEN 'electrician_profile' THEN ARRAY['active','verification_status','auth_user_id','user_id']
    WHEN 'electrician_application' THEN ARRAY['verification_status','active']
    WHEN 'manual_payment' THEN ARRAY['booking_id','payment_method','amount']
    WHEN 'manual_refund' THEN ARRAY['booking_id','payment_entry_id','amount']
    WHEN 'electrician_payout' THEN ARRAY['booking_id','payout_status','payout_method','payout_reference','payout_note','electrician_payable','platform_commission','paid_at']
    ELSE ARRAY[]::text[] END;

  v_entity_id := coalesce(nullif(v_new->>'id','')::uuid,nullif(v_old->>'id','')::uuid);
  v_booking_id := CASE WHEN v_entity_type='booking' THEN v_entity_id
    ELSE coalesce(nullif(v_new->>'booking_id','')::uuid,nullif(v_old->>'booking_id','')::uuid) END;
  IF v_entity_id IS NULL THEN
    IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  END IF;

  FOREACH v_key IN ARRAY v_allow LOOP
    IF v_old->v_key IS DISTINCT FROM v_new->v_key THEN
      v_fields := array_append(v_fields,v_key);
      IF v_old ? v_key THEN v_before := v_before || jsonb_build_object(v_key,v_old->v_key); END IF;
      IF v_new ? v_key THEN v_after := v_after || jsonb_build_object(v_key,v_new->v_key); END IF;
    END IF;
  END LOOP;
  IF cardinality(v_fields)=0 THEN
    IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  END IF;

  v_role := CASE WHEN v_actor IS NULL THEN 'system'
    WHEN public.is_srk_admin() THEN 'admin' ELSE 'user' END;
  INSERT INTO public.srk_admin_audit_events
    (entity_type,entity_id,booking_id,action,actor_user_id,actor_role,changed_fields,before_data,after_data)
  VALUES
    (v_entity_type,v_entity_id,v_booking_id,
     CASE TG_OP WHEN 'INSERT' THEN 'created' WHEN 'UPDATE' THEN 'updated' ELSE 'deleted' END,
     v_actor,v_role,v_fields,v_before,v_after);
  IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.srk_admin_record_manual_payment(p_booking_id uuid, p_method text, p_reference text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_booking public.service_bookings%rowtype;
  v_total numeric(12,2);
  v_method text;
  v_reference text;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  if p_booking_id is null then
    raise exception 'Booking ID is required';
  end if;
  v_method := lower(trim(coalesce(p_method,'')));
  if v_method not in ('cash','upi','bank_transfer') then
    raise exception 'Payment method must be cash, upi, or bank_transfer';
  end if;
  v_reference := trim(coalesce(p_reference,''));
  if length(v_reference) < 4 or length(v_reference) > 120 then
    raise exception 'A valid receipt number or payment reference is required';
  end if;
  if p_note is not null and length(p_note) > 250 then
    raise exception 'Payment note is too long';
  end if;

  select * into v_booking
  from public.service_bookings
  where id = p_booking_id
  for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_booking.status <> 'completed' or v_booking.quote_status <> 'approved' then
    raise exception 'Only completed bookings with an approved quote can be marked paid';
  end if;
  if v_booking.assigned_electrician_id is null then
    raise exception 'Booking has no assigned electrician';
  end if;
  if v_booking.payment_status = 'paid' or v_booking.payment_status in ('partially_refunded','refunded') then
    raise exception 'Booking already has a paid or refunded payment';
  end if;
  if v_booking.razorpay_order_id is not null or v_booking.razorpay_payment_id is not null then
    raise exception 'Razorpay-linked bookings must be paid only through verified Razorpay flow';
  end if;
  if exists (select 1 from public.srk_manual_payment_entries e where e.booking_id = p_booking_id) then
    raise exception 'A manual payment entry already exists for this booking';
  end if;
  if v_booking.service_charge is null or v_booking.service_charge < 0 then
    raise exception 'Approved quote breakdown is invalid';
  end if;
  v_total := round(v_booking.service_charge,2);
  if v_total < 1 or v_total > 10000000 or round(coalesce(v_booking.quoted_amount,-1),2) <> v_total then
    raise exception 'Approved service total does not match the final bill';
  end if;

  insert into public.srk_manual_payment_entries
    (booking_id,payment_method,amount,payment_reference,note,recorded_by)
  values
    (p_booking_id,v_method,v_total,v_reference,nullif(trim(coalesce(p_note,'')),''),auth.uid());

  update public.service_bookings
  set payment_method = case v_method
        when 'cash' then 'Cash'
        when 'upi' then 'UPI'
        else 'Bank Transfer'
      end,
      payment_status = 'paid',
      amount_paid = v_total,
      payment_verified_at = now()
  where id = p_booking_id;

  return jsonb_build_object(
    'success',true,
    'booking_id',p_booking_id,
    'payment_method',v_method,
    'amount',v_total,
    'reference',v_reference
  );
end;
$function$
;
CREATE OR REPLACE FUNCTION public.srk_admin_mark_electrician_payout_paid(p_payout_id uuid, p_method text, p_reference text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_row public.srk_electrician_payouts%rowtype;
  v_booking_id uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING errcode = '42501';
  END IF;
  IF p_payout_id IS NULL THEN
    RAISE EXCEPTION 'Payout ID is required';
  END IF;
  IF p_method IS NULL OR p_method NOT IN ('upi','bank') THEN
    RAISE EXCEPTION 'Payout method must be upi or bank';
  END IF;
  IF p_reference IS NULL OR pg_catalog.length(pg_catalog.btrim(p_reference)) < 4
     OR pg_catalog.length(pg_catalog.btrim(p_reference)) > 120 THEN
    RAISE EXCEPTION 'Valid UTR / UPI reference is required';
  END IF;
  IF p_note IS NOT NULL AND pg_catalog.length(p_note) > 250 THEN
    RAISE EXCEPTION 'Payout note is too long';
  END IF;

  -- Global lock order: booking first, then payout. Manual refund uses the same
  -- booking-first order, so refund and payout settlement cannot pass each other.
  SELECT booking_id INTO v_booking_id
    FROM public.srk_electrician_payouts
   WHERE id = p_payout_id;
  IF NOT FOUND OR v_booking_id IS NULL THEN
    RAISE EXCEPTION 'Payout record not found or has no booking';
  END IF;

  PERFORM 1
    FROM public.service_bookings
   WHERE id = v_booking_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payout booking not found';
  END IF;

  SELECT * INTO v_row
    FROM public.srk_electrician_payouts
   WHERE id = p_payout_id
   FOR UPDATE;
  IF NOT FOUND OR v_row.booking_id IS DISTINCT FROM v_booking_id THEN
    RAISE EXCEPTION 'Payout record changed; retry the operation';
  END IF;
  IF v_row.payout_status <> 'pending' THEN
    RAISE EXCEPTION 'Only pending payouts can be marked paid';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM public.service_bookings b
     WHERE b.id = v_row.booking_id
       AND b.status = 'completed'
       AND b.quote_status = 'approved'
       AND b.payment_status = 'paid'
       AND b.payment_verified_at IS NOT NULL
       AND (
         (
           v_row.razorpay_payment_id IS NOT NULL
           AND b.razorpay_payment_id = v_row.razorpay_payment_id
         )
         OR
         (
           v_row.razorpay_payment_id IS NULL
           AND b.razorpay_payment_id IS NULL
           AND EXISTS (
             SELECT 1
               FROM public.srk_manual_payment_entries e
              WHERE e.booking_id = b.id
                AND pg_catalog.round(coalesce(e.amount,0),2) =
                    pg_catalog.round(coalesce(b.amount_paid,0),2)
           )
         )
       )
       AND b.assigned_electrician_id = v_row.electrician_profile_id
       AND pg_catalog.round(coalesce(b.amount_paid,0),2) =
           pg_catalog.round(coalesce(b.service_charge,0),2)
       AND pg_catalog.round(coalesce(v_row.gross_service_amount,0),2) =
           pg_catalog.round(coalesce(b.service_charge,0),2)
AND pg_catalog.round(coalesce(v_row.platform_commission,0),2) =
           pg_catalog.round(coalesce(b.service_charge,0) * b.commission_rate / 100,2)
       AND pg_catalog.round(coalesce(v_row.electrician_payable,0),2) =
           pg_catalog.round(coalesce(b.service_charge,0)
             - pg_catalog.round(coalesce(b.service_charge,0) * b.commission_rate / 100,2),2)
  ) THEN
    RAISE EXCEPTION 'Booking payment or payout ledger does not match verified booking; payout blocked';
  END IF;

  UPDATE public.srk_electrician_payouts
     SET payout_status = 'paid',
         payout_method = p_method,
         payout_reference = pg_catalog.btrim(p_reference),
         payout_note = nullif(pg_catalog.btrim(p_note),''),
         paid_by = auth.uid(),
         paid_at = pg_catalog.now(),
         updated_at = pg_catalog.now()
   WHERE id = p_payout_id;
  RETURN pg_catalog.jsonb_build_object('success', true, 'payout_id', p_payout_id, 'status', 'paid');
END;
$function$
;
CREATE OR REPLACE FUNCTION public.srk_get_my_assigned_booking_quote_details()
 RETURNS TABLE(booking_id uuid, service_type text, state text, district text, pincode text, booking_status text, quoted_amount numeric, service_charge numeric, quote_status text, quote_note text, payment_method text, payment_status text, location_lat double precision, location_lng double precision, address text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
  select b.id, b.service_type, b.state, b.district, b.pincode, b.status,
         b.quoted_amount, b.service_charge,
         b.quote_status, b.quote_note, b.payment_method, b.payment_status,
         b.location_lat, b.location_lng, b.address
    from public.electrician_profiles p
    join public.service_bookings b on b.assigned_electrician_id = p.id
   where auth.uid() is not null
     and (p.user_id = auth.uid() or p.auth_user_id = auth.uid())
     and p.verification_status = 'approved'
     and p.active = true
     and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed')
   order by b.created_at desc
   limit 100;
$function$
;
CREATE OR REPLACE FUNCTION public.srk_get_my_offer_details()
 RETURNS TABLE(offer_id uuid, offer_status text, match_level text, offer_created_at timestamp with time zone, booking_id uuid, service_type text, state text, district text, pincode text, preferred_date date, preferred_time time without time zone, work_details text, quoted_amount numeric, booking_status text, customer_name text, customer_phone text, address text, location_lat double precision, location_lng double precision, service_charge numeric, quote_status text, quote_note text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
  select
    o.id,
    o.status,
    o.match_level,
    o.created_at,
    b.id,
    b.service_type,
    b.state,
    b.district,
    b.pincode,
    b.preferred_date,
    b.preferred_time,
    b.work_details,
    b.quoted_amount,
    b.status,
    case
      when b.assigned_electrician_id = p.id
       and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.customer_name else null
    end,
    case
      when b.assigned_electrician_id = p.id
       and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.phone else null
    end,
    case
      when b.assigned_electrician_id = p.id
       and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.address else null
    end,
    case
      when b.assigned_electrician_id = p.id
       and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.location_lat else null
    end,
    case
      when b.assigned_electrician_id = p.id
       and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.location_lng else null
    end,
    case
      when b.assigned_electrician_id = p.id
       and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.service_charge else null
    end,
    case
      when b.assigned_electrician_id = p.id
       and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.quote_status else null
    end,
    case
      when b.assigned_electrician_id = p.id
       and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.quote_note else null
    end
  from public.job_offers o
  join public.electrician_profiles p on p.id = o.electrician_id
  join public.service_bookings b on b.id = o.booking_id
  where p.user_id = auth.uid()
    and p.verification_status = 'approved'
    and p.active = true
  order by o.created_at desc
  limit 100;
$function$
  select
    o.id,
    o.status,
    o.match_level,
    o.created_at,
    b.id,
    b.service_type,
    b.state,
    b.district,
    b.pincode,
    b.preferred_date,
    b.preferred_time,
    b.work_details,
    b.quoted_amount,
    b.status,
    case
      when b.assigned_electrician_id = p.id
       and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.quote_status else null
    end,
    case
      when b.assigned_electrician_id = p.id
       and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.quote_note else null
    end
  from public.job_offers o
  join public.electrician_profiles p on p.id = o.electrician_id
  join public.service_bookings b on b.id = o.booking_id
  where p.user_id = auth.uid()
    and p.verification_status = 'approved'
    and p.active = true
  order by o.created_at desc
  limit 100;
$function$
;
CREATE OR REPLACE FUNCTION public.srk_get_my_offer_price_details()
 RETURNS TABLE(offer_id uuid, booking_id uuid, offer_status text, customer_suggested_amount numeric, electrician_quote_kind text, service_charge numeric, quote_status text, quote_note text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
  select
    o.id,
    b.id,
    o.status,
    b.customer_suggested_amount,
    b.electrician_quote_kind,
    case when b.assigned_electrician_id = p.id then b.service_charge else null end,
    case when b.assigned_electrician_id = p.id then b.quote_status else null end,
    case when b.assigned_electrician_id = p.id then b.quote_note else null end
  from public.job_offers o
  join public.electrician_profiles p on p.id = o.electrician_id
  join public.service_bookings b on b.id = o.booking_id
  where auth.uid() is not null
    and (p.user_id = auth.uid() or p.auth_user_id = auth.uid())
    and p.verification_status = 'approved'
    and p.active = true
  order by o.created_at desc
  limit 100;
$function$
;
create or replace function public.srk_get_public_service_pricing_options(p_service_type_id uuid)
returns jsonb
language plpgsql
set search_path=pg_catalog,public
as $function$
declare v_result jsonb;
begin
 if p_service_type_id is null then raise exception 'Service type ID is required' using errcode='22023'; end if;
 select jsonb_build_object(
  'category_id',c.id,'category_code',c.category_code,'category_name',c.category_name,
  'service_type_id',s.id,'service_code',s.service_code,'service_name',s.service_name,
  'pricing_unit',coalesce(r.pricing_unit,'hour'),'timer_enabled',coalesce(r.timer_enabled,true),
  'pricing_note',r.pricing_note,
  'skill_levels',coalesce((select jsonb_agg(jsonb_build_object('skill_level_id',l.id,'skill_level_code',l.level_code,'skill_level_name',l.level_name) order by l.sort_order)
    from public.srk_skill_levels l where l.category_id=c.id and l.is_active),'[]'::jsonb),
  'hp_options',coalesce((select jsonb_agg(jsonb_build_object('motor_hp',t.motor_hp) order by t.motor_hp)
    from public.srk_service_pricing_hp_tiers t where t.pricing_rule_id=r.id),'[]'::jsonb)
 ) into v_result
 from public.srk_service_types s
 join public.srk_service_categories c on c.id=s.category_id
 left join lateral (select * from public.srk_service_pricing_rules x where x.category_id=c.id and x.service_type_id=s.id
  and x.effective_from<=clock_timestamp() and (x.effective_to is null or x.effective_to>clock_timestamp())
  order by x.effective_from desc limit 1) r on true
 where s.id=p_service_type_id and s.is_active and c.is_active;
 if v_result is null then raise exception 'Active service type not found'; end if;
 return v_result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_finalize_booking_bill(p_booking_id uuid)
 RETURNS srk_booking_final_bills
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
declare
  v_booking public.service_bookings%rowtype;
  v_bill public.srk_booking_final_bills%rowtype;
  v_rule public.srk_service_pricing_rules%rowtype;
  v_labour numeric(12,2):=0;
  v_worker record;
  v_worker_gross numeric(12,2);
  v_worker_commission numeric(12,2);
  v_existing public.srk_booking_final_bills%rowtype;
  v_next_revision integer;
  v_tech_worked integer;
  v_helper_worked integer;
  v_is_fixed boolean:=false;
  v_expected_fixed_amount numeric(12,2);
  v_cancellation_fee numeric(12,2):=0;
begin
  if auth.uid() is null or not public.srk_has_admin_permission('bookings.manage') then
    raise exception 'Booking management permission required' using errcode='42501';
  end if;

  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;

  if v_booking.status is distinct from 'in_progress'
     or v_booking.completion_approval_status is distinct from 'pending'
     or v_booking.completion_requested_at is null
     or coalesce(v_booking.work_timer_running,false) then
    raise exception 'Final bill requires completed worker sessions and a pending Customer completion review';
  end if;
  if v_booking.payment_status='paid' then raise exception 'Paid booking cannot be rebilled'; end if;
  if v_booking.commission_rate is null or v_booking.commission_rate<0 or v_booking.commission_rate>100 then
    raise exception 'Booking commission snapshot is invalid';
  end if;

  if v_booking.pricing_unit_snapshot in ('per_item','motor_hp') then
    v_is_fixed:=true;
    if v_booking.pricing_rule_id is null or v_booking.pricing_quantity is null or v_booking.pricing_quantity<=0 then
      raise exception 'Fixed-price booking pricing snapshot is incomplete';
    end if;
    select * into v_rule from public.srk_service_pricing_rules
    where id=v_booking.pricing_rule_id and pricing_unit=v_booking.pricing_unit_snapshot for share;
    if not found or (v_booking.pricing_unit_snapshot='per_item' and (v_rule.technician_rate is null or v_rule.technician_rate<=0)) then
      raise exception 'Fixed-price booking rule snapshot is missing or invalid';
    end if;
    if v_booking.pricing_unit_snapshot='motor_hp' then
      select t.fixed_price into v_expected_fixed_amount from public.srk_service_pricing_hp_tiers t where t.pricing_rule_id=v_rule.id and t.motor_hp=v_booking.motor_hp;
      if v_expected_fixed_amount is null then raise exception 'Approved fixed price for this Motor/Pump HP is missing'; end if;
    else
      v_expected_fixed_amount:=round(v_rule.technician_rate*v_booking.pricing_quantity,2);
    end if;
    if v_booking.district_rate_snapshot is not null then
      v_expected_fixed_amount:=srk_private.get_district_fixed_service_amount(p_booking_id);
      if v_expected_fixed_amount is null then raise exception 'District fixed service rate snapshot is missing'; end if;
    end if;
    v_labour:=v_expected_fixed_amount;

    select count(*) filter (where bw.worker_role='technician'),
           count(*) filter (where bw.worker_role='helper')
      into v_tech_worked,v_helper_worked
    from public.srk_booking_workers bw
    where bw.booking_id=p_booking_id and bw.assignment_status in ('completed','released');

    if v_tech_worked<v_booking.requested_technician_count
       or v_helper_worked<v_booking.requested_helper_count then
      raise exception 'Requested number of Technicians/Helpers has not completed the fixed-price work';
    end if;

    perform 1 from public.srk_booking_workers where booking_id=p_booking_id for update;
    perform 1 from public.srk_fixed_price_worker_allocations where booking_id=p_booking_id for update;

    if (select count(*) from public.srk_fixed_price_worker_allocations where booking_id=p_booking_id)
       <> (select count(*) from public.srk_booking_workers
           where booking_id=p_booking_id and assignment_status in ('completed','released')) then
      raise exception 'Every completed/released worker must have exactly one fixed-price allocation';
    end if;

    if exists (
      select 1 from public.srk_fixed_price_worker_allocations a
      left join public.srk_booking_workers bw
        on bw.id=a.booking_worker_id and bw.booking_id=p_booking_id
       and bw.assignment_status in ('completed','released')
      where a.booking_id=p_booking_id and bw.id is null
    ) then
      raise exception 'Fixed-price allocation references a worker who is not completed/released on this booking';
    end if;

    if (select coalesce(sum(gross_service_earning),0)
        from public.srk_fixed_price_worker_allocations where booking_id=p_booking_id)
       <> v_expected_fixed_amount then
      raise exception 'Fixed-price worker allocations must exactly equal the approved service price';
    end if;
  else
    if v_booking.pricing_unit_snapshot is not null
       and v_booking.pricing_unit_snapshot not in ('hour') then
      raise exception 'Unsupported pricing unit for final billing';
    end if;

    select count(*) into v_tech_worked
    from public.srk_booking_workers bw
    where bw.booking_id=p_booking_id and bw.worker_role='technician'
      and bw.assignment_status in ('completed','released')
      and exists (select 1 from public.srk_worker_work_sessions s
                  where s.booking_worker_id=bw.id and s.billable_seconds>0);

    select count(*) into v_helper_worked
    from public.srk_booking_workers bw
    where bw.booking_id=p_booking_id and bw.worker_role='helper'
      and bw.assignment_status in ('completed','released')
      and exists (select 1 from public.srk_worker_work_sessions s
                  where s.booking_worker_id=bw.id and s.billable_seconds>0);

    if v_tech_worked<v_booking.requested_technician_count
       or v_helper_worked<v_booking.requested_helper_count then
      raise exception 'Requested number of Technicians/Helpers has not completed billable work';
    end if;

    for v_worker in
      select bw.id booking_worker_id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot,
        coalesce(sum(s.billable_seconds),0)::bigint seconds, public.srk_worker_session_time_breakdown(bw.id,bw.hourly_rate_snapshot) time_breakdown
      from public.srk_booking_workers bw
      left join public.srk_worker_work_sessions s on s.booking_worker_id=bw.id
      where bw.booking_id=p_booking_id and bw.assignment_status in ('completed','released')
      group by bw.id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot
      having coalesce(sum(s.billable_seconds),0)>0
    loop
      if v_worker.hourly_rate_snapshot is null then raise exception 'Worker rate snapshot missing'; end if;
      if v_worker.seconds>coalesce(v_booking.requested_duration_hours,1440)*3600 then
        raise exception 'Worker actual billable time exceeds booked maximum duration';
      end if;
      v_worker_gross:=round((v_worker.time_breakdown->>'gross_amount')::numeric,2);
      v_labour:=v_labour+v_worker_gross;
    end loop;
  end if;

  if exists (
    select 1 from public.srk_booking_workers
    where booking_id=p_booking_id
      and assignment_status not in ('completed','released','cancelled','rejected')
  ) then raise exception 'All assigned workers must complete or be released before final billing'; end if;

  if exists (
    select 1 from public.srk_worker_work_sessions s
    join public.srk_booking_workers bw on bw.id=s.booking_worker_id
    where bw.booking_id=p_booking_id and s.session_status not in ('completed','cancelled')
  ) then raise exception 'Every work session must be completed or cancelled before final billing'; end if;

  v_cancellation_fee:=coalesce(v_booking.pending_cancellation_fee_amount,0);

  select * into v_existing from public.srk_booking_final_bills
  where booking_id=p_booking_id for update;

  if found then
    if exists (
      select 1 from public.srk_worker_earnings e
      join public.srk_worker_wallet_ledger l on l.earning_id=e.id
      where e.booking_id=p_booking_id
    ) then raise exception 'Final bill cannot be reissued after worker earnings have entered the wallet ledger; use refund/reconciliation'; end if;
    if exists (select 1 from public.srk_booking_refund_requests r
               where r.booking_id=p_booking_id and r.status<>'rejected') then
      raise exception 'Final bill cannot be reissued while a refund request is active';
    end if;
    if v_existing.status in ('issued','approved','disputed') then
      raise exception 'An active final bill already exists';
    end if;

    v_next_revision:=v_existing.revision_no+1;
    insert into public.srk_booking_final_bill_revisions(
      bill_id,revision_no,previous_bill_data,previous_items,reason,archived_by
    ) values (
      v_existing.id,v_existing.revision_no,to_jsonb(v_existing),
      coalesce((select jsonb_agg(to_jsonb(i) order by i.created_at)
                from public.srk_booking_final_bill_items i where i.bill_id=v_existing.id),'[]'::jsonb),
      'Reissued after work reopening',auth.uid()
    );
    delete from public.srk_booking_final_bill_items where bill_id=v_existing.id;
    update public.srk_booking_final_bills
    set bill_number='SRK-BILL-'||lpad(nextval('public.srk_bill_number_seq')::text,6,'0'),
      revision_no=v_next_revision,service_amount=v_labour,cancellation_fee_amount=v_cancellation_fee,
      discount_amount=0,tax_amount=0,status='issued',prepared_at=clock_timestamp(),updated_at=clock_timestamp()
    where id=v_existing.id returning * into v_bill;
  else
    insert into public.srk_booking_final_bills(
      booking_id,bill_number,revision_no,service_amount,cancellation_fee_amount,status,prepared_at
    ) values (
      p_booking_id,'SRK-BILL-'||lpad(nextval('public.srk_bill_number_seq')::text,6,'0'),
      1,v_labour,v_cancellation_fee,'issued',clock_timestamp()
    ) returning * into v_bill;
  end if;

  insert into public.srk_booking_final_bill_items(
    bill_id,item_type,description,quantity,unit,unit_price
  ) values (
    v_bill.id,'labour',
    case when v_is_fixed then 'Approved fixed per-item service charge'
         else 'Actual worker timer-based labour charges' end,
    1,'booking',v_labour
  );
  if v_cancellation_fee>0 then
    insert into public.srk_booking_final_bill_items(
      bill_id,item_type,description,quantity,unit,unit_price
    ) values(v_bill.id,'cancellation_fee','Pending cancellation fee from a previous booking',1,'booking',v_cancellation_fee);
  end if;

  if v_is_fixed then
    for v_worker in
      select a.booking_worker_id,a.worker_id,bw.worker_role,
        a.gross_service_earning gross_amount
      from public.srk_fixed_price_worker_allocations a
      join public.srk_booking_workers bw on bw.id=a.booking_worker_id
      where a.booking_id=p_booking_id
      order by a.booking_worker_id
    loop
      v_worker_gross:=v_worker.gross_amount;
      v_worker_commission:=round(v_worker_gross*v_booking.commission_rate/100,2);

      insert into public.srk_worker_earnings(
        booking_id,booking_worker_id,worker_id,worker_role,bill_id,
        billable_seconds,gross_service_earning,company_commission_rate,
        company_commission,net_earning,payment_method,payout_status,settlement_status
      ) values (
        p_booking_id,v_worker.booking_worker_id,v_worker.worker_id,v_worker.worker_role,
        v_bill.id,0,v_worker_gross,v_booking.commission_rate,v_worker_commission,
        v_worker_gross-v_worker_commission,
        case when lower(v_booking.payment_method) in ('upi','card') then 'online'
             else lower(v_booking.payment_method) end,
        'pending','pending'
      )
      on conflict(booking_worker_id) do update set
        bill_id=excluded.bill_id,billable_seconds=0,
        gross_service_earning=excluded.gross_service_earning,
        company_commission_rate=excluded.company_commission_rate,
        company_commission=excluded.company_commission,net_earning=excluded.net_earning,
        payment_method=excluded.payment_method,payout_status='pending',
        settlement_status='pending',updated_at=clock_timestamp();
    end loop;
  else
    for v_worker in
      select bw.id booking_worker_id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot,
        coalesce(sum(s.billable_seconds),0)::bigint seconds, public.srk_worker_session_time_breakdown(bw.id,bw.hourly_rate_snapshot) time_breakdown
      from public.srk_booking_workers bw
      left join public.srk_worker_work_sessions s on s.booking_worker_id=bw.id
      where bw.booking_id=p_booking_id and bw.assignment_status in ('completed','released')
      group by bw.id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot
      having coalesce(sum(s.billable_seconds),0)>0
    loop
      v_worker_gross:=round((v_worker.time_breakdown->>'gross_amount')::numeric,2);
      v_worker_commission:=round(v_worker_gross*v_booking.commission_rate/100,2);

      insert into public.srk_worker_earnings(
        booking_id,booking_worker_id,worker_id,worker_role,bill_id,
        billable_seconds,normal_billable_seconds,overtime_billable_seconds,overtime_multiplier,gross_service_earning,company_commission_rate,
        company_commission,net_earning,payment_method,payout_status,settlement_status
      ) values (
        p_booking_id,v_worker.booking_worker_id,v_worker.worker_id,v_worker.worker_role,
        v_bill.id,v_worker.seconds,(v_worker.time_breakdown->>'normal_seconds')::bigint,(v_worker.time_breakdown->>'overtime_seconds')::bigint,(v_worker.time_breakdown->>'overtime_multiplier')::numeric,v_worker_gross,v_booking.commission_rate,v_worker_commission,
        v_worker_gross-v_worker_commission,
        case when lower(v_booking.payment_method) in ('upi','card') then 'online'
             else lower(v_booking.payment_method) end,
        'pending','pending'
      )
      on conflict(booking_worker_id) do update set
        bill_id=excluded.bill_id,billable_seconds=excluded.billable_seconds,normal_billable_seconds=excluded.normal_billable_seconds,overtime_billable_seconds=excluded.overtime_billable_seconds,overtime_multiplier=excluded.overtime_multiplier,
        gross_service_earning=excluded.gross_service_earning,
        company_commission_rate=excluded.company_commission_rate,
        company_commission=excluded.company_commission,net_earning=excluded.net_earning,
        payment_method=excluded.payment_method,payout_status='pending',
        settlement_status='pending',updated_at=clock_timestamp();
    end loop;
  end if;

  return v_bill;
end;
$function$;

revoke all on function public.srk_customer_create_booking(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision) from public,anon,authenticated;
revoke all on function public.srk_customer_create_booking(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision,numeric) from public,anon,authenticated;
revoke all on function public.srk_customer_create_booking(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision,numeric,uuid) from public,anon,authenticated;
revoke all on function public.srk_customer_create_booking(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision,numeric,uuid,integer) from public,anon,authenticated;
grant execute on function public.srk_customer_create_booking_v2(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision,numeric,uuid,integer) to authenticated;

revoke all on function public.srk_get_my_assigned_booking_quote_details() from public,anon;
revoke all on function public.srk_get_my_offer_details() from public,anon;
revoke all on function public.srk_get_my_offer_price_details() from public,anon;
grant execute on function public.srk_get_my_assigned_booking_quote_details() to authenticated;
grant execute on function public.srk_get_my_offer_details() to authenticated;
grant execute on function public.srk_get_my_offer_price_details() to authenticated;

revoke all on function srk_private.preview_booking_price_base(uuid,uuid,uuid,uuid,integer,integer,integer,numeric,integer) from public,anon,authenticated;
grant execute on function srk_private.preview_booking_price_with_district(uuid,uuid,uuid,uuid,integer,integer,integer,numeric,integer,text,text) to authenticated;
revoke all on function public.srk_customer_preview_booking_price_v3(uuid,uuid,uuid,uuid,integer,integer,integer,numeric,integer,text,text) from public,anon;
grant execute on function public.srk_customer_preview_booking_price_v3(uuid,uuid,uuid,uuid,integer,integer,integer,numeric,integer,text,text) to authenticated;


alter table public.service_bookings drop constraint if exists service_bookings_materials_amount_nonnegative;
alter table public.srk_booking_final_bill_items drop constraint if exists srk_bill_item_type_valid;
alter table public.srk_booking_final_bill_items drop constraint if exists srk_booking_final_bill_items_item_type_check;
alter table public.srk_booking_final_bills drop constraint if exists srk_final_bill_amounts_nonnegative;
alter table public.srk_booking_final_bills drop constraint if exists srk_final_bill_discount_cap;
alter table public.srk_electrician_payouts drop constraint if exists srk_electrician_payouts_materials_amount_check;
alter table public.srk_worker_session_events drop constraint if exists srk_worker_session_event_pause_reason_valid;
alter table public.srk_worker_session_events drop constraint if exists srk_worker_session_events_pause_reason_check;
alter table public.srk_worker_work_sessions drop constraint if exists srk_work_session_pause_reason_valid;
alter table public.srk_worker_work_sessions drop constraint if exists srk_worker_work_sessions_pause_reason_check;

alter table public.service_bookings drop column if exists materials_amount;
alter table public.srk_booking_final_bills drop column if exists materials_amount;
alter table public.srk_electrician_payouts drop column if exists materials_amount;
alter table public.srk_service_pricing_rules drop column if exists materials_charged_separately;
alter table public.srk_service_pricing_rules drop column if exists winding_charged_separately;

alter table public.srk_booking_final_bill_items add constraint srk_booking_final_bill_items_item_type_check
 check (item_type = any(array['service','labour','discount','cancellation_fee']::text[]));
alter table public.srk_booking_final_bills add constraint srk_final_bill_amounts_nonnegative
 check (service_amount>=0 and discount_amount>=0 and tax_amount>=0);
alter table public.srk_booking_final_bills add constraint srk_final_bill_discount_cap check (discount_amount<=service_amount);
alter table public.srk_worker_session_events add constraint srk_worker_session_events_pause_reason_check
 check (pause_reason is null or pause_reason=any(array['food_break','customer_permission','technical_problem','other','lunch','market_other','gps_outside_worksite','admin_override']::text[]));
alter table public.srk_worker_work_sessions add constraint srk_worker_work_sessions_pause_reason_check
 check (pause_reason is null or pause_reason=any(array['food_break','customer_permission','technical_problem','other','lunch','market_other','gps_outside_worksite','admin_override']::text[]));


update public.srk_service_types set is_active=false where lower(service_name) like '%winding%' and is_active;
update public.srk_service_skills sk set is_active=false from public.srk_service_types st where st.id=sk.service_type_id and lower(st.service_name) like '%winding%' and sk.is_active;
update public.srk_service_rates sr set effective_to=clock_timestamp() where sr.service_type_id in (select id from public.srk_service_types where lower(service_name) like '%winding%') and sr.effective_to is null;
update public.srk_service_pricing_rules pr set effective_to=clock_timestamp() where pr.service_type_id in (select id from public.srk_service_types where lower(service_name) like '%winding%') and pr.effective_to is null;


do $assert$
begin
 if exists(select 1 from information_schema.columns where table_schema='public' and column_name in ('materials_amount','materials_charged_separately','winding_charged_separately')) then
  raise exception 'Legacy pricing columns remain after service-only migration';
 end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and (pg_get_functiondef(p.oid) ilike '%materials_amount%'
    or pg_get_functiondef(p.oid) ilike '%materials_included%'
    or pg_get_functiondef(p.oid) ilike '%materials_charged_separately%')) then
  raise exception 'Legacy billing logic remains after service-only migration';
 end if;
 if exists(select 1 from public.srk_service_types where lower(service_name) like '%winding%' and is_active) then
  raise exception 'An excluded service is still active';
 end if;
end;
$assert$;

