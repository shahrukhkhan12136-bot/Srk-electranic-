
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
    array['verification_status','is_active'],v_before,
    jsonb_set(to_jsonb(v_worker),'{admin_review_note}',to_jsonb(p_note),true));
  return v_worker;
end $$;

create or replace function public.srk_worker_session_action(
 p_session_id uuid,p_action text,p_pause_reason text default null,p_note text default null,p_idempotency_key text default null
) returns public.srk_worker_work_sessions
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_session public.srk_worker_work_sessions%rowtype; v_user_id uuid; v_booking_id uuid;
  v_now timestamptz:=clock_timestamp(); v_elapsed bigint;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_session from public.srk_worker_work_sessions where id=p_session_id for update;
  if not found then raise exception 'Work session not found'; end if;
  select wp.user_id,bw.booking_id into v_user_id,v_booking_id
  from public.srk_booking_workers bw join public.srk_worker_profiles wp on wp.id=bw.worker_id
  where bw.id=v_session.booking_worker_id;
  if v_user_id is distinct from auth.uid() and not coalesce(public.is_srk_admin(),false) then
    raise exception 'Not authorized for this work session';
  end if;
  if p_idempotency_key is not null and exists(select 1 from public.srk_worker_session_events where idempotency_key=p_idempotency_key) then
    return v_session;
  end if;
  if p_action='start' then
    if v_session.session_status<>'not_started' then raise exception 'Session cannot be started from current state'; end if;
    update public.srk_worker_work_sessions set session_status='running',started_at=v_now,last_resumed_at=v_now,updated_at=v_now
      where id=p_session_id returning * into v_session;
    update public.srk_booking_workers set assignment_status='working',updated_at=v_now
      where id=v_session.booking_worker_id and assignment_status in ('accepted','assigned','paused');
    update public.service_bookings set status='in_progress',work_started_at=coalesce(work_started_at,v_now)
      where id=v_booking_id and status in ('new','confirmed','assigned','in_progress');
    insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,note,idempotency_key)
      values(p_session_id,'started',v_now,auth.uid(),p_note,p_idempotency_key);
  elsif p_action='pause' then
    if v_session.session_status<>'running' then raise exception 'Only a running session can be paused'; end if;
    if p_pause_reason not in ('food_break','material','customer_permission','technical_problem','other') then raise exception 'Valid pause reason required'; end if;
    v_elapsed:=greatest(0,floor(extract(epoch from(v_now-v_session.last_resumed_at)))::bigint);
    update public.srk_worker_work_sessions set session_status='paused',billable_seconds=least(5184000,billable_seconds+v_elapsed),
      last_resumed_at=null,pause_reason=p_pause_reason,updated_at=v_now where id=p_session_id returning * into v_session;
    update public.srk_booking_workers set assignment_status='paused',updated_at=v_now where id=v_session.booking_worker_id;
    insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,pause_reason,note,idempotency_key)
      values(p_session_id,'paused',v_now,auth.uid(),p_pause_reason,p_note,p_idempotency_key);
  elsif p_action='resume' then
    if v_session.session_status<>'paused' then raise exception 'Only a paused session can be resumed'; end if;
    update public.srk_worker_work_sessions set session_status='running',last_resumed_at=v_now,pause_reason=null,updated_at=v_now
      where id=p_session_id returning * into v_session;
    update public.srk_booking_workers set assignment_status='working',updated_at=v_now where id=v_session.booking_worker_id;
    insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,note,idempotency_key)
      values(p_session_id,'resumed',v_now,auth.uid(),p_note,p_idempotency_key);
  elsif p_action='complete' then
    if v_session.session_status not in ('running','paused') then raise exception 'Session cannot be completed from current state'; end if;
    v_elapsed:=case when v_session.session_status='running' then greatest(0,floor(extract(epoch from(v_now-v_session.last_resumed_at)))::bigint) else 0 end;
    update public.srk_worker_work_sessions set session_status='completed',
      billable_seconds=least(5184000,billable_seconds+v_elapsed),ended_at=v_now,last_resumed_at=null,
      completion_note=p_note,updated_at=v_now where id=p_session_id returning * into v_session;
    update public.srk_booking_workers set assignment_status='assigned',updated_at=v_now
      where id=v_session.booking_worker_id and assignment_status in ('working','paused');
    insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,note,idempotency_key)
      values(p_session_id,'completed',v_now,auth.uid(),p_note,p_idempotency_key);
  else raise exception 'Unsupported session action';
  end if;
  return v_session;
end $$;

create or replace function public.srk_worker_request_skill(p_skill_id uuid,p_skill_level_id uuid)
returns public.srk_worker_skills
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_worker public.srk_worker_profiles%rowtype; v_skill public.srk_service_skills%rowtype;
  v_level public.srk_skill_levels%rowtype; v_result public.srk_worker_skills%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_worker from public.srk_worker_profiles where user_id=auth.uid();
  if not found then raise exception 'Worker profile not found'; end if;
  select * into v_skill from public.srk_service_skills where id=p_skill_id and is_active;
  if not found then raise exception 'Active skill not found'; end if;
  select * into v_level from public.srk_skill_levels where id=p_skill_level_id and category_id=v_worker.category_id and is_active;
  if v_level.id is null then raise exception 'Skill level does not match worker category'; end if;
  if not exists(select 1 from public.srk_service_types s where s.id=v_skill.service_type_id and s.category_id=v_worker.category_id) then
    raise exception 'Skill is outside worker category';
  end if;
  insert into public.srk_worker_skills(worker_id,skill_id,skill_level_id,verification_status)
  values(v_worker.id,p_skill_id,p_skill_level_id,'pending')
  on conflict(worker_id,skill_id) do update set skill_level_id=excluded.skill_level_id,
    verification_status='pending',reviewed_by=null,reviewed_at=null,updated_at=clock_timestamp()
  returning * into v_result;
  return v_result;
end $$;

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
  v_reason:=coalesce(v_new->>'admin_note',v_new->>'reason','Admin panel change');
  select coalesce(array_agg(k),array[]::text[]) into v_changed
  from (select key k from jsonb_object_keys(v_new) key union select key k from jsonb_object_keys(v_old) key) keys
  where v_old->k is distinct from v_new->k;
  insert into public.srk_admin_audit_events(entity_type,entity_id,booking_id,action,actor_user_id,actor_role,changed_fields,before_data,after_data)
  values(tg_argv[0],v_id,v_booking,tg_op,auth.uid(),v_actor_role,v_changed,v_old,v_new);
  if v_booking is not null then
    insert into public.srk_booking_admin_changes(booking_id,admin_user_id,entity_type,entity_id,action,reason,old_values,new_values)
    values(v_booking,auth.uid(),tg_argv[0],v_id,tg_op,v_reason,v_old,v_new);
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end $$;
