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
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into v_booking from public.service_bookings
 where id=p_booking_id and customer_user_id=auth.uid();
 if not found then raise exception 'Customer booking not found' using errcode='42501'; end if;
 if v_booking.requested_skill_level_id is null then return; end if;
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

CREATE OR REPLACE FUNCTION public.srk_customer_consent_higher_skill_level(
 p_booking_id uuid,p_higher_skill_level_id uuid
) RETURNS public.service_bookings
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_booking public.service_bookings%rowtype;
 v_requested public.srk_skill_levels%rowtype;
 v_higher public.srk_skill_levels%rowtype;
 v_option record;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into v_booking from public.service_bookings
 where id=p_booking_id and customer_user_id=auth.uid() for update;
 if not found then raise exception 'Customer booking not found' using errcode='42501'; end if;
 if v_booking.status not in ('new','confirmed') then
  raise exception 'Higher-level consent is only available before work starts';
 end if;
 if v_booking.requested_skill_level_id is null then
  raise exception 'No requested qualification level is recorded';
 end if;
 select * into v_requested from public.srk_skill_levels where id=v_booking.requested_skill_level_id;
 select * into v_higher from public.srk_skill_levels
 where id=p_higher_skill_level_id and category_id=v_booking.category_id and is_active;
 if not found or v_higher.sort_order<=v_requested.sort_order then
  raise exception 'The selected alternative must be a higher active qualification level';
 end if;

 select * into v_option from public.srk_customer_get_higher_skill_level_options(p_booking_id) o
 where o.skill_level_id=p_higher_skill_level_id;
 if not found then raise exception 'Higher qualification option is not available'; end if;
 if v_booking.requested_technician_count>0 and
    (v_option.eligible_technician_count<=0 or v_option.technician_hourly_rate is null) then
  raise exception 'No eligible higher-level Technician and approved rate are available';
 end if;
 if v_booking.requested_helper_count>0 and
    (v_option.eligible_helper_count<=0 or v_option.helper_hourly_rate is null) then
  raise exception 'No eligible higher-level Helper and approved rate are available';
 end if;

 update public.service_bookings
 set higher_skill_consent_level_id=v_higher.id,
     higher_skill_consent_at=clock_timestamp(),
     higher_skill_consent_by=auth.uid()
 where id=p_booking_id returning * into v_booking;

 insert into public.srk_booking_skill_level_events(
  booking_id,actor_user_id,event_type,from_skill_level_id,to_skill_level_id,reason
 ) values(
  p_booking_id,auth.uid(),'higher_level_consented',v_requested.id,v_higher.id,
  'Customer explicitly consented to higher qualification and its published rate'
 );
 update public.srk_booking_matching_queue
 set queue_status='pending',next_attempt_at=clock_timestamp(),updated_at=clock_timestamp()
 where booking_id=p_booking_id and queue_status not in ('fulfilled','cancelled');
 return v_booking;
end
$function$;