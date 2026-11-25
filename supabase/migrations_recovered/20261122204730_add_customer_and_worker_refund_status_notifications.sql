
create or replace function public.srk_on_refund_status_notification()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_customer uuid;
begin
  if tg_op='INSERT' or new.status is distinct from old.status then
    select customer_user_id into v_customer from public.service_bookings where id=new.booking_id;
    if v_customer is not null then
      insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
      values(v_customer,'refund_status','Refund status updated','Your refund request is now: '||new.status,new.booking_id);
    end if;
    insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
    select w.user_id,'refund_review','Booking refund review','A refund request for your booking is now: '||new.status,new.booking_id
    from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.booking_id=new.booking_id;
  end if;
  return new;
end $$;
drop trigger if exists srk_refund_status_notification_trigger on public.srk_booking_refund_requests;
create trigger srk_refund_status_notification_trigger
after insert or update of status on public.srk_booking_refund_requests
for each row execute function public.srk_on_refund_status_notification();
revoke all on function public.srk_on_refund_status_notification() from public,anon,authenticated;
