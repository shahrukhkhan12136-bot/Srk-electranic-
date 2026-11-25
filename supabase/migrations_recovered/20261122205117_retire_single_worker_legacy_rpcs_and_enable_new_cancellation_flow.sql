
create table if not exists public.srk_booking_cancellation_events (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  actor_user_id uuid not null,
  actor_role text not null,
  reason text not null,
  cancelled_at timestamptz not null default now(),
  constraint srk_booking_cancellation_role_valid check(actor_role in ('customer','technician','helper','admin'))
);
alter table public.srk_booking_cancellation_events enable row level security;
create policy srk_booking_cancellation_participant_read on public.srk_booking_cancellation_events
for select to authenticated using(
  public.srk_has_admin_permission('bookings.manage')
  or exists(select 1 from public.service_bookings b where b.id=booking_id and b.customer_user_id=(select auth.uid()))
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.booking_id=srk_booking_cancellation_events.booking_id and w.user_id=(select auth.uid()))
);

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
    raise exception 'Booking can no longer be cancelled directly; contact Support so completed work and timer evidence are preserved';
  end if;
  if exists(select 1 from public.srk_worker_work_sessions s join public.srk_booking_workers bw on bw.id=s.booking_worker_id
    where bw.booking_id=p_booking_id and s.billable_seconds>0) then
    raise exception 'Billable work already exists; contact Support for review';
  end if;
  update public.service_bookings set status='cancelled',admin_change_reason='Customer cancellation: '||p_reason
  where id=p_booking_id returning * into v;
  update public.srk_booking_matching_queue set queue_status='cancelled',updated_at=clock_timestamp()
  where booking_id=p_booking_id;
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

revoke all on function public.srk_customer_cancel_booking_v2(uuid,text) from public,anon;
grant execute on function public.srk_customer_cancel_booking_v2(uuid,text) to authenticated;

revoke all on function public.srk_admin_offer_booking(uuid) from public,anon,authenticated;
revoke all on function public.srk_respond_to_offer(uuid,text) from public,anon,authenticated;
revoke all on function public.srk_update_booking_work_status(uuid,text) from public,anon,authenticated;
revoke all on function public.srk_electrician_request_work_start(uuid) from public,anon,authenticated;
revoke all on function public.srk_electrician_request_work_completion(uuid) from public,anon,authenticated;
revoke all on function public.srk_electrician_confirm_cash_payment(uuid) from public,anon,authenticated;
revoke all on function public.srk_submit_booking_quote(uuid,numeric,numeric,text) from public,anon,authenticated;
revoke all on function public.srk_customer_respond_work_start(uuid,text) from public,anon,authenticated;
revoke all on function public.srk_customer_respond_work_completion(uuid,text,text) from public,anon,authenticated;
revoke all on function public.srk_customer_respond_booking_quote(uuid,text) from public,anon,authenticated;
revoke all on function public.srk_admin_update_booking(uuid,text,text,text,text,text) from public,anon,authenticated;
revoke all on function public.srk_admin_review_application(uuid,text) from public,anon,authenticated;
revoke all on function public.srk_admin_set_electrician_active(uuid,boolean) from public,anon,authenticated;
revoke all on function public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text) from public,anon,authenticated;
revoke all on function public.srk_customer_cancel_my_booking(uuid) from public,anon,authenticated;
