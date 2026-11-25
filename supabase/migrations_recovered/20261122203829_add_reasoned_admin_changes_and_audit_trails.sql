
alter table public.service_bookings add column if not exists admin_change_reason text;
alter table public.srk_customer_profiles add column if not exists admin_note text;
alter table public.srk_support_cases add column if not exists admin_note text;
alter table public.srk_emergency_alerts add column if not exists admin_note text;
alter table public.srk_booking_ratings add column if not exists moderation_note text;
alter table public.srk_service_rates add column if not exists change_reason text;

create or replace function public.srk_log_admin_entity_change()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_old jsonb; v_new jsonb; v_id uuid; v_booking uuid; v_changed text[];
  v_actor_role text; v_reason text;
begin
  if auth.uid() is null then if tg_op='DELETE' then return old; else return new; end if; end if;
  if not exists(select 1 from public.srk_admin_users where user_id=auth.uid())
     and not exists(select 1 from public.srk_admin_staff_members where user_id=auth.uid() and is_active) then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  v_old:=case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else '{}'::jsonb end;
  v_new:=case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else '{}'::jsonb end;
  v_id:=coalesce(nullif(v_new->>'id','')::uuid,nullif(v_old->>'id','')::uuid);
  v_booking:=coalesce(nullif(v_new->>'booking_id','')::uuid,nullif(v_old->>'booking_id','')::uuid);
  v_actor_role:=case when exists(select 1 from public.srk_admin_users where user_id=auth.uid()) then 'super_admin' else 'staff' end;
  v_reason:=coalesce(v_new->>'admin_note',v_new->>'change_reason',v_new->>'admin_change_reason',v_new->>'reason','Admin panel change');
  select coalesce(array_agg(k),array[]::text[]) into v_changed
  from (select key k from jsonb_object_keys(v_new) key union select key k from jsonb_object_keys(v_old) key) keys
  where v_old->k is distinct from v_new->k;
  insert into public.srk_admin_audit_events(entity_type,entity_id,booking_id,action,actor_user_id,actor_role,changed_fields,before_data,after_data)
  values(tg_argv[0],v_id,v_booking,tg_op,auth.uid(),v_actor_role,v_changed,v_old,
    case when v_reason is null then v_new else jsonb_set(v_new,'{admin_action_reason}',to_jsonb(v_reason),true) end);
  if v_booking is not null then
    insert into public.srk_booking_admin_changes(booking_id,admin_user_id,entity_type,entity_id,action,reason,old_values,new_values)
    values(v_booking,auth.uid(),tg_argv[0],v_id,tg_op,v_reason,v_old,v_new);
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end $$;

create or replace function public.srk_admin_set_customer_status(p_customer_id uuid,p_status text,p_reason text)
returns public.srk_customer_profiles
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.srk_customer_profiles%rowtype;
begin
  if not public.srk_has_admin_permission('customers.manage') then raise exception 'Customer management permission required'; end if;
  if p_status not in ('active','restricted','suspended') then raise exception 'Invalid customer status'; end if;
  update public.srk_customer_profiles set account_status=p_status,restriction_reason=p_reason,admin_note=p_reason,
    restricted_at=case when p_status='active' then null else clock_timestamp() end,updated_at=clock_timestamp()
  where id=p_customer_id returning * into v;
  if not found then raise exception 'Customer not found'; end if;
  insert into public.srk_app_notifications(user_id,notification_type,title,body)
  values(v.user_id,'account_status','Account status updated','Your account status is now: '||p_status||'. Reason: '||coalesce(p_reason,'Not specified'));
  return v;
end $$;

create or replace function public.srk_admin_update_support_case(
 p_case_id uuid,p_status text,p_priority text default null,p_assigned_staff uuid default null,p_resolution text default null,p_note text default null
) returns public.srk_support_cases
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.srk_support_cases%rowtype; v_old text;
begin
  if not public.srk_has_admin_permission('support.manage') then raise exception 'Support permission required'; end if;
  select status into v_old from public.srk_support_cases where id=p_case_id for update;
  if not found then raise exception 'Support case not found'; end if;
  update public.srk_support_cases set status=coalesce(p_status,status),priority=coalesce(p_priority,priority),
    assigned_staff=coalesce(p_assigned_staff,assigned_staff),resolution=coalesce(p_resolution,resolution),
    admin_note=p_note,
    resolved_at=case when p_status in ('resolved','closed') then clock_timestamp() else resolved_at end,
    updated_at=clock_timestamp()
  where id=p_case_id returning * into v;
  insert into public.srk_support_case_events(case_id,actor_user_id,action,old_status,new_status,note)
  values(p_case_id,auth.uid(),'admin_update',v_old,v.status,p_note);
  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  values(v.raised_by,'support_update','Support case updated','Your support case status is now: '||v.status,v.booking_id);
  return v;
