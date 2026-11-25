
create or replace function public.srk_raise_emergency_alert(
  p_booking_id uuid,p_alert_type text,p_message text,
  p_latitude double precision,p_longitude double precision
)
returns public.srk_emergency_alerts
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
  v_role text;
  v_alert public.srk_emergency_alerts%rowtype;
  v_response_minutes integer := 1;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;
  if p_alert_type is null or length(btrim(p_alert_type)) not between 2 and 80
     or (p_message is not null and length(p_message)>2000)
     or (p_latitude is not null and p_latitude not between -90 and 90)
     or (p_longitude is not null and p_longitude not between -180 and 180)
     or ((p_latitude is null) <> (p_longitude is null)) then
    raise exception 'Invalid emergency alert details' using errcode='22023';
  end if;

  if p_booking_id is not null then
    if exists(select 1 from public.service_bookings
      where id=p_booking_id and customer_user_id=auth.uid()) then
      v_role:='customer';
    else
      select w.worker_type into v_role
      from public.srk_booking_workers bw
      join public.srk_worker_profiles w on w.id=bw.worker_id
      where bw.booking_id=p_booking_id and w.user_id=auth.uid()
        and bw.assignment_status in ('accepted','assigned','working','paused','completed','released')
      limit 1;
    end if;
  else
    if exists(select 1 from public.srk_customer_profiles where user_id=auth.uid()) then
      v_role:='customer';
    else
      select worker_type into v_role from public.srk_worker_profiles where user_id=auth.uid() limit 1;
    end if;
  end if;
  if v_role is null or v_role not in ('customer','technician','helper') then
    raise exception 'Customer or assigned worker profile required' using errcode='42501';
  end if;

  select coalesce((setting_value #>> '{}')::integer,1)
    into v_response_minutes
  from public.srk_system_settings where setting_key='emergency_first_response_minutes';
  v_response_minutes:=greatest(1,least(coalesce(v_response_minutes,1),60));

  insert into public.srk_emergency_alerts(
    booking_id,raised_by,raised_by_role,alert_type,message,latitude,longitude,
    priority,status,response_due_at,retention_until
  )
  values(
    p_booking_id,auth.uid(),v_role,btrim(p_alert_type),nullif(btrim(coalesce(p_message,'')),''),
    p_latitude,p_longitude,'emergency','open',
    clock_timestamp()+make_interval(mins=>v_response_minutes),
    clock_timestamp()+interval '3 years'
  )
  returning * into v_alert;

  insert into public.srk_emergency_escalations(
    alert_id,escalation_level,triggered_at,response_due_at,notified_role,delivery_channel,delivery_status
  ) values (
    v_alert.id,1,clock_timestamp(),v_alert.response_due_at,'admin','in_app','queued'
  ) on conflict(alert_id,escalation_level) do nothing;

  return v_alert;
end
$function$;
