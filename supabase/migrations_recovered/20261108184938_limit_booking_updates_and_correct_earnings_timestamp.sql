
revoke update on table public.service_bookings from authenticated;
revoke update (commission_amount, commission_rate) on table public.service_bookings from authenticated;
grant update (status, quoted_amount, amount_paid, payment_status)
on table public.service_bookings to authenticated;

drop function if exists public.srk_get_my_earnings();
create function public.srk_get_my_earnings()
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
set search_path = pg_catalog, public, auth, pg_temp
as $$
  select b.id, b.service_type, b.created_at, b.status, b.payment_status,
         coalesce(b.amount_paid,0), coalesce(b.commission_amount,0),
         case when b.status='completed' and b.payment_status='paid'
              then greatest(coalesce(b.amount_paid,0)-coalesce(b.commission_amount,0),0)
              else 0 end
  from public.electrician_profiles p
  join public.service_bookings b on b.assigned_electrician_id=p.id
  where p.user_id=auth.uid() and p.verification_status='approved'
  order by b.created_at desc
  limit 200;
$$;
revoke all on function public.srk_get_my_earnings() from public, anon;
grant execute on function public.srk_get_my_earnings() to authenticated;
