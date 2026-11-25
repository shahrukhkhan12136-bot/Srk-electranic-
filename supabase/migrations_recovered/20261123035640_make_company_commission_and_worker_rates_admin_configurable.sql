
insert into public.srk_system_settings(setting_key,setting_value,admin_note)
values('company_commission_rate','15'::jsonb,'Default company commission percentage; applies to bookings created after each change.')
on conflict(setting_key) do nothing;

create or replace function public.guard_new_booking()
returns trigger
language plpgsql
set search_path to 'pg_catalog','public','pg_temp'
as $function$
declare v_commission numeric(5,2);
begin
  select coalesce((setting_value #>> '{}')::numeric,15.00)
    into v_commission
  from public.srk_system_settings
  where setting_key='company_commission_rate';
  v_commission:=coalesce(v_commission,15.00);
  if v_commission<0 or v_commission>100 then
    raise exception 'Configured company commission rate is invalid';
  end if;
  new.status:='new';
  new.payment_status:='unpaid';
  new.assigned_electrician_id:=null;
  new.commission_rate:=v_commission;
  new.commission_amount:=null;
  new.created_at:=now();
  return new;
end;
$function$;

create or replace function public.srk_admin_set_company_commission_rate(p_rate numeric,p_reason text)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare v_old numeric(5,2); v_new numeric(5,2);
begin
  if auth.uid() is null or not public.srk_has_admin_permission('catalog.manage') then
    raise exception 'Admin permission required to change company commission' using errcode='42501';
  end if;
  if p_rate is null or p_rate<0 or p_rate>100 or p_rate<>round(p_rate,2) then
    raise exception 'Commission rate must be between 0 and 100 with up to 2 decimal places';
  end if;
  if length(btrim(coalesce(p_reason,'')))<10 then
    raise exception 'Reason must be at least 10 characters';
  end if;
  select coalesce((setting_value #>> '{}')::numeric,15.00)
    into v_old from public.srk_system_settings
    where setting_key='company_commission_rate' for update;
  v_old:=coalesce(v_old,15.00);
  v_new:=p_rate::numeric(5,2);
  insert into public.srk_system_settings(setting_key,setting_value,updated_by,updated_at,admin_note)
  values('company_commission_rate',to_jsonb(v_new),auth.uid(),clock_timestamp(),btrim(p_reason))
  on conflict(setting_key) do update set setting_value=excluded.setting_value,
    updated_by=excluded.updated_by,updated_at=excluded.updated_at,admin_note=excluded.admin_note;
  insert into public.srk_admin_audit_events(entity_type,entity_id,action,actor_user_id,actor_role,changed_fields,before_data,after_data)
  values('system_setting',null,'company_commission_rate_changed',auth.uid(),'admin',
    array['company_commission_rate','reason'],
    jsonb_build_object('company_commission_rate',v_old),
    jsonb_build_object('company_commission_rate',v_new,'reason',btrim(p_reason)));
  return jsonb_build_object('success',true,'previous_rate',v_old,'current_rate',v_new,
    'effective_for','new bookings only');
end;
$function$;

revoke all on function public.srk_admin_set_company_commission_rate(numeric,text) from public,anon;
grant execute on function public.srk_admin_set_company_commission_rate(numeric,text) to authenticated;

create or replace function public.srk_admin_settle_cash_worker_share(p_earning_id uuid,p_actual_cash_share numeric,p_reason text)
returns public.srk_worker_earnings
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
  v public.srk_worker_earnings%rowtype;
  v_booking_paid text;
  v_service_total numeric(12,2);
  v_already_allocated numeric(12,2);
  v_commission numeric(12,2);
begin
  if not public.srk_has_admin_permission('payouts.manage') then
    raise exception 'Payout management permission required';
  end if;
  if p_actual_cash_share is null or p_actual_cash_share<0 or length(coalesce(p_reason,''))<10 then
    raise exception 'Valid cash share and reason are required';
  end if;
  select * into v from public.srk_worker_earnings where id=p_earning_id for update;
  if not found or v.payment_method<>'cash' or v.settlement_status<>'cash_split_pending' then
    raise exception 'Cash earning is not awaiting split settlement';
  end if;
  select b.payment_status,f.service_amount into v_booking_paid,v_service_total
  from public.service_bookings b join public.srk_booking_final_bills f on f.id=v.bill_id
  where b.id=v.booking_id;
  if v_booking_paid<>'paid' then raise exception 'Cash payment must be confirmed before settlement'; end if;
  select coalesce(sum(gross_service_earning),0) into v_already_allocated
  from public.srk_worker_earnings
  where booking_id=v.booking_id and settlement_status='cash_commission_due' and id<>v.id;
  if v_already_allocated+p_actual_cash_share>v_service_total then
    raise exception 'Cash shares exceed total labour amount';
  end if;
  if v.company_commission_rate is null or v.company_commission_rate<0 or v.company_commission_rate>100 then
    raise exception 'Earning commission snapshot is invalid';
  end if;
  v_commission:=round(p_actual_cash_share*v.company_commission_rate/100,2);
  update public.srk_worker_earnings set gross_service_earning=p_actual_cash_share,
    company_commission= v_commission,net_earning=p_actual_cash_share-v_commission,
    settlement_status='cash_commission_due',payout_status='pending',admin_note=p_reason,updated_at=clock_timestamp()
  where id=p_earning_id returning * into v;
  insert into public.srk_worker_wallet_ledger(worker_id,booking_id,earning_id,entry_type,amount,balance_effect,description,idempotency_key)
  values(v.worker_id,v.booking_id,v.id,'cash_commission_due',v_commission,-v_commission,
    'Admin-settled cash share commission: '||p_reason,'cash-share-commission:'||v.id::text)
  on conflict(idempotency_key) do nothing;
  return v;
end;
$function$;

revoke all on function public.srk_admin_publish_service_rate(uuid,uuid,uuid,numeric,numeric) from public,anon,authenticated;
