CREATE OR REPLACE FUNCTION public.srk_on_booking_assignment_notification()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public'
AS $function$
declare
 v_user uuid;
 v_customer uuid;
 v_order text;
 v_worker_message text;
begin
 select user_id into v_user from public.srk_worker_profiles where id=new.worker_id;
 select customer_user_id,order_number into v_customer,v_order
 from public.service_bookings where id=new.booking_id;

 if tg_op='INSERT' then
  if v_user is not null and new.assignment_status='offered' then
   insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
   values(v_user,'booking_offer','New booking offer',
    'You have received a new service booking offer: '||coalesce(v_order,''),new.booking_id);
  end if;
 elsif new.assignment_status is distinct from old.assignment_status then
  if new.assignment_status='accepted' and v_customer is not null then
   insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
   values(v_customer,'worker_response','Worker accepted',
    'A worker accepted your booking.',new.booking_id);
  elsif new.assignment_status='rejected'
    and coalesce(new.admin_note,'') ilike '%offer closed automatically%' then
   if v_user is not null then
    v_worker_message:=case
     when coalesce(new.admin_note,'') ilike '%higher qualification%'
      then 'The customer selected a higher qualification level. Your previous offer is now closed.'
     else 'Another worker accepted and all requested positions are now filled. This offer is closed.'
    end;
    insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
    values(v_user,'booking_offer_closed','Booking offer closed',v_worker_message,new.booking_id);
   end if;
  elsif new.assignment_status='rejected'
    and coalesce(new.admin_note,'') ilike '%offer timed out%' then
   if v_user is not null then
    insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
    values(v_user,'booking_offer_expired','Booking offer expired',
     'The booking offer expired before you responded.',new.booking_id);
   end if;
  elsif new.assignment_status='rejected' and v_customer is not null then
   insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
   values(v_customer,'worker_response','Worker declined',
    'A worker declined the booking offer.',new.booking_id);
  end if;
 end if;
 return new;
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
 if exists(select 1 from public.srk_booking_workers
  where booking_id=p_booking_id and assignment_status in ('accepted','assigned','working','paused','completed')) then
  raise exception 'Higher-level consent must be given before a worker accepts the booking';
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

 update public.srk_booking_workers
 set assignment_status='rejected',rejected_at=clock_timestamp(),offer_expires_at=null,
     admin_note='Offer closed automatically: customer selected a higher qualification level.',
     updated_at=clock_timestamp()
 where booking_id=p_booking_id and assignment_status='offered';

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

