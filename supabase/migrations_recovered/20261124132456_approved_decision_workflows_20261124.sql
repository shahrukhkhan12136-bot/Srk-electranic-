
-- SRK ELECTRONIC approved decision workflows (2026-11-24)

-- 1) Worker cancellation fault review. No fee amount is configured until separately approved.
create table if not exists public.srk_worker_cancellation_reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  booking_worker_id uuid not null references public.srk_booking_workers(id) on delete restrict,
  worker_id uuid not null references public.srk_worker_profiles(id) on delete restrict,
  worker_user_id uuid not null references auth.users(id) on delete restrict,
  worker_role text not null check (worker_role in ('technician','helper')),
  cancellation_reason text not null,
  review_status text not null default 'pending' check (review_status in ('pending','justified','unjustified')),
  fee_amount numeric(12,2),
  fee_assessment_status text not null default 'not_assessed' check (fee_assessment_status in ('not_assessed','amount_policy_pending','assessed')),
  reviewed_by uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  admin_note text,
  created_at timestamptz not null default clock_timestamp(),
  constraint srk_worker_cancel_review_fee_nonnegative check (fee_amount is null or fee_amount > 0),
  constraint srk_worker_cancel_review_review_tuple check (
    (review_status='pending' and reviewed_by is null and reviewed_at is null)
    or (review_status<>'pending' and reviewed_by is not null and reviewed_at is not null)
  ),
  constraint srk_worker_cancel_review_fee_rule check (
    (review_status<>'unjustified' and fee_amount is null and fee_assessment_status='not_assessed')
    or (review_status='unjustified' and fee_amount is null and fee_assessment_status='amount_policy_pending')
    or (review_status='unjustified' and fee_amount is not null and fee_assessment_status='assessed')
  ),
  unique (booking_worker_id)
);
create index if not exists srk_worker_cancel_reviews_pending_idx
  on public.srk_worker_cancellation_reviews(review_status,created_at desc);
alter table public.srk_worker_cancellation_reviews enable row level security;
revoke all on public.srk_worker_cancellation_reviews from anon, authenticated;
grant select,insert,update on public.srk_worker_cancellation_reviews to service_role;

create or replace function public.srk_capture_worker_cancellation_for_review()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_assignment public.srk_booking_workers%rowtype; v_worker public.srk_worker_profiles%rowtype;
begin
 if new.actor_role not in ('technician','helper') then return new; end if;
 select bw.* into v_assignment
 from public.srk_booking_workers bw
 join public.srk_worker_profiles wp on wp.id=bw.worker_id
 where bw.booking_id=new.booking_id and wp.user_id=new.actor_user_id
   and bw.worker_role=new.actor_role and bw.assignment_status='cancelled'
 order by bw.updated_at desc limit 1;
 if not found then return new; end if;
 select * into v_worker from public.srk_worker_profiles where id=v_assignment.worker_id;
 insert into public.srk_worker_cancellation_reviews
  (booking_id,booking_worker_id,worker_id,worker_user_id,worker_role,cancellation_reason)
 values(new.booking_id,v_assignment.id,v_assignment.worker_id,new.actor_user_id,
        new.actor_role,new.reason)
 on conflict (booking_worker_id) do nothing;
 return new;
end $$;
drop trigger if exists srk_capture_worker_cancellation_review on public.srk_booking_cancellation_events;
create trigger srk_capture_worker_cancellation_review
after insert on public.srk_booking_cancellation_events
for each row execute function public.srk_capture_worker_cancellation_for_review();

