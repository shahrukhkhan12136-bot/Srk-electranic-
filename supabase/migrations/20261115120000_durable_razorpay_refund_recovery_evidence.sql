-- Durable, two-phase Razorpay refund recovery. Feature Branch source only.
-- Phase 1 commits immutable provider evidence. Phase 2 finalizes accounting in a separate request.

create table if not exists public.srk_razorpay_refund_recovery_audits (
  id uuid primary key default gen_random_uuid(),
  refund_record_id uuid not null references public.srk_razorpay_refunds(id) on delete restrict,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  provider_refund_id text not null check (provider_refund_id ~ '^rfnd_[A-Za-z0-9]+$'),
  payment_id text not null check (payment_id ~ '^pay_[A-Za-z0-9]+$'),
  amount_paise bigint not null check (amount_paise > 0),
  currency text not null check (currency = 'INR'),
  provider_status text not null check (provider_status in ('pending','processed','failed')),
  provider_created_at timestamptz,
  acquirer_reference text,
  provider_payload_sha256 text not null check (provider_payload_sha256 ~ '^[a-f0-9]{64}$'),
  observation_id uuid not null unique,
  provider_evidence jsonb not null check (jsonb_typeof(provider_evidence) = 'object'),
  admin_user_id uuid not null references auth.users(id) on delete restrict,
  admin_note text not null check (length(btrim(admin_note)) between 10 and 2000),
  recorded_at timestamptz not null default clock_timestamp()
);

alter table public.srk_razorpay_refund_recovery_audits enable row level security;
revoke all on table public.srk_razorpay_refund_recovery_audits from public,anon,authenticated,service_role;

create or replace function public.srk_reject_razorpay_refund_recovery_audit_mutation()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  raise exception 'REFUND_RECOVERY_EVIDENCE_IS_APPEND_ONLY' using errcode='55000';
end;
$$;
revoke all on function public.srk_reject_razorpay_refund_recovery_audit_mutation() from public,anon,authenticated;
drop trigger if exists srk_razorpay_refund_recovery_audit_immutable on public.srk_razorpay_refund_recovery_audits;
create trigger srk_razorpay_refund_recovery_audit_immutable
before update or delete on public.srk_razorpay_refund_recovery_audits
for each row execute function public.srk_reject_razorpay_refund_recovery_audit_mutation();

