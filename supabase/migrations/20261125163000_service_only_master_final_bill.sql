-- New Master final bills are service/labour only.
-- Existing legacy records and compatibility columns remain untouched.
-- Feature branch only; never apply to Main without explicit approval.

CREATE OR REPLACE FUNCTION public.srk_service_role_build_master_final_bill(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE
 v_booking public.service_bookings%rowtype;
 v_labour bigint;
 v_rows integer;
 v_rate numeric(7,2);
 v_commission bigint;
 v_bill public.srk_booking_final_bills%rowtype;
BEGIN
 IF coalesce(auth.role(),current_setting('request.jwt.claim.role',true))<>'service_role' THEN
  RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
 END IF;
 SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND OR v_booking.srk_service_category_code IS NULL OR v_booking.status<>'completed'
  OR v_booking.completion_approval_status<>'approved' OR v_booking.customer_completed_at IS NULL THEN
  RAISE EXCEPTION 'CUSTOMER_CONFIRMED_MASTER_COMPLETION_REQUIRED' USING ERRCODE='55000';
 END IF;
 SELECT count(*),coalesce(sum(total_labour_paise),0)::bigint INTO v_rows,v_labour
  FROM public.srk_booking_technician_labour_ledger WHERE booking_id=p_booking_id;
 IF v_rows=0 OR v_labour<=0 THEN RAISE EXCEPTION 'TECHNICIAN_LABOUR_LEDGER_REQUIRED'; END IF;
 IF EXISTS(SELECT 1 FROM public.srk_booking_technician_workdays
  WHERE booking_id=p_booking_id AND status<>'stopped') THEN
  RAISE EXCEPTION 'ALL_TECHNICIAN_WORKDAYS_MUST_BE_STOPPED';
 END IF;
 v_rate:=v_booking.srk_commission_rate_snapshot;
 IF v_rate IS NULL OR v_rate NOT BETWEEN 0 AND 100 THEN
  RAISE EXCEPTION 'BOOKING_COMMISSION_SNAPSHOT_REQUIRED';
 END IF;
 v_commission:=round(v_labour*v_rate/100)::bigint;

 -- Legacy compatibility columns are written as zero; new bill total is service only.
 INSERT INTO public.srk_booking_final_bills(
  booking_id,labour_amount_paise,materials_amount_paise,subtotal_paise,commission_rate_snapshot,
  company_commission_paise,technician_labour_payable_paise,technician_material_reimbursement_paise,
  technician_total_payable_paise,labour_ledger_rows,material_request_id,material_decision
 ) VALUES(p_booking_id,v_labour,0,v_labour,v_rate,v_commission,v_labour-v_commission,0,
  v_labour-v_commission,v_rows,NULL,'not_requested') ON CONFLICT(booking_id) DO NOTHING;

 SELECT * INTO v_bill FROM public.srk_booking_final_bills WHERE booking_id=p_booking_id;
 IF v_bill.labour_amount_paise<>v_labour OR v_bill.subtotal_paise<>v_labour
  OR v_bill.company_commission_paise<>v_commission
  OR v_bill.technician_labour_payable_paise<>v_labour-v_commission
  OR v_bill.labour_ledger_rows<>v_rows THEN
  RAISE EXCEPTION 'FINAL_BILL_REPLAY_MISMATCH' USING ERRCODE='55000';
 END IF;
 RETURN jsonb_build_object('success',true,'bill_id',v_bill.id,'booking_id',p_booking_id,
  'service_amount_paise',v_bill.labour_amount_paise,'company_commission_paise',v_bill.company_commission_paise,
  'technician_net_earning_paise',v_bill.technician_labour_payable_paise);
END; $$;

REVOKE ALL ON FUNCTION public.srk_service_role_build_master_final_bill(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_role_build_master_final_bill(uuid) TO service_role;

-- Retain prior request records but disable the obsolete request/approval RPC entry points.
REVOKE ALL ON FUNCTION public.srk_technician_submit_booking_materials(uuid,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.srk_customer_decide_booking_materials(uuid,text,text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.srk_guard_master_payable_service_only()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $$
BEGIN
 NEW.materials_reimbursement_paise:=0;
 NEW.total_payable_paise:=NEW.labour_payable_paise;
 RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION public.srk_guard_master_payable_service_only() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_master_payable_service_only_insert ON public.srk_master_technician_payables;
CREATE TRIGGER srk_master_payable_service_only_insert
BEFORE INSERT ON public.srk_master_technician_payables
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_master_payable_service_only();

COMMENT ON FUNCTION public.srk_service_role_build_master_final_bill(uuid) IS
 'Creates new Master final bills from Technician service/labour ledger only. Historical rows remain unchanged.';
