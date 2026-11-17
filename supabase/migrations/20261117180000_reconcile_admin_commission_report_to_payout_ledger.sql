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
      b.id as booking_id,
      b.assigned_electrician_id,
      (coalesce(p.gross_service_amount,0) + coalesce(p.materials_amount,0))::numeric as gross,
      coalesce(p.platform_commission,0)::numeric as commission,
      coalesce(p.electrician_payable,0)::numeric as payable
    from public.service_bookings b
    left join public.srk_electrician_payouts p
      on p.booking_id = b.id
     and p.electrician_profile_id = b.assigned_electrician_id
     and p.payout_status in ('pending','paid','blocked')
    where b.status = 'completed'
      and b.payment_status = 'paid'
      and b.payment_verified_at is not null
  ),
  collection_totals as (
    -- Collections must not disappear merely because a payout row is missing
    -- or its electrician assignment does not reconcile.
    select coalesce(sum(coalesce(b.amount_paid,0)),0)::numeric as collected
    from public.service_bookings b
    where b.status = 'completed'
      and b.payment_status = 'paid'
      and b.payment_verified_at is not null
  ),
  totals as (
    select
      ct.collected,
      coalesce(sum(pc.commission),0)::numeric as commission,
      coalesce(sum(pc.payable),0)::numeric as payable
    from collection_totals ct
    left join paid_completed pc on true
    group by ct.collected
  ),
  partners as (
    select
      p.id as electrician_id,
      p.display_name,
      count(pc.booking_id)::integer as paid_completed_jobs,
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
