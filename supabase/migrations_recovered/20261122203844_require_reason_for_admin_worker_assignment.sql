
revoke all on function public.srk_admin_offer_worker_to_booking(uuid,uuid,text) from public,anon,authenticated;

create or replace function public.srk_admin_offer_worker_to_booking(
 p_booking_id uuid,p_worker_id uuid,p_worker_role text,p_reason text
) returns public.srk_booking_workers
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare
  v_booking public.service_bookings%rowtype; v_worker public.srk_worker_profiles%rowtype;
  v_existing integer; v_limit integer; v_assignment public.srk_booking_workers%rowtype;
  v_skill_level uuid; v_rate_id uuid; v_rate numeric(10,2); v_distance numeric;
begin
  if not public.srk_has_admin_permission('bookings.manage') then raise exception 'Booking management permission required'; end if;
  if length(coalesce(p_reason,''))<10 then raise exception 'Admin assignment reason must be at least 10 characters'; end if;
  if p_worker_role not in ('technician','helper') then raise exception 'Invalid worker role'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  select * into v_worker from public.srk_worker_profiles where id=p_worker_id for update;
  if not found then raise exception 'Worker not found'; end if;
  if v_worker.worker_type<>p_worker_role or v_worker.category_id is distinct from v_booking.category_id then raise exception 'Worker category or role mismatch'; end if;
  if v_worker.verification_status<>'approved' or not v_worker.is_active or not v_worker.is_online then raise exception 'Worker must be approved, active and online'; end if;
  if v_booking.booking_latitude is null or v_worker.location_lat is null then raise exception 'Booking and worker GPS locations required'; end if;
  v_distance:=6371*acos(least(1,greatest(-1,
    cos(radians(v_booking.booking_latitude))*cos(radians(v_worker.location_lat))*
    cos(radians(v_worker.location_lng)-radians(v_booking.booking_longitude))+
    sin(radians(v_booking.booking_latitude))*sin(radians(v_worker.location_lat))
  )));
  if v_distance>30 or v_distance>v_worker.service_radius_km then raise exception 'Worker outside 30 KM service range'; end if;
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
  insert into public.srk_booking_workers(booking_id,worker_id,worker_role,assignment_status,offered_by,
    rate_id,hourly_rate_snapshot,skill_level_snapshot_id,admin_note)
  values(p_booking_id,p_worker_id,p_worker_role,'offered',auth.uid(),v_rate_id,v_rate,v_skill_level,p_reason)
  returning * into v_assignment;
  return v_assignment;
end $$;

revoke all on function public.srk_admin_offer_worker_to_booking(uuid,uuid,text,text) from public,anon;
grant execute on function public.srk_admin_offer_worker_to_booking(uuid,uuid,text,text) to authenticated;
