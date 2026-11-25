
alter table public.srk_worker_earnings
  add column if not exists normal_billable_seconds bigint not null default 0,
  add column if not exists overtime_billable_seconds bigint not null default 0,
  add column if not exists overtime_multiplier numeric(5,2) not null default 1.50;

create or replace function public.srk_worker_session_time_breakdown(
  p_booking_worker_id uuid,p_hourly_rate numeric
)
returns jsonb
language sql
stable
set search_path to 'pg_catalog','public'
as $function$
  with cfg as (
    select
      coalesce((select (setting_value #>> '{}')::numeric from public.srk_system_settings where setting_key='normal_daily_billable_hours'),8) as normal_hours,
      coalesce((select (setting_value #>> '{}')::numeric from public.srk_system_settings where setting_key='overtime_multiplier'),1.5) as overtime_multiplier
  ), daily as (
    select s.work_date,sum(s.billable_seconds)::bigint seconds
    from public.srk_worker_work_sessions s
    where s.booking_worker_id=p_booking_worker_id
    group by s.work_date
  ), totals as (
    select
      coalesce(sum(least(d.seconds,(cfg.normal_hours*3600)::bigint)),0)::bigint normal_seconds,
      coalesce(sum(greatest(d.seconds-(cfg.normal_hours*3600)::bigint,0)),0)::bigint overtime_seconds,
      cfg.overtime_multiplier
    from daily d cross join cfg
    group by cfg.overtime_multiplier
  )
  select jsonb_build_object(
    'normal_seconds',normal_seconds,'overtime_seconds',overtime_seconds,
    'overtime_multiplier',overtime_multiplier,
    'gross_amount',round((normal_seconds::numeric/3600)*p_hourly_rate
      +(overtime_seconds::numeric/3600)*p_hourly_rate*overtime_multiplier,2)
  ) from totals
$function$;
revoke execute on function public.srk_worker_session_time_breakdown(uuid,numeric) from public,anon,authenticated;

do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
  v_pos integer;
  v_prefix text;
  v_suffix text;
begin
  v_def:=pg_get_functiondef('public.srk_admin_finalize_booking_bill(uuid)'::regprocedure);
  v_old:='coalesce(sum(s.billable_seconds),0)::bigint seconds';
  v_new:='coalesce(sum(s.billable_seconds),0)::bigint seconds, public.srk_worker_session_time_breakdown(bw.id,bw.hourly_rate_snapshot) time_breakdown';
  if position(v_old in v_def)=0 then raise exception 'Expected worker time aggregate was not found'; end if;
  v_def:=replace(v_def,v_old,v_new);

  v_old:='v_worker_gross:=round((v_worker.seconds::numeric/3600)*v_worker.hourly_rate_snapshot,2);';
  v_new:='v_worker_gross:=round((v_worker.time_breakdown->>''gross_amount'')::numeric,2);';
  if position(v_old in v_def)=0 then raise exception 'Expected gross calculation was not found'; end if;
  v_def:=replace(v_def,v_old,v_new);

  v_pos:=position('for v_worker in' in reverse(v_def));
  -- Locate the non-fixed timer earnings loop using its distinctive SELECT.
  v_pos:=strpos(v_def,'for v_worker in'||E'\n      select bw.id booking_worker_id');
  if v_pos=0 then raise exception 'Timer earnings loop not found'; end if;
  v_prefix:=substring(v_def from 1 for v_pos-1);
  v_suffix:=substring(v_def from v_pos);

  v_old:='billable_seconds,gross_service_earning,company_commission_rate,';
  v_new:='billable_seconds,normal_billable_seconds,overtime_billable_seconds,overtime_multiplier,gross_service_earning,company_commission_rate,';
  if position(v_old in v_suffix)=0 then raise exception 'Timer earnings columns not found'; end if;
  v_suffix:=replace(v_suffix,v_old,v_new);

  v_old:='v_bill.id,v_worker.seconds,v_worker_gross,v_booking.commission_rate,v_worker_commission,';
  v_new:='v_bill.id,v_worker.seconds,(v_worker.time_breakdown->>''normal_seconds'')::bigint,(v_worker.time_breakdown->>''overtime_seconds'')::bigint,(v_worker.time_breakdown->>''overtime_multiplier'')::numeric,v_worker_gross,v_booking.commission_rate,v_worker_commission,';
  if position(v_old in v_suffix)=0 then raise exception 'Timer earnings values not found'; end if;
  v_suffix:=replace(v_suffix,v_old,v_new);

  v_old:='billable_seconds=excluded.billable_seconds,';
  v_new:='billable_seconds=excluded.billable_seconds,normal_billable_seconds=excluded.normal_billable_seconds,overtime_billable_seconds=excluded.overtime_billable_seconds,overtime_multiplier=excluded.overtime_multiplier,';
  if position(v_old in v_suffix)=0 then raise exception 'Timer earnings upsert fields not found'; end if;
  v_suffix:=replace(v_suffix,v_old,v_new);

  execute v_prefix||v_suffix;
end
$migration$;