-- Phase 1: service-role-only writer. One observation UUID makes network retries idempotent,
-- while a fresh provider GET can create a new timestamped observation even for identical JSON.
create or replace function public.srk_service_record_razorpay_refund_recovery_evidence(
  p_refund_record_id uuid,
  p_provider_refund_id text,
  p_payment_id text,
  p_amount_paise bigint,
  p_currency text,
  p_provider_status text,
  p_provider_created_at timestamptz,
  p_acquirer_reference text,
  p_provider_payload_sha256 text,
  p_observation_id uuid,
  p_provider_evidence jsonb,
  p_admin_user_id uuid,
  p_admin_note text
)
returns uuid language plpgsql security definer set search_path=''
as $$
declare
  v_refund public.srk_razorpay_refunds%rowtype;
  v_booking public.service_bookings%rowtype;
  v_audit_id uuid;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;
  if p_refund_record_id is null or p_admin_user_id is null or p_observation_id is null
     or p_provider_refund_id is null or p_provider_refund_id !~ '^rfnd_[A-Za-z0-9]+$'
     or p_payment_id is null or p_payment_id !~ '^pay_[A-Za-z0-9]+$'
     or p_amount_paise is null or p_amount_paise <= 0
     or p_currency is distinct from 'INR'
     or p_provider_status is null or p_provider_status not in ('pending','processed','failed')
     or p_provider_payload_sha256 is null or p_provider_payload_sha256 !~ '^[a-f0-9]{64}$'
     or p_provider_evidence is null or jsonb_typeof(p_provider_evidence) is distinct from 'object'
     or p_admin_note is null or length(btrim(p_admin_note)) not between 10 and 2000 then
    raise exception 'INVALID_REFUND_RECOVERY_EVIDENCE_OR_AUDIT_NOTE' using errcode='22023';
  end if;

  if p_provider_evidence->>'id' is distinct from p_provider_refund_id
     or p_provider_evidence->>'payment_id' is distinct from p_payment_id
     or p_provider_evidence->>'currency' is distinct from p_currency
     or p_provider_evidence->>'status' is distinct from p_provider_status
     or coalesce(p_provider_evidence->>'amount','') !~ '^[0-9]+$'
     or (p_provider_evidence->>'amount')::bigint is distinct from p_amount_paise then
    raise exception 'PROVIDER_EVIDENCE_FIELDS_DO_NOT_MATCH_AUDIT_ARGUMENTS' using errcode='55000';
  end if;

  select * into v_refund from public.srk_razorpay_refunds where id=p_refund_record_id;
  if not found then raise exception 'REFUND_RECORD_NOT_FOUND'; end if;
  select * into v_booking from public.service_bookings where id=v_refund.booking_id;
  if not found then raise exception 'REFUND_BOOKING_NOT_FOUND'; end if;

  if v_booking.razorpay_payment_id is distinct from v_refund.payment_id
     or p_payment_id is distinct from v_refund.payment_id
     or p_amount_paise is distinct from v_refund.amount_paise
     or p_currency is distinct from v_refund.currency then
    raise exception 'PROVIDER_EVIDENCE_DOES_NOT_MATCH_INTERNAL_PAYMENT' using errcode='55000';
  end if;
  if v_refund.refund_id is not null and v_refund.refund_id is distinct from p_provider_refund_id then
    raise exception 'PROVIDER_REFUND_ID_CONFLICT' using errcode='55000';
  end if;

  insert into public.srk_razorpay_refund_recovery_audits(
    refund_record_id,booking_id,provider_refund_id,payment_id,amount_paise,currency,
    provider_status,provider_created_at,acquirer_reference,provider_payload_sha256,
    observation_id,provider_evidence,admin_user_id,admin_note
  ) values (
    v_refund.id,v_refund.booking_id,p_provider_refund_id,p_payment_id,p_amount_paise,p_currency,
    p_provider_status,p_provider_created_at,nullif(btrim(coalesce(p_acquirer_reference,'')),''),
    p_provider_payload_sha256,p_observation_id,p_provider_evidence,p_admin_user_id,btrim(p_admin_note)
  ) on conflict (observation_id) do nothing
  returning id into v_audit_id;

  if v_audit_id is null then
    select id into v_audit_id from public.srk_razorpay_refund_recovery_audits
    where observation_id=p_observation_id
      and refund_record_id=v_refund.id
      and provider_payload_sha256=p_provider_payload_sha256
      and provider_refund_id=p_provider_refund_id
      and payment_id=p_payment_id
      and amount_paise=p_amount_paise
      and provider_status=p_provider_status;
    if v_audit_id is null then
      raise exception 'OBSERVATION_ID_REUSED_WITH_DIFFERENT_PROVIDER_FACTS' using errcode='55000';
    end if;
  end if;
  return v_audit_id;
end;
$$;
revoke all on function public.srk_service_record_razorpay_refund_recovery_evidence(uuid,text,text,bigint,text,text,timestamptz,text,text,uuid,jsonb,uuid,text) from public,anon,authenticated;
grant execute on function public.srk_service_record_razorpay_refund_recovery_evidence(uuid,text,text,bigint,text,text,timestamptz,text,text,uuid,jsonb,uuid,text) to service_role;

-- Phase 2: a separate HTTP/PostgREST call creates a separate DB transaction.
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
  if v_has_payout and v_payout.payout_status is distinct from 'blocked' then
    raise exception 'ELECTRICIAN_PAYOUT_MUST_REMAIN_BLOCKED_DURING_REFUND_RECOVERY' using errcode='55000';
  end if;
  if v_booking.payment_status is distinct from 'paid' and v_booking.payment_status is distinct from 'refunded' then
    raise exception 'BOOKING_PAYMENT_STATE_NOT_RECOVERABLE' using errcode='55000';
  end if;

  if v_booking.payment_status='refunded' and v_refund.status='processed' then
    return jsonb_build_object('success',true,'status','processed','replayed',true,
      'booking_id',v_booking.id,'refund_record_id',v_refund.id,'recovery_audit_id',v_audit.id);
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

  return jsonb_build_object('success',true,'status','processed','replayed',false,
    'booking_id',v_booking.id,'refund_record_id',v_refund.id,'recovery_audit_id',v_audit.id);
end;
$$;
revoke all on function public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid) from public,anon,authenticated;
grant execute on function public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid) to service_role;
