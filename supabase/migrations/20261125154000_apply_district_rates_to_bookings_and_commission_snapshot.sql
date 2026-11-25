
alter table public.service_bookings
  add column if not exists district_lgd_code text,
  add column if not exists district_rate_snapshot jsonb;

create index if not exists service_bookings_district_lgd_code_idx
  on public.service_bookings(district_lgd_code);

create or replace function srk_private.get_district_worker_hourly_rate(
  p_booking_id uuid,p_skill_level_id uuid,p_worker_role text
) returns numeric
language plpgsql stable security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
declare
  v_booking public.service_bookings%rowtype;
  v_key text;
  v_rate numeric;
begin
  if p_worker_role not in ('technician','helper') then return null; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id;
  if not found or v_booking.district_rate_snapshot is null then return null; end if;
  v_key:=case when p_worker_role='technician' then 'technician_rate' else 'helper_rate' end;
  select (x->>v_key)::numeric into v_rate
  from jsonb_array_elements(coalesce(v_booking.district_rate_snapshot->'skill_rates','[]'::jsonb)) x
  where x->>'skill_level_id'=p_skill_level_id::text
  limit 1;
  if v_rate is null then
    v_rate:=nullif(v_booking.district_rate_snapshot->'pricing_rule'->>v_key,'')::numeric;
  end if;
  return v_rate;
end;
$function$;

create or replace function srk_private.get_district_fixed_service_amount(p_booking_id uuid)
returns numeric
language plpgsql stable security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
declare
  v_booking public.service_bookings%rowtype;
  v_amount numeric;
begin
  select * into v_booking from public.service_bookings where id=p_booking_id;
  if not found or v_booking.district_rate_snapshot is null then return null; end if;
  if v_booking.pricing_unit_snapshot='per_item' then
    v_amount:=nullif(v_booking.district_rate_snapshot->'pricing_rule'->>'fixed_price','')::numeric;
    if v_amount is not null then v_amount:=round(v_amount*coalesce(v_booking.pricing_quantity,1),2); end if;
  elsif v_booking.pricing_unit_snapshot='motor_hp' then
    select (x->>'fixed_price')::numeric into v_amount
    from jsonb_array_elements(coalesce(v_booking.district_rate_snapshot->'pricing_rule'->'hp_tiers','[]'::jsonb)) x
    where (x->>'motor_hp')::numeric=v_booking.motor_hp
    limit 1;
  end if;
  return v_amount;
end;
$function$;

create or replace function srk_private.create_booking_with_district_rates(
  p_category_id uuid,p_service_type_id uuid,p_skill_id uuid,
  p_technician_count integer,p_helper_count integer,p_duration_hours integer,
  p_state text,p_district text,p_pincode text,p_address text,
  p_booking_latitude double precision,p_booking_longitude double precision,
  p_current_gps_latitude double precision,p_current_gps_longitude double precision,
  p_motor_hp numeric,p_skill_level_id uuid,p_unit_count integer
) returns public.service_bookings
language plpgsql volatile security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
declare
  v_booking public.service_bookings%rowtype;
  v_district public.srk_india_districts%rowtype;
  v_rule_override public.srk_district_service_rate_overrides%rowtype;
  v_requested_override public.srk_district_service_rate_overrides%rowtype;
  v_skill_rates jsonb:='[]'::jsonb;
  v_rule_snapshot jsonb;
  v_service_rate_count integer:=0;
  v_commission numeric(5,2);
  v_hp_price numeric;
