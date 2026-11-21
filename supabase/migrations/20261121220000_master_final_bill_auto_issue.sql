-- Automatically issue a Master final bill once customer completion, all stopped workdays,
-- immutable labour rows and the customer material decision are all ready.

CREATE OR REPLACE FUNCTION public.srk_service_role_build_master_final_bill(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE
  v_booking public.service_bookings%rowtype; v_req public.srk_booking_material_requests%rowtype;
  v_has_req boolean:=false; v_materials bigint:=0; v_labour bigint; v_rows integer;
  v_rate numeric(7,2); v_bill public.srk_booking_final_bills%rowtype;
BEGIN
  IF COALESCE(auth.jwt()->>'role','')<>'service_role' AND pg_trigger_depth()=0 THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.srk_service_category_code IS NULL OR v_booking.status<>'completed'
     OR v_booking.completion_approval_status<>'approved' OR v_booking.customer_completed_at IS NULL THEN
    RAISE EXCEPTION 'CUSTOMER_CONFIRMED_MASTER_COMPLETION_REQUIRED' USING ERRCODE='55000';
  END IF;
  SELECT count(*),coalesce(sum(total_labour_paise),0)::bigint INTO v_rows,v_labour
    FROM public.srk_booking_technician_labour_ledger WHERE booking_id=p_booking_id;
  IF v_rows=0 OR v_labour<=0 THEN RAISE EXCEPTION 'TECHNICIAN_LABOUR_LEDGER_REQUIRED' USING ERRCODE='55000'; END IF;
  IF EXISTS(SELECT 1 FROM public.srk_booking_technician_workdays
    WHERE booking_id=p_booking_id AND status<>'stopped') THEN
    RAISE EXCEPTION 'ALL_TECHNICIAN_WORKDAYS_MUST_BE_STOPPED' USING ERRCODE='55000';
  END IF;
  SELECT * INTO v_req FROM public.srk_booking_material_requests WHERE booking_id=p_booking_id;
  v_has_req:=FOUND;
  IF v_has_req AND v_req.status='pending_customer' THEN RAISE EXCEPTION 'CUSTOMER_MATERIAL_DECISION_PENDING' USING ERRCODE='55000'; END IF;
  IF v_has_req AND v_req.status='approved' THEN v_materials:=v_req.materials_total_paise; END IF;
  v_rate:=v_booking.srk_commission_rate_snapshot;
  IF v_rate IS NULL OR v_rate NOT BETWEEN 0 AND 100 THEN RAISE EXCEPTION 'BOOKING_COMMISSION_SNAPSHOT_REQUIRED' USING ERRCODE='55000'; END IF;
  INSERT INTO public.srk_booking_final_bills(
    booking_id,labour_amount_paise,materials_amount_paise,subtotal_paise,commission_rate_snapshot,
    company_commission_paise,technician_labour_payable_paise,technician_material_reimbursement_paise,
    technician_total_payable_paise,labour_ledger_rows,material_request_id,material_decision
  ) VALUES(
    p_booking_id,v_labour,v_materials,v_labour+v_materials,v_rate,
    round(v_labour*v_rate/100)::bigint,v_labour-round(v_labour*v_rate/100)::bigint,
    v_materials,v_labour-round(v_labour*v_rate/100)::bigint+v_materials,v_rows,
    CASE WHEN v_has_req THEN v_req.id ELSE NULL END,
    CASE WHEN NOT v_has_req THEN 'not_requested' ELSE v_req.status END
  ) ON CONFLICT(booking_id) DO NOTHING;
  SELECT * INTO v_bill FROM public.srk_booking_final_bills WHERE booking_id=p_booking_id;
  IF v_bill.labour_amount_paise<>v_labour OR v_bill.materials_amount_paise<>v_materials
     OR v_bill.labour_ledger_rows<>v_rows OR v_bill.commission_rate_snapshot<>v_rate
     OR v_bill.material_request_id IS DISTINCT FROM CASE WHEN v_has_req THEN v_req.id ELSE NULL END
     OR v_bill.material_decision IS DISTINCT FROM CASE WHEN NOT v_has_req THEN 'not_requested' ELSE v_req.status END
     OR v_bill.subtotal_paise<>v_labour+v_materials THEN RAISE EXCEPTION 'FINAL_BILL_REPLAY_MISMATCH' USING ERRCODE='55000'; END IF;
  RETURN jsonb_build_object('success',true,'bill_id',v_bill.id,'booking_id',p_booking_id,
    'labour_amount_paise',v_bill.labour_amount_paise,'materials_amount_paise',v_bill.materials_amount_paise,
    'subtotal_paise',v_bill.subtotal_paise,'company_commission_paise',v_bill.company_commission_paise,
    'technician_total_payable_paise',v_bill.technician_total_payable_paise,'material_decision',v_bill.material_decision);
END; $$;

CREATE OR REPLACE FUNCTION public.srk_try_build_master_final_bill_from_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE v_booking_id uuid; v_message text; v_booking public.service_bookings%rowtype;
BEGIN
  IF TG_TABLE_NAME='service_bookings' THEN v_booking_id:=NEW.id;
  ELSE v_booking_id:=NEW.booking_id; END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=v_booking_id;
  IF NOT FOUND OR v_booking.srk_service_category_code IS NULL
    OR v_booking.status<>'completed' OR v_booking.completion_approval_status<>'approved'
    OR v_booking.customer_completed_at IS NULL THEN
    RETURN NEW;
  END IF;
  IF EXISTS(SELECT 1 FROM public.srk_booking_final_bills WHERE booking_id=v_booking_id) THEN
    RETURN NEW;
  END IF;
  PERFORM public.srk_service_role_build_master_final_bill(v_booking_id);
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS v_message=MESSAGE_TEXT;
  IF v_message IN ('TECHNICIAN_LABOUR_LEDGER_REQUIRED',
                   'ALL_TECHNICIAN_WORKDAYS_MUST_BE_STOPPED',
                   'CUSTOMER_MATERIAL_DECISION_PENDING') THEN
    RETURN NEW;
  END IF;
  RAISE;
END; $$;
REVOKE ALL ON FUNCTION public.srk_try_build_master_final_bill_from_trigger() FROM PUBLIC,anon,authenticated;

DROP TRIGGER IF EXISTS srk_master_final_bill_after_customer_completion ON public.service_bookings;
CREATE TRIGGER srk_master_final_bill_after_customer_completion
AFTER UPDATE OF status,completion_approval_status,customer_completed_at ON public.service_bookings
FOR EACH ROW WHEN (NEW.srk_service_category_code IS NOT NULL)
EXECUTE FUNCTION public.srk_try_build_master_final_bill_from_trigger();

DROP TRIGGER IF EXISTS srk_master_final_bill_after_material_decision ON public.srk_booking_material_requests;
CREATE TRIGGER srk_master_final_bill_after_material_decision
AFTER UPDATE OF status ON public.srk_booking_material_requests
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION public.srk_try_build_master_final_bill_from_trigger();

DROP TRIGGER IF EXISTS srk_master_final_bill_after_labour_ledger ON public.srk_booking_technician_labour_ledger;
CREATE TRIGGER srk_master_final_bill_after_labour_ledger
AFTER INSERT ON public.srk_booking_technician_labour_ledger
FOR EACH ROW EXECUTE FUNCTION public.srk_try_build_master_final_bill_from_trigger();

COMMENT ON FUNCTION public.srk_try_build_master_final_bill_from_trigger() IS
 'Retries Master final-bill creation after customer completion, final Technician daily ledger insertion, or customer material decision. Expected not-ready states are deferred without blocking the originating action.';
