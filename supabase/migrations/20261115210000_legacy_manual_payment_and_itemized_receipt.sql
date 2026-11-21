-- Preserve old booking-price data only as read-only historical financial evidence.
-- This archive is never used to create, send, approve, dispatch, bill or settle new bookings.
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
  archived_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE srk_private.legacy_booking_financial_evidence ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON srk_private.legacy_booking_financial_evidence FROM PUBLIC,anon,authenticated;
GRANT SELECT ON srk_private.legacy_booking_financial_evidence TO service_role;
COMMENT ON TABLE srk_private.legacy_booking_financial_evidence IS
'Read-only archive of legacy booking price fields for historical receipt, refund and accounting evidence only. Never used by the new booking workflow.';

INSERT INTO srk_private.legacy_booking_financial_evidence
  (booking_id,quoted_amount,service_charge,materials_amount,quote_status,quote_note,
   quote_submitted_at,quote_responded_at,customer_suggested_amount,electrician_quote_kind)
SELECT b.id,b.quoted_amount,b.service_charge,b.materials_amount,b.quote_status,b.quote_note,
       b.quote_submitted_at,b.quote_responded_at,
       nullif(to_jsonb(b)->>'customer_suggested_amount','')::numeric(12,2),
       to_jsonb(b)->>'electrician_quote_kind'
FROM public.service_bookings b
WHERE b.quoted_amount IS NOT NULL OR b.service_charge IS NOT NULL OR b.materials_amount IS DISTINCT FROM 0
   OR b.quote_status IS DISTINCT FROM 'not_submitted' OR b.quote_note IS NOT NULL
   OR b.quote_submitted_at IS NOT NULL OR b.quote_responded_at IS NOT NULL
   OR nullif(to_jsonb(b)->>'customer_suggested_amount','') IS NOT NULL
   OR to_jsonb(b)->>'electrician_quote_kind' IS NOT NULL
ON CONFLICT (booking_id) DO NOTHING;

-- No new legacy/manual payment can be recorded through the retired quote flow.
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

  select * into v_legacy
    from srk_private.legacy_booking_financial_evidence
   where booking_id=p_booking_id;
  if not found then
    raise exception 'Historical payment evidence is unavailable' using errcode='55000';
  end if;
  v_labour_paise:=round(coalesce(v_legacy.service_charge,0)*100)::bigint;
  v_materials_paise:=round(coalesce(v_legacy.materials_amount,0)*100)::bigint;
  v_total_paise:=v_labour_paise+v_materials_paise;
  if v_labour_paise<=0
     or round(v_booking.amount_paid*100)::bigint<>v_total_paise
     or (v_legacy.quoted_amount is not null
         and round(v_legacy.quoted_amount*100)::bigint<>v_total_paise) then
    raise exception 'Historical payment does not match archived labour and materials evidence' using errcode='55000';
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
    'description','ऐतिहासिक सत्यापित भुगतान रसीद — मेहनताना और सामग्री अलग-अलग',
    'document_type','payment_receipt'
  );
end;
$function$;

revoke all on function public.srk_customer_get_payment_receipt(uuid) from public,anon;
grant execute on function public.srk_customer_get_payment_receipt(uuid) to authenticated;

notify pgrst,'reload schema';
