-- Recovery finalization must independently prove the provider refund is the full verified booking collection.
-- This keeps a partial or stale provider record from being promoted to a completed booking refund.
create or replace function public.srk_service_finalize_razorpay_refund_from_recovery_evidence(p_recovery_audit_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  v_audit public.srk_razorpay_refund_recovery_audits%rowtype;
  v_refund public.srk_razorpay_refunds%rowtype;
  v_booking public.service_bookings%rowtype;
  v_payout public.srk_electrician_payouts%rowtype;
  v_has_payout boolean:=false;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;
  if p_recovery_audit_id is null then raise exception 'RECOVERY_EVIDENCE_ID_REQUIRED' using errcode='22023'; end if;

  select * into v_audit from public.srk_razorpay_refund_recovery_audits where id=p_recovery_audit_id;
  if not found then raise exception 'RECOVERY_EVIDENCE_NOT_FOUND'; end if;
  if v_audit.provider_status is distinct from 'processed' then
    raise exception 'ONLY_VERIFIED_PROCESSED_PROVIDER_EVIDENCE_CAN_FINALIZE' using errcode='55000';
  end if;
  if v_audit.recorded_at < clock_timestamp()-interval '15 minutes' then
    raise exception 'RECOVERY_EVIDENCE_TOO_OLD_REFRESH_PROVIDER_STATUS' using errcode='55000';
  end if;

  select * into v_booking from public.service_bookings where id=v_audit.booking_id for update;
  if not found then raise exception 'REFUND_BOOKING_NOT_FOUND'; end if;
  if v_audit.amount_paise is distinct from round(v_booking.amount_paid*100)::bigint then
    raise exception 'RECOVERY_REFUND_AMOUNT_DOES_NOT_MATCH_FULL_BOOKING_COLLECTION' using errcode='55000';
  end if;
  select * into v_refund from public.srk_razorpay_refunds
    where id=v_audit.refund_record_id and booking_id=v_booking.id for update;
  if not found then raise exception 'REFUND_RECORD_CHANGED_RETRY'; end if;

  if v_refund.payment_id is distinct from v_audit.payment_id
     or v_booking.razorpay_payment_id is distinct from v_audit.payment_id
     or v_refund.amount_paise is distinct from v_audit.amount_paise
     or v_refund.currency is distinct from v_audit.currency
     or (v_refund.refund_id is not null and v_refund.refund_id is distinct from v_audit.provider_refund_id) then
    raise exception 'RECOVERY_EVIDENCE_NO_LONGER_MATCHES_REFUND_RECORD' using errcode='55000';
  end if;

  select * into v_payout from public.srk_electrician_payouts where booking_id=v_booking.id for update;
  v_has_payout:=found;
  if v_has_payout and v_payout.payout_status='paid' then
    raise exception 'ELECTRICIAN_PAYOUT_ALREADY_PAID_MANUAL_RECONCILIATION_REQUIRED' using errcode='55000';
  end if;
  if v_booking.payment_status is distinct from 'paid' and v_booking.payment_status is distinct from 'refunded' then
    raise exception 'BOOKING_PAYMENT_STATE_NOT_RECOVERABLE' using errcode='55000';
  end if;

  -- A completed refund trigger moves its payout to refunded; allow only that exact replay state.
  if v_booking.payment_status='refunded' and v_refund.status='processed' then
    if v_has_payout and v_payout.payout_status is distinct from 'refunded' then
      raise exception 'REFUNDED_BOOKING_PAYOUT_STATE_REQUIRES_MANUAL_RECONCILIATION' using errcode='55000';
    end if;
    return jsonb_build_object('success',true,'status','processed','replayed',true,
      'booking_id',v_booking.id,'refund_record_id',v_refund.id,'recovery_audit_id',v_audit.id);
  end if;

  if v_has_payout and v_payout.payout_status is distinct from 'blocked' then
    raise exception 'ELECTRICIAN_PAYOUT_MUST_REMAIN_BLOCKED_DURING_REFUND_RECOVERY' using errcode='55000';
  end if;

  update public.srk_razorpay_refunds set refund_id=v_audit.provider_refund_id,
    provider_status='processed',status='processed',last_error=null,
    processed_at=coalesce(processed_at,clock_timestamp()),updated_at=clock_timestamp()
  where id=v_refund.id;

  update public.srk_booking_refund_requests set status='processed',refund_record_id=v_refund.id,
    processed_at=coalesce(processed_at,clock_timestamp()),updated_at=clock_timestamp()
  where booking_id=v_booking.id;

  if v_booking.payment_status='paid' then
    update public.service_bookings set payment_status='refunded'
    where id=v_booking.id and payment_status='paid';
  end if;

  -- The existing payable trigger only converts pending -> refunded. Refund preparation
  -- deliberately blocks the payout, so close that exact blocked row only after verified
  -- processed evidence and the booking/accounting trigger have succeeded.
  if v_has_payout then
    update public.srk_electrician_payouts
      set payout_status='refunded',
          payout_note='Razorpay full refund verified; payout permanently withheld.',
          updated_at=clock_timestamp()
    where id=v_payout.id and payout_status='blocked';
    if not found then
      raise exception 'BLOCKED_PAYOUT_COULD_NOT_BE_CLOSED_AS_REFUNDED' using errcode='55000';
    end if;
  end if;

  return jsonb_build_object('success',true,'status','processed','replayed',false,
    'booking_id',v_booking.id,'refund_record_id',v_refund.id,'recovery_audit_id',v_audit.id);
end;
$$;

revoke all on function public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid) from public,anon,authenticated;
grant execute on function public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid) to service_role;