create or replace function public.srk_admin_review_worker_cancellation_fault(
 p_review_id uuid, p_decision text, p_note text
) returns public.srk_worker_cancellation_reviews
language plpgsql security definer set search_path=''
as $$
declare v public.srk_worker_cancellation_reviews%rowtype;
begin
 if auth.uid() is null or not public.is_srk_admin() then
  raise exception 'MAIN_ADMIN_REQUIRED' using errcode='42501';
 end if;
 if p_review_id is null or p_decision not in ('justified','unjustified')
   or length(btrim(coalesce(p_note,'')))<10 or length(p_note)>2000 then
  raise exception 'VALID_REVIEW_DECISION_AND_REASON_REQUIRED' using errcode='22023';
 end if;
 select * into v from public.srk_worker_cancellation_reviews where id=p_review_id for update;
 if not found then raise exception 'CANCELLATION_REVIEW_NOT_FOUND'; end if;
 if v.review_status<>'pending' then raise exception 'CANCELLATION_ALREADY_REVIEWED'; end if;
 update public.srk_worker_cancellation_reviews
 set review_status=p_decision,fee_assessment_status=case when p_decision='unjustified'
      then 'amount_policy_pending' else 'not_assessed' end,
     reviewed_by=auth.uid(),reviewed_at=clock_timestamp(),admin_note=btrim(p_note)
 where id=p_review_id returning * into v;
 insert into public.srk_booking_worker_events(booking_worker_id,booking_id,worker_id,event_type,actor_user_id,reason,details)
 values(v.booking_worker_id,v.booking_id,v.worker_id,'cancellation_fault_reviewed',auth.uid(),btrim(p_note),
        jsonb_build_object('review_status',p_decision,'fee_amount',null,'fee_amount_policy_pending',p_decision='unjustified'));
 return v;
end $$;
revoke all on function public.srk_admin_review_worker_cancellation_fault(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_review_worker_cancellation_fault(uuid,text,text) to authenticated;

-- 2) Emergency decision appeals and immutable review history.
create table if not exists public.srk_emergency_decision_appeals (
 id uuid primary key default gen_random_uuid(),
 alert_id uuid not null references public.srk_emergency_alerts(id) on delete restrict,
 appealed_by uuid not null references auth.users(id) on delete restrict,
 appellant_role text not null check (appellant_role in ('customer','technician','helper')),
 appeal_reason text not null check (length(btrim(appeal_reason)) between 20 and 2000),
 status text not null default 'submitted' check (status in ('submitted','under_review','accepted','rejected','closed')),
 reviewed_by uuid references auth.users(id) on delete restrict,
 reviewed_at timestamptz,
 review_note text,
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(),
 constraint srk_emergency_appeal_review_tuple check (
  (status in ('submitted','under_review') and reviewed_by is null and reviewed_at is null)
  or (status in ('accepted','rejected','closed') and reviewed_by is not null and reviewed_at is not null)
 ),
 unique(alert_id,appealed_by)
);
create index if not exists srk_emergency_appeals_status_idx
 on public.srk_emergency_decision_appeals(status,created_at desc);
create table if not exists public.srk_emergency_decision_appeal_events (
 id uuid primary key default gen_random_uuid(),
 appeal_id uuid not null references public.srk_emergency_decision_appeals(id) on delete restrict,
 actor_user_id uuid not null references auth.users(id) on delete restrict,
 action text not null check (action in ('submitted','review_started','accepted','rejected','closed')),
 note text,
 created_at timestamptz not null default clock_timestamp()
);
create index if not exists srk_emergency_appeal_events_appeal_idx
 on public.srk_emergency_decision_appeal_events(appeal_id,created_at);
alter table public.srk_emergency_decision_appeals enable row level security;
alter table public.srk_emergency_decision_appeal_events enable row level security;
revoke all on public.srk_emergency_decision_appeals,public.srk_emergency_decision_appeal_events from anon,authenticated;
grant select,insert,update on public.srk_emergency_decision_appeals,public.srk_emergency_decision_appeal_events to service_role;

create or replace function public.srk_submit_emergency_decision_appeal(p_alert_id uuid,p_reason text)
returns public.srk_emergency_decision_appeals
language plpgsql security definer set search_path=''
as $$
declare v_alert public.srk_emergency_alerts%rowtype; v_role text; v_booking public.service_bookings%rowtype; v_worker_role text; v_result public.srk_emergency_decision_appeals%rowtype;
begin
 if auth.uid() is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
 if p_alert_id is null or length(btrim(coalesce(p_reason,''))) not between 20 and 2000 then
  raise exception 'VALID_ALERT_AND_APPEAL_REASON_REQUIRED' using errcode='22023';
 end if;
 select * into v_alert from public.srk_emergency_alerts where id=p_alert_id for share;
 if not found or v_alert.decision_status is null then raise exception 'DECIDED_EMERGENCY_ALERT_REQUIRED'; end if;
 if v_alert.booking_id is not null then
  select * into v_booking from public.service_bookings where id=v_alert.booking_id;
  if v_booking.customer_user_id=auth.uid() then v_role:='customer'; end if;
  select bw.worker_role into v_worker_role
   from public.srk_booking_workers bw join public.srk_worker_profiles wp on wp.id=bw.worker_id
   where bw.booking_id=v_alert.booking_id and wp.user_id=auth.uid()
   order by case bw.worker_role when 'technician' then 1 else 2 end limit 1;
  if v_role is null and v_worker_role in ('technician','helper') then v_role:=v_worker_role; end if;
 else
  if v_alert.raised_by=auth.uid() then
   v_role:=case when v_alert.raised_by_role in ('customer','technician','helper') then v_alert.raised_by_role else null end;
  end if;
 end if;
 if v_role is null then raise exception 'ONLY_BOOKING_CUSTOMER_OR_ASSIGNED_WORKER_MAY_APPEAL' using errcode='42501'; end if;
 insert into public.srk_emergency_decision_appeals(alert_id,appealed_by,appellant_role,appeal_reason)
 values(p_alert_id,auth.uid(),v_role,btrim(p_reason)) returning * into v_result;
 insert into public.srk_emergency_decision_appeal_events(appeal_id,actor_user_id,action,note)
 values(v_result.id,auth.uid(),'submitted',btrim(p_reason));
 return v_result;
