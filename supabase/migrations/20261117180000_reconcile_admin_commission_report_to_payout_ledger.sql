-- Keep the Main Admin commission report aligned with the canonical payout ledger.
-- Customer collections can include carry-forward cancellation fees; those fees are
-- SRK revenue and must never be counted as electrician gross or electrician payable.

create or replace function public.srk_admin_commission_report()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  with paid_completed as (
    select
      b.assigned_electrician_id,
      coalesce(b.amount_paid,0)::numeric as collected,
      (coalesce(p.gross_service_amount,0) + coalesce(p.materials_amount,0))::numeric as gross,
      coalesce(p.platform_commission,0)::numeric as commission,
      coalesce(p.electrician_payable,0)::numeric as payable
    from public.service_bookings b
    join public.srk_electrician_payouts p
      on p.booking_id = b.id
     and p.electrician_profile_id = b.assigned_electrician_id
    where b.status = 'completed'
      and b.payment_status = 'paid'
      and b.payment_verified_at is not null
      and p.payout_status in ('pending','paid','blocked')
  ),
  totals as (
    select
      coalesce(sum(collected),0)::numeric as collected,
      coalesce(sum(commission),0)::numeric as commission,
      coalesce(sum(payable),0)::numeric as payable
    from paid_completed
  ),
  partners as (
    select
      p.id as electrician_id,
      p.display_name,
      count(pc.*)::integer as paid_completed_jobs,
      coalesce(sum(pc.gross),0)::numeric as gross_received,
      coalesce(sum(pc.commission),0)::numeric as company_commission,
      coalesce(sum(pc.payable),0)::numeric as electrician_earning
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

comment on function public.srk_admin_commission_report() is
  'Main Admin commission report: customer collection is shown separately; electrician gross, commission and payable are sourced from the canonical payout ledger, excluding SRK cancellation fees from electrician earnings.';
