-- Keep all commission dashboards consistent with the direct-UPI remittance ledger.
-- Also recognize either supported electrician auth link (user_id or auth_user_id).

create or replace function public.srk_get_my_earnings()
returns table (
  booking_id uuid,
  service_type text,
  booking_created_at timestamptz,
  booking_status text,
  payment_status text,
  amount_received numeric,
  commission_amount numeric,
  electrician_earning numeric
)
language sql
stable
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
  select b.id,
         b.service_type,
         b.created_at,
         b.status,
         b.payment_status,
         coalesce(b.amount_paid,0)::numeric,
         coalesce(b.commission_amount,
           round(coalesce(b.amount_paid,0)*coalesce(b.commission_rate,15)/100,2))::numeric,
         case when b.status='completed' and b.payment_status='paid'
              then greatest(coalesce(b.amount_paid,0) -
                coalesce(b.commission_amount,
                  round(coalesce(b.amount_paid,0)*coalesce(b.commission_rate,15)/100,2)),0)
              else 0 end::numeric
  from public.electrician_profiles p
  join public.service_bookings b on b.assigned_electrician_id=p.id
  where (p.user_id=auth.uid() or p.auth_user_id=auth.uid())
    and p.verification_status='approved'
  order by b.created_at desc
  limit 200;
$function$;

create or replace function public.srk_admin_commission_report()
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode='42501';
  end if;

  with paid_completed as (
    select assigned_electrician_id,
           coalesce(amount_paid,0)::numeric as gross,
           coalesce(commission_amount,
             round(coalesce(amount_paid,0)*coalesce(commission_rate,15)/100,2))::numeric as commission
    from public.service_bookings
    where status='completed' and payment_status='paid'
  ),
  totals as (
    select coalesce(sum(gross),0)::numeric as collected,
           coalesce(sum(commission),0)::numeric as commission,
           coalesce(sum(gross-commission),0)::numeric as payable
    from paid_completed
  ),
  partners as (
    select p.id as electrician_id,
           p.display_name,
           count(pc.*)::integer as paid_completed_jobs,
           coalesce(sum(pc.gross),0)::numeric as gross_received,
           coalesce(sum(pc.commission),0)::numeric as company_commission,
           coalesce(sum(pc.gross-pc.commission),0)::numeric as electrician_earning
    from public.electrician_profiles p
    left join paid_completed pc on pc.assigned_electrician_id=p.id
    group by p.id,p.display_name
    order by p.display_name
  )
  select jsonb_build_object(
    'total_collected',t.collected,
    'total_commission',t.commission,
    'total_electrician_payable',t.payable,
    'partners',coalesce((select jsonb_agg(to_jsonb(partners)) from partners),'[]'::jsonb)
  ) into v_result
  from totals t;
  return v_result;
end;
$function$;

revoke all on function public.srk_get_my_earnings() from public,anon;
revoke all on function public.srk_admin_commission_report() from public,anon;
grant execute on function public.srk_get_my_earnings() to authenticated;
grant execute on function public.srk_admin_commission_report() to authenticated;