exception when unique_violation then raise exception 'APPEAL_ALREADY_SUBMITTED_FOR_THIS_ALERT';
end $$;
revoke all on function public.srk_submit_emergency_decision_appeal(uuid,text) from public,anon;
grant execute on function public.srk_submit_emergency_decision_appeal(uuid,text) to authenticated;

create or replace function public.srk_admin_review_emergency_decision_appeal(
 p_appeal_id uuid,p_decision text,p_note text
) returns public.srk_emergency_decision_appeals
language plpgsql security definer set search_path=''
as $$
declare v public.srk_emergency_decision_appeals%rowtype;
begin
 if auth.uid() is null or not public.srk_has_admin_permission('emergency.manage') then
  raise exception 'EMERGENCY_MANAGE_PERMISSION_REQUIRED' using errcode='42501';
 end if;
 if p_appeal_id is null or p_decision not in ('under_review','accepted','rejected','closed')
   or length(btrim(coalesce(p_note,'')))<10 or length(p_note)>2000 then
  raise exception 'VALID_APPEAL_DECISION_AND_NOTE_REQUIRED' using errcode='22023';
 end if;
 select * into v from public.srk_emergency_decision_appeals where id=p_appeal_id for update;
 if not found then raise exception 'APPEAL_NOT_FOUND'; end if;
 if v.status in ('accepted','rejected','closed') then raise exception 'APPEAL_ALREADY_FINALIZED'; end if;
 update public.srk_emergency_decision_appeals
 set status=p_decision,reviewed_by=case when p_decision='under_review' then null else auth.uid() end,
     reviewed_at=case when p_decision='under_review' then null else clock_timestamp() end,
     review_note=btrim(p_note),updated_at=clock_timestamp()
 where id=p_appeal_id returning * into v;
 insert into public.srk_emergency_decision_appeal_events(appeal_id,actor_user_id,action,note)
 values(v.id,auth.uid(),case p_decision when 'under_review' then 'review_started' else p_decision end,btrim(p_note));
 insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
 select v.appealed_by,'emergency_appeal_'||p_decision,'Emergency appeal update',
  'Your emergency appeal status is now: '||p_decision||'. '||btrim(p_note),a.booking_id
 from public.srk_emergency_alerts a where a.id=v.alert_id;
 return v;
end $$;
revoke all on function public.srk_admin_review_emergency_decision_appeal(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_review_emergency_decision_appeal(uuid,text,text) to authenticated;

-- 3) In-app call metadata only; no audio/video recording fields or storage.
create table if not exists public.srk_in_app_call_history (
 id uuid primary key default gen_random_uuid(),
 booking_id uuid not null references public.service_bookings(id) on delete restrict,
 provider_call_id text not null unique,
 caller_user_id uuid not null references auth.users(id) on delete restrict,
 callee_user_id uuid not null references auth.users(id) on delete restrict,
 call_status text not null check (call_status in ('initiated','ringing','answered','missed','declined','failed','ended')),
 started_at timestamptz not null,
 answered_at timestamptz,
 ended_at timestamptz,
 duration_seconds integer generated always as (
  case when answered_at is null or ended_at is null then 0
       else greatest(0,floor(extract(epoch from (ended_at-answered_at)))::integer) end
 ) stored,
 provider_metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(provider_metadata)='object'),
 created_at timestamptz not null default clock_timestamp(),
 constraint srk_call_time_order check ((answered_at is null or answered_at>=started_at) and (ended_at is null or ended_at>=coalesce(answered_at,started_at))),
 constraint srk_call_distinct_participants check (caller_user_id<>callee_user_id)
);
create index if not exists srk_in_app_call_history_booking_time_idx
 on public.srk_in_app_call_history(booking_id,started_at desc);
