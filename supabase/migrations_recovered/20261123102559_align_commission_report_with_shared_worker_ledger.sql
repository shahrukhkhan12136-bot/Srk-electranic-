create or replace function public.srk_admin_commission_report()
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare v_result jsonb;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode='42501';
  end if;

  with paid_completed as (
    select b.id,b.assigned_electrician_id,
      coalesce(b.amount_paid,0)::numeric gross,
      case when exists(select 1 from public.srk_worker_earnings e where e.booking_id=b.id)
        then (select coalesce(sum(e.company_commission),0) from public.srk_worker_earnings e where e.booking_id=b.id)
        else coalesce(b.commission_amount,round(coalesce(b.service_charge,0)*coalesce(b.commission_rate,15)/100,2))
      end::numeric commission
    from public.service_bookings b
    where b.status='completed' and b.payment_status='paid'
  ),
  totals as (
    select coalesce(sum(gross),0)::numeric collected,
      coalesce(sum(commission),0)::numeric commission,
      coalesce(sum(gross-commission),0)::numeric payable
    from paid_completed
  ),
  shared_workers as (
    select wp.id worker_id,wp.worker_type,wp.worker_code,wp.full_name display_name,
      count(distinct e.booking_id)::integer paid_completed_jobs,
      coalesce(sum(e.gross_service_earning),0)::numeric gross_received,
      coalesce(sum(e.company_commission),0)::numeric company_commission,
      coalesce(sum(e.net_earning),0)::numeric worker_earning
    from public.srk_worker_profiles wp
    join public.srk_worker_earnings e on e.worker_id=wp.id
    join paid_completed pc on pc.id=e.booking_id
    group by wp.id,wp.worker_type,wp.worker_code,wp.full_name
  ),
  legacy_workers as (
    select p.id worker_id,'legacy_electrician'::text worker_type,null::text worker_code,
      p.display_name,
      count(pc.id)::integer paid_completed_jobs,
      coalesce(sum(pc.gross),0)::numeric gross_received,
      coalesce(sum(pc.commission),0)::numeric company_commission,
      coalesce(sum(pc.gross-pc.commission),0)::numeric worker_earning
    from public.electrician_profiles p
    left join paid_completed pc on pc.assigned_electrician_id=p.id
      and not exists(select 1 from public.srk_worker_earnings e where e.booking_id=pc.id)
    where exists(select 1 from paid_completed pc2
      where pc2.assigned_electrician_id=p.id
        and not exists(select 1 from public.srk_worker_earnings e2 where e2.booking_id=pc2.id))
    group by p.id,p.display_name
  ),
  partners as (
    select * from shared_workers
    union all
    select * from legacy_workers
  )
  select jsonb_build_object(
    'total_collected',t.collected,
    'total_commission',t.commission,
    'total_electrician_payable',t.payable,
    'partners',coalesce((select jsonb_agg(jsonb_build_object(
      'electrician_id',worker_id,'worker_id',worker_id,'worker_type',worker_type,
      'worker_code',worker_code,'display_name',display_name,
      'paid_completed_jobs',paid_completed_jobs,'gross_received',gross_received,
      'company_commission',company_commission,'electrician_earning',worker_earning,
      'worker_earning',worker_earning
    ) order by display_name) from partners),'[]'::jsonb)
  ) into v_result from totals t;
  return v_result;
end
$function$;
revoke all on function public.srk_admin_commission_report() from public,anon;
grant execute on function public.srk_admin_commission_report() to authenticated;