
create or replace function public.srk_on_booking_chat_membership()
returns trigger
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_room uuid; v_customer uuid;
begin
  if tg_op='INSERT' or new.assignment_status in ('accepted','assigned','working','paused') then
    select customer_user_id into v_customer from public.service_bookings where id=new.booking_id;
    insert into public.srk_booking_chat_rooms(booking_id,is_active) values(new.booking_id,true)
      on conflict(booking_id) do update set is_active=true returning id into v_room;
    if v_customer is not null then
      insert into public.srk_booking_chat_members(room_id,user_id,member_role)
      values(v_room,v_customer,'customer') on conflict(room_id,user_id) do update set left_at=null;
    end if;
    insert into public.srk_booking_chat_members(room_id,user_id,member_role)
    select v_room,w.user_id,w.worker_type from public.srk_booking_workers bw
    join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.booking_id=new.booking_id and bw.assignment_status in ('accepted','assigned','working','paused')
    on conflict(room_id,user_id) do update set left_at=null;
  elsif new.assignment_status in ('rejected','cancelled','released') then
    update public.srk_booking_chat_members m set left_at=clock_timestamp()
    from public.srk_booking_chat_rooms r,public.srk_worker_profiles w
    where r.id=m.room_id and r.booking_id=new.booking_id and m.user_id=w.user_id and w.id=new.worker_id;
  end if;
  return new;
end $$;

drop trigger if exists srk_booking_chat_membership_trigger on public.srk_booking_workers;
create trigger srk_booking_chat_membership_trigger after insert or update of assignment_status
on public.srk_booking_workers for each row execute function public.srk_on_booking_chat_membership();

create or replace function public.srk_on_completion_request_notification()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public
as $$
begin
  if new.completion_approval_status='pending' and old.completion_approval_status is distinct from 'pending'
     and new.customer_user_id is not null then
    insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
    values(new.customer_user_id,'completion_review','Work completed - review required',
      'The assigned team has marked the work complete. Review the final bill and confirm or report a problem.',new.id);
  end if;
  return new;
end $$;
drop trigger if exists srk_completion_request_notification_trigger on public.service_bookings;
create trigger srk_completion_request_notification_trigger
after update of completion_approval_status on public.service_bookings
for each row execute function public.srk_on_completion_request_notification();

-- Do not expose trigger-only functions through PostgREST.
revoke all on function public.srk_assign_worker_code() from public,anon,authenticated;
revoke all on function public.srk_close_booking_location_share() from public,anon,authenticated;
revoke all on function public.srk_on_booking_assignment_notification() from public,anon,authenticated;
revoke all on function public.srk_on_booking_payment_completed() from public,anon,authenticated;
revoke all on function public.srk_on_booking_status_notification() from public,anon,authenticated;
revoke all on function public.srk_on_emergency_notification() from public,anon,authenticated;
revoke all on function public.srk_post_worker_earning_to_ledger() from public,anon,authenticated;
revoke all on function public.srk_log_admin_entity_change() from public,anon,authenticated;
revoke all on function public.srk_on_booking_chat_membership() from public,anon,authenticated;
revoke all on function public.srk_on_completion_request_notification() from public,anon,authenticated;
revoke all on function public.srk_enforce_technician_payment_cycle() from public,anon,authenticated;
drop function if exists public.srk_enforce_technician_payment_cycle();

revoke all on function public.srk_admin_set_staff_role(uuid,text,boolean) from public,anon;
grant execute on function public.srk_admin_set_staff_role(uuid,text,boolean) to authenticated;
revoke all on function public.srk_has_admin_permission(text) from public,anon;
grant execute on function public.srk_has_admin_permission(text) to authenticated;
revoke all on function public.srk_admin_review_worker_profile(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_review_worker_profile(uuid,text,text) to authenticated;
revoke all on function public.srk_admin_review_worker_application(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_review_worker_application(uuid,text,text) to authenticated;
revoke all on function public.srk_admin_review_worker_skill(uuid,text,uuid,text) from public,anon;
grant execute on function public.srk_admin_review_worker_skill(uuid,text,uuid,text) to authenticated;
revoke all on function public.srk_admin_review_worker_payout(uuid,boolean,numeric,text) from public,anon;
grant execute on function public.srk_admin_review_worker_payout(uuid,boolean,numeric,text) to authenticated;
revoke all on function public.srk_admin_mark_worker_payout_paid(uuid,text,text,text) from public,anon;
grant execute on function public.srk_admin_mark_worker_payout_paid(uuid,text,text,text) to authenticated;
revoke all on function public.srk_admin_moderate_booking_rating(uuid,text) from public,anon;
grant execute on function public.srk_admin_moderate_booking_rating(uuid,text) to authenticated;
revoke all on function public.srk_admin_update_support_case(uuid,text,text,uuid,text,text) from public,anon;
grant execute on function public.srk_admin_update_support_case(uuid,text,text,uuid,text,text) to authenticated;
revoke all on function public.srk_admin_resolve_emergency_alert(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_resolve_emergency_alert(uuid,text,text) to authenticated;
revoke all on function public.srk_admin_publish_service_rate(uuid,uuid,uuid,numeric,numeric) from public,anon;
grant execute on function public.srk_admin_publish_service_rate(uuid,uuid,uuid,numeric,numeric) to authenticated;
revoke all on function public.srk_admin_finalize_booking_bill(uuid) from public,anon;
grant execute on function public.srk_admin_finalize_booking_bill(uuid) to authenticated;
revoke all on function public.srk_admin_offer_worker_to_booking(uuid,uuid,text) from public,anon;
grant execute on function public.srk_admin_offer_worker_to_booking(uuid,uuid,text) to authenticated;
