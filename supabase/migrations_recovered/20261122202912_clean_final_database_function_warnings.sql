
create or replace function public.srk_admin_set_worker_status(p_worker_id uuid,p_status text,p_reason text)
returns public.srk_worker_profiles
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.srk_worker_profiles%rowtype; v_before jsonb;
begin
  if not public.srk_has_admin_permission('workers.manage') then raise exception 'Worker management permission required'; end if;
  if p_status not in ('approved','under_review','rejected','suspended') then raise exception 'Invalid worker status'; end if;
  select to_jsonb(w) into v_before from public.srk_worker_profiles w where id=p_worker_id for update;
  if v_before is null then raise exception 'Worker not found'; end if;
  update public.srk_worker_profiles set verification_status=p_status,is_active=(p_status='approved'),
    is_online=case when p_status='approved' then is_online else false end,
    location_lat=case when p_status='approved' then location_lat else null end,
    location_lng=case when p_status='approved' then location_lng else null end,updated_at=clock_timestamp()
  where id=p_worker_id returning * into v;
  insert into public.srk_admin_audit_events(entity_type,entity_id,action,actor_user_id,actor_role,changed_fields,before_data,after_data)
  values('worker_profile',p_worker_id,'status_'||p_status,auth.uid(),'admin',
    array['verification_status','is_active','is_online','location_lat','location_lng'],v_before,
    jsonb_set(to_jsonb(v),'{admin_reason}',to_jsonb(p_reason),true));
  insert into public.srk_app_notifications(user_id,notification_type,title,body)
  values(v.user_id,'worker_status','Worker account status updated','Your account status is now: '||p_status||'. Reason: '||coalesce(p_reason,'Not specified'));
  return v;
end $$;

create or replace function public.srk_submit_booking_rating(
 p_booking_id uuid,p_rating integer,p_comment text default null,p_target_worker_id uuid default null
) returns public.srk_booking_ratings
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_booking public.service_bookings%rowtype; v_role text; v_rating public.srk_booking_ratings%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id;
  if not found or v_booking.status<>'completed' then raise exception 'Only completed bookings can be rated'; end if;
  if v_booking.customer_user_id=auth.uid() then
    v_role:='customer';
    if p_target_worker_id is null or not exists(select 1 from public.srk_booking_workers bw
      where bw.booking_id=p_booking_id and bw.worker_id=p_target_worker_id and bw.assignment_status='completed') then
      raise exception 'Select a worker assigned to this completed booking';
    end if;
  else
    select w.worker_type into v_role from public.srk_booking_workers bw
    join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.booking_id=p_booking_id and w.user_id=auth.uid() and bw.assignment_status='completed' limit 1;
    if v_role is null then raise exception 'Only completed booking workers can rate the customer'; end if;
    p_target_worker_id:=null;
  end if;
  insert into public.srk_booking_ratings(booking_id,rater_user_id,rater_role,target_worker_id,target_user_id,rating,comment,moderation_status)
  values(p_booking_id,auth.uid(),v_role,p_target_worker_id,
    case when v_role<>'customer' then v_booking.customer_user_id else null end,p_rating,p_comment,'pending')
  returning * into v_rating;
  return v_rating;
end $$;
