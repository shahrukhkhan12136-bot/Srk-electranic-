-- Keep immutable historical financial evidence before removing live quote columns.
CREATE SCHEMA IF NOT EXISTS srk_private;
CREATE TABLE IF NOT EXISTS srk_private.legacy_booking_financial_evidence (
  booking_id uuid PRIMARY KEY REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  quoted_amount numeric(12,2),
  service_charge numeric(12,2),
  materials_amount numeric(12,2),
  quote_status text,
  quote_note text,
  quote_submitted_at timestamptz,
  quote_responded_at timestamptz,
  customer_suggested_amount numeric(12,2),
  electrician_quote_kind text,
  legacy_booking_status text,
  archived_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE srk_private.legacy_booking_financial_evidence ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON srk_private.legacy_booking_financial_evidence FROM PUBLIC,anon,authenticated;
GRANT SELECT ON srk_private.legacy_booking_financial_evidence TO service_role;
INSERT INTO srk_private.legacy_booking_financial_evidence
 (booking_id,quoted_amount,service_charge,materials_amount,quote_status,quote_note,
  quote_submitted_at,quote_responded_at,customer_suggested_amount,electrician_quote_kind,legacy_booking_status)
SELECT b.id,
 nullif(to_jsonb(b)->>'quoted_amount','')::numeric,
 nullif(to_jsonb(b)->>'service_charge','')::numeric,
 nullif(to_jsonb(b)->>'materials_amount','')::numeric,
 to_jsonb(b)->>'quote_status',to_jsonb(b)->>'quote_note',
 nullif(to_jsonb(b)->>'quote_submitted_at','')::timestamptz,
 nullif(to_jsonb(b)->>'quote_responded_at','')::timestamptz,
 nullif(to_jsonb(b)->>'customer_suggested_amount','')::numeric,
 to_jsonb(b)->>'electrician_quote_kind',to_jsonb(b)->>'status'
FROM public.service_bookings b
WHERE nullif(to_jsonb(b)->>'quoted_amount','') IS NOT NULL
 OR nullif(to_jsonb(b)->>'service_charge','') IS NOT NULL
 OR nullif(to_jsonb(b)->>'materials_amount','') IS NOT NULL
 OR to_jsonb(b)->>'quote_status' IS NOT NULL
 OR to_jsonb(b)->>'quote_note' IS NOT NULL
 OR to_jsonb(b)->>'quote_submitted_at' IS NOT NULL
 OR to_jsonb(b)->>'quote_responded_at' IS NOT NULL
 OR to_jsonb(b)->>'customer_suggested_amount' IS NOT NULL
 OR to_jsonb(b)->>'electrician_quote_kind' IS NOT NULL
 OR to_jsonb(b)->>'status' IN ('inspection','awaiting_quote_approval','quote_approved','quote_rejected')
ON CONFLICT (booking_id) DO NOTHING;

-- Restore the legacy Admin manual-payment RPC and reconcile labour/materials separately.
-- Feature-branch source only. Do not apply to Production without explicit approval.

-- Retire legacy quote-based manual payment entry. Historical payment rows remain intact.
DROP FUNCTION IF EXISTS public.srk_admin_record_manual_payment(uuid,text,text,text);

create or replace function public.srk_customer_get_payment_receipt(p_booking_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_booking public.service_bookings%rowtype;
  v_bill public.srk_booking_labour_bills%rowtype;
  v_legacy srk_private.legacy_booking_financial_evidence%rowtype;
  v_fee_paise bigint:=0;
  v_fee_items jsonb:='[]'::jsonb;
  v_total_paise bigint;
  v_labour_paise bigint;
  v_materials_paise bigint;
begin
  if v_uid is null then raise exception 'Customer login required' using errcode='42501'; end if;
  if p_booking_id is null then raise exception 'Booking ID required' using errcode='22023'; end if;
  select * into v_booking from public.service_bookings
   where id=p_booking_id and customer_user_id=v_uid;
  if not found then raise exception 'Booking not found' using errcode='42501'; end if;
  if v_booking.payment_status<>'paid' or v_booking.payment_verified_at is null
     or coalesce(v_booking.amount_paid,0)<=0 then
    raise exception 'Only verified paid bookings have a payment receipt' using errcode='55000';
  end if;

  if v_booking.selected_category is not null then
    select * into v_bill from public.srk_booking_labour_bills
     where booking_id=p_booking_id and customer_user_id=v_uid;
    if not found then raise exception 'Immutable labour bill not found' using errcode='55000'; end if;
    select coalesce(sum(i.amount_paise),0),
      coalesce(jsonb_agg(jsonb_build_object('source_booking_id',i.source_booking_id,
        'amount_paise',i.amount_paise,'amount',i.amount_paise/100.0) order by i.created_at,i.id),'[]'::jsonb)
      into v_fee_paise,v_fee_items
      from public.srk_booking_cancellation_fee_items i
     where i.booking_id=p_booking_id and i.status='settled';
    v_total_paise:=v_bill.labour_amount_paise+v_fee_paise;
    if round(v_booking.amount_paid*100)::bigint<>v_total_paise then
      raise exception 'Paid amount does not match immutable labour and cancellation fee ledger' using errcode='55000';
    end if;
    return jsonb_build_object(
      'receipt_reference','SRK-PAY-'||upper(left(replace(v_booking.id::text,'-',''),12)),
      'booking_id',v_booking.id,'customer_name',v_booking.customer_name,
      'service_type',v_booking.service_type,'address',v_booking.address,
      'district',v_booking.district,'state',v_booking.state,'pincode',v_booking.pincode,
      'booking_date',v_booking.created_at,'payment_date',v_booking.payment_verified_at,
      'payment_method',case when lower(coalesce(v_booking.payment_method,'')) in
        ('cash','upi','card','online','razorpay','bank_transfer','bank transfer')
        then lower(v_booking.payment_method) else 'other' end,
      'amount_paid',round(v_booking.amount_paid,2),
      'labour_amount',v_bill.labour_amount,
      'materials_amount',0,
      'cancellation_fee_amount',v_fee_paise/100.0,
      'cancellation_fee_items',v_fee_items,
      'total_amount',v_total_paise/100.0,
      'description','सत्यापित भुगतान रसीद — मेहनताना और पुरानी cancellation fee अलग-अलग',
      'document_type','payment_receipt'
    );
  end if;

  select * into v_legacy from srk_private.legacy_booking_financial_evidence
   where booking_id=p_booking_id;
  if not found then raise exception 'Historical financial evidence is unavailable' using errcode='55000'; end if;
  v_labour_paise:=round(coalesce(v_legacy.service_charge,0)*100)::bigint;
  v_materials_paise:=round(coalesce(v_legacy.materials_amount,0)*100)::bigint;
  v_total_paise:=v_labour_paise+v_materials_paise;
  if v_labour_paise<=0 OR round(v_booking.amount_paid*100)::bigint<>v_total_paise
     OR (v_legacy.quoted_amount IS NOT NULL AND round(v_legacy.quoted_amount*100)::bigint<>v_total_paise) THEN
    raise exception 'Historical receipt does not reconcile to archived financial evidence' using errcode='55000';
  end if;

  return jsonb_build_object(
    'receipt_reference','SRK-PAY-'||upper(left(replace(v_booking.id::text,'-',''),12)),
    'booking_id',v_booking.id,'customer_name',v_booking.customer_name,
    'service_type',v_booking.service_type,'address',v_booking.address,
    'district',v_booking.district,'state',v_booking.state,'pincode',v_booking.pincode,
    'booking_date',v_booking.created_at,'payment_date',v_booking.payment_verified_at,
    'payment_method',case when lower(coalesce(v_booking.payment_method,'')) in
      ('cash','upi','card','online','razorpay','bank_transfer','bank transfer')
      then lower(v_booking.payment_method) else 'other' end,
    'amount_paid',v_total_paise/100.0,
    'labour_amount',v_labour_paise/100.0,
    'materials_amount',v_materials_paise/100.0,
    'cancellation_fee_amount',0,
    'cancellation_fee_items','[]'::jsonb,
    'total_amount',v_total_paise/100.0,
    'description','सत्यापित भुगतान रसीद — मेहनताना और सामग्री अलग-अलग',
    'document_type','payment_receipt'
  );
end;
$function$;

revoke all on function public.srk_customer_get_payment_receipt(uuid) from public,anon;
grant execute on function public.srk_customer_get_payment_receipt(uuid) to authenticated;

notify pgrst,'reload schema';
