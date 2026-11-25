
create or replace function public.srk_notify_customer_schedule_proposal()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public
as $function$
declare
  v_customer uuid;
  v_order text;
begin
  if new.status<>'proposed' then return new; end if;

  select b.customer_user_id,b.order_number
    into v_customer,v_order
  from public.srk_booking_workers bw
  join public.service_bookings b on b.id=bw.booking_id
  where bw.id=new.booking_worker_id;

  if v_customer is not null then
    insert into public.srk_app_notifications(
      user_id,notification_type,title,body,related_booking_id
    ) values (
      v_customer,'schedule_proposed','New work schedule proposed',
      'Your service team proposed a work schedule for booking '||
        coalesce(v_order,'')||'. Please review and respond.',
      (select bw.booking_id from public.srk_booking_workers bw where bw.id=new.booking_worker_id)
    );
  end if;
  return new;
end
$function$;

create or replace function public.srk_notify_customer_final_bill_issued()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public
as $function$
declare
  v_customer uuid;
begin
  if new.status<>'issued' then return new; end if;
  if tg_op='UPDATE' and old.status is not distinct from new.status then return new; end if;

  select customer_user_id into v_customer
  from public.service_bookings where id=new.booking_id;

  if v_customer is not null then
    insert into public.srk_app_notifications(
      user_id,notification_type,title,body,related_booking_id
    ) values (
      v_customer,'final_bill_issued','Your final bill is ready',
      'Final bill '||coalesce(new.bill_number,'')||
      ' is ready. Total amount: ₹'||to_char(new.total_amount,'FM999999999990.00')||
      '. Please review it in your booking.',
      new.booking_id
    );
  end if;
  return new;
end
$function$;

drop trigger if exists srk_schedule_proposal_customer_notification on public.srk_booking_schedule_proposals;
create trigger srk_schedule_proposal_customer_notification
after insert on public.srk_booking_schedule_proposals
for each row execute function public.srk_notify_customer_schedule_proposal();

drop trigger if exists srk_final_bill_customer_notification on public.srk_booking_final_bills;
create trigger srk_final_bill_customer_notification
after insert or update of status on public.srk_booking_final_bills
for each row execute function public.srk_notify_customer_final_bill_issued();

revoke all on function public.srk_notify_customer_schedule_proposal() from public,anon,authenticated;
revoke all on function public.srk_notify_customer_final_bill_issued() from public,anon,authenticated;