begin
  if auth.uid() is null then raise exception 'OTP login required' using errcode='42501'; end if;
  select * into v_district from public.srk_india_districts
  where is_active and lower(btrim(state_name))=lower(btrim(p_state))
    and lower(btrim(district_name))=lower(btrim(p_district))
  limit 1;
  if not found then
    raise exception 'यह जिला अभी आधिकारिक जिला सूची में उपलब्ध नहीं है। सही State और District चुनें।';
  end if;

  v_booking:=public.srk_customer_create_booking(
    p_category_id,p_service_type_id,p_skill_id,p_technician_count,p_helper_count,
    p_duration_hours,p_state,p_district,p_pincode,p_address,p_booking_latitude,
    p_booking_longitude,p_current_gps_latitude,p_current_gps_longitude,
    p_motor_hp,p_skill_level_id,p_unit_count
  );

  select count(*) into v_service_rate_count
  from public.srk_service_rates sr
  where sr.category_id=v_booking.category_id and sr.service_type_id=v_booking.service_type_id
    and sr.rate_status='approved' and sr.effective_from<=clock_timestamp()
    and (sr.effective_to is null or sr.effective_to>clock_timestamp());

  select coalesce(jsonb_agg(jsonb_build_object(
    'skill_level_id',sr.skill_level_id,'service_rate_id',sr.id,
    'technician_rate',o.technician_rate,'helper_rate',o.helper_rate
  ) order by l.sort_order),'[]'::jsonb)
  into v_skill_rates
  from public.srk_service_rates sr
  join public.srk_skill_levels l on l.id=sr.skill_level_id and l.is_active
  join public.srk_district_service_rate_overrides o
    on o.service_rate_id=sr.id and o.district_lgd_code=v_district.district_lgd_code
   and o.effective_to is null
  where sr.category_id=v_booking.category_id and sr.service_type_id=v_booking.service_type_id
    and sr.rate_status='approved' and sr.effective_from<=clock_timestamp()
    and (sr.effective_to is null or sr.effective_to>clock_timestamp());

  if v_booking.pricing_rule_id is not null then
    select * into v_rule_override from public.srk_district_service_rate_overrides o
    where o.district_lgd_code=v_district.district_lgd_code
      and o.pricing_rule_id=v_booking.pricing_rule_id and o.effective_to is null
    order by o.effective_from desc limit 1;
  end if;

  if v_booking.pricing_unit_snapshot='hour' then
    if v_service_rate_count>0 then
      select o.* into v_requested_override
      from public.srk_service_rates sr
      join public.srk_district_service_rate_overrides o
        on o.service_rate_id=sr.id and o.district_lgd_code=v_district.district_lgd_code
       and o.effective_to is null
      where sr.category_id=v_booking.category_id and sr.service_type_id=v_booking.service_type_id
        and sr.skill_level_id=v_booking.requested_skill_level_id
        and sr.rate_status='approved' and sr.effective_from<=clock_timestamp()
        and (sr.effective_to is null or sr.effective_to>clock_timestamp())
      order by o.effective_from desc limit 1;
      if not found then
        raise exception 'इस जिले और चुनी गई Skill के लिए रेट अभी Admin ने सेट नहीं किया है।';
      end if;
      if p_helper_count>0 and coalesce(v_requested_override.helper_rate,0)<=0 then
        raise exception 'इस जिले और चुनी गई सेवा के लिए Helper Rate सेट नहीं है।';
      end if;
      v_rule_snapshot:=null;
    else
      if v_rule_override.id is null or coalesce(v_rule_override.technician_rate,0)<=0 then
        raise exception 'इस जिले और सेवा के लिए Technician Rate अभी Admin ने सेट नहीं किया है।';
      end if;
      if p_helper_count>0 and coalesce(v_rule_override.helper_rate,0)<=0 then
        raise exception 'इस जिले और सेवा के लिए Helper Rate अभी Admin ने सेट नहीं किया है।';
      end if;
      v_rule_snapshot:=jsonb_build_object(
        'pricing_rule_id',v_booking.pricing_rule_id,'pricing_unit','hour',
        'technician_rate',v_rule_override.technician_rate,'helper_rate',v_rule_override.helper_rate
      );
    end if;
  elsif v_booking.pricing_unit_snapshot='per_item' then
    if v_rule_override.id is null or coalesce(v_rule_override.fixed_price,0)<=0 then
      raise exception 'इस जिले और Fixed सेवा का रेट अभी Admin ने सेट नहीं किया है।';
    end if;
    v_rule_snapshot:=jsonb_build_object(
      'pricing_rule_id',v_booking.pricing_rule_id,'pricing_unit','per_item',
      'fixed_price',v_rule_override.fixed_price
    );
  elsif v_booking.pricing_unit_snapshot='motor_hp' then
    if v_rule_override.id is null or jsonb_typeof(v_rule_override.hp_tiers)<>'array' then
      raise exception 'इस जिले के Motor/Pump HP रेट अभी Admin ने सेट नहीं किए हैं।';
    end if;
    select (x->>'fixed_price')::numeric into v_hp_price
    from jsonb_array_elements(v_rule_override.hp_tiers) x
    where (x->>'motor_hp')::numeric=v_booking.motor_hp
    limit 1;
    if v_hp_price is null or v_hp_price<=0 then
      raise exception 'इस जिले और चुने गए HP का रेट अभी Admin ने सेट नहीं किया है।';
    end if;
    v_rule_snapshot:=jsonb_build_object(
      'pricing_rule_id',v_booking.pricing_rule_id,'pricing_unit','motor_hp',
      'hp_tiers',v_rule_override.hp_tiers
    );
  else
    raise exception 'Unsupported district pricing unit';
  end if;

  select coalesce((setting_value #>> '{}')::numeric,15.00)
  into v_commission
  from public.srk_system_settings where setting_key='company_commission_rate';
  v_commission:=coalesce(v_commission,15.00);
  if v_commission<0 or v_commission>100 then raise exception 'Company commission setting is invalid'; end if;

  update public.service_bookings
  set district_lgd_code=v_district.district_lgd_code,
      district_rate_snapshot=jsonb_build_object(
        'district_lgd_code',v_district.district_lgd_code,
        'district_name',v_district.district_name,
        'state_name',v_district.state_name,
        'source_date',v_district.source_date,
        'pricing_unit',v_booking.pricing_unit_snapshot,
        'pricing_rule',v_rule_snapshot,
        'skill_rates',v_skill_rates,
        'company_commission_rate',v_commission,
        'captured_at',clock_timestamp()
      ),
      commission_rate=v_commission
  where id=v_booking.id returning * into v_booking;

  return v_booking;
end;
$function$;

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
  select * into v_base from public.srk_customer_preview_booking_price_v2(
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
  v_pending:=coalesce(v_base.pending_cancellation_fee_amount,0);

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
$function$;

revoke all on function srk_private.get_district_worker_hourly_rate(uuid,uuid,text) from public,anon,authenticated;
revoke all on function srk_private.get_district_fixed_service_amount(uuid) from public,anon,authenticated;
revoke all on function srk_private.create_booking_with_district_rates(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision,numeric,uuid,integer) from public,anon;
revoke all on function srk_private.preview_booking_price_with_district(uuid,uuid,uuid,uuid,integer,integer,integer,numeric,integer,text,text) from public,anon;
grant execute on function srk_private.create_booking_with_district_rates(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision,numeric,uuid,integer) to authenticated;
grant execute on function srk_private.preview_booking_price_with_district(uuid,uuid,uuid,uuid,integer,integer,integer,numeric,integer,text,text) to authenticated;

create or replace function public.srk_customer_create_booking_v2(
  p_category_id uuid,p_service_type_id uuid,p_skill_id uuid,
  p_technician_count integer,p_helper_count integer,p_duration_hours integer,
  p_state text,p_district text,p_pincode text,p_address text,
  p_booking_latitude double precision,p_booking_longitude double precision,
  p_current_gps_latitude double precision,p_current_gps_longitude double precision,
  p_motor_hp numeric,p_skill_level_id uuid,p_unit_count integer
) returns public.service_bookings
language sql volatile security invoker set search_path=pg_catalog,public
as $function$
  select srk_private.create_booking_with_district_rates(
    p_category_id,p_service_type_id,p_skill_id,p_technician_count,p_helper_count,p_duration_hours,
    p_state,p_district,p_pincode,p_address,p_booking_latitude,p_booking_longitude,
    p_current_gps_latitude,p_current_gps_longitude,p_motor_hp,p_skill_level_id,p_unit_count
  );
$function$;

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
$function$;

revoke all on function public.srk_customer_create_booking_v2(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision,numeric,uuid,integer) from public,anon;
revoke all on function public.srk_customer_preview_booking_price_v3(uuid,uuid,uuid,uuid,integer,integer,integer,numeric,integer,text,text) from public,anon;
grant execute on function public.srk_customer_create_booking_v2(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision,numeric,uuid,integer) to authenticated;
grant execute on function public.srk_customer_preview_booking_price_v3(uuid,uuid,uuid,uuid,integer,integer,integer,numeric,integer,text,text) to authenticated;


CREATE OR REPLACE FUNCTION public.srk_admin_offer_worker_to_booking(p_booking_id uuid, p_worker_id uuid, p_worker_role text, p_reason text)
 RETURNS srk_booking_workers
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
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
 if v_booking.pricing_unit_snapshot='motor_hp' then
  if v_rule.id is null or v_rule.pricing_unit<>'motor_hp' or not exists(select 1 from public.srk_service_pricing_hp_tiers t where t.pricing_rule_id=v_rule.id and t.motor_hp=v_booking.motor_hp) then raise exception 'Approved Motor/Pump HP price missing'; end if;
  v_rate:=null;
 elsif v_booking.pricing_unit_snapshot='per_item' then
  if v_rule.id is null or v_rule.pricing_unit<>'per_item' then raise exception 'Booking fixed-price snapshot is missing'; end if;
  if p_worker_role='technician' then v_rate:=v_rule.technician_rate; else v_rate:=v_rule.helper_rate; end if;
  if p_worker_role='technician' and (v_rate is null or v_rate<=0) then raise exception 'Approved fixed service price missing'; end if;
 else
  if v_booking.pricing_rule_id is not null and v_rule.pricing_unit='hour' then
   if p_worker_role='technician' then v_rate:=v_rule.technician_rate; else v_rate:=v_rule.helper_rate; end if;
   if v_rate is null and v_booking.district_rate_snapshot is null then raise exception 'Hourly rate not configured for this worker role'; end if;
  else
   select r.id,case when p_worker_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end
    into v_rate_id,v_rate from public.srk_service_rates r
    where r.category_id=v_worker.category_id and r.skill_level_id=v_skill_level
     and (r.service_type_id is null or r.service_type_id=v_booking.service_type_id)
     and r.rate_status='approved' and r.effective_from<=clock_timestamp()
     and (r.effective_to is null or r.effective_to>clock_timestamp())
     and ((case when p_worker_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end) is not null or v_booking.district_rate_snapshot is not null)
    order by (r.service_type_id is not null) desc,r.effective_from desc limit 1;
   if v_rate is null and v_booking.district_rate_snapshot is null then raise exception 'Approved hourly rate not configured'; end if;
  end if;
 end if;
 if v_booking.pricing_unit_snapshot='hour' and v_booking.district_rate_snapshot is not null then
  v_rate:=srk_private.get_district_worker_hourly_rate(v_booking.id,v_skill_level,p_worker_role);
  if v_rate is null then raise exception 'District rate is not configured for this worker skill'; end if;
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
  case when v_booking.pricing_unit_snapshot in ('per_item','motor_hp') then null else v_rate end,v_skill_level,p_reason)
 returning * into v_assignment;
 return v_assignment;
end
$function$


CREATE OR REPLACE FUNCTION public.srk_process_booking_matching_queue()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
 v_queue_candidate record;
 v_queue record;
 v_booking public.service_bookings%rowtype;
 v_timeout integer;
 v_max_attempts integer;
 v_default_timeout integer;
 v_default_max_attempts integer;
 v_tech_count integer;
 v_helper_count integer;
 v_tech_offered integer;
 v_helper_offered integer;
 v_candidate record;
 v_level uuid;
 v_rate_id uuid;
 v_rate numeric(10,2);
 v_role text;
 v_inserted integer:=0;
 v_offered boolean;
 v_rule public.srk_service_pricing_rules%rowtype;
begin
 select nullif(setting_value::text,'null')::integer into v_timeout
 from public.srk_system_settings where setting_key='offer_timeout_seconds';
 v_default_timeout:=v_timeout;
 select coalesce(nullif(setting_value::text,'null')::integer,10) into v_max_attempts
 from public.srk_system_settings where setting_key='max_matching_attempts';
 v_max_attempts:=coalesce(v_max_attempts,10);
 v_default_max_attempts:=v_max_attempts;

 if v_timeout is not null then
  update public.srk_booking_workers
  set assignment_status='rejected',rejected_at=clock_timestamp(),
      admin_note='Offer timed out',updated_at=clock_timestamp()
  where assignment_status='offered' and offer_expires_at is not null
    and offer_expires_at<=clock_timestamp();
 end if;

 for v_queue_candidate in
  select q.booking_id from public.srk_booking_matching_queue q
  where q.queue_status in ('pending','searching','waiting')
    and q.next_attempt_at<=clock_timestamp()
  order by q.created_at limit 25
 loop
  select * into v_booking from public.service_bookings
  where id=v_queue_candidate.booking_id for update skip locked;
  if not found then continue; end if;
  select * into v_queue from public.srk_booking_matching_queue q
  where q.booking_id=v_queue_candidate.booking_id
    and q.queue_status in ('pending','searching','waiting')
    and q.next_attempt_at<=clock_timestamp()
  for update skip locked;
  if not found then continue; end if;

  v_timeout:=coalesce((v_booking.operational_settings_snapshot->>'offer_timeout_seconds')::integer,v_default_timeout);
  v_max_attempts:=coalesce((v_booking.operational_settings_snapshot->>'max_matching_attempts')::integer,v_default_max_attempts);
  if v_booking.status='cancelled' then
   update public.srk_booking_matching_queue set queue_status='cancelled',updated_at=clock_timestamp()
   where booking_id=v_queue_candidate.booking_id;
   continue;
  end if;

  select count(*) into v_tech_count from public.srk_booking_workers
  where booking_id=v_booking.id and worker_role='technician'
   and assignment_status in ('accepted','assigned','working','paused','completed');
  select count(*) into v_helper_count from public.srk_booking_workers
  where booking_id=v_booking.id and worker_role='helper'
   and assignment_status in ('accepted','assigned','working','paused','completed');
  select count(*) into v_tech_offered from public.srk_booking_workers
  where booking_id=v_booking.id and worker_role='technician' and assignment_status='offered';
  select count(*) into v_helper_offered from public.srk_booking_workers
  where booking_id=v_booking.id and worker_role='helper' and assignment_status='offered';

  -- If a role is already filled, close every outstanding offer for that role.
  if v_tech_count>=v_booking.requested_technician_count then
   update public.srk_booking_workers
   set assignment_status='rejected',rejected_at=clock_timestamp(),offer_expires_at=null,
       admin_note='Offer closed automatically: all requested positions filled by earlier acceptance.',
       updated_at=clock_timestamp()
   where booking_id=v_booking.id and worker_role='technician' and assignment_status='offered';
   v_tech_offered:=0;
  end if;
  if v_helper_count>=v_booking.requested_helper_count then
   update public.srk_booking_workers
   set assignment_status='rejected',rejected_at=clock_timestamp(),offer_expires_at=null,
       admin_note='Offer closed automatically: all requested positions filled by earlier acceptance.',
       updated_at=clock_timestamp()
   where booking_id=v_booking.id and worker_role='helper' and assignment_status='offered';
   v_helper_offered:=0;
  end if;

  if v_tech_count>=1 then
   update public.service_bookings set status='confirmed' where id=v_booking.id and status='new';
  end if;
  if v_tech_count>=v_booking.requested_technician_count
     and v_helper_count>=v_booking.requested_helper_count then
   update public.srk_booking_workers set assignment_status='assigned',updated_at=clock_timestamp()
   where booking_id=v_booking.id and assignment_status='accepted';
   update public.srk_booking_matching_queue
   set queue_status='fulfilled',completed_at=coalesce(completed_at,clock_timestamp()),updated_at=clock_timestamp()
   where booking_id=v_booking.id;
   update public.service_bookings set status='confirmed' where id=v_booking.id and status='new';
   continue;
  end if;

  v_role:=case when v_tech_count<v_booking.requested_technician_count then 'technician' else 'helper' end;
  if (v_role='technician' and v_tech_offered>0) or (v_role='helper' and v_helper_offered>0) then
   update public.srk_booking_matching_queue
   set queue_status='searching',next_attempt_at=clock_timestamp()+interval '1 minute',updated_at=clock_timestamp()
   where booking_id=v_booking.id;
   continue;
  end if;
  if coalesce(v_queue.attempts,0)>=v_max_attempts then
   update public.srk_booking_matching_queue
   set queue_status='failed',
       last_error='Maximum matching attempts ('||v_max_attempts||') reached; required worker role remains unfilled.',
       next_attempt_at=clock_timestamp(),updated_at=clock_timestamp()
   where booking_id=v_booking.id;
   continue;
  end if;

  select * into v_rule from public.srk_service_pricing_rules where id=v_booking.pricing_rule_id;
  v_offered:=false;
  for v_candidate in
   select c.* from public.srk_find_eligible_workers(v_booking.id,v_role) c
   where not exists(select 1 from public.srk_booking_workers bw
    where bw.booking_id=v_booking.id and bw.worker_id=c.worker_id)
   order by c.distance_km
  loop
   select ws.skill_level_id into v_level from public.srk_worker_skills ws
   where ws.worker_id=v_candidate.worker_id and ws.skill_id=v_booking.selected_skill_id
    and ws.verification_status='approved' limit 1;
   v_rate_id:=null; v_rate:=null;
   if v_booking.pricing_unit_snapshot='motor_hp' then
    if v_rule.id is null or v_rule.pricing_unit<>'motor_hp'
       or not exists(select 1 from public.srk_service_pricing_hp_tiers t
        where t.pricing_rule_id=v_rule.id and t.motor_hp=v_booking.motor_hp) then
     continue;
    end if;
    v_rate:=null;
   elsif v_booking.pricing_unit_snapshot='per_item' then
    if v_rule.id is null or v_rule.pricing_unit<>'per_item' then continue; end if;
    if v_role='technician' then v_rate:=v_rule.technician_rate; else v_rate:=v_rule.helper_rate; end if;
    if v_role='technician' and (v_rate is null or v_rate<=0) then continue; end if;
   else
    if v_booking.pricing_rule_id is not null and v_rule.pricing_unit='hour' then
     if v_role='technician' then v_rate:=v_rule.technician_rate; else v_rate:=v_rule.helper_rate; end if;
     if v_rate is null and v_booking.district_rate_snapshot is null then continue; end if;
    else
     select r.id,case when v_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end
      into v_rate_id,v_rate
     from public.srk_service_rates r
     where r.category_id=v_booking.category_id and r.skill_level_id=v_level
      and (r.service_type_id is null or r.service_type_id=v_booking.service_type_id)
      and r.rate_status='approved' and r.effective_from<=clock_timestamp()
      and (r.effective_to is null or r.effective_to>clock_timestamp())
      and ((case when v_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end) is not null or v_booking.district_rate_snapshot is not null)
     order by (r.service_type_id is not null) desc,r.effective_from desc limit 1;
     if v_rate is null and v_booking.district_rate_snapshot is null then continue; end if;
    end if;
   end if;

   if v_booking.pricing_unit_snapshot='hour' and v_booking.district_rate_snapshot is not null then
    v_rate:=srk_private.get_district_worker_hourly_rate(v_booking.id,v_level,v_role);
    if v_rate is null then continue; end if;
   end if;
   insert into public.srk_booking_workers(
    booking_id,worker_id,worker_role,assignment_status,rate_id,hourly_rate_snapshot,
    skill_level_snapshot_id,offer_expires_at,worker_custom_settings_snapshot
   ) values(
    v_booking.id,v_candidate.worker_id,v_role,'offered',v_rate_id,
    case when v_booking.pricing_unit_snapshot in ('per_item','motor_hp') then null else v_rate end,
    v_level,
    case when v_timeout is null then null else clock_timestamp()+make_interval(secs=>v_timeout) end,
    coalesce((select jsonb_object_agg(setting_key,setting_value)
     from public.srk_user_custom_settings
     where user_id=(select user_id from public.srk_worker_profiles where id=v_candidate.worker_id)
      and account_role=v_role),'{}'::jsonb)
   );
   v_inserted:=v_inserted+1;
   v_offered:=true;
  end loop;

  if v_offered then
   update public.srk_booking_matching_queue
   set queue_status='searching',attempts=attempts+1,last_attempt_at=clock_timestamp(),
       next_attempt_at=clock_timestamp()+make_interval(secs=>coalesce(v_timeout,600)),
       last_error=null,updated_at=clock_timestamp()
   where booking_id=v_booking.id;
  else
   update public.srk_booking_matching_queue
   set queue_status='waiting',attempts=attempts+1,last_attempt_at=clock_timestamp(),
       next_attempt_at=clock_timestamp()+interval '1 minute',
       last_error='No eligible online approved worker with an approved pricing rule/rate',
       updated_at=clock_timestamp()
   where booking_id=v_booking.id;
  end if;
 end loop;
 return v_inserted;
end
$function$


CREATE OR REPLACE FUNCTION public.srk_admin_set_fixed_price_worker_allocations(p_booking_id uuid, p_allocations jsonb, p_reason text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
declare
  v_booking public.service_bookings%rowtype;
  v_rule public.srk_service_pricing_rules%rowtype;
  v_expected numeric(12,2);
  v_total numeric(12,2);
  v_count integer;
  v_old jsonb;
  v_new jsonb;
  v_event_type text;
begin
  if auth.uid() is null or not public.srk_has_admin_permission('bookings.manage') then
    raise exception 'Booking management permission required' using errcode='42501';
  end if;
  if p_booking_id is null or p_allocations is null
     or jsonb_typeof(p_allocations) <> 'array'
     or jsonb_array_length(p_allocations) = 0
     or p_reason is null or length(btrim(p_reason)) not between 10 and 2000 then
    raise exception 'Booking, non-empty allocation array and reason (10-2000 characters) are required' using errcode='22023';
  end if;

  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;

  if v_booking.status is distinct from 'in_progress'
     or v_booking.completion_approval_status is distinct from 'pending'
     or v_booking.completion_requested_at is null
     or coalesce(v_booking.work_timer_running,false) then
    raise exception 'Allocations are allowed only after work completion is submitted for Customer review';
  end if;

  if exists (
    select 1 from public.srk_booking_final_bills b
    where b.booking_id=p_booking_id and b.status in ('issued','approved','disputed')
  ) or exists (
    select 1 from public.srk_worker_earnings e
    where e.booking_id=p_booking_id
  ) then
    raise exception 'Worker allocations are locked after a bill or worker earning has been created';
  end if;

  if v_booking.pricing_unit_snapshot is distinct from 'per_item' and v_booking.pricing_unit_snapshot is distinct from 'motor_hp'
     or v_booking.pricing_rule_id is null
     or v_booking.pricing_quantity is null
     or v_booking.pricing_quantity <= 0 then
    raise exception 'This allocation RPC supports only valid fixed-price per-item or motor HP bookings';
  end if;

  perform 1 from public.srk_booking_workers where booking_id=p_booking_id for update;

  select * into v_rule from public.srk_service_pricing_rules
  where id=v_booking.pricing_rule_id and pricing_unit=v_booking.pricing_unit_snapshot for share;
  if not found or (v_booking.pricing_unit_snapshot='per_item' and (v_rule.technician_rate is null or v_rule.technician_rate <= 0)) then
    raise exception 'Booking per-item pricing snapshot is missing or invalid';
  end if;

  if v_booking.pricing_unit_snapshot='motor_hp' then
    select t.fixed_price into v_expected from public.srk_service_pricing_hp_tiers t where t.pricing_rule_id=v_rule.id and t.motor_hp=v_booking.motor_hp;
    if v_expected is null then raise exception 'Approved fixed price for this Motor/Pump HP is missing'; end if;
  else
    v_expected := round(v_rule.technician_rate * v_booking.pricing_quantity,2);
  end if;
  if v_booking.district_rate_snapshot is not null then
    v_expected:=srk_private.get_district_fixed_service_amount(p_booking_id);
    if v_expected is null then raise exception 'District fixed service rate snapshot is missing'; end if;
  end if;
  if v_expected <= 0 then raise exception 'Expected fixed service amount must be positive'; end if;

  if exists (
    select 1 from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid,gross_amount numeric)
    where x.booking_worker_id is null or x.gross_amount is null
       or x.gross_amount < 0 or x.gross_amount <> round(x.gross_amount,2)
  ) then
    raise exception 'Each allocation requires a booking_worker_id and a non-negative two-decimal gross_amount';
  end if;

  select count(*),coalesce(sum(x.gross_amount),0) into v_count,v_total
  from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid,gross_amount numeric);

  if v_count <> jsonb_array_length(p_allocations)
     or (select count(distinct x.booking_worker_id)
         from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid,gross_amount numeric)) <> v_count then
    raise exception 'Duplicate or malformed worker allocation entries are not allowed';
  end if;

  if v_total <> v_expected then
    raise exception 'Worker allocation total (%) must exactly equal fixed service amount (%)',v_total,v_expected;
  end if;

  if exists (
    select 1 from public.srk_booking_workers bw
    where bw.booking_id=p_booking_id and bw.assignment_status in ('completed','released')
      and not exists (
        select 1 from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid,gross_amount numeric)
        where x.booking_worker_id=bw.id
      )
  ) or exists (
    select 1 from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid,gross_amount numeric)
    left join public.srk_booking_workers bw
      on bw.id=x.booking_worker_id and bw.booking_id=p_booking_id
     and bw.assignment_status in ('completed','released')
    where bw.id is null
  ) then
    raise exception 'Allocation must include every completed/released assigned worker and no other worker';
  end if;

  if not exists (
    select 1 from public.srk_booking_workers bw
    where bw.booking_id=p_booking_id and bw.assignment_status in ('completed','released')
  ) then
    raise exception 'At least one completed/released worker assignment is required';
  end if;

  select coalesce(jsonb_agg(to_jsonb(a) order by a.booking_worker_id),'[]'::jsonb)
    into v_old from public.srk_fixed_price_worker_allocations a where a.booking_id=p_booking_id;

  select case when count(*)=0 then 'created' else 'replaced' end into v_event_type
  from public.srk_fixed_price_worker_allocations where booking_id=p_booking_id;

  delete from public.srk_fixed_price_worker_allocations where booking_id=p_booking_id;

  insert into public.srk_fixed_price_worker_allocations(
    booking_id,booking_worker_id,worker_id,gross_service_earning,allocation_reason,allocated_by
  )
  select p_booking_id,bw.id,bw.worker_id,x.gross_amount,btrim(p_reason),auth.uid()
  from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid,gross_amount numeric)
  join public.srk_booking_workers bw on bw.id=x.booking_worker_id and bw.booking_id=p_booking_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'booking_worker_id',a.booking_worker_id,'worker_id',a.worker_id,
    'worker_role',bw.worker_role,'gross_service_earning',a.gross_service_earning
  ) order by a.booking_worker_id),'[]'::jsonb)
  into v_new
  from public.srk_fixed_price_worker_allocations a
  join public.srk_booking_workers bw on bw.id=a.booking_worker_id
  where a.booking_id=p_booking_id;

  insert into public.srk_fixed_price_worker_allocation_events(
    booking_id,event_type,previous_allocations,new_allocations,reason,actor_user_id
  ) values (p_booking_id,v_event_type,v_old,v_new,btrim(p_reason),auth.uid());

  return v_count;
end;
$function$


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
      1,v_labour,0,v_cancellation_fee,'issued',clock_timestamp()
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
$function$

