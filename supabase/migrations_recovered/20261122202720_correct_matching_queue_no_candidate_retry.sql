
create or replace function public.srk_process_booking_matching_queue()
returns integer language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare
  v_queue record; v_booking public.service_bookings%rowtype; v_timeout integer;
  v_tech_count integer; v_helper_count integer; v_candidate record;
  v_level uuid; v_rate_id uuid; v_rate numeric(10,2); v_role text;
  v_inserted integer:=0; v_offered boolean;
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
      update public.srk_booking_matching_queue set queue_status='cancelled',updated_at=clock_timestamp()
      where booking_id=v_queue.booking_id;
      continue;
    end if;

    select count(*) into v_tech_count from public.srk_booking_workers
      where booking_id=v_booking.id and worker_role='technician'
        and assignment_status in ('offered','accepted','assigned','working','paused','completed');
    select count(*) into v_helper_count from public.srk_booking_workers
      where booking_id=v_booking.id and worker_role='helper'
        and assignment_status in ('offered','accepted','assigned','working','paused','completed');

    if v_tech_count>=v_booking.requested_technician_count and v_helper_count>=v_booking.requested_helper_count then
      update public.srk_booking_workers set assignment_status='assigned',updated_at=clock_timestamp()
      where booking_id=v_booking.id and assignment_status='accepted';
      update public.srk_booking_matching_queue set queue_status='fulfilled',
        completed_at=coalesce(completed_at,clock_timestamp()),updated_at=clock_timestamp()
      where booking_id=v_booking.id;
      update public.service_bookings set status='confirmed' where id=v_booking.id and status='new';
      continue;
    end if;

    v_role:=case when v_tech_count<v_booking.requested_technician_count then 'technician' else 'helper' end;
    v_offered:=false;
    for v_candidate in
      select c.* from public.srk_find_eligible_workers(v_booking.id,v_role) c
      where not exists(select 1 from public.srk_booking_workers bw where bw.booking_id=v_booking.id and bw.worker_id=c.worker_id)
      order by c.distance_km
    loop
      select ws.skill_level_id into v_level from public.srk_worker_skills ws
      where ws.worker_id=v_candidate.worker_id and ws.skill_id=v_booking.selected_skill_id
        and ws.verification_status='approved' limit 1;
      select r.id,case when v_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end
      into v_rate_id,v_rate from public.srk_service_rates r
      where r.category_id=v_booking.category_id and r.skill_level_id=v_level
        and (r.service_type_id is null or r.service_type_id=v_booking.service_type_id)
        and r.rate_status='approved' and r.effective_from<=clock_timestamp()
        and (r.effective_to is null or r.effective_to>clock_timestamp())
        and (case when v_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end) is not null
      order by (r.service_type_id is not null) desc,r.effective_from desc limit 1;
      if v_rate is null then continue; end if;

      insert into public.srk_booking_workers(booking_id,worker_id,worker_role,assignment_status,
        rate_id,hourly_rate_snapshot,skill_level_snapshot_id,offer_expires_at)
      values(v_booking.id,v_candidate.worker_id,v_role,'offered',v_rate_id,v_rate,v_level,
        case when v_timeout is null then null else clock_timestamp()+make_interval(secs=>v_timeout) end);
      update public.srk_booking_matching_queue set queue_status='searching',attempts=attempts+1,
        last_attempt_at=clock_timestamp(),next_attempt_at=clock_timestamp()+interval '1 minute',
        last_error=null,updated_at=clock_timestamp() where booking_id=v_booking.id;
      v_inserted:=v_inserted+1;
      v_offered:=true;
      exit;
    end loop;

    if not v_offered then
      update public.srk_booking_matching_queue set queue_status='waiting',attempts=attempts+1,
        last_attempt_at=clock_timestamp(),next_attempt_at=clock_timestamp()+interval '1 minute',
        last_error='No eligible online approved worker with an approved rate',updated_at=clock_timestamp()
      where booking_id=v_booking.id;
    end if;
  end loop;
  return v_inserted;
end $$;
