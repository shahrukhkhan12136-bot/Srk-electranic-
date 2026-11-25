
create or replace function public.srk_admin_commission_report()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  with paid_completed as (
    select assigned_electrician_id,
           coalesce(amount_paid,0)::numeric as gross,
           coalesce(commission_amount,0)::numeric as commission
    from public.service_bookings
    where status = 'completed' and payment_status = 'paid'
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
    left join paid_completed pc on pc.assigned_electrician_id = p.id
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
$$;

revoke all on function public.srk_admin_commission_report() from public, anon;
grant execute on function public.srk_admin_commission_report() to authenticated;

revoke select, update (commission_amount, commission_rate)
on table public.service_bookings from authenticated;
