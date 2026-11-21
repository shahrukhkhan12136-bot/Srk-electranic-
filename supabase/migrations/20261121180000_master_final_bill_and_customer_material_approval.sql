-- Master consolidated final bill + customer-approved material requests.
-- Feature-branch source only; do not apply to any database or enable booking flags yet.

ALTER TABLE public.service_bookings
  ADD COLUMN IF NOT EXISTS srk_commission_rate_snapshot numeric(7,2);

UPDATE public.service_bookings
   SET srk_commission_rate_snapshot=commission_rate
 WHERE srk_commission_rate_snapshot IS NULL
   AND commission_rate BETWEEN 0 AND 100;

CREATE OR REPLACE FUNCTION public.srk_snapshot_master_booking_commission()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF NEW.srk_commission_rate_snapshot IS NULL THEN
    NEW.srk_commission_rate_snapshot:=NEW.commission_rate;
  END IF;
  RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION public.srk_snapshot_master_booking_commission() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_snapshot_master_booking_commission ON public.service_bookings;
CREATE TRIGGER srk_snapshot_master_booking_commission
BEFORE INSERT ON public.service_bookings
FOR EACH ROW EXECUTE FUNCTION public.srk_snapshot_master_booking_commission();

CREATE TABLE IF NOT EXISTS public.srk_booking_material_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL UNIQUE REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  submitted_by_technician_id uuid NOT NULL REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'pending_customer' CHECK(status IN ('pending_customer','approved','rejected')),
  materials_total_paise bigint NOT NULL CHECK(materials_total_paise>0),
  submitted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  decided_at timestamptz,
  decided_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  decision_note text CHECK(decision_note IS NULL OR char_length(decision_note)<=500),
  CHECK((status='pending_customer' AND decided_at IS NULL AND decided_by IS NULL)
     OR (status IN ('approved','rejected') AND decided_at IS NOT NULL AND decided_by IS NOT NULL))
);
CREATE TABLE IF NOT EXISTS public.srk_booking_material_request_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.srk_booking_material_requests(id) ON DELETE RESTRICT,
  line_number smallint NOT NULL CHECK(line_number BETWEEN 1 AND 50),
  item_name text NOT NULL CHECK(char_length(btrim(item_name)) BETWEEN 1 AND 160),
  quantity numeric(12,3) NOT NULL CHECK(quantity>0 AND quantity<=100000),
  unit_price_paise bigint NOT NULL CHECK(unit_price_paise>0),
  line_total_paise bigint NOT NULL CHECK(line_total_paise=round(quantity*unit_price_paise)::bigint),
  UNIQUE(request_id,line_number)
);
CREATE TABLE IF NOT EXISTS public.srk_booking_material_decision_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.srk_booking_material_requests(id) ON DELETE RESTRICT,
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  customer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  decision text NOT NULL CHECK(decision IN ('approved','rejected')),
  note text,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE IF NOT EXISTS public.srk_booking_final_bills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL UNIQUE REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  labour_amount_paise bigint NOT NULL CHECK(labour_amount_paise>0),
  materials_amount_paise bigint NOT NULL DEFAULT 0 CHECK(materials_amount_paise>=0),
  subtotal_paise bigint NOT NULL CHECK(subtotal_paise=labour_amount_paise+materials_amount_paise),
  commission_rate_snapshot numeric(7,2) NOT NULL CHECK(commission_rate_snapshot BETWEEN 0 AND 100),
  company_commission_paise bigint NOT NULL CHECK(company_commission_paise=round(labour_amount_paise*commission_rate_snapshot/100)::bigint),
  technician_labour_payable_paise bigint NOT NULL CHECK(technician_labour_payable_paise=labour_amount_paise-company_commission_paise),
  technician_material_reimbursement_paise bigint NOT NULL CHECK(technician_material_reimbursement_paise=materials_amount_paise),
  technician_total_payable_paise bigint NOT NULL CHECK(technician_total_payable_paise=technician_labour_payable_paise+technician_material_reimbursement_paise),
  labour_ledger_rows integer NOT NULL CHECK(labour_ledger_rows>0),
  material_request_id uuid REFERENCES public.srk_booking_material_requests(id) ON DELETE RESTRICT,
  material_decision text NOT NULL CHECK(material_decision IN ('not_requested','approved','rejected')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

ALTER TABLE public.srk_booking_material_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_booking_material_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_booking_material_decision_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_booking_final_bills ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_booking_material_requests,public.srk_booking_material_request_items,
 public.srk_booking_material_decision_events,public.srk_booking_final_bills FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.srk_booking_material_requests,public.srk_booking_material_request_items,
 public.srk_booking_material_decision_events,public.srk_booking_final_bills TO service_role;

CREATE OR REPLACE FUNCTION public.srk_guard_master_financial_history()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN RAISE EXCEPTION 'MASTER_FINANCIAL_HISTORY_IS_IMMUTABLE' USING ERRCODE='55000'; END; $$;
REVOKE ALL ON FUNCTION public.srk_guard_master_financial_history() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_master_material_items_immutable ON public.srk_booking_material_request_items;
CREATE TRIGGER srk_master_material_items_immutable BEFORE UPDATE OR DELETE
ON public.srk_booking_material_request_items FOR EACH ROW
EXECUTE FUNCTION public.srk_guard_master_financial_history();
DROP TRIGGER IF EXISTS srk_master_material_decisions_append_only ON public.srk_booking_material_decision_events;
CREATE TRIGGER srk_master_material_decisions_append_only BEFORE UPDATE OR DELETE
ON public.srk_booking_material_decision_events FOR EACH ROW
EXECUTE FUNCTION public.srk_guard_master_financial_history();
DROP TRIGGER IF EXISTS srk_master_final_bill_immutable ON public.srk_booking_final_bills;
CREATE TRIGGER srk_master_final_bill_immutable BEFORE UPDATE OR DELETE
ON public.srk_booking_final_bills FOR EACH ROW
EXECUTE FUNCTION public.srk_guard_master_financial_history();

CREATE OR REPLACE FUNCTION public.srk_technician_submit_booking_materials(p_booking_id uuid,p_items jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE v_uid uuid:=auth.uid(); v_tid uuid; v_rid uuid; v_total bigint; v_count integer;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_booking_id IS NULL OR jsonb_typeof(p_items)<>'array'
     OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 50 THEN
    RAISE EXCEPTION 'MATERIAL_ITEMS_MUST_BE_AN_ARRAY_OF_1_TO_50' USING ERRCODE='22023';
  END IF;
  SELECT id INTO v_tid FROM public.srk_technicians WHERE auth_user_id=v_uid;
  IF v_tid IS NULL OR NOT EXISTS(SELECT 1 FROM public.srk_booking_technician_assignments
    WHERE booking_id=p_booking_id AND technician_id=v_tid AND assignment_status IN ('accepted','active')) THEN
    RAISE EXCEPTION 'ACTIVE_BOOKING_TECHNICIAN_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.service_bookings
    WHERE id=p_booking_id AND srk_service_category_code IS NOT NULL AND status IN ('in_progress','completed')) THEN
    RAISE EXCEPTION 'MASTER_ACTIVE_OR_COMPLETED_BOOKING_REQUIRED' USING ERRCODE='55000';
  END IF;
  IF EXISTS(SELECT 1 FROM public.srk_booking_final_bills WHERE booking_id=p_booking_id)
     OR EXISTS(SELECT 1 FROM public.srk_booking_material_requests WHERE booking_id=p_booking_id) THEN
    RAISE EXCEPTION 'MATERIAL_REQUEST_OR_FINAL_BILL_ALREADY_EXISTS' USING ERRCODE='23505';
  END IF;
  IF EXISTS(SELECT 1 FROM jsonb_to_recordset(p_items) AS x(name text,quantity numeric,unit_price_paise bigint)
    WHERE name IS NULL OR char_length(btrim(name)) NOT BETWEEN 1 AND 160
       OR quantity IS NULL OR quantity<=0 OR quantity>100000
       OR unit_price_paise IS NULL OR unit_price_paise<=0 OR unit_price_paise>1000000000) THEN
    RAISE EXCEPTION 'INVALID_MATERIAL_ITEM' USING ERRCODE='22023';
  END IF;
  SELECT sum(round(x.quantity*x.unit_price_paise)::bigint),count(*)
    INTO v_total,v_count
    FROM jsonb_to_recordset(p_items) AS x(name text,quantity numeric,unit_price_paise bigint);
  IF v_count NOT BETWEEN 1 AND 50 OR v_total IS NULL OR v_total<=0 OR v_total>100000000000 THEN
    RAISE EXCEPTION 'MATERIAL_TOTAL_OUT_OF_RANGE' USING ERRCODE='22003';
  END IF;
  INSERT INTO public.srk_booking_material_requests(booking_id,submitted_by_technician_id,materials_total_paise)
  VALUES(p_booking_id,v_tid,v_total) RETURNING id INTO v_rid;
  INSERT INTO public.srk_booking_material_request_items(request_id,line_number,item_name,quantity,unit_price_paise,line_total_paise)
  SELECT v_rid,x.ordinality::smallint,btrim(x.name),x.quantity,x.unit_price_paise,
         round(x.quantity*x.unit_price_paise)::bigint
    FROM jsonb_to_recordset(p_items) WITH ORDINALITY AS x(name text,quantity numeric,unit_price_paise bigint,ordinality bigint);
  RETURN jsonb_build_object('success',true,'request_id',v_rid,'items',v_count,
    'materials_total_paise',v_total,'status','pending_customer');
END; $$;

CREATE OR REPLACE FUNCTION public.srk_customer_decide_booking_materials(p_request_id uuid,p_decision text,p_note text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE v_uid uuid:=auth.uid(); v_req public.srk_booking_material_requests%rowtype; v_customer uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'CUSTOMER_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_decision NOT IN ('approved','rejected') OR (p_note IS NOT NULL AND char_length(p_note)>500) THEN
    RAISE EXCEPTION 'INVALID_MATERIAL_DECISION' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_req FROM public.srk_booking_material_requests WHERE id=p_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'MATERIAL_REQUEST_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  SELECT customer_user_id INTO v_customer FROM public.service_bookings WHERE id=v_req.booking_id;
  IF v_customer IS DISTINCT FROM v_uid THEN RAISE EXCEPTION 'BOOKING_CUSTOMER_REQUIRED' USING ERRCODE='42501'; END IF;
  IF v_req.status<>'pending_customer' OR EXISTS(SELECT 1 FROM public.srk_booking_final_bills WHERE booking_id=v_req.booking_id) THEN
    RAISE EXCEPTION 'MATERIAL_DECISION_ALREADY_CLOSED' USING ERRCODE='55000';
  END IF;
  UPDATE public.srk_booking_material_requests SET status=p_decision,decided_at=clock_timestamp(),
    decided_by=v_uid,decision_note=p_note WHERE id=p_request_id;
  INSERT INTO public.srk_booking_material_decision_events(request_id,booking_id,customer_user_id,decision,note)
  VALUES(p_request_id,v_req.booking_id,v_uid,p_decision,p_note);
  RETURN jsonb_build_object('success',true,'decision',p_decision,
    'materials_amount_paise',CASE WHEN p_decision='approved' THEN v_req.materials_total_paise ELSE 0 END);
END; $$;

CREATE OR REPLACE FUNCTION public.srk_service_role_build_master_final_bill(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE
  v_booking public.service_bookings%rowtype; v_req public.srk_booking_material_requests%rowtype;
  v_has_req boolean:=false; v_materials bigint:=0; v_labour bigint; v_rows integer;
  v_rate numeric(7,2); v_bill public.srk_booking_final_bills%rowtype;
BEGIN
  IF COALESCE(auth.role(),current_setting('request.jwt.claim.role',true))<>'service_role' THEN
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
  SELECT * INTO v_req FROM public.srk_booking_material_requests WHERE booking_id=p_booking_id;
  v_has_req:=FOUND;
  IF v_has_req AND v_req.status='pending_customer' THEN RAISE EXCEPTION 'CUSTOMER_MATERIAL_DECISION_PENDING'; END IF;
  IF v_has_req AND v_req.status='approved' THEN v_materials:=v_req.materials_total_paise; END IF;
  v_rate:=v_booking.srk_commission_rate_snapshot;
  IF v_rate IS NULL OR v_rate NOT BETWEEN 0 AND 100 THEN RAISE EXCEPTION 'BOOKING_COMMISSION_SNAPSHOT_REQUIRED'; END IF;
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
     OR v_bill.labour_ledger_rows<>v_rows THEN RAISE EXCEPTION 'FINAL_BILL_REPLAY_MISMATCH'; END IF;
  RETURN jsonb_build_object('success',true,'bill_id',v_bill.id,'booking_id',p_booking_id,
    'labour_amount_paise',v_bill.labour_amount_paise,'materials_amount_paise',v_bill.materials_amount_paise,
    'subtotal_paise',v_bill.subtotal_paise,'company_commission_paise',v_bill.company_commission_paise,
    'technician_total_payable_paise',v_bill.technician_total_payable_paise,'material_decision',v_bill.material_decision);
END; $$;

REVOKE ALL ON FUNCTION public.srk_technician_submit_booking_materials(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_submit_booking_materials(uuid,jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_customer_decide_booking_materials(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_decide_booking_materials(uuid,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_service_role_build_master_final_bill(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_role_build_master_final_bill(uuid) TO service_role;

COMMENT ON TABLE public.srk_booking_material_requests IS
  'Technician-submitted material estimate. Customer approval/rejection is required before the final bill can be issued.';
COMMENT ON TABLE public.srk_booking_final_bills IS
  'Immutable consolidated Master bill from all Technician daily labour ledger rows and only customer-approved materials. Commission applies to labour only; materials are passed through separately.';