create index if not exists srk_in_app_call_history_caller_idx on public.srk_in_app_call_history(caller_user_id,started_at desc);
create index if not exists srk_in_app_call_history_callee_idx on public.srk_in_app_call_history(callee_user_id,started_at desc);
alter table public.srk_in_app_call_history enable row level security;
revoke all on public.srk_in_app_call_history from anon,authenticated;
grant select,insert,update on public.srk_in_app_call_history to service_role;

create or replace function public.srk_service_record_in_app_call(
 p_booking_id uuid,p_provider_call_id text,p_caller_user_id uuid,p_callee_user_id uuid,
 p_call_status text,p_started_at timestamptz,p_answered_at timestamptz,p_ended_at timestamptz,
 p_provider_metadata jsonb default '{}'::jsonb
) returns public.srk_in_app_call_history
language plpgsql security definer set search_path=''
as $$
declare v public.srk_in_app_call_history%rowtype;
begin
 if coalesce(auth.role(),'')<>'service_role' then raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501'; end if;
 if p_booking_id is null or length(btrim(coalesce(p_provider_call_id,''))) not between 1 and 200
  or p_caller_user_id is null or p_callee_user_id is null or p_caller_user_id=p_callee_user_id
  or p_call_status not in ('initiated','ringing','answered','missed','declined','failed','ended')
  or p_started_at is null or coalesce(jsonb_typeof(p_provider_metadata),'object')<>'object' then
  raise exception 'INVALID_CALL_EVENT' using errcode='22023';
 end if;
 if not exists(select 1 from public.service_bookings b where b.id=p_booking_id and
   (b.customer_user_id in (p_caller_user_id,p_callee_user_id)
    or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles wp on wp.id=bw.worker_id
      where bw.booking_id=b.id and wp.user_id in (p_caller_user_id,p_callee_user_id)))) then
  raise exception 'CALL_PARTICIPANTS_NOT_LINKED_TO_BOOKING' using errcode='42501';
 end if;
 insert into public.srk_in_app_call_history(booking_id,provider_call_id,caller_user_id,callee_user_id,
  call_status,started_at,answered_at,ended_at,provider_metadata)
 values(p_booking_id,p_provider_call_id,p_caller_user_id,p_callee_user_id,p_call_status,p_started_at,
  p_answered_at,p_ended_at,coalesce(p_provider_metadata,'{}'::jsonb))
 on conflict(provider_call_id) do update set call_status=excluded.call_status,
  answered_at=coalesce(excluded.answered_at,public.srk_in_app_call_history.answered_at),
  ended_at=coalesce(excluded.ended_at,public.srk_in_app_call_history.ended_at),
  provider_metadata=excluded.provider_metadata
 returning * into v;
 return v;
end $$;
revoke all on function public.srk_service_record_in_app_call(uuid,text,uuid,uuid,text,timestamptz,timestamptz,timestamptz,jsonb) from public,anon,authenticated;
grant execute on function public.srk_service_record_in_app_call(uuid,text,uuid,uuid,text,timestamptz,timestamptz,timestamptz,jsonb) to service_role;

create or replace function public.srk_list_my_booking_call_history(p_booking_id uuid,p_limit integer default 100)
returns setof public.srk_in_app_call_history
language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
 if p_booking_id is null or p_limit not between 1 and 200 then raise exception 'INVALID_CALL_HISTORY_QUERY'; end if;
 if not exists(select 1 from public.service_bookings b where b.id=p_booking_id and
  (b.customer_user_id=auth.uid() or exists(select 1 from public.srk_booking_workers bw
    join public.srk_worker_profiles wp on wp.id=bw.worker_id
    where bw.booking_id=b.id and wp.user_id=auth.uid()))) then
  raise exception 'BOOKING_PARTICIPANT_REQUIRED' using errcode='42501';
 end if;
 return query select h.* from public.srk_in_app_call_history h
  where h.booking_id=p_booking_id and auth.uid() in (h.caller_user_id,h.callee_user_id)
  order by h.started_at desc limit p_limit;
