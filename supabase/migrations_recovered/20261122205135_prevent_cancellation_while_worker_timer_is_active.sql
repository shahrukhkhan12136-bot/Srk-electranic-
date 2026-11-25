
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
  update public.srk_booking_location_shares set is_active=false,ended_at=clock_timestamp()
  where booking_id=p_booking_id and is_active;
  insert into public.srk_booking_cancellation_events(booking_id,actor_user_id,actor_role,reason)
  values(p_booking_id,auth.uid(),'customer',p_reason);
  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  select w.user_id,'booking_cancelled','Booking cancelled','Customer cancelled the booking. Reason: '||p_reason,p_booking_id
  from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
  where bw.booking_id=p_booking_id;
  return v;
end $$;
