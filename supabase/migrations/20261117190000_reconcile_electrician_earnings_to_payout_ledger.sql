-- Electrician earnings must use the canonical payout ledger, not customer collection.
-- Customer collections may include SRK cancellation-fee carry-forward amounts.
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
set search_path = ''
as $function$
  select
    b.id,
    b.service_type,
    b.created_at,
    b.status,
    b.payment_status,
    coalesce(b.amount_paid,0)::numeric,
    coalesce(po.platform_commission,0)::numeric,
    case
      when b.status='completed' and b.payment_status='paid'
        then coalesce(po.electrician_payable,0)::numeric
      else 0::numeric
    end
  from public.electrician_profiles p
  join public.service_bookings b
    on b.assigned_electrician_id=p.id
  left join public.srk_electrician_payouts po
    on po.booking_id=b.id
   and po.electrician_profile_id=p.id
   and po.payout_status in ('pending','paid','blocked')
  where p.user_id=auth.uid()
    and p.verification_status='approved'
  order by b.created_at desc
  limit 200;
$function$;

revoke all on function public.srk_get_my_earnings() from public,anon;
grant execute on function public.srk_get_my_earnings() to authenticated;

comment on function public.srk_get_my_earnings() is
  'Returns the authenticated approved electrician bookings; customer collection remains amount_received, while commission and electrician earnings come only from the canonical non-refunded payout ledger.';
