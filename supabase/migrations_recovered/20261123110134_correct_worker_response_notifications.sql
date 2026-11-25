
create or replace function public.srk_on_booking_assignment_notification()
returns trigger
language plpgsql
security definer
set search_path to 'pg_catalog','public'
as $function$
declare
 v_user uuid;
 v_customer uuid;
 v_order text;
begin
 select user_id into v_user
 from public.srk_worker_profiles where id=new.worker_id;

 select customer_user_id,order_number
 into v_customer,v_order
 from public.service_bookings where id=new.booking_id;

 if tg_op='INSERT' then
  if v_user is not null and new.assignment_status='offered' then
   insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
   values(v_user,'booking_offer','New booking offer',
    'You have received a new service booking offer: '||coalesce(v_order,''),new.booking_id);
  end if;
 elsif new.assignment_status is distinct from old.assignment_status then
  if new.assignment_status='accepted' and v_customer is not null then
   insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
   values(v_customer,'worker_response','Worker accepted',
    'A worker accepted your booking.',new.booking_id);
  elsif new.assignment_status='rejected'
        and coalesce(new.admin_note,'') not ilike '%offer timed out%'
        and v_customer is not null then
   insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
   values(v_customer,'worker_response','Worker declined',
    'A worker declined the booking offer.',new.booking_id);
  end if;
 end if;
 return new;
end
$function$;

revoke all on function public.srk_on_booking_assignment_notification() from public,anon,authenticated;