CREATE OR REPLACE FUNCTION public.srk_worker_respond_assignment(p_assignment_id uuid,p_accept boolean)
RETURNS public.srk_booking_workers
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_assignment public.srk_booking_workers%rowtype;
 v_worker public.srk_worker_profiles%rowtype;
 v_booking public.service_bookings%rowtype;
 v_booking_id uuid;
 v_worker_id uuid;
 v_accepted_count integer;
 v_requested_count integer;
 v_required_skill_level uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select bw.booking_id,bw.worker_id into v_booking_id,v_worker_id
 from public.srk_booking_workers bw
 join public.srk_worker_profiles wp on wp.id=bw.worker_id
 where bw.id=p_assignment_id and wp.user_id=auth.uid();
 if not found then raise exception 'Offer not found or not yours'; end if;
 select * into v_booking from public.service_bookings where id=v_booking_id for update;
 if not found or v_booking.status='cancelled' then raise exception 'Booking is no longer available'; end if;
 select bw.* into v_assignment
 from public.srk_booking_workers bw
 join public.srk_worker_profiles wp on wp.id=bw.worker_id
 where bw.id=p_assignment_id and wp.user_id=auth.uid()
 for update of bw;
 if not found or v_assignment.assignment_status<>'offered' then
  raise exception 'Offer not found or no longer pending';
 end if;
 if p_accept and v_assignment.offer_expires_at is not null
    and v_assignment.offer_expires_at<=clock_timestamp() then
  raise exception 'Offer has expired; wait for the next eligible assignment';
 end if;
 select * into v_worker from public.srk_worker_profiles where id=v_worker_id for update;
 if not found then raise exception 'Worker profile not found'; end if;

 if p_accept then
  if v_worker.verification_status<>'approved' or not v_worker.is_active then
   raise exception 'Worker is not currently approved and active';
  end if;
  v_required_skill_level:=coalesce(v_booking.higher_skill_consent_level_id,v_booking.requested_skill_level_id);
  if v_required_skill_level is not null and (
    v_assignment.skill_level_snapshot_id is distinct from v_required_skill_level
    or not exists(select 1 from public.srk_worker_skills ws
      where ws.worker_id=v_worker.id and ws.skill_id=v_booking.selected_skill_id
       and ws.skill_level_id=v_required_skill_level and ws.verification_status='approved')
  ) then
   raise exception 'Worker no longer matches the customer-approved qualification level';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_worker.id::text,0));
  if exists(select 1 from public.srk_worker_work_sessions s
            where s.worker_id=v_worker.id and s.session_status in ('running','paused'))
     or exists(select 1 from public.srk_booking_workers bw
               where bw.worker_id=v_worker.id and bw.assignment_status in ('working','paused')) then
   raise exception 'Finish or complete the active/paused booking before accepting another booking';
  end if;
  if exists(
   select 1 from public.srk_booking_workers bw
   where bw.worker_id=v_worker.id and bw.id<>v_assignment.id
    and bw.assignment_status in ('accepted','assigned')
    and not exists(select 1 from public.srk_worker_schedule_blocks sb
     where sb.booking_worker_id=bw.id and sb.block_status in ('reserved','confirmed','in_progress'))
  ) then
   raise exception 'Another accepted booking still needs a customer-confirmed schedule';
  end if;
  if exists(
   select 1 from public.srk_worker_schedule_blocks sb
   where sb.worker_id=v_worker.id and sb.block_status in ('reserved','confirmed','in_progress')
    and sb.starts_at<=clock_timestamp()+make_interval(hours=>coalesce(v_booking.requested_duration_hours,1))
    and sb.ends_at>clock_timestamp()
  ) then
   raise exception 'A confirmed worker schedule conflicts with this booking';
  end if;
  v_requested_count:=case when v_assignment.worker_role='technician'
   then v_booking.requested_technician_count else v_booking.requested_helper_count end;
  select count(*) into v_accepted_count from public.srk_booking_workers
  where booking_id=v_assignment.booking_id and worker_role=v_assignment.worker_role
   and assignment_status in ('accepted','assigned','working','paused','completed');
  if v_accepted_count>=v_requested_count then
   raise exception 'Requested number of this worker role has already been filled';
  end if;
 end if;

 update public.srk_booking_workers
 set assignment_status=case when p_accept then 'accepted' else 'rejected' end,
     accepted_at=case when p_accept then clock_timestamp() else null end,
     rejected_at=case when p_accept then null else clock_timestamp() end,
     offer_expires_at=null,updated_at=clock_timestamp()
 where id=p_assignment_id returning * into v_assignment;

 if p_accept then
  if v_assignment.worker_role='technician' then
   update public.service_bookings set status='confirmed'
   where id=v_assignment.booking_id and status='new';
  end if;
  v_requested_count:=case when v_assignment.worker_role='technician'
   then v_booking.requested_technician_count else v_booking.requested_helper_count end;
  select count(*) into v_accepted_count from public.srk_booking_workers
  where booking_id=v_assignment.booking_id and worker_role=v_assignment.worker_role
   and assignment_status in ('accepted','assigned','working','paused','completed');
  if v_accepted_count>=v_requested_count then
   update public.srk_booking_workers
   set assignment_status='rejected',rejected_at=clock_timestamp(),offer_expires_at=null,
       admin_note='Offer closed automatically: all requested positions filled by earlier acceptance.',
       updated_at=clock_timestamp()
   where booking_id=v_assignment.booking_id and worker_role=v_assignment.worker_role
     and assignment_status='offered' and id<>v_assignment.id;
  end if;
 end if;
 update public.srk_booking_matching_queue
 set queue_status='pending',next_attempt_at=clock_timestamp(),updated_at=clock_timestamp()
 where booking_id=v_assignment.booking_id and queue_status not in ('fulfilled','cancelled');
 return v_assignment;
end
$function$;