end $$;
revoke all on function public.srk_list_my_booking_call_history(uuid,integer) from public,anon;
grant execute on function public.srk_list_my_booking_call_history(uuid,integer) to authenticated;

-- 4) Opaque worker identity QR tokens. Token is returned only once; DB stores SHA-256 hash.
create table if not exists public.srk_worker_identity_qr_tokens (
 id uuid primary key default gen_random_uuid(),
 worker_id uuid not null references public.srk_worker_profiles(id) on delete restrict,
 token_hash bytea not null unique,
 issued_at timestamptz not null default clock_timestamp(),
 expires_at timestamptz not null,
 revoked_at timestamptz,
 issued_by uuid not null references auth.users(id) on delete restrict,
 constraint srk_worker_qr_expiry_valid check (expires_at>issued_at)
);
create index if not exists srk_worker_identity_qr_worker_idx
 on public.srk_worker_identity_qr_tokens(worker_id,expires_at desc) where revoked_at is null;
alter table public.srk_worker_identity_qr_tokens enable row level security;
revoke all on public.srk_worker_identity_qr_tokens from anon,authenticated;
grant select,insert,update on public.srk_worker_identity_qr_tokens to service_role;

create or replace function public.srk_worker_issue_identity_qr()
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_worker public.srk_worker_profiles%rowtype; v_token text; v_exp timestamptz; v_id uuid;
begin
 if auth.uid() is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
 select * into v_worker from public.srk_worker_profiles where user_id=auth.uid() for update;
 if not found then raise exception 'WORKER_PROFILE_REQUIRED' using errcode='42501'; end if;
 if v_worker.verification_status<>'approved' or not v_worker.is_active then
  raise exception 'ONLY_ACTIVE_APPROVED_WORKERS_CAN_ISSUE_QR' using errcode='42501';
 end if;
 v_token:=encode(extensions.gen_random_bytes(32),'hex'); v_exp:=clock_timestamp()+interval '365 days';
 update public.srk_worker_identity_qr_tokens set revoked_at=clock_timestamp()
  where worker_id=v_worker.id and revoked_at is null;
 insert into public.srk_worker_identity_qr_tokens(worker_id,token_hash,expires_at,issued_by)
 values(v_worker.id,extensions.digest(v_token,'sha256'),v_exp,auth.uid()) returning id into v_id;
 return jsonb_build_object('token',v_token,'worker_code',v_worker.worker_code,'expires_at',v_exp,'qr_token_id',v_id);
end $$;
revoke all on function public.srk_worker_issue_identity_qr() from public,anon;
grant execute on function public.srk_worker_issue_identity_qr() to authenticated;

create or replace function public.srk_verify_worker_identity_qr(p_token text)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v record;
begin
 if auth.uid() is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
 if p_token is null or length(p_token)<>64 or p_token !~ '^[0-9a-f]{64}$' then
  raise exception 'INVALID_WORKER_QR_TOKEN' using errcode='22023';
 end if;
 select wp.worker_code,wp.full_name,wp.worker_type,wp.verification_status,wp.is_active
 into v from public.srk_worker_identity_qr_tokens t
 join public.srk_worker_profiles wp on wp.id=t.worker_id
 where t.token_hash=extensions.digest(p_token,'sha256') and t.revoked_at is null
  and t.expires_at>clock_timestamp();
 if not found then raise exception 'WORKER_QR_INVALID_OR_EXPIRED'; end if;
 return jsonb_build_object('worker_code',v.worker_code,'name',v.full_name,'worker_type',v.worker_type,
  'verification_status',v.verification_status,'is_active',v.is_active,
  'verified',v.verification_status='approved' and v.is_active);
end $$;
revoke all on function public.srk_verify_worker_identity_qr(text) from public,anon;
grant execute on function public.srk_verify_worker_identity_qr(text) to authenticated;