end $$;

create or replace function public.srk_admin_resolve_emergency_alert(p_alert_id uuid,p_status text,p_note text default null)
returns public.srk_emergency_alerts
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.srk_emergency_alerts%rowtype;
begin
  if not public.srk_has_admin_permission('support.manage') then raise exception 'Support permission required'; end if;
  if p_status not in ('acknowledged','responding','resolved','false_alarm') then raise exception 'Invalid emergency status'; end if;
  update public.srk_emergency_alerts set status=p_status,assigned_staff=coalesce(assigned_staff,auth.uid()),
    admin_note=p_note,
    resolved_at=case when p_status in ('resolved','false_alarm') then clock_timestamp() else resolved_at end
  where id=p_alert_id returning * into v;
  if not found then raise exception 'Emergency alert not found'; end if;
  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  values(v.raised_by,'emergency_update','Emergency response update',coalesce(p_note,'Emergency alert status: '||p_status),v.booking_id);
  return v;
end $$;

create or replace function public.srk_admin_moderate_booking_rating(p_rating_id uuid,p_decision text,p_note text default null)
returns public.srk_booking_ratings
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.srk_booking_ratings%rowtype;
begin
  if not public.srk_has_admin_permission('ratings.moderate') then raise exception 'Rating moderation permission required'; end if;
  if p_decision not in ('published','hidden','rejected') then raise exception 'Invalid moderation decision'; end if;
  update public.srk_booking_ratings set moderation_status=p_decision,moderated_by=auth.uid(),
    moderated_at=clock_timestamp(),moderation_note=p_note
  where id=p_rating_id returning * into v;
  if not found then raise exception 'Rating not found'; end if;
  return v;
end $$;

drop trigger if exists srk_audit_booking_rating_admin on public.srk_booking_ratings;
create trigger srk_audit_booking_rating_admin after insert or update or delete on public.srk_booking_ratings
for each row execute function public.srk_log_admin_entity_change('booking_rating');

drop trigger if exists srk_audit_worker_refund_allocation_admin on public.srk_worker_refund_allocations;
create trigger srk_audit_worker_refund_allocation_admin after insert or update or delete on public.srk_worker_refund_allocations
for each row execute function public.srk_log_admin_entity_change('worker_refund_allocation');

drop trigger if exists srk_audit_worker_earning_admin on public.srk_worker_earnings;
create trigger srk_audit_worker_earning_admin after insert or update or delete on public.srk_worker_earnings
for each row execute function public.srk_log_admin_entity_change('worker_earning');

drop trigger if exists srk_audit_offline_timer_admin on public.srk_worker_offline_timer_events;
create trigger srk_audit_offline_timer_admin after insert or update or delete on public.srk_worker_offline_timer_events
for each row execute function public.srk_log_admin_entity_change('offline_timer_event');

create or replace function public.srk_admin_update_booking_address(
 p_booking_id uuid,p_address text,p_state text,p_district text,p_pincode text,p_reason text
) returns public.service_bookings
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.service_bookings%rowtype;
begin
  if not public.srk_has_admin_permission('bookings.manage') then raise exception 'Booking management permission required'; end if;
  if length(coalesce(p_reason,''))<10 then raise exception 'Admin reason must be at least 10 characters'; end if;
  if p_pincode !~ '^[0-9]{6}$' or length(btrim(coalesce(p_address,'')))<5 then raise exception 'Valid address and PIN code required'; end if;
  update public.service_bookings set address=p_address,state=p_state,district=p_district,pincode=p_pincode,
    admin_change_reason=p_reason where id=p_booking_id returning * into v;
  if not found then raise exception 'Booking not found'; end if;
  return v;
end $$;

revoke all on function public.srk_admin_update_booking_address(uuid,text,text,text,text,text) from public,anon;
grant execute on function public.srk_admin_update_booking_address(uuid,text,text,text,text,text) to authenticated;
