-- SRK ELECTRONIC Master: Technician-collected cash commission dues and future online offsets.
-- Feature Branch source only. Do not apply to Production without the separately approved rollout.
-- 85/15 split remains unchanged. Gateway fees are not part of this calculation.

ALTER TABLE public.srk_master_technician_payables
  ADD COLUMN IF NOT EXISTS commission_recovery_paise bigint NOT NULL DEFAULT 0
    CHECK (commission_recovery_paise >= 0);

ALTER TABLE public.srk_master_technician_payables
  DROP CONSTRAINT IF EXISTS srk_master_technician_payables_payout_status_check;
ALTER TABLE public.srk_master_technician_payables
  ADD CONSTRAINT srk_master_technician_payables_payout_status_check
  CHECK (payout_status IN ('pending','requested','paid','blocked','refunded','cash_collected','offset'));

ALTER TABLE public.srk_master_technician_payables
  DROP CONSTRAINT IF EXISTS srk_master_technician_payables_total_payable_paise_check;
ALTER TABLE public.srk_master_technician_payables
  ADD CONSTRAINT srk_master_technician_payables_total_payable_paise_check
  CHECK (
    total_payable_paise = labour_payable_paise + materials_reimbursement_paise - commission_recovery_paise
    AND total_payable_paise >= 0
    AND commission_recovery_paise <= labour_payable_paise
  );

CREATE TABLE IF NOT EXISTS public.srk_master_technician_commission_dues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  payment_id uuid NOT NULL REFERENCES public.srk_master_booking_payments(id) ON DELETE RESTRICT,
  technician_id uuid NOT NULL REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  commission_due_paise bigint NOT NULL CHECK (commission_due_paise > 0),
  commission_recovered_paise bigint NOT NULL DEFAULT 0 CHECK (
    commission_recovered_paise >= 0 AND commission_recovered_paise <= commission_due_paise
  ),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','partially_recovered','recovered','refunded')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (booking_id,technician_id)
);

CREATE TABLE IF NOT EXISTS public.srk_master_technician_commission_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  technician_id uuid NOT NULL REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  payment_id uuid NOT NULL REFERENCES public.srk_master_booking_payments(id) ON DELETE RESTRICT,
  payable_id uuid REFERENCES public.srk_master_technician_payables(id) ON DELETE RESTRICT,
  event_type text NOT NULL CHECK (event_type IN ('cash_commission_due','online_commission_recovered','cash_payment_refunded')),
  amount_paise bigint NOT NULL CHECK (amount_paise > 0),
  source_due_id uuid REFERENCES public.srk_master_technician_commission_dues(id) ON DELETE RESTRICT,
  event_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

ALTER TABLE public.srk_master_technician_commission_dues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_master_technician_commission_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_master_technician_commission_dues,public.srk_master_technician_commission_events
  FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.srk_master_technician_commission_dues,public.srk_master_technician_commission_events
  TO service_role;

CREATE OR REPLACE FUNCTION public.srk_guard_master_commission_events()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN
  RAISE EXCEPTION 'MASTER_COMMISSION_EVENTS_ARE_APPEND_ONLY' USING ERRCODE='55000';
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_guard_master_commission_events() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_master_technician_commission_events_append_only
  ON public.srk_master_technician_commission_events;
CREATE TRIGGER srk_master_technician_commission_events_append_only
BEFORE UPDATE OR DELETE ON public.srk_master_technician_commission_events
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_master_commission_events();

CREATE OR REPLACE FUNCTION public.srk_apply_master_cash_commission_and_online_offset()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_method text;
  v_due bigint;
  v_left bigint;
  v_take bigint;
  v_due_row record;
BEGIN
  -- Serialize collection/offset work for this Technician.
  PERFORM 1 FROM public.srk_technicians WHERE id=NEW.technician_id FOR UPDATE;
  SELECT payment_method INTO v_method
  FROM public.srk_master_booking_payments WHERE id=NEW.payment_id;
  IF v_method IS NULL THEN RAISE EXCEPTION 'MASTER_PAYMENT_METHOD_NOT_FOUND'; END IF;

  IF v_method='cash' THEN
    -- Customer paid the Technician directly: their 85% is already in hand;
    -- the 15% company commission becomes a recoverable wallet obligation.
    UPDATE public.srk_master_technician_payables
    SET payout_status='cash_collected'
    WHERE id=NEW.id;
    IF NEW.company_commission_paise > 0 THEN
      INSERT INTO public.srk_master_technician_commission_dues(
        booking_id,payment_id,technician_id,commission_due_paise
      ) VALUES(NEW.booking_id,NEW.payment_id,NEW.technician_id,NEW.company_commission_paise)
      RETURNING id INTO v_due_row;
      INSERT INTO public.srk_master_technician_commission_events(
        technician_id,booking_id,payment_id,payable_id,event_type,amount_paise,source_due_id,event_data
      ) VALUES(
        NEW.technician_id,NEW.booking_id,NEW.payment_id,NEW.id,'cash_commission_due',
        NEW.company_commission_paise,v_due_row.id,
        jsonb_build_object('collection_method','cash','customer_amount_paise',NEW.labour_gross_paise+NEW.materials_reimbursement_paise)
      );
    END IF;
    RETURN NEW;
  END IF;

  -- Company-collected UPI/bank/Razorpay money creates an 85% payable.
  -- First recover any older cash commission due, oldest booking first.
  v_left:=NEW.labour_payable_paise;
  FOR v_due_row IN
    SELECT * FROM public.srk_master_technician_commission_dues
    WHERE technician_id=NEW.technician_id
      AND status IN ('open','partially_recovered')
      AND commission_recovered_paise < commission_due_paise
    ORDER BY created_at,id
    FOR UPDATE
  LOOP
    EXIT WHEN v_left<=0;
    v_due:=v_due_row.commission_due_paise-v_due_row.commission_recovered_paise;
    v_take:=least(v_left,v_due);
    UPDATE public.srk_master_technician_commission_dues
    SET commission_recovered_paise=commission_recovered_paise+v_take,
        status=CASE WHEN commission_recovered_paise+v_take=commission_due_paise
          THEN 'recovered' ELSE 'partially_recovered' END
    WHERE id=v_due_row.id;
    UPDATE public.srk_master_technician_payables
    SET commission_recovery_paise=commission_recovery_paise+v_take,
        total_payable_paise=total_payable_paise-v_take,
        payout_status=CASE WHEN total_payable_paise-v_take=0 THEN 'offset' ELSE payout_status END
    WHERE id=NEW.id;
    INSERT INTO public.srk_master_technician_commission_events(
      technician_id,booking_id,payment_id,payable_id,event_type,amount_paise,source_due_id,event_data
    ) VALUES(
      NEW.technician_id,NEW.booking_id,NEW.payment_id,NEW.id,'online_commission_recovered',
      v_take,v_due_row.id,jsonb_build_object('source','future_company_collected_payment')
    );
    v_left:=v_left-v_take;
  END LOOP;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_apply_master_cash_commission_and_online_offset() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_master_apply_cash_commission_online_offset
  ON public.srk_master_technician_payables;