-- 5) Suspension automatically stops active work timers, releases the suspended worker,
-- and reopens the matching queue while retaining all historical session/assignment rows.
create or replace function public.srk_apply_suspended_worker_active_booking_rule()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v record; v_now timestamptz:=clock_timestamp(); v_customer uuid;
begin
 if new.verification_status<>'suspended' or old.verification_status='suspended' then return new; end if;
 for v in
  select bw.id assignment_id,bw.booking_id,bw.worker_role,bw.assignment_status
  from public.srk_booking_workers bw
  where bw.worker_id=new.id and bw.assignment_status in ('accepted','assigned','working','paused')
  order by bw.booking_id
 loop
  update public.srk_worker_work_sessions s
  set session_status='completed',
      billable_seconds=least(5184000,s.billable_seconds+
        case when s.session_status='running' and s.last_resumed_at is not null
          then greatest(0,floor(extract(epoch from(v_now-s.last_resumed_at)))::bigint) else 0 end),
      ended_at=v_now,last_resumed_at=null,
      completion_note=concat_ws(E'\n',nullif(s.completion_note,''),'Stopped immediately because worker was suspended by Admin.'),
      updated_at=v_now
  where s.booking_worker_id=v.assignment_id and s.session_status in ('running','paused');
  insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,note,source)
  select s.id,'completed',v_now,auth.uid(),'Timer stopped because worker was suspended by Admin.','admin_override'
  from public.srk_worker_work_sessions s
  where s.booking_worker_id=v.assignment_id and s.session_status='completed'
    and s.ended_at=v_now;
  update public.srk_booking_workers
   set assignment_status='released',released_at=v_now,
       admin_note=concat_ws(E'\n',nullif(admin_note,''),'Released immediately due to worker suspension: ',coalesce(new.admin_note,'No reason supplied')),
       updated_at=v_now
  where id=v.assignment_id;
  update public.srk_worker_schedule_blocks
   set block_status=case when ends_at<=v_now then 'completed' else 'cancelled' end,updated_at=v_now
  where booking_worker_id=v.assignment_id and block_status in ('reserved','confirmed','in_progress');
  update public.srk_booking_matching_queue
   set queue_status='pending',attempts=0,next_attempt_at=v_now,last_error=null,completed_at=null,updated_at=v_now
  where booking_id=v.booking_id and queue_status<>'cancelled';
  if not found then
   insert into public.srk_booking_matching_queue(booking_id,queue_status,attempts,next_attempt_at)
   select v.booking_id,'pending',0,v_now
   where exists(select 1 from public.service_bookings b where b.id=v.booking_id and b.status not in ('completed','cancelled'))
   on conflict(booking_id) do update set queue_status='pending',attempts=0,next_attempt_at=excluded.next_attempt_at,
     last_error=null,completed_at=null,updated_at=v_now;
  end if;
  select customer_user_id into v_customer from public.service_bookings where id=v.booking_id;
  if v_customer is not null then
   insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id,deep_link)
   values(v_customer,'worker_suspended_reassignment','Technician reassignment started',
    'Your assigned worker has been suspended. Work has been stopped and SRK ELECTRONIC is searching for another eligible worker.',
    v.booking_id,'/bookings/'||v.booking_id::text);
  end if;
  insert into public.srk_booking_worker_events(booking_worker_id,booking_id,worker_id,event_type,actor_user_id,reason,details)
  values(v.assignment_id,v.booking_id,new.id,'released_due_to_suspension',auth.uid(),coalesce(new.admin_note,'Worker suspended'),
    jsonb_build_object('previous_status',v.assignment_status,'timer_stopped',true,'matching_reopened',true));
 end loop;
 return new;
end $$;
drop trigger if exists srk_worker_suspension_active_booking_guard on public.srk_worker_profiles;
create trigger srk_worker_suspension_active_booking_guard
after update of verification_status on public.srk_worker_profiles
for each row when (new.verification_status='suspended' and old.verification_status is distinct from new.verification_status)
execute function public.srk_apply_suspended_worker_active_booking_rule();

-- 6) Admin-approved partial refund amount. The amount stays capped by verified paid amount.
create table if not exists public.srk_booking_refund_amount_events (
 id uuid primary key default gen_random_uuid(),
 refund_request_id uuid not null references public.srk_booking_refund_requests(id) on delete restrict,
 old_amount numeric(12,2) not null,
 new_amount numeric(12,2) not null check (new_amount>0),
 changed_by uuid not null references auth.users(id) on delete restrict,
 reason text not null check (length(btrim(reason)) between 10 and 1000),
 changed_at timestamptz not null default clock_timestamp()
);
create index if not exists srk_booking_refund_amount_events_request_idx
 on public.srk_booking_refund_amount_events(refund_request_id,changed_at desc);
