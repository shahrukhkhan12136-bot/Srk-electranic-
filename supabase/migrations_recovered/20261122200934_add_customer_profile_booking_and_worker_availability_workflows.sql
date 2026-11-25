
create or replace function public.srk_customer_upsert_profile(p_full_name text,p_phone text)
returns public.srk_customer_profiles
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_profile public.srk_customer_profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'OTP login required'; end if;
  if length(btrim(coalesce(p_full_name,'')))<2 then raise exception 'Customer name is required'; end if;
  if p_phone !~ '^[0-9]{10}$' then raise exception 'Valid 10-digit mobile number required'; end if;
  insert into public.srk_customer_profiles(user_id,full_name,phone)
  values(auth.uid(),btrim(p_full_name),p_phone)
  on conflict(user_id) do update set full_name=excluded.full_name,phone=excluded.phone,updated_at=clock_timestamp()
  returning * into v_profile;
  return v_profile;
end $$;

create or replace function public.srk_customer_create_booking(
  p_category_id uuid,
  p_service_type_id uuid,
  p_skill_id uuid,
  p_technician_count integer,
  p_helper_count integer,
  p_duration_hours integer,
  p_state text,
  p_district text,
  p_pincode text,
  p_address text,
  p_booking_latitude double precision,
  p_booking_longitude double precision,
  p_current_gps_latitude double precision default null,
  p_current_gps_longitude double precision default null
) returns public.service_bookings
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_customer public.srk_customer_profiles%rowtype; v_service public.srk_service_types%rowtype; v_skill public.srk_service_skills%rowtype; v_booking public.service_bookings%rowtype;
begin
  if auth.uid() is null then raise exception 'OTP login required'; end if;
  select * into v_customer from public.srk_customer_profiles where user_id=auth.uid();
  if not found then raise exception 'Complete customer profile before booking'; end if;
  if p_technician_count not between 1 and 20 or p_helper_count not between 0 and 20 then raise exception 'Invalid worker count'; end if;
  if p_duration_hours not between 1 and 1440 then raise exception 'Work duration must be 1 hour to 60 days'; end if;
  if p_pincode !~ '^[0-9]{6}$' then raise exception 'Valid 6-digit booking PIN code required'; end if;
  if nullif(btrim(p_state),'') is null or nullif(btrim(p_district),'') is null or nullif(btrim(p_address),'') is null then
    raise exception 'Complete booking address is required';
  end if;
  if p_booking_latitude is null or p_booking_longitude is null
    or p_booking_latitude not between -90 and 90 or p_booking_longitude not between -180 and 180 then
    raise exception 'Booking Address GPS coordinates are required';
  end if;
  if (p_current_gps_latitude is null)<>(p_current_gps_longitude is null) then
    raise exception 'Current GPS latitude and longitude must be supplied together';
  end if;

  select * into v_service from public.srk_service_types
  where id=p_service_type_id and category_id=p_category_id and is_active;
  if not found then raise exception 'Selected service does not belong to this active category'; end if;
  select * into v_skill from public.srk_service_skills
  where id=p_skill_id and service_type_id=p_service_type_id and is_active;
  if not found then raise exception 'Selected work/skill does not belong to this service'; end if;

  insert into public.service_bookings(
    customer_name,phone,state,district,pincode,address,service_type,payment_method,status,
    commission_rate,materials_amount,customer_user_id,customer_id,category_id,service_type_id,selected_skill_id,
    requested_technician_count,requested_helper_count,requested_duration_hours,
    booking_latitude,booking_longitude,location_lat,location_lng,booking_address_confirmed_at
  ) values(
    v_customer.full_name,v_customer.phone,btrim(p_state),btrim(p_district),p_pincode,btrim(p_address),
    v_service.service_name,'Cash','new',15.00,0,auth.uid(),v_customer.id,p_category_id,p_service_type_id,p_skill_id,
    p_technician_count,p_helper_count,p_duration_hours,
    p_booking_latitude,p_booking_longitude,p_current_gps_latitude,p_current_gps_longitude,clock_timestamp()
  ) returning * into v_booking;
  return v_booking;
end $$;

create or replace function public.srk_worker_set_availability(
  p_is_online boolean,
  p_latitude double precision default null,
  p_longitude double precision default null
) returns public.srk_worker_profiles
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_worker public.srk_worker_profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_worker from public.srk_worker_profiles where user_id=auth.uid() for update;
  if not found then raise exception 'Worker profile not found'; end if;
  if p_is_online and (v_worker.verification_status<>'approved' or not v_worker.is_active) then
    raise exception 'Only Admin-approved active workers can go online';
  end if;
  if p_is_online and (p_latitude is null or p_longitude is null or p_latitude not between -90 and 90 or p_longitude not between -180 and 180) then
    raise exception 'Valid GPS location required to go online';
  end if;
  if not p_is_online and exists(
    select 1 from public.srk_worker_work_sessions s join public.srk_booking_workers bw on bw.id=s.booking_worker_id
    where bw.worker_id=v_worker.id and s.session_status='running'
  ) then raise exception 'Complete or pause active work before going offline'; end if;
  update public.srk_worker_profiles
    set is_online=p_is_online,
        location_lat=case when p_is_online then p_latitude else null end,
        location_lng=case when p_is_online then p_longitude else null end,
        updated_at=clock_timestamp()
    where id=v_worker.id returning * into v_worker;
  return v_worker;
end $$;

revoke all on function public.srk_customer_upsert_profile(text,text) from public,anon;
revoke all on function public.srk_customer_create_booking(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision) from public,anon;
revoke all on function public.srk_worker_set_availability(boolean,double precision,double precision) from public,anon;
grant execute on function public.srk_customer_upsert_profile(text,text) to authenticated;
grant execute on function public.srk_customer_create_booking(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision) to authenticated;
grant execute on function public.srk_worker_set_availability(boolean,double precision,double precision) to authenticated;

create or replace function public.srk_worker_respond_assignment(p_assignment_id uuid,p_accept boolean)
returns public.srk_booking_workers
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_assignment public.srk_booking_workers%rowtype; v_worker public.srk_worker_profiles%rowtype; v_count bigint; v_booking uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select bw.* into v_assignment
  from public.srk_booking_workers bw join public.srk_worker_profiles wp on wp.id=bw.worker_id
  where bw.id=p_assignment_id and wp.user_id=auth.uid() for update of bw;
  if not found then raise exception 'Assignment not found or not yours'; end if;
  if v_assignment.assignment_status<>'offered' then raise exception 'Offer is no longer pending'; end if;
  select * into v_worker from public.srk_worker_profiles where id=v_assignment.worker_id;
  if p_accept and v_worker.worker_type='technician' then
    select completed_booking_count into v_count from public.srk_technician_booking_cycle where technician_id=v_worker.id;
    v_count:=coalesce(v_count,0)+1;
    if v_count in (3,6) then
      update public.service_bookings set payment_method='Online' where id=v_assignment.booking_id;
    end if;
  end if;
  update public.srk_booking_workers set assignment_status=case when p_accept then 'accepted' else 'rejected' end,
    accepted_at=case when p_accept then clock_timestamp() else null end,
    rejected_at=case when p_accept then null else clock_timestamp() end,updated_at=clock_timestamp()
  where id=p_assignment_id returning * into v_assignment;
  return v_assignment;
end $$;
