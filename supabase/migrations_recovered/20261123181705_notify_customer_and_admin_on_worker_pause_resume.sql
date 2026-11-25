
create or replace function public.srk_notify_worker_session_event()
returns trigger
language plpgsql
security definer
set search_path to 'pg_catalog','public'
as $function$
declare
  v_booking_id uuid;
  v_customer_user_id uuid;
  v_worker_user_id uuid;
  v_title text;
  v_body text;
  v_type text;
begin
  if new.event_type not in ('paused','resumed') then return new; end if;
  select bw.booking_id,b.customer_user_id,wp.user_id
    into v_booking_id,v_customer_user_id,v_worker_user_id
  from public.srk_worker_work_sessions s
  join public.srk_booking_workers bw on bw.id=s.booking_worker_id
  join public.service_bookings b on b.id=bw.booking_id
  join public.srk_worker_profiles wp on wp.id=bw.worker_id
  where s.id=new.session_id;
  if v_booking_id is null then return new; end if;

  if new.event_type='paused' then
    v_title:='Technician/Helper ने काम रोका';
    v_body:='काम का टाइमर रोक दिया गया है। Pause शुरू होने का समय: '||new.event_at::text;
    v_type:='worker_pause';
  else
    v_title:='काम फिर से शुरू हुआ';
    v_body:='Technician/Helper ने काम का टाइमर फिर चालू कर दिया है। समय: '||new.event_at::text;
    v_type:='worker_resume';
  end if;

  if v_customer_user_id is not null then
    insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id,deep_link)
    values(v_customer_user_id,v_type,v_title,v_body,v_booking_id,'/bookings/'||v_booking_id::text);
  end if;
  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id,deep_link)
  select au.user_id,v_type,v_title,v_body,v_booking_id,'/admin/bookings/'||v_booking_id::text
  from public.srk_admin_users au;
  return new;
end
$function$;
drop trigger if exists srk_worker_session_pause_resume_notification on public.srk_worker_session_events;
create trigger srk_worker_session_pause_resume_notification
after insert on public.srk_worker_session_events
for each row execute function public.srk_notify_worker_session_event();
