
create or replace function public.srk_on_worker_earning_notification()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public
as $function$
declare v_user uuid;
begin
  if new.settlement_status in ('available','cash_commission_due','cash_split_pending')
     and (tg_op='INSERT' or new.settlement_status is distinct from old.settlement_status) then
    select user_id into v_user
    from public.srk_worker_profiles
    where id=new.worker_id;

    if v_user is not null then
      insert into public.srk_app_notifications(
        user_id,notification_type,title,body,related_booking_id
      ) values (
        v_user,'earning_status','Booking earning updated',
        'Your earning settlement status is: '||new.settlement_status,
        new.booking_id
      );
    end if;
  end if;
  return new;
end
$function$;

create or replace function public.srk_on_worker_payout_notification()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public
as $function$
declare v_user uuid;
begin
  if tg_op='INSERT' or new.status is distinct from old.status then
    select user_id into v_user
    from public.srk_worker_profiles
    where id=new.worker_id;

    if v_user is not null then
      insert into public.srk_app_notifications(
        user_id,notification_type,title,body
      ) values (
        v_user,'payout_status','Payout status updated',
        'Your payout '||coalesce(new.payout_code,'')||' is now: '||new.status||
        case when new.payment_reference is not null
          then '. Reference: '||new.payment_reference else '' end
      );
    end if;
  end if;
  return new;
end
$function$;

revoke all on function public.srk_on_worker_earning_notification() from public,anon,authenticated;
revoke all on function public.srk_on_worker_payout_notification() from public,anon,authenticated;