CREATE TRIGGER srk_master_apply_cash_commission_online_offset
AFTER INSERT ON public.srk_master_technician_payables
FOR EACH ROW EXECUTE FUNCTION public.srk_apply_master_cash_commission_and_online_offset();

CREATE OR REPLACE FUNCTION public.srk_master_wallet_summary()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $function$
DECLARE v_uid uuid:=auth.uid(); v_tid uuid; v_out jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT id INTO v_tid FROM public.srk_technicians WHERE auth_user_id=v_uid AND account_status='active';
  IF v_tid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_IDENTITY_NOT_LINKED' USING ERRCODE='P0002'; END IF;
  SELECT jsonb_build_object(
    'technician_id',v_tid,
    'earned_paise',coalesce(sum(p.labour_payable_paise+p.materials_reimbursement_paise),0),
    'pending_paise',coalesce(sum(p.total_payable_paise) FILTER(WHERE p.payout_status='pending'),0),
    'requested_paise',coalesce(sum(p.total_payable_paise) FILTER(WHERE p.payout_status='requested'),0),
    'paid_paise',coalesce(sum(p.total_payable_paise) FILTER(WHERE p.payout_status='paid'),0),
    'cash_collected_paise',coalesce(sum(p.labour_payable_paise+p.materials_reimbursement_paise) FILTER(WHERE p.payout_status='cash_collected'),0),
    'commission_due_paise',coalesce((SELECT sum(d.commission_due_paise-d.commission_recovered_paise)
      FROM public.srk_master_technician_commission_dues d
      WHERE d.technician_id=v_tid AND d.status IN ('open','partially_recovered')),0),
    'commission_recovered_paise',coalesce((SELECT sum(e.amount_paise)
      FROM public.srk_master_technician_commission_events e
      WHERE e.technician_id=v_tid AND e.event_type='online_commission_recovered'),0),
    'blocked_paise',coalesce(sum(p.total_payable_paise) FILTER(WHERE p.payout_status='blocked'),0),
    'refunded_paise',coalesce(sum(p.total_payable_paise) FILTER(WHERE p.payout_status='refunded'),0),
    'offset_paise',coalesce(sum(p.commission_recovery_paise),0),
    'currency','INR',
    'payables',coalesce(jsonb_agg(jsonb_build_object(
      'payable_id',p.id,'booking_id',p.booking_id,'amount_paise',p.total_payable_paise,
      'commission_recovery_paise',p.commission_recovery_paise,'status',p.payout_status,
      'payment_method',m.payment_method,'created_at',p.created_at
    ) ORDER BY p.created_at DESC) FILTER(WHERE p.id IS NOT NULL),'[]'::jsonb),
    'commission_dues',coalesce((SELECT jsonb_agg(jsonb_build_object(
      'booking_id',d.booking_id,'due_paise',d.commission_due_paise,
      'recovered_paise',d.commission_recovered_paise,'outstanding_paise',d.commission_due_paise-d.commission_recovered_paise,
      'status',d.status,'created_at',d.created_at
    ) ORDER BY d.created_at DESC) FROM public.srk_master_technician_commission_dues d
      WHERE d.technician_id=v_tid),'[]'::jsonb)
  ) INTO v_out
  FROM public.srk_master_technician_payables p
  JOIN public.srk_master_booking_payments m ON m.id=p.payment_id
  WHERE p.technician_id=v_tid;
  RETURN coalesce(v_out,jsonb_build_object('technician_id',v_tid,'earned_paise',0,'pending_paise',0,
    'requested_paise',0,'paid_paise',0,'cash_collected_paise',0,'commission_due_paise',0,
    'commission_recovered_paise',0,'blocked_paise',0,'refunded_paise',0,'offset_paise',0,
    'currency','INR','payables','[]'::jsonb,'commission_dues','[]'::jsonb));
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_master_wallet_summary() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_master_wallet_summary() TO authenticated;

COMMENT ON TABLE public.srk_master_technician_commission_dues IS
  '15 percent SRK company commission owed when Technician directly collects a cash booking; future company-collected online/manual UPI/bank earnings offset this due.';
COMMENT ON TABLE public.srk_master_technician_commission_events IS
  'Append-only audit of cash commission dues and future online commission recovery.';
