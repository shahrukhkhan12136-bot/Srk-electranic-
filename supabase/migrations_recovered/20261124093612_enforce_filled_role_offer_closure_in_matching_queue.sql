CREATE OR REPLACE FUNCTION public.srk_process_booking_matching_queue()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public'
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
     if v_rate is null then continue; end if;
    else
     select r.id,case when v_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end
      into v_rate_id,v_rate
     from public.srk_service_rates r
     where r.category_id=v_booking.category_id and r.skill_level_id=v_level
      and (r.service_type_id is null or r.service_type_id=v_booking.service_type_id)
      and r.rate_status='approved' and r.effective_from<=clock_timestamp()
      and (r.effective_to is null or r.effective_to>clock_timestamp())
      and (case when v_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end) is not null
     order by (r.service_type_id is not null) desc,r.effective_from desc limit 1;
     if v_rate is null then continue; end if;
    end if;
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
$function$;