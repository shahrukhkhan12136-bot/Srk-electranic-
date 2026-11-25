CREATE OR REPLACE FUNCTION public.srk_worker_set_availability(
 p_is_online boolean,p_latitude double precision DEFAULT NULL::double precision,
 p_longitude double precision DEFAULT NULL::double precision
) RETURNS public.srk_worker_profiles
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public'
AS $function$
declare v_worker public.srk_worker_profiles%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_is_online is null then raise exception 'Online/offline selection is required'; end if;
 select * into v_worker from public.srk_worker_profiles where user_id=auth.uid() for update;
 if not found then raise exception 'Worker profile not found'; end if;
 if p_is_online and (v_worker.verification_status<>'approved' or not v_worker.is_active) then
  raise exception 'Only Admin-approved active workers can go online';
 end if;
 if p_is_online and (
  p_latitude is null or p_longitude is null
  or p_latitude not between -90 and 90 or p_longitude not between -180 and 180
 ) then
  raise exception 'Valid GPS location required to go online';
 end if;

 -- Going offline affects only future matching. Existing bookings, sessions,
 -- timers and live-location sharing continue independently.
 update public.srk_worker_profiles
 set is_online=p_is_online,
     location_lat=case when p_is_online then p_latitude else null end,
     location_lng=case when p_is_online then p_longitude else null end,
     updated_at=clock_timestamp()
 where id=v_worker.id returning * into v_worker;
 return v_worker;
end
$function$;