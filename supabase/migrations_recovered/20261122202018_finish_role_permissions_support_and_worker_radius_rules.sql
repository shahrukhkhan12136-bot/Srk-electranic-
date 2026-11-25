
create or replace function public.srk_admin_review_worker_profile(p_worker_id uuid,p_decision text,p_note text default null)
returns public.srk_worker_profiles
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_worker public.srk_worker_profiles%rowtype; v_before jsonb;
begin
  if not public.srk_has_admin_permission('workers.verify') then raise exception 'Worker verification permission required'; end if;
  if p_decision not in ('approved','rejected','under_review','suspended') then raise exception 'Invalid review decision'; end if;
  select to_jsonb(w) into v_before from public.srk_worker_profiles w where id=p_worker_id for update;
  if v_before is null then raise exception 'Worker profile not found'; end if;
  update public.srk_worker_profiles set verification_status=p_decision,is_active=(p_decision='approved'),updated_at=clock_timestamp()
    where id=p_worker_id returning * into v_worker;
  insert into public.srk_admin_audit_events(entity_type,entity_id,action,actor_user_id,actor_role,changed_fields,before_data,after_data)
  values('worker_profile',p_worker_id,'verification_'||p_decision,auth.uid(),'admin',
    array['verification_status','is_active'],v_before,to_jsonb(v_worker));
  return v_worker;
end $$;

create or replace function public.srk_admin_review_worker_payout(
 p_payout_id uuid,p_approve boolean,p_approved_amount numeric default null,p_note text default null
) returns public.srk_worker_payout_requests
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_payout public.srk_worker_payout_requests%rowtype; v_available numeric(12,2); v_reserved numeric(12,2); v_amount numeric(12,2);
begin
  if not public.srk_has_admin_permission('payouts.manage') then raise exception 'Payout management permission required'; end if;
  select * into v_payout from public.srk_worker_payout_requests where id=p_payout_id for update;
  if not found or v_payout.status not in ('requested','under_review') then raise exception 'Payout request is not reviewable'; end if;
  perform 1 from public.srk_worker_profiles where id=v_payout.worker_id for update;
  if not p_approve then
    update public.srk_worker_payout_requests set status='rejected',reviewed_at=clock_timestamp(),reviewed_by=auth.uid(),admin_note=p_note
    where id=p_payout_id returning * into v_payout;
    return v_payout;
  end if;
  v_amount:=coalesce(p_approved_amount,v_payout.requested_amount);
  select coalesce(sum(balance_effect),0) into v_available from public.srk_worker_wallet_ledger where worker_id=v_payout.worker_id;
  select coalesce(sum(coalesce(approved_amount,requested_amount)),0) into v_reserved
    from public.srk_worker_payout_requests where worker_id=v_payout.worker_id and id<>p_payout_id
      and status in ('requested','under_review','approved');
  if v_amount<=0 or v_amount>v_payout.requested_amount or v_amount>v_available-v_reserved then
    raise exception 'Approved amount exceeds unreserved available balance';
  end if;
  update public.srk_worker_payout_requests set status='approved',approved_amount=v_amount,
    reviewed_at=clock_timestamp(),reviewed_by=auth.uid(),admin_note=p_note
  where id=p_payout_id returning * into v_payout;
  return v_payout;
end $$;

create or replace function public.srk_admin_mark_worker_payout_paid(
 p_payout_id uuid,p_payment_method text,p_payment_reference text,p_note text default null
) returns public.srk_worker_payout_requests
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_payout public.srk_worker_payout_requests%rowtype; v_available numeric(12,2); v_reserved numeric(12,2);
begin
  if not public.srk_has_admin_permission('payouts.manage') then raise exception 'Payout management permission required'; end if;
  if nullif(btrim(p_payment_reference),'') is null then raise exception 'UTR/transaction reference required'; end if;
  if p_payment_method not in ('upi','bank_transfer','phonepe','other') then raise exception 'Invalid payout method'; end if;
  select * into v_payout from public.srk_worker_payout_requests where id=p_payout_id for update;
  if not found or v_payout.status<>'approved' then raise exception 'Only approved payout can be marked paid'; end if;
  perform 1 from public.srk_worker_profiles where id=v_payout.worker_id for update;
  select coalesce(sum(balance_effect),0) into v_available from public.srk_worker_wallet_ledger where worker_id=v_payout.worker_id;
  select coalesce(sum(approved_amount),0) into v_reserved from public.srk_worker_payout_requests
    where worker_id=v_payout.worker_id and id<>p_payout_id and status='approved';
  if v_payout.approved_amount>v_available-v_reserved then raise exception 'Wallet balance changed; payout cannot be paid'; end if;
  insert into public.srk_worker_wallet_ledger(worker_id,entry_type,amount,balance_effect,description,reference_id,idempotency_key)
  values(v_payout.worker_id,'payout_paid',v_payout.approved_amount,-v_payout.approved_amount,
    'Admin verified payout',p_payment_reference,'payout-paid:'||v_payout.id::text);
  update public.srk_worker_payout_requests set status='paid',payment_method=p_payment_method,
    payment_reference=p_payment_reference,admin_note=coalesce(p_note,admin_note),paid_at=clock_timestamp()
  where id=p_payout_id returning * into v_payout;
  return v_payout;
end $$;

