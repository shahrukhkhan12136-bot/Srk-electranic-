-- Harden customer self-cancellation and provide a customer-safe refund-request history.
-- Source-only until separately approved for database application.

create or replace function public.srk_customer_list_my_booking_refund_requests()
returns table (
  id uuid,
  booking_id uuid,
  amount numeric,
  reason text,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  processed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
begin
  if auth.uid() is null then
    raise exception 'Customer login required' using errcode = '42501';
  end if;

  return query
  select r.id, r.booking_id, r.amount, r.reason, r.status,
         r.created_at, r.updated_at, r.processed_at
    from public.srk_booking_refund_requests r
   where r.customer_user_id = auth.uid()
   order by r.created_at desc
   limit 100;
end;
$function$;

revoke all on function public.srk_customer_list_my_booking_refund_requests() from public, anon;
grant execute on function public.srk_customer_list_my_booking_refund_requests() to authenticated;
