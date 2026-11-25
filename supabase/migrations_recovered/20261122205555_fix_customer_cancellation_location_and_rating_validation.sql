
create or replace function public.srk_customer_cancel_booking_v2(p_booking_id uuid,p_reason text)
returns public.service_bookings
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.service_bookings%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if length(coalesce(p_reason,''))<5 then raise exception 'Cancellation reason is required'; end if;
  select * into v from public.service_bookings where id=p_booking_id and customer_user_id=auth.uid() for update;
  if not found then raise exception 'Customer booking not found'; end if;
  if v.status not in ('new','confirmed','assigned') then
    raise exception 'Booking can no longer be cancelled directly; contact Support so timer evidence is preserved';
  end if;
  if exists(select 1 from public.srk_worker_work_sessions s join public.srk_booking_workers bw on bw.id=s.booking_worker_id
    where bw.booking_id=p_booking_id and (s.billable_seconds>0 or s.session_status in ('running','paused'))) then
    raise exception 'Work has started or billable time exists; contact Support for review';
  end if;
  update public.service_bookings set status='cancelled',admin_change_reason='Customer cancellation: '||p_reason
  where id=p_booking_id returning * into v;
  update public.srk_booking_matching_queue set queue_status='cancelled',updated_at=clock_timestamp()
  where booking_id=p_booking_id;
  update public.srk_worker_work_sessions set session_status='cancelled',ended_at=clock_timestamp(),updated_at=clock_timestamp()
  where booking_worker_id in(select id from public.srk_booking_workers where booking_id=p_booking_id)
    and session_status='not_started';
  update public.srk_booking_workers set assignment_status='cancelled',admin_note='Customer cancellation: '||p_reason,updated_at=clock_timestamp()
  where booking_id=p_booking_id and assignment_status in ('offered','accepted','assigned');
  update public.srk_worker_schedule_blocks set block_status='cancelled',updated_at=clock_timestamp()
  where booking_worker_id in(select id from public.srk_booking_workers where booking_id=p_booking_id)
    and block_status in ('reserved','confirmed','in_progress');
  update public.srk_booking_location_shares set ended_at=clock_timestamp()
  where booking_id=p_booking_id and ended_at is null;
  insert into public.srk_booking_cancellation_events(booking_id,actor_user_id,actor_role,reason)
  values(p_booking_id,auth.uid(),'customer',p_reason);
  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  select w.user_id,'booking_cancelled','Booking cancelled','Customer cancelled the booking. Reason: '||p_reason,p_booking_id
  from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
  where bw.booking_id=p_booking_id;
  return v;
end $$;

create or replace function public.srk_submit_booking_rating(
 p_booking_id uuid,p_rating integer,p_comment text default null,p_target_worker_id uuid default null
) returns public.srk_booking_ratings
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_booking public.service_bookings%rowtype; v_role text; v_worker uuid; v_target_worker uuid;
  v_rating_row public.srk_booking_ratings%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_rating not between 1 and 5 then raise exception 'Rating must be between 1 and 5'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id;
  if not found or v_booking.status<>'completed' then raise exception 'Only completed bookings can be rated'; end if;

  if v_booking.customer_user_id=auth.uid() then
    if p_target_worker_id is not null then raise exception 'Customer rates the completed booking, not a selected worker'; end if;
    v_role:='customer';
    select bw.worker_id into v_target_worker
    from public.srk_booking_workers bw
    where bw.booking_id=p_booking_id and bw.worker_role='technician' and bw.assignment_status in ('completed','released')
    order by bw.accepted_at nulls last,bw.assigned_at limit 1;
    if v_target_worker is null then raise exception 'Completed Technician assignment not found'; end if;
    insert into public.srk_booking_ratings(booking_id,rater_user_id,rater_role,target_worker_id,target_user_id,rating,comment,moderation_status)
    values(p_booking_id,auth.uid(),'customer',v_target_worker,null,p_rating,p_comment,'pending')
    returning * into v_rating_row;
  else
    select w.id,w.worker_type into v_worker,v_role
    from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.booking_id=p_booking_id and w.user_id=auth.uid()
      and bw.assignment_status in ('completed','released') limit 1;
    if v_worker is null then raise exception 'Only completed booking workers can rate the customer'; end if;
    insert into public.srk_booking_ratings(booking_id,rater_user_id,rater_role,target_worker_id,target_user_id,rating,comment,moderation_status)
    values(p_booking_id,auth.uid(),v_role,v_worker,v_booking.customer_user_id,p_rating,p_comment,'pending')
    returning * into v_rating_row;
  end if;
  return v_rating_row;
end $$;
