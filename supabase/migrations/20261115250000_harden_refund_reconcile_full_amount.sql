-- Independently enforce full-collection equality at the trusted provider reconciliation boundary.
-- Do not rely only on the Netlify caller's amount comparison or refund preparation snapshot.
create or replace function public.srk_service_reconcile_booking_refund(
  p_refund_record_id uuid,
  p_provider_refund_id text,
  p_provider_status text,
  p_error text default null
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_refund public.srk_razorpay_refunds%rowtype;
  v_booking public.service_bookings%rowtype;
  v_status text;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;
  if p_refund_record_id is null
     or p_provider_status is null
     or p_provider_status not in ('pending','processed','failed')
     or (p_provider_status='processed' and p_provider_refund_id is null)
     or (p_provider_refund_id is not null and p_provider_refund_id !~ '^rfnd_[A-Za-z0-9]+$') then
    raise exception 'INVALID_PROVIDER_REFUND_RESULT' using errcode='22023';
  end if;

  -- Keep the booking-first lock order shared with refund preparation and payout settlement.
  select b.* into v_booking
    from public.service_bookings b
    join public.srk_razorpay_refunds r on r.booking_id=b.id
    where r.id=p_refund_record_id
    for update of b;
  if not found then raise exception 'REFUND_BOOKING_NOT_FOUND'; end if;

  select * into v_refund from public.srk_razorpay_refunds
    where id=p_refund_record_id and booking_id=v_booking.id for update;
  if not found then raise exception 'REFUND_RECORD_CHANGED_RETRY'; end if;
  if v_refund.refund_id is not null and p_provider_refund_id is not null
     and v_refund.refund_id is distinct from p_provider_refund_id then
    raise exception 'PROVIDER_REFUND_ID_MISMATCH' using errcode='55000';
  end if;

  -- A processed provider result is allowed to close the booking only for the entire
  -- captured collection. Partial refunds remain unsupported and must be reviewed manually.
  if p_provider_status='processed'
     and (v_booking.amount_paid is null
       or v_booking.amount_paid<=0
       or v_refund.amount_paise is distinct from round(v_booking.amount_paid*100)::bigint) then
    raise exception 'PROVIDER_REFUND_AMOUNT_DOES_NOT_MATCH_FULL_BOOKING_COLLECTION' using errcode='55000';
  end if;

  -- Provider refund states are terminal once processed or failed. Ignore late,
  -- out-of-order events instead of regressing a final state back to processing.
  if v_refund.status in ('processed','failed') then
    return jsonb_build_object('success',true,'status',v_refund.status,'replayed',true);
  end if;
  v_status:=case p_provider_status when 'pending' then 'processing'
    when 'processed' then 'processed' else 'failed' end;

  update public.srk_razorpay_refunds
    set refund_id=coalesce(p_provider_refund_id,refund_id),
        provider_status=p_provider_status,status=v_status,
        last_error=case when p_provider_status='failed' then left(coalesce(p_error,'Refund failed'),500) else null end,
        processed_at=case when p_provider_status='processed' then clock_timestamp() else null end,
        updated_at=clock_timestamp()
    where id=p_refund_record_id;

  update public.srk_booking_refund_requests
    set status=case when p_provider_status='processed' then 'processed'
      when p_provider_status='failed' then 'unknown' else 'processing' end,
        updated_at=clock_timestamp(),
        processed_at=case when p_provider_status='processed' then clock_timestamp() else null end
    where refund_record_id=p_refund_record_id;

  if p_provider_status='processed' then
    update public.service_bookings set payment_status='refunded'
      where id=v_refund.booking_id and payment_status='paid';
  elsif p_provider_status='failed' then
    update public.srk_electrician_payouts
      set payout_status='pending',payout_note=v_refund.previous_payout_note,
          updated_at=clock_timestamp()
      where booking_id=v_refund.booking_id
        and payout_status='blocked'
        and payout_note='Razorpay refund pending';
  end if;

  return jsonb_build_object('success',true,'status',v_status,'booking_id',v_refund.booking_id);
end;
$$;

revoke all on function public.srk_service_reconcile_booking_refund(uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.srk_service_reconcile_booking_refund(uuid,text,text,text) to service_role;
