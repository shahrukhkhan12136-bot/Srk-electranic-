
create or replace function public.srk_notify_support_case_participants()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public
as $function$
begin
  if new.status is distinct from old.status then
    insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
    values(new.raised_by,'support_status','Support case updated',
      'Your support case '||coalesce(new.case_number,'')||' status is now: '||new.status,
      new.booking_id);
  end if;

  if new.assigned_staff is distinct from old.assigned_staff and new.assigned_staff is not null then
    insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
    values(new.assigned_staff,'support_assignment','Support case assigned',
      'A support case has been assigned to you: '||coalesce(new.case_number,''),
      new.booking_id);
  end if;
  return new;
end
$function$;

create or replace function public.srk_notify_emergency_participants()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public
as $function$
begin
  if new.status is distinct from old.status then
    insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
    values(new.raised_by,'emergency_status','Emergency alert updated',
      'Your emergency alert status is now: '||new.status,new.booking_id);
  end if;

  if new.assigned_staff is distinct from old.assigned_staff and new.assigned_staff is not null then
    insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
    values(new.assigned_staff,'emergency_assignment','Emergency alert assigned',
      'An emergency alert has been assigned to you and requires attention.',new.booking_id);
  end if;
  return new;
end
$function$;

create or replace function public.srk_notify_payment_dispute_participants()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public
as $function$
begin
  if new.status is distinct from old.status then
    insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
    select distinct recipient.user_id,'payment_dispute_status','Payment dispute updated',
      'A payment dispute for your booking is now: '||new.status,new.booking_id
    from (
      select new.raised_by as user_id
      union
      select b.customer_user_id from public.service_bookings b where b.id=new.booking_id
      union
      select w.user_id
      from public.srk_booking_workers bw
      join public.srk_worker_profiles w on w.id=bw.worker_id
      where bw.booking_id=new.booking_id
    ) recipient
    where recipient.user_id is not null;
  end if;
  return new;
end
$function$;

drop trigger if exists srk_support_case_participant_status_notification on public.srk_support_cases;
create trigger srk_support_case_participant_status_notification
after update of status,assigned_staff on public.srk_support_cases
for each row execute function public.srk_notify_support_case_participants();

drop trigger if exists srk_emergency_participant_status_notification on public.srk_emergency_alerts;
create trigger srk_emergency_participant_status_notification
after update of status,assigned_staff on public.srk_emergency_alerts
for each row execute function public.srk_notify_emergency_participants();

drop trigger if exists srk_payment_dispute_participant_status_notification on public.srk_booking_payment_disputes;
create trigger srk_payment_dispute_participant_status_notification
after update of status on public.srk_booking_payment_disputes
for each row execute function public.srk_notify_payment_dispute_participants();

revoke all on function public.srk_notify_support_case_participants() from public,anon,authenticated;
revoke all on function public.srk_notify_emergency_participants() from public,anon,authenticated;
revoke all on function public.srk_notify_payment_dispute_participants() from public,anon,authenticated;
