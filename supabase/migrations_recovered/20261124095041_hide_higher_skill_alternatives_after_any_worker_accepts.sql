CREATE OR REPLACE FUNCTION public.srk_customer_get_higher_skill_level_options(p_booking_id uuid)
RETURNS TABLE(
 skill_level_id uuid,level_code text,level_name text,
 technician_hourly_rate numeric,helper_hourly_rate numeric,
 eligible_technician_count bigint,eligible_helper_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_booking public.service_bookings%rowtype;
 v_requested public.srk_skill_levels%rowtype;
 v_attempts integer:=0;
 v_initial_radius numeric;
 v_expansion_step numeric;
 v_max_radius numeric;
 v_search_radius numeric;
 v_base_technician_count bigint:=0;
 v_base_helper_count bigint:=0;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into v_booking from public.service_bookings
 where id=p_booking_id and customer_user_id=auth.uid();
 if not found then raise exception 'Customer booking not found' using errcode='42501'; end if;
 if v_booking.status not in ('new','confirmed') or v_booking.requested_skill_level_id is null then return; end if;
 if exists(select 1 from public.srk_booking_workers
  where booking_id=p_booking_id and assignment_status in ('accepted','assigned','working','paused','completed')) then
  return;
 end if;
 select * into v_requested from public.srk_skill_levels where id=v_booking.requested_skill_level_id;
 select coalesce(q.attempts,0) into v_attempts
 from public.srk_booking_matching_queue q where q.booking_id=p_booking_id;
 v_initial_radius:=coalesce(
  (v_booking.operational_settings_snapshot->>'initial_matching_radius_km')::numeric,
  (select (setting_value #>> '{}')::numeric from public.srk_system_settings where setting_key='initial_matching_radius_km'),30);
 v_expansion_step:=coalesce(
  (v_booking.operational_settings_snapshot->>'matching_radius_expansion_step_km')::numeric,
  (select (setting_value #>> '{}')::numeric from public.srk_system_settings where setting_key='matching_radius_expansion_step_km'),30);
 v_max_radius:=coalesce(
  (v_booking.operational_settings_snapshot->>'maximum_matching_radius_km')::numeric,
  (select (setting_value #>> '{}')::numeric from public.srk_system_settings where setting_key='maximum_matching_radius_km'),200);
 v_search_radius:=least(v_max_radius,v_initial_radius+coalesce(v_attempts,0)*v_expansion_step);

 select count(*) into v_base_technician_count
 from public.srk_find_eligible_workers(p_booking_id,'technician') e
 where not exists(select 1 from public.srk_booking_workers bw
  where bw.booking_id=p_booking_id and bw.worker_id=e.worker_id);
 select count(*) into v_base_helper_count
 from public.srk_find_eligible_workers(p_booking_id,'helper') e
 where not exists(select 1 from public.srk_booking_workers bw
  where bw.booking_id=p_booking_id and bw.worker_id=e.worker_id);

 if (coalesce(v_booking.requested_technician_count,0)=0 or
     v_base_technician_count>=v_booking.requested_technician_count)
    and
    (coalesce(v_booking.requested_helper_count,0)=0 or
     v_base_helper_count>=v_booking.requested_helper_count) then
  return;
 end if;

 return query
 select l.id,l.level_code,l.level_name,r.technician_hourly_rate,r.helper_hourly_rate,
  (select count(*) from public.srk_worker_profiles w
   where w.worker_type='technician' and w.category_id=v_booking.category_id
    and w.verification_status='approved' and w.is_active and w.is_online
    and exists(select 1 from public.srk_worker_skills ws
     where ws.worker_id=w.id and ws.skill_id=v_booking.selected_skill_id
      and ws.skill_level_id=l.id and ws.verification_status='approved')
    and not exists(select 1 from public.srk_booking_workers bw
     where bw.booking_id=v_booking.id and bw.worker_id=w.id)
    and not exists(select 1 from public.srk_worker_work_sessions s
     where s.worker_id=w.id and s.session_status in ('running','paused'))
    and not exists(select 1 from public.srk_booking_workers bw
     where bw.worker_id=w.id and bw.assignment_status in ('working','paused'))
    and not exists(select 1 from public.srk_booking_workers bw
     where bw.worker_id=w.id and bw.assignment_status in ('accepted','assigned')
      and not exists(select 1 from public.srk_worker_schedule_blocks sb
       where sb.booking_worker_id=bw.id and sb.block_status in ('reserved','confirmed','in_progress')))
    and not exists(select 1 from public.srk_worker_schedule_blocks sb
     where sb.worker_id=w.id and sb.block_status in ('reserved','confirmed','in_progress')
      and sb.starts_at<=clock_timestamp()+make_interval(hours=>coalesce(v_booking.requested_duration_hours,1))
      and sb.ends_at>clock_timestamp())
    and (
     (v_booking.booking_latitude is null and
      (w.pincode=v_booking.pincode or
       (lower(trim(w.state))=lower(trim(v_booking.state)) and lower(trim(w.district))=lower(trim(v_booking.district)))))
     or
     (v_booking.booking_latitude is not null and w.location_lat is not null and w.location_lng is not null
      and (6371*acos(least(1,greatest(-1,
       cos(radians(v_booking.booking_latitude))*cos(radians(w.location_lat))*cos(radians(w.location_lng)-radians(v_booking.booking_longitude))+
       sin(radians(v_booking.booking_latitude))*sin(radians(w.location_lat))
      ))))<=least(v_search_radius,coalesce(w.service_radius_km,v_search_radius)))
    )
  ) as eligible_technician_count,
  (select count(*) from public.srk_worker_profiles w
   where w.worker_type='helper' and w.category_id=v_booking.category_id
    and w.verification_status='approved' and w.is_active and w.is_online
    and exists(select 1 from public.srk_worker_skills ws
     where ws.worker_id=w.id and ws.skill_id=v_booking.selected_skill_id
      and ws.skill_level_id=l.id and ws.verification_status='approved')
    and not exists(select 1 from public.srk_booking_workers bw
     where bw.booking_id=v_booking.id and bw.worker_id=w.id)
    and not exists(select 1 from public.srk_worker_work_sessions s
     where s.worker_id=w.id and s.session_status in ('running','paused'))
    and not exists(select 1 from public.srk_booking_workers bw
     where bw.worker_id=w.id and bw.assignment_status in ('working','paused'))
    and not exists(select 1 from public.srk_booking_workers bw
     where bw.worker_id=w.id and bw.assignment_status in ('accepted','assigned')
      and not exists(select 1 from public.srk_worker_schedule_blocks sb
       where sb.booking_worker_id=bw.id and sb.block_status in ('reserved','confirmed','in_progress')))
    and not exists(select 1 from public.srk_worker_schedule_blocks sb
     where sb.worker_id=w.id and sb.block_status in ('reserved','confirmed','in_progress')
      and sb.starts_at<=clock_timestamp()+make_interval(hours=>coalesce(v_booking.requested_duration_hours,1))
      and sb.ends_at>clock_timestamp())
    and (
     (v_booking.booking_latitude is null and
      (w.pincode=v_booking.pincode or
       (lower(trim(w.state))=lower(trim(v_booking.state)) and lower(trim(w.district))=lower(trim(v_booking.district)))))
     or
     (v_booking.booking_latitude is not null and w.location_lat is not null and w.location_lng is not null
      and (6371*acos(least(1,greatest(-1,
       cos(radians(v_booking.booking_latitude))*cos(radians(w.location_lat))*cos(radians(w.location_lng)-radians(v_booking.booking_longitude))+
       sin(radians(v_booking.booking_latitude))*sin(radians(w.location_lat))
      ))))<=least(v_search_radius,coalesce(w.service_radius_km,v_search_radius)))
    )
  ) as eligible_helper_count
 from public.srk_skill_levels l
 join public.srk_service_rates r on r.category_id=v_booking.category_id
  and r.service_type_id=v_booking.service_type_id and r.skill_level_id=l.id
  and r.rate_status='approved' and r.effective_from<=clock_timestamp()
  and (r.effective_to is null or r.effective_to>clock_timestamp())
 where l.category_id=v_booking.category_id and l.is_active
  and l.sort_order>v_requested.sort_order
 order by l.sort_order;
end
$function$;