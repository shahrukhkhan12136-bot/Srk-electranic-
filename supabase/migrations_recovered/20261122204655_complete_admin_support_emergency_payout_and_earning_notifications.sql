
create or replace function public.srk_notify_admin_permission_team()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_permission text; v_title text; v_body text; v_booking uuid;
begin
  v_permission:=tg_argv[0];
  v_title:=tg_argv[1];
  v_body:=tg_argv[2];
  v_booking:=nullif(to_jsonb(new)->>'booking_id','')::uuid;

  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  select user_id,'admin_action_required',v_title,v_body,v_booking
  from public.srk_admin_users
  union
  select sm.user_id,'admin_action_required',v_title,v_body,v_booking
  from public.srk_admin_staff_members sm
  join public.srk_admin_roles r on r.id=sm.role_id and r.is_active
  join public.srk_admin_role_permissions rp on rp.role_id=r.id and rp.permission_code=v_permission
  where sm.is_active;
  return new;
end $$;

drop trigger if exists srk_support_case_admin_notification_trigger on public.srk_support_cases;
create trigger srk_support_case_admin_notification_trigger after insert on public.srk_support_cases
for each row execute function public.srk_notify_admin_permission_team('support.manage','New support case','A new customer/worker support case needs review.');

drop trigger if exists srk_payment_dispute_admin_notification_trigger on public.srk_booking_payment_disputes;
create trigger srk_payment_dispute_admin_notification_trigger after insert on public.srk_booking_payment_disputes
for each row execute function public.srk_notify_admin_permission_team('payments.read','New payment dispute','A payment dispute needs Admin review.');

create or replace function public.srk_on_emergency_notification()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public
as $$
begin
  perform public.srk_notify_admin_permission_team('support.manage','Emergency Alert','An emergency alert requires immediate Admin attention.');
  return new;
end $$;

create or replace function public.srk_on_worker_payout_notification()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_user uuid;
begin
  if tg_op='INSERT' or new.status is distinct from old.status then
    select user_id into v_user from public.srk_worker_profiles where id=new.worker_id;
    insert into public.srk_app_notifications(user_id,notification_type,title,body)
    values(v_user,'payout_status','Payout status updated',
      'Your payout '||coalesce(new.payout_code,'')||' is now: '||new.status||
      case when new.payment_reference is not null then '. Reference: '||new.payment_reference else '' end);
  end if;
  return new;
end $$;
drop trigger if exists srk_worker_payout_notification_trigger on public.srk_worker_payout_requests;
create trigger srk_worker_payout_notification_trigger after insert or update of status on public.srk_worker_payout_requests
for each row execute function public.srk_on_worker_payout_notification();

create or replace function public.srk_on_worker_earning_notification()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_user uuid;
begin
  if new.settlement_status in ('available','cash_commission_due','cash_split_pending') then
    select user_id into v_user from public.srk_worker_profiles where id=new.worker_id;
    insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
    values(v_user,'earning_status','Booking earning updated',
      'Your earning settlement status is: '||new.settlement_status,new.booking_id);
  end if;
  return new;
end $$;
drop trigger if exists srk_worker_earning_notification_trigger on public.srk_worker_earnings;
create trigger srk_worker_earning_notification_trigger after insert or update of settlement_status on public.srk_worker_earnings
for each row execute function public.srk_on_worker_earning_notification();

revoke all on function public.srk_notify_admin_permission_team() from public,anon,authenticated;
revoke all on function public.srk_on_worker_payout_notification() from public,anon,authenticated;
revoke all on function public.srk_on_worker_earning_notification() from public,anon,authenticated;
