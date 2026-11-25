
-- Index foreign keys for the newly introduced workflow tables.
create index if not exists srk_worker_cancel_reviews_booking_idx on public.srk_worker_cancellation_reviews(booking_id);
create index if not exists srk_worker_cancel_reviews_worker_idx on public.srk_worker_cancellation_reviews(worker_id);
create index if not exists srk_worker_cancel_reviews_worker_user_idx on public.srk_worker_cancellation_reviews(worker_user_id);
create index if not exists srk_worker_cancel_reviews_reviewed_by_idx on public.srk_worker_cancellation_reviews(reviewed_by) where reviewed_by is not null;
create index if not exists srk_emergency_appeals_alert_idx on public.srk_emergency_decision_appeals(alert_id);
create index if not exists srk_emergency_appeals_user_idx on public.srk_emergency_decision_appeals(appealed_by);
create index if not exists srk_emergency_appeals_reviewer_idx on public.srk_emergency_decision_appeals(reviewed_by) where reviewed_by is not null;
create index if not exists srk_emergency_appeal_events_actor_idx on public.srk_emergency_decision_appeal_events(actor_user_id);
create index if not exists srk_worker_qr_issued_by_idx on public.srk_worker_identity_qr_tokens(issued_by);
create index if not exists srk_refund_amount_events_actor_idx on public.srk_booking_refund_amount_events(changed_by);

-- Call history deliberately stores no raw provider payload, media URL, or recording metadata.
alter table public.srk_in_app_call_history drop column if exists provider_metadata;
drop function if exists public.srk_service_record_in_app_call(uuid,text,uuid,uuid,text,timestamptz,timestamptz,timestamptz,jsonb);
create or replace function public.srk_service_record_in_app_call(
 p_booking_id uuid,p_provider_call_id text,p_caller_user_id uuid,p_callee_user_id uuid,
 p_call_status text,p_started_at timestamptz,p_answered_at timestamptz,p_ended_at timestamptz
) returns public.srk_in_app_call_history
language plpgsql security definer set search_path=''
as $$
declare v public.srk_in_app_call_history%rowtype;
begin
 if coalesce(auth.role(),'')<>'service_role' then raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501'; end if;
 if p_booking_id is null or length(btrim(coalesce(p_provider_call_id,''))) not between 1 and 200
  or p_caller_user_id is null or p_callee_user_id is null or p_caller_user_id=p_callee_user_id
  or p_call_status not in ('initiated','ringing','answered','missed','declined','failed','ended')
  or p_started_at is null or (p_answered_at is not null and p_answered_at<p_started_at)
  or (p_ended_at is not null and p_ended_at<coalesce(p_answered_at,p_started_at)) then
  raise exception 'INVALID_CALL_EVENT' using errcode='22023';
 end if;
 if not exists(select 1 from public.service_bookings b where b.id=p_booking_id and
   (b.customer_user_id in (p_caller_user_id,p_callee_user_id)
    or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles wp on wp.id=bw.worker_id
      where bw.booking_id=b.id and wp.user_id in (p_caller_user_id,p_callee_user_id)))) then
  raise exception 'CALL_PARTICIPANTS_NOT_LINKED_TO_BOOKING' using errcode='42501';
 end if;
 insert into public.srk_in_app_call_history(booking_id,provider_call_id,caller_user_id,callee_user_id,
  call_status,started_at,answered_at,ended_at)
 values(p_booking_id,p_provider_call_id,p_caller_user_id,p_callee_user_id,p_call_status,p_started_at,
  p_answered_at,p_ended_at)
 on conflict(provider_call_id) do update set call_status=excluded.call_status,
  answered_at=coalesce(excluded.answered_at,public.srk_in_app_call_history.answered_at),
  ended_at=coalesce(excluded.ended_at,public.srk_in_app_call_history.ended_at)
 returning * into v;
 return v;
end $$;
revoke all on function public.srk_service_record_in_app_call(uuid,text,uuid,uuid,text,timestamptz,timestamptz,timestamptz) from public,anon,authenticated;
grant execute on function public.srk_service_record_in_app_call(uuid,text,uuid,uuid,text,timestamptz,timestamptz,timestamptz) to service_role;

create or replace function public.srk_admin_list_in_app_call_history(p_booking_id uuid default null,p_limit integer default 200)
returns setof public.srk_in_app_call_history
language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'MAIN_ADMIN_REQUIRED' using errcode='42501'; end if;
 if p_limit not between 1 and 500 then raise exception 'INVALID_CALL_HISTORY_LIMIT'; end if;
 return query select * from public.srk_in_app_call_history
  where p_booking_id is null or booking_id=p_booking_id
  order by started_at desc limit p_limit;
end $$;
revoke all on function public.srk_admin_list_in_app_call_history(uuid,integer) from public,anon;
grant execute on function public.srk_admin_list_in_app_call_history(uuid,integer) to authenticated;