create or replace function public.srk_find_eligible_workers(p_booking_id uuid,p_worker_type text)
returns table(worker_id uuid,worker_code text,worker_type text,distance_km numeric)
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_booking public.service_bookings%rowtype;
begin
  if p_worker_type not in ('technician','helper') then raise exception 'Invalid worker type'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id;
  if not found then raise exception 'Booking not found'; end if;
  if v_booking.booking_latitude is null or v_booking.booking_longitude is null then raise exception 'Booking GPS required'; end if;
  return query
  select w.id,w.worker_code,w.worker_type,
    round((6371*acos(least(1,greatest(-1,
      cos(radians(v_booking.booking_latitude))*cos(radians(w.location_lat))*cos(radians(w.location_lng)-radians(v_booking.booking_longitude))+
      sin(radians(v_booking.booking_latitude))*sin(radians(w.location_lat))
    ))))::numeric,2)
  from public.srk_worker_profiles w
  where w.worker_type=p_worker_type and w.category_id=v_booking.category_id
    and w.verification_status='approved' and w.is_active and w.is_online
    and w.location_lat is not null and w.location_lng is not null
    and exists(select 1 from public.srk_worker_skills ws where ws.worker_id=w.id and ws.skill_id=v_booking.selected_skill_id and ws.verification_status='approved')
    and (6371*acos(least(1,greatest(-1,
      cos(radians(v_booking.booking_latitude))*cos(radians(w.location_lat))*cos(radians(w.location_lng)-radians(v_booking.booking_longitude))+
      sin(radians(v_booking.booking_latitude))*sin(radians(w.location_lat))
    ))))<=least(30,w.service_radius_km)
    and not exists(select 1 from public.srk_worker_work_sessions s join public.srk_booking_workers bw on bw.id=s.booking_worker_id
      where bw.worker_id=w.id and s.session_status='running')
    and not exists(select 1 from public.srk_worker_schedule_blocks sb where sb.worker_id=w.id
      and sb.block_status in ('reserved','confirmed','in_progress')
      and sb.starts_at<=clock_timestamp()+make_interval(hours=>coalesce(v_booking.requested_duration_hours,1))
      and sb.ends_at>clock_timestamp())
  order by 4,w.created_at;
end $$;

create or replace function public.srk_create_support_case(
 p_booking_id uuid,p_category text,p_subject text,p_description text,p_priority text default 'normal'
) returns public.srk_support_cases
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_role text; v_case public.srk_support_cases%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_booking_id is not null then
    if exists(select 1 from public.service_bookings where id=p_booking_id and customer_user_id=auth.uid()) then v_role:='customer';
    else
      select w.worker_type into v_role from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
      where bw.booking_id=p_booking_id and w.user_id=auth.uid() limit 1;
    end if;
  else
    if exists(select 1 from public.srk_customer_profiles where user_id=auth.uid()) then v_role:='customer';
    else select worker_type into v_role from public.srk_worker_profiles where user_id=auth.uid(); end if;
  end if;
  if v_role is null then raise exception 'Customer or worker profile required'; end if;
  insert into public.srk_support_cases(booking_id,raised_by,raised_by_role,category,subject,description,priority)
  values(p_booking_id,auth.uid(),v_role,p_category,p_subject,p_description,p_priority) returning * into v_case;
  insert into public.srk_support_case_events(case_id,actor_user_id,action,new_status,note)
  values(v_case.id,auth.uid(),'case_created','open',p_description);
  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  select user_id,'support_new_case','New support case','A support case requires Admin attention.',p_booking_id
  from public.srk_admin_users;
  return v_case;
end $$;

create or replace function public.srk_send_support_message(p_case_id uuid,p_message text,p_attachment_path text default null)
returns public.srk_support_messages
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_msg public.srk_support_messages%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.srk_support_cases c where c.id=p_case_id
    and (c.raised_by=auth.uid() or c.assigned_staff=auth.uid() or public.srk_has_admin_permission('support.manage'))) then
    raise exception 'Not authorized for this support case';
  end if;
  insert into public.srk_support_messages(case_id,sender_user_id,message,attachment_path)
  values(p_case_id,auth.uid(),p_message,p_attachment_path) returning * into v_msg;
  return v_msg;
end $$;

create or replace function public.srk_raise_emergency_alert(
 p_booking_id uuid,p_alert_type text,p_message text,p_latitude double precision,p_longitude double precision
) returns public.srk_emergency_alerts
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_role text; v_alert public.srk_emergency_alerts%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_booking_id is not null then
    if exists(select 1 from public.service_bookings where id=p_booking_id and customer_user_id=auth.uid()) then v_role:='customer';
    else select w.worker_type into v_role from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
      where bw.booking_id=p_booking_id and w.user_id=auth.uid() limit 1;
    end if;
  else
    if exists(select 1 from public.srk_customer_profiles where user_id=auth.uid()) then v_role:='customer';
    else select worker_type into v_role from public.srk_worker_profiles where user_id=auth.uid(); end if;
  end if;
  if v_role is null then raise exception 'Customer or worker profile required'; end if;
  insert into public.srk_emergency_alerts(booking_id,raised_by,raised_by_role,alert_type,message,latitude,longitude,priority)
  values(p_booking_id,auth.uid(),v_role,p_alert_type,p_message,p_latitude,p_longitude,'emergency')
  returning * into v_alert;
  return v_alert;
end $$;

revoke all on function public.srk_send_support_message(uuid,text,text) from public,anon;
grant execute on function public.srk_send_support_message(uuid,text,text) to authenticated;