alter table public.srk_booking_refund_amount_events enable row level security;
revoke all on public.srk_booking_refund_amount_events from anon,authenticated;
grant select,insert on public.srk_booking_refund_amount_events to service_role;

create or replace function public.srk_admin_set_booking_refund_amount(
 p_request_id uuid,p_amount numeric,p_reason text
) returns public.srk_booking_refund_requests
language plpgsql security definer set search_path=''
as $$
declare v public.srk_booking_refund_requests%rowtype; v_paid numeric(12,2);
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501'; end if;
 if p_request_id is null or p_amount is null or p_amount<=0 or p_amount>10000000
  or length(btrim(coalesce(p_reason,''))) not between 10 and 1000 then
  raise exception 'VALID_REFUND_AMOUNT_AND_REASON_REQUIRED' using errcode='22023';
 end if;
 select r.* into v from public.srk_booking_refund_requests r where r.id=p_request_id for update;
 if not found then raise exception 'REFUND_REQUEST_NOT_FOUND'; end if;
 if v.status not in ('requested','in_review') then raise exception 'REFUND_AMOUNT_LOCKED_AFTER_DECISION'; end if;
 select round(b.amount_paid,2) into v_paid from public.service_bookings b
 where b.id=v.booking_id and b.payment_status='paid' and b.payment_verified_at is not null for update;
 if not found or p_amount>v_paid then raise exception 'REFUND_AMOUNT_EXCEEDS_VERIFIED_PAID_AMOUNT'; end if;
 insert into public.srk_booking_refund_amount_events(refund_request_id,old_amount,new_amount,changed_by,reason)
 values(v.id,v.amount,round(p_amount,2),auth.uid(),btrim(p_reason));
 update public.srk_booking_refund_requests set amount=round(p_amount,2),updated_at=clock_timestamp()
 where id=v.id returning * into v;
 return v;
end $$;
revoke all on function public.srk_admin_set_booking_refund_amount(uuid,numeric,text) from public,anon;
grant execute on function public.srk_admin_set_booking_refund_amount(uuid,numeric,text) to authenticated;

-- Safely patch the approved-refund preparation RPC so a reviewed partial amount is allowed.
do $$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_admin_prepare_booking_refund(uuid)'::regprocedure);
 v_old:='v_amount:=round(v_booking.amount_paid,2);' || E'\n if round(v_request.amount,2)<>v_amount then raise exception ''REFUND_AMOUNT_MUST_EQUAL_FULL_PAID_BOOKING_AMOUNT'' using errcode=''55000''; end if;';
 v_new:='v_amount:=round(v_request.amount,2);' || E'\n if v_amount<=0 or v_amount>round(v_booking.amount_paid,2) then raise exception ''REFUND_AMOUNT_MUST_NOT_EXCEED_VERIFIED_PAID_AMOUNT'' using errcode=''55000''; end if;';
 if position(v_old in v_def)=0 then raise exception 'Could not safely patch Razorpay refund amount guard'; end if;
 execute replace(v_def,v_old,v_new);
end $$;

-- Manual refund amount also follows the Admin-reviewed amount, not an automatic full refund.
do $$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_admin_record_manual_refund(uuid,text,text)'::regprocedure);
 v_old:='if round(coalesce(v_booking.amount_paid,0),2)<>v_payment.amount then raise exception ''Recorded payment amount does not match booking amount''; end if;';
 v_new:='if round(coalesce(v_booking.amount_paid,0),2)<>v_payment.amount then raise exception ''Recorded payment amount does not match booking amount''; end if;' || E'\n if v_refund_request.amount<=0 or v_refund_request.amount>v_payment.amount then raise exception ''Approved refund amount exceeds verified payment''; end if;';
 if position(v_old in v_def)=0 then raise exception 'Could not safely patch manual refund validation'; end if;
 v_def:=replace(v_def,v_old,v_new);
 v_old:='values(p_booking_id,v_payment.id,v_payment.amount,v_reference,nullif(trim(coalesce(p_note,'''')),''''),auth.uid());';
 v_new:='values(p_booking_id,v_payment.id,v_refund_request.amount,v_reference,nullif(trim(coalesce(p_note,'''')),''''),auth.uid());';
 if position(v_old in v_def)=0 then raise exception 'Could not safely patch manual refund amount'; end if;
 execute replace(v_def,v_old,v_new);
end $$;
