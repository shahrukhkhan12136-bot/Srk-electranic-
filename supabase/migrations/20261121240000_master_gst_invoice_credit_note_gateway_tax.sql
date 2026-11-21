-- Configurable GST snapshots, tax invoices, credit notes and gateway-fee GST evidence.
-- Feature branch source only. No database has been modified or migration applied.
CREATE TABLE IF NOT EXISTS public.srk_gst_indian_state_codes(
 state_code char(2) PRIMARY KEY CHECK(state_code ~ '^[0-9]{2}$'),
 state_name text NOT NULL UNIQUE
);
INSERT INTO public.srk_gst_indian_state_codes(state_code,state_name) VALUES
 ('01','Jammu and Kashmir'),('02','Himachal Pradesh'),('03','Punjab'),('04','Chandigarh'),
 ('05','Uttarakhand'),('06','Haryana'),('07','Delhi'),('08','Rajasthan'),('09','Uttar Pradesh'),
 ('10','Bihar'),('11','Sikkim'),('12','Arunachal Pradesh'),('13','Nagaland'),('14','Manipur'),
 ('15','Mizoram'),('16','Tripura'),('17','Meghalaya'),('18','Assam'),('19','West Bengal'),
 ('20','Jharkhand'),('21','Odisha'),('22','Chhattisgarh'),('23','Madhya Pradesh'),
 ('24','Gujarat'),('26','Dadra and Nagar Haveli and Daman and Diu'),('27','Maharashtra'),
 ('28','Andhra Pradesh (Old)'),('29','Karnataka'),('30','Goa'),('31','Lakshadweep'),
 ('32','Kerala'),('33','Tamil Nadu'),('34','Puducherry'),('35','Andaman and Nicobar Islands'),
 ('36','Telangana'),('37','Andhra Pradesh'),('38','Ladakh')
ON CONFLICT(state_code) DO UPDATE SET state_name=EXCLUDED.state_name;

CREATE TABLE IF NOT EXISTS public.srk_gst_company_profiles(
 id smallint PRIMARY KEY DEFAULT 1 CHECK(id=1),
 registration_status text NOT NULL CHECK(registration_status IN ('registered','unregistered')),
 legal_name text NOT NULL CHECK(char_length(btrim(legal_name)) BETWEEN 2 AND 200),
 gstin text,
 supplier_state_code char(2) REFERENCES public.srk_gst_indian_state_codes(state_code),
 invoice_prefix text NOT NULL DEFAULT 'SRK' CHECK(invoice_prefix ~ '^[A-Z0-9-]{2,12}$'),
 effective_from date NOT NULL,
 version integer NOT NULL CHECK(version>0),
 configured_by uuid NOT NULL REFERENCES auth.users(id),
 configured_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK((registration_status='registered' AND gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$' AND supplier_state_code IS NOT NULL)
    OR (registration_status='unregistered' AND gstin IS NULL))
);
CREATE TABLE IF NOT EXISTS public.srk_gst_service_rate_rules(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 service_category_code text NOT NULL,
 service_code text NOT NULL,
 component text NOT NULL CHECK(component IN ('labour','materials')),
 taxable boolean NOT NULL,
 gst_rate_basis_points integer NOT NULL DEFAULT 0 CHECK(gst_rate_basis_points BETWEEN 0 AND 2800),
 effective_from date NOT NULL,
 version integer NOT NULL CHECK(version>0),
 active boolean NOT NULL DEFAULT true,
 configured_by uuid NOT NULL REFERENCES auth.users(id),
 configured_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK((taxable AND gst_rate_basis_points>0) OR (NOT taxable AND gst_rate_basis_points=0)),
 UNIQUE(service_category_code,service_code,component,version)
);
CREATE UNIQUE INDEX IF NOT EXISTS srk_gst_one_active_rule_per_component
 ON public.srk_gst_service_rate_rules(service_category_code,service_code,component) WHERE active;

CREATE TABLE IF NOT EXISTS public.srk_booking_tax_snapshots(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 booking_id uuid NOT NULL UNIQUE REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
 final_bill_id uuid NOT NULL UNIQUE REFERENCES public.srk_booking_final_bills(id) ON DELETE RESTRICT,
 company_profile_version integer NOT NULL,
 registration_status text NOT NULL CHECK(registration_status IN ('registered','unregistered')),
 supplier_gstin text,
 supplier_state_code char(2),
 place_of_supply_state_code char(2) NOT NULL REFERENCES public.srk_gst_indian_state_codes(state_code),
 labour_amount_paise bigint NOT NULL CHECK(labour_amount_paise>0),
 materials_amount_paise bigint NOT NULL CHECK(materials_amount_paise>=0),
 labour_taxable boolean NOT NULL,
 labour_rate_basis_points integer NOT NULL CHECK(labour_rate_basis_points BETWEEN 0 AND 2800),
 labour_taxable_value_paise bigint NOT NULL CHECK(labour_taxable_value_paise>=0),
 labour_cgst_paise bigint NOT NULL DEFAULT 0,
 labour_sgst_paise bigint NOT NULL DEFAULT 0,
 labour_igst_paise bigint NOT NULL DEFAULT 0,
 materials_taxable boolean NOT NULL,
 materials_rate_basis_points integer NOT NULL CHECK(materials_rate_basis_points BETWEEN 0 AND 2800),
 materials_taxable_value_paise bigint NOT NULL CHECK(materials_taxable_value_paise>=0),
 materials_cgst_paise bigint NOT NULL DEFAULT 0,
 materials_sgst_paise bigint NOT NULL DEFAULT 0,
 materials_igst_paise bigint NOT NULL DEFAULT 0,
 total_cgst_paise bigint NOT NULL,
 total_sgst_paise bigint NOT NULL,
 total_igst_paise bigint NOT NULL,
 total_tax_paise bigint NOT NULL,
 taxable_value_paise bigint NOT NULL,
 gross_before_tax_paise bigint NOT NULL,
 total_due_paise bigint NOT NULL,
 tax_treatment text NOT NULL CHECK(tax_treatment IN ('intra_state','inter_state','unregistered')),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(total_tax_paise=total_cgst_paise+total_sgst_paise+total_igst_paise),
 CHECK(total_due_paise=gross_before_tax_paise+total_tax_paise)
);
CREATE TABLE IF NOT EXISTS public.srk_master_tax_invoices(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
 payment_id uuid NOT NULL UNIQUE REFERENCES public.srk_master_booking_payments(id) ON DELETE RESTRICT,
 tax_snapshot_id uuid NOT NULL REFERENCES public.srk_booking_tax_snapshots(id) ON DELETE RESTRICT,
 invoice_number text NOT NULL UNIQUE,
 document_status text NOT NULL DEFAULT 'issued' CHECK(document_status IN ('issued','credited_full')),
 invoice_snapshot jsonb NOT NULL,
 issued_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(booking_id)
);
CREATE TABLE IF NOT EXISTS public.srk_master_tax_credit_notes(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 invoice_id uuid NOT NULL UNIQUE REFERENCES public.srk_master_tax_invoices(id) ON DELETE RESTRICT,
 payment_id uuid NOT NULL REFERENCES public.srk_master_booking_payments(id) ON DELETE RESTRICT,
 credit_note_number text NOT NULL UNIQUE,
 reason text NOT NULL CHECK(char_length(btrim(reason)) BETWEEN 5 AND 250),
 amount_paise bigint NOT NULL CHECK(amount_paise>0),
 tax_breakdown jsonb NOT NULL,
 issued_by uuid,
 issued_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE IF NOT EXISTS public.srk_master_gateway_fee_tax_entries(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 payment_id uuid NOT NULL REFERENCES public.srk_master_booking_payments(id) ON DELETE RESTRICT,
 provider text NOT NULL CHECK(provider IN ('razorpay','other')),
 provider_fee_reference text NOT NULL,
 fee_before_tax_paise bigint NOT NULL CHECK(fee_before_tax_paise>=0),
 gst_rate_basis_points integer NOT NULL CHECK(gst_rate_basis_points BETWEEN 0 AND 2800),
 gst_amount_paise bigint NOT NULL CHECK(gst_amount_paise>=0),
 total_fee_paise bigint NOT NULL CHECK(total_fee_paise=fee_before_tax_paise+gst_amount_paise),
 input_tax_credit_eligible boolean NOT NULL DEFAULT false,
 invoice_reference text,
 reconciliation_note text,
 recorded_by uuid NOT NULL REFERENCES auth.users(id),
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(provider,provider_fee_reference)
);

ALTER TABLE public.srk_gst_indian_state_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_gst_company_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_gst_service_rate_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_booking_tax_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_master_tax_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_master_tax_credit_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_master_gateway_fee_tax_entries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_gst_indian_state_codes,public.srk_gst_company_profiles,
 public.srk_gst_service_rate_rules,public.srk_booking_tax_snapshots,public.srk_master_tax_invoices,
 public.srk_master_tax_credit_notes,public.srk_master_gateway_fee_tax_entries FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.srk_gst_indian_state_codes,public.srk_gst_company_profiles,
 public.srk_gst_service_rate_rules,public.srk_booking_tax_snapshots,public.srk_master_tax_invoices,
 public.srk_master_tax_credit_notes,public.srk_master_gateway_fee_tax_entries TO service_role;

CREATE OR REPLACE FUNCTION public.srk_admin_configure_gst_company(
 p_registration_status text,p_legal_name text,p_gstin text,p_supplier_state_code text,
 p_invoice_prefix text,p_effective_from date
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE v_version integer;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ONLY' USING ERRCODE='42501'; END IF;
 IF p_registration_status NOT IN ('registered','unregistered')
  OR char_length(btrim(coalesce(p_legal_name,''))) NOT BETWEEN 2 AND 200
  OR p_effective_from IS NULL OR p_effective_from>CURRENT_DATE
  OR coalesce(p_invoice_prefix,'') !~ '^[A-Z0-9-]{2,12}$' THEN RAISE EXCEPTION 'INVALID_GST_COMPANY_PROFILE'; END IF;
 IF p_registration_status='registered' AND (
   coalesce(p_gstin,'') !~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$'
   OR p_supplier_state_code IS NULL OR left(p_gstin,2)<>p_supplier_state_code
   OR NOT EXISTS(SELECT 1 FROM public.srk_gst_indian_state_codes WHERE state_code=p_supplier_state_code)
 ) THEN RAISE EXCEPTION 'VALID_GSTIN_AND_MATCHING_STATE_REQUIRED'; END IF;
 IF p_registration_status='unregistered' AND (p_gstin IS NOT NULL OR p_supplier_state_code IS NOT NULL) THEN
  RAISE EXCEPTION 'UNREGISTERED_PROFILE_MUST_NOT_SET_GSTIN'; END IF;
 SELECT coalesce(max(version),0)+1 INTO v_version FROM public.srk_gst_company_profiles;
 INSERT INTO public.srk_gst_company_profiles(id,registration_status,legal_name,gstin,supplier_state_code,invoice_prefix,effective_from,version,configured_by)
 VALUES(1,p_registration_status,btrim(p_legal_name),CASE WHEN p_registration_status='registered' THEN upper(btrim(p_gstin)) ELSE NULL END,
  p_supplier_state_code,p_invoice_prefix,p_effective_from,v_version,auth.uid())
 ON CONFLICT(id) DO UPDATE SET registration_status=EXCLUDED.registration_status,legal_name=EXCLUDED.legal_name,
  gstin=EXCLUDED.gstin,supplier_state_code=EXCLUDED.supplier_state_code,invoice_prefix=EXCLUDED.invoice_prefix,
  effective_from=EXCLUDED.effective_from,version=EXCLUDED.version,configured_by=EXCLUDED.configured_by,configured_at=clock_timestamp();
 RETURN jsonb_build_object('success',true,'version',v_version,'registration_status',p_registration_status);
END; $$;

CREATE OR REPLACE FUNCTION public.srk_admin_upsert_gst_service_rule(
 p_service_category_code text,p_service_code text,p_component text,p_taxable boolean,
 p_gst_rate_basis_points integer,p_effective_from date
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE v_version integer; v_id uuid;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ONLY' USING ERRCODE='42501'; END IF;
 IF char_length(btrim(coalesce(p_service_category_code,''))) NOT BETWEEN 2 AND 80
  OR char_length(btrim(coalesce(p_service_code,''))) NOT BETWEEN 2 AND 100
  OR p_component NOT IN ('labour','materials') OR p_taxable IS NULL
  OR p_gst_rate_basis_points NOT BETWEEN 0 AND 2800 OR p_effective_from IS NULL OR p_effective_from>CURRENT_DATE
  OR (p_taxable AND p_gst_rate_basis_points=0) OR (NOT p_taxable AND p_gst_rate_basis_points<>0) THEN
  RAISE EXCEPTION 'INVALID_GST_SERVICE_RULE'; END IF;
 UPDATE public.srk_gst_service_rate_rules SET active=false
  WHERE service_category_code=p_service_category_code AND service_code=p_service_code AND component=p_component AND active;
 SELECT coalesce(max(version),0)+1 INTO v_version FROM public.srk_gst_service_rate_rules
  WHERE service_category_code=p_service_category_code AND service_code=p_service_code AND component=p_component;
 INSERT INTO public.srk_gst_service_rate_rules(service_category_code,service_code,component,taxable,gst_rate_basis_points,effective_from,version,configured_by)
 VALUES(p_service_category_code,p_service_code,p_component,p_taxable,p_gst_rate_basis_points,p_effective_from,v_version,auth.uid())
 RETURNING id INTO v_id;
 RETURN jsonb_build_object('success',true,'rule_id',v_id,'version',v_version);
END; $$;

CREATE OR REPLACE FUNCTION public.srk_master_create_booking_tax_snapshot()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE b public.service_bookings%rowtype; c public.srk_gst_company_profiles%rowtype;
 lr public.srk_gst_service_rate_rules%rowtype; mr public.srk_gst_service_rate_rules%rowtype;
 v_state char(2); v_ltax bigint:=0; v_mtax bigint:=0; v_cgst bigint:=0; v_sgst bigint:=0; v_igst bigint:=0;
 v_lc bigint:=0; v_ls bigint:=0; v_li bigint:=0; v_mc bigint:=0; v_ms bigint:=0; v_mi bigint:=0;
 v_treatment text; v_taxable bigint; v_due bigint;
BEGIN
 SELECT * INTO b FROM public.service_bookings WHERE id=NEW.booking_id;
 SELECT * INTO c FROM public.srk_gst_company_profiles WHERE id=1;
 IF NOT FOUND THEN RAISE EXCEPTION 'GST_COMPANY_PROFILE_NOT_CONFIGURED'; END IF;
 SELECT state_code INTO v_state FROM public.srk_gst_indian_state_codes
  WHERE lower(state_name)=lower(btrim(coalesce(b.state,'')));
 IF v_state IS NULL THEN RAISE EXCEPTION 'GST_PLACE_OF_SUPPLY_STATE_NOT_MAPPED'; END IF;
 IF c.registration_status='registered' THEN
  SELECT * INTO lr FROM public.srk_gst_service_rate_rules
   WHERE service_category_code=b.srk_service_category_code AND service_code=b.srk_service_skill_code
    AND component='labour' AND active AND effective_from<=CURRENT_DATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'GST_LABOUR_RATE_RULE_NOT_CONFIGURED'; END IF;
  IF NEW.materials_amount_paise>0 THEN
   SELECT * INTO mr FROM public.srk_gst_service_rate_rules
    WHERE service_category_code=b.srk_service_category_code AND service_code=b.srk_service_skill_code
     AND component='materials' AND active AND effective_from<=CURRENT_DATE;
   IF NOT FOUND THEN RAISE EXCEPTION 'GST_MATERIAL_RATE_RULE_NOT_CONFIGURED'; END IF;
  ELSE
   mr.taxable:=false;mr.gst_rate_basis_points:=0;
  END IF;
  IF lr.taxable THEN v_ltax:=round(NEW.labour_amount_paise::numeric*lr.gst_rate_basis_points/10000)::bigint; END IF;
  IF mr.taxable THEN v_mtax:=round(NEW.materials_amount_paise::numeric*mr.gst_rate_basis_points/10000)::bigint; END IF;
  IF c.supplier_state_code=v_state THEN
   v_treatment:='intra_state';v_lc:=v_ltax/2;v_ls:=v_ltax-v_lc;v_mc:=v_mtax/2;v_ms:=v_mtax-v_mc;
  ELSE
   v_treatment:='inter_state';v_li:=v_ltax;v_mi:=v_mtax;
  END IF;
  v_cgst:=v_lc+v_mc;v_sgst:=v_ls+v_ms;v_igst:=v_li+v_mi;
 ELSE
  v_treatment:='unregistered';lr.taxable:=false;lr.gst_rate_basis_points:=0;
  mr.taxable:=false;mr.gst_rate_basis_points:=0;
 END IF;
 v_taxable:=CASE WHEN c.registration_status='registered' THEN
  (CASE WHEN lr.taxable THEN NEW.labour_amount_paise ELSE 0 END)+(CASE WHEN mr.taxable THEN NEW.materials_amount_paise ELSE 0 END)
  ELSE 0 END;
 v_due:=NEW.subtotal_paise+v_cgst+v_sgst+v_igst;
 INSERT INTO public.srk_booking_tax_snapshots(
  booking_id,final_bill_id,company_profile_version,registration_status,supplier_gstin,supplier_state_code,place_of_supply_state_code,
  labour_amount_paise,materials_amount_paise,labour_taxable,labour_rate_basis_points,labour_taxable_value_paise,labour_cgst_paise,labour_sgst_paise,labour_igst_paise,
  materials_taxable,materials_rate_basis_points,materials_taxable_value_paise,materials_cgst_paise,materials_sgst_paise,materials_igst_paise,
  total_cgst_paise,total_sgst_paise,total_igst_paise,total_tax_paise,taxable_value_paise,gross_before_tax_paise,total_due_paise,tax_treatment
 ) VALUES(NEW.booking_id,NEW.id,c.version,c.registration_status,c.gstin,c.supplier_state_code,v_state,
  NEW.labour_amount_paise,NEW.materials_amount_paise,coalesce(lr.taxable,false),coalesce(lr.gst_rate_basis_points,0),CASE WHEN coalesce(lr.taxable,false) THEN NEW.labour_amount_paise ELSE 0 END,v_lc,v_ls,v_li,
  coalesce(mr.taxable,false),coalesce(mr.gst_rate_basis_points,0),CASE WHEN coalesce(mr.taxable,false) THEN NEW.materials_amount_paise ELSE 0 END,v_mc,v_ms,v_mi,
  v_cgst,v_sgst,v_igst,v_cgst+v_sgst+v_igst,v_taxable,NEW.subtotal_paise,v_due,v_treatment);
 RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION public.srk_master_create_booking_tax_snapshot() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_master_booking_tax_snapshot ON public.srk_booking_final_bills;
CREATE TRIGGER srk_master_booking_tax_snapshot AFTER INSERT ON public.srk_booking_final_bills
FOR EACH ROW EXECUTE FUNCTION public.srk_master_create_booking_tax_snapshot();

CREATE OR REPLACE FUNCTION public.srk_master_issue_tax_invoice()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE t public.srk_booking_tax_snapshots%rowtype; c public.srk_gst_company_profiles%rowtype;
 b public.service_bookings%rowtype; v_number text; v_snapshot jsonb;
BEGIN
 SELECT * INTO t FROM public.srk_booking_tax_snapshots WHERE booking_id=NEW.booking_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_TAX_SNAPSHOT_REQUIRED'; END IF;
 SELECT * INTO c FROM public.srk_gst_company_profiles WHERE id=1;
 SELECT * INTO b FROM public.service_bookings WHERE id=NEW.booking_id;
 v_number:=c.invoice_prefix||'-'||to_char(clock_timestamp() AT TIME ZONE 'Asia/Kolkata','YYYY')||'-'||lpad(nextval('public.srk_master_tax_invoice_number_seq')::text,8,'0');
 v_snapshot:=jsonb_build_object('invoice_number',v_number,'booking_id',NEW.booking_id,'payment_id',NEW.id,
  'legal_name',c.legal_name,'gstin',t.supplier_gstin,'registration_status',t.registration_status,
  'place_of_supply_state_code',t.place_of_supply_state_code,'tax_treatment',t.tax_treatment,
  'labour_amount_paise',t.labour_amount_paise,'materials_amount_paise',t.materials_amount_paise,'labour_taxable_value_paise',t.labour_taxable_value_paise,
  'labour_rate_basis_points',t.labour_rate_basis_points,'labour_cgst_paise',t.labour_cgst_paise,'labour_sgst_paise',t.labour_sgst_paise,'labour_igst_paise',t.labour_igst_paise,
  'materials_taxable_value_paise',t.materials_taxable_value_paise,'materials_rate_basis_points',t.materials_rate_basis_points,
  'materials_cgst_paise',t.materials_cgst_paise,'materials_sgst_paise',t.materials_sgst_paise,'materials_igst_paise',t.materials_igst_paise,
  'taxable_value_paise',t.taxable_value_paise,'cgst_paise',t.total_cgst_paise,'sgst_paise',t.total_sgst_paise,'igst_paise',t.total_igst_paise,
  'total_tax_paise',t.total_tax_paise,'total_due_paise',t.total_due_paise,'customer_name',b.customer_name,'service_type',b.service_type);
 INSERT INTO public.srk_master_tax_invoices(booking_id,payment_id,tax_snapshot_id,invoice_number,invoice_snapshot)
 VALUES(NEW.booking_id,NEW.id,t.id,v_number,v_snapshot);
 RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION public.srk_master_issue_tax_invoice() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_master_tax_invoice_on_payment ON public.srk_master_booking_payments;
CREATE TRIGGER srk_master_tax_invoice_on_payment AFTER INSERT ON public.srk_master_booking_payments
FOR EACH ROW EXECUTE FUNCTION public.srk_master_issue_tax_invoice();

CREATE OR REPLACE FUNCTION public.srk_master_issue_tax_credit_note()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE i public.srk_master_tax_invoices%rowtype; t public.srk_booking_tax_snapshots%rowtype; v_reason text;
BEGIN
 IF NEW.payment_status='refunded' AND OLD.payment_status IS DISTINCT FROM NEW.payment_status THEN
  SELECT * INTO i FROM public.srk_master_tax_invoices WHERE payment_id=NEW.id FOR UPDATE;
  SELECT * INTO t FROM public.srk_booking_tax_snapshots WHERE booking_id=NEW.booking_id;
  IF FOUND AND i.id IS NOT NULL THEN
   v_reason:='Full refund — original invoice reversal';
   INSERT INTO public.srk_master_tax_credit_notes(invoice_id,payment_id,credit_note_number,reason,amount_paise,tax_breakdown,issued_by)
   VALUES(i.id,NEW.id,'CN-'||upper(left(replace(NEW.id::text,'-',''),16)),v_reason,t.total_due_paise,
    jsonb_build_object('taxable_value_paise',t.taxable_value_paise,'cgst_paise',t.total_cgst_paise,'sgst_paise',t.total_sgst_paise,'igst_paise',t.total_igst_paise,'total_tax_paise',t.total_tax_paise),NULL)
   ON CONFLICT(invoice_id) DO NOTHING;
  END IF;
 END IF;
 RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION public.srk_master_issue_tax_credit_note() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_master_tax_credit_note_on_refund ON public.srk_master_booking_payments;
CREATE TRIGGER srk_master_tax_credit_note_on_refund AFTER UPDATE OF payment_status ON public.srk_master_booking_payments
FOR EACH ROW EXECUTE FUNCTION public.srk_master_issue_tax_credit_note();

CREATE OR REPLACE FUNCTION public.srk_admin_record_master_gateway_fee_tax(
 p_payment_id uuid,p_provider text,p_provider_fee_reference text,p_fee_before_tax_paise bigint,
 p_gst_rate_basis_points integer,p_gst_amount_paise bigint,p_input_tax_credit_eligible boolean,p_invoice_reference text,p_note text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE v_id uuid; v_expected bigint;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ONLY' USING ERRCODE='42501'; END IF;
 IF p_provider NOT IN ('razorpay','other') OR char_length(btrim(coalesce(p_provider_fee_reference,'')))<4
  OR p_fee_before_tax_paise<0 OR p_gst_rate_basis_points NOT BETWEEN 0 AND 2800 OR p_gst_amount_paise<0
  OR p_input_tax_credit_eligible IS NULL OR (p_note IS NOT NULL AND char_length(p_note)>500)
  OR (p_invoice_reference IS NOT NULL AND char_length(p_invoice_reference)>120) THEN RAISE EXCEPTION 'INVALID_GATEWAY_FEE_TAX_EVIDENCE'; END IF;
 v_expected:=round(p_fee_before_tax_paise::numeric*p_gst_rate_basis_points/10000)::bigint;
 IF p_gst_amount_paise<>v_expected THEN RAISE EXCEPTION 'GATEWAY_FEE_GST_AMOUNT_MISMATCH'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.srk_master_booking_payments WHERE id=p_payment_id AND payment_status='paid') THEN RAISE EXCEPTION 'VERIFIED_MASTER_PAYMENT_REQUIRED'; END IF;
 INSERT INTO public.srk_master_gateway_fee_tax_entries(payment_id,provider,provider_fee_reference,fee_before_tax_paise,gst_rate_basis_points,gst_amount_paise,total_fee_paise,input_tax_credit_eligible,invoice_reference,reconciliation_note,recorded_by)
 VALUES(p_payment_id,p_provider,btrim(p_provider_fee_reference),p_fee_before_tax_paise,p_gst_rate_basis_points,p_gst_amount_paise,p_fee_before_tax_paise+p_gst_amount_paise,p_input_tax_credit_eligible,p_invoice_reference,nullif(btrim(coalesce(p_note,'')),''),auth.uid())
 RETURNING id INTO v_id;
 RETURN jsonb_build_object('success',true,'entry_id',v_id,'gateway_fee_total_paise',p_fee_before_tax_paise+p_gst_amount_paise);
END; $$;

CREATE OR REPLACE FUNCTION public.srk_admin_get_master_gst_summary(p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE v_out jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ONLY' USING ERRCODE='42501'; END IF;
 IF p_from IS NULL OR p_to IS NULL OR p_to<p_from OR p_to-p_from>366 THEN RAISE EXCEPTION 'INVALID_GST_REPORT_RANGE'; END IF;
 SELECT jsonb_build_object(
  'from',p_from,'to',p_to,
  'invoices',coalesce((SELECT jsonb_agg(jsonb_build_object('invoice_number',i.invoice_number,'booking_id',i.booking_id,'issued_at',i.issued_at,'snapshot',i.invoice_snapshot) ORDER BY i.issued_at) FROM public.srk_master_tax_invoices i WHERE (i.issued_at AT TIME ZONE 'Asia/Kolkata')::date BETWEEN p_from AND p_to),'[]'::jsonb),
  'credit_notes',coalesce((SELECT jsonb_agg(jsonb_build_object('credit_note_number',n.credit_note_number,'invoice_id',n.invoice_id,'amount_paise',n.amount_paise,'tax_breakdown',n.tax_breakdown,'issued_at',n.issued_at) ORDER BY n.issued_at) FROM public.srk_master_tax_credit_notes n WHERE (n.issued_at AT TIME ZONE 'Asia/Kolkata')::date BETWEEN p_from AND p_to),'[]'::jsonb),
  'gateway_fees',coalesce((SELECT jsonb_agg(jsonb_build_object('payment_id',g.payment_id,'provider',g.provider,'fee_before_tax_paise',g.fee_before_tax_paise,'gst_amount_paise',g.gst_amount_paise,'input_tax_credit_eligible',g.input_tax_credit_eligible,'invoice_reference',g.invoice_reference) ORDER BY g.recorded_at) FROM public.srk_master_gateway_fee_tax_entries g WHERE (g.recorded_at AT TIME ZONE 'Asia/Kolkata')::date BETWEEN p_from AND p_to),'[]'::jsonb)
 ) INTO v_out;
 RETURN v_out;
END; $$;

CREATE OR REPLACE FUNCTION public.srk_guard_master_tax_documents_immutable()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN RAISE EXCEPTION 'MASTER_TAX_DOCUMENTS_ARE_IMMUTABLE' USING ERRCODE='55000'; END; $$;
REVOKE ALL ON FUNCTION public.srk_guard_master_tax_documents_immutable() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER srk_master_tax_snapshot_immutable BEFORE UPDATE OR DELETE ON public.srk_booking_tax_snapshots
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_master_tax_documents_immutable();
CREATE TRIGGER srk_master_tax_invoice_immutable BEFORE UPDATE OR DELETE ON public.srk_master_tax_invoices
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_master_tax_documents_immutable();
CREATE TRIGGER srk_master_tax_credit_note_immutable BEFORE UPDATE OR DELETE ON public.srk_master_tax_credit_notes
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_master_tax_documents_immutable();
CREATE TRIGGER srk_master_gateway_fee_tax_immutable BEFORE UPDATE OR DELETE ON public.srk_master_gateway_fee_tax_entries
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_master_tax_documents_immutable();

REVOKE ALL ON FUNCTION public.srk_admin_configure_gst_company(text,text,text,text,text,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_configure_gst_company(text,text,text,text,text,date) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_upsert_gst_service_rule(text,text,text,boolean,integer,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_upsert_gst_service_rule(text,text,text,boolean,integer,date) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_record_master_gateway_fee_tax(uuid,text,text,bigint,integer,bigint,boolean,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_record_master_gateway_fee_tax(uuid,text,text,bigint,integer,bigint,boolean,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_get_master_gst_summary(date,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_get_master_gst_summary(date,date) TO authenticated;

-- Retry bill creation when GST company/rate configuration becomes complete.
CREATE OR REPLACE FUNCTION public.srk_try_build_master_final_bill_from_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE v_booking_id uuid; v_message text; v_booking public.service_bookings%rowtype;
BEGIN
 IF TG_TABLE_NAME='service_bookings' THEN v_booking_id:=NEW.id; ELSE v_booking_id:=NEW.booking_id; END IF;
 SELECT * INTO v_booking FROM public.service_bookings WHERE id=v_booking_id;
 IF NOT FOUND OR v_booking.srk_service_category_code IS NULL OR v_booking.status<>'completed'
  OR v_booking.completion_approval_status<>'approved' OR v_booking.customer_completed_at IS NULL THEN RETURN NEW; END IF;
 IF EXISTS(SELECT 1 FROM public.srk_booking_final_bills WHERE booking_id=v_booking_id) THEN RETURN NEW; END IF;
 PERFORM public.srk_service_role_build_master_final_bill(v_booking_id);
 RETURN NEW;
EXCEPTION WHEN OTHERS THEN
 GET STACKED DIAGNOSTICS v_message=MESSAGE_TEXT;
 IF v_message IN ('TECHNICIAN_LABOUR_LEDGER_REQUIRED','ALL_TECHNICIAN_WORKDAYS_MUST_BE_STOPPED',
  'CUSTOMER_MATERIAL_DECISION_PENDING','GST_COMPANY_PROFILE_NOT_CONFIGURED','GST_PLACE_OF_SUPPLY_STATE_NOT_MAPPED',
  'GST_LABOUR_RATE_RULE_NOT_CONFIGURED','GST_MATERIAL_RATE_RULE_NOT_CONFIGURED') THEN RETURN NEW; END IF;
 RAISE;
END; $$;
REVOKE ALL ON FUNCTION public.srk_try_build_master_final_bill_from_trigger() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.srk_master_retry_tax_ready_final_bills()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE r record; v_message text;
BEGIN
 FOR r IN SELECT b.id FROM public.service_bookings b
  WHERE b.srk_service_category_code IS NOT NULL AND b.status='completed'
   AND b.completion_approval_status='approved' AND b.customer_completed_at IS NOT NULL
   AND NOT EXISTS(SELECT 1 FROM public.srk_booking_final_bills f WHERE f.booking_id=b.id)
 LOOP
  BEGIN PERFORM public.srk_service_role_build_master_final_bill(r.id);
  EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS v_message=MESSAGE_TEXT;
   IF v_message NOT IN ('TECHNICIAN_LABOUR_LEDGER_REQUIRED','ALL_TECHNICIAN_WORKDAYS_MUST_BE_STOPPED',
    'CUSTOMER_MATERIAL_DECISION_PENDING','GST_COMPANY_PROFILE_NOT_CONFIGURED','GST_PLACE_OF_SUPPLY_STATE_NOT_MAPPED',
    'GST_LABOUR_RATE_RULE_NOT_CONFIGURED','GST_MATERIAL_RATE_RULE_NOT_CONFIGURED') THEN RAISE; END IF;
  END;
 END LOOP;
 RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION public.srk_master_retry_tax_ready_final_bills() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_master_retry_final_bills_after_gst_profile ON public.srk_gst_company_profiles;
CREATE TRIGGER srk_master_retry_final_bills_after_gst_profile AFTER INSERT OR UPDATE ON public.srk_gst_company_profiles
FOR EACH ROW EXECUTE FUNCTION public.srk_master_retry_tax_ready_final_bills();
DROP TRIGGER IF EXISTS srk_master_retry_final_bills_after_gst_rule ON public.srk_gst_service_rate_rules;
CREATE TRIGGER srk_master_retry_final_bills_after_gst_rule AFTER INSERT OR UPDATE ON public.srk_gst_service_rate_rules
FOR EACH ROW EXECUTE FUNCTION public.srk_master_retry_tax_ready_final_bills();

-- Replace the Master collection RPCs so they collect tax-inclusive totals while keeping Technician
-- commission/payables calculated only from labour and approved material reimbursement.
CREATE OR REPLACE FUNCTION public.srk_service_role_record_master_online_payment(
 p_booking_id uuid,p_order_id text,p_payment_id text,p_amount_paise bigint
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE
 b public.service_bookings%rowtype; f public.srk_booking_final_bills%rowtype; t public.srk_booking_tax_snapshots%rowtype;
 p public.srk_master_booking_payments%rowtype; v_payment_id uuid;
 v_commission_left bigint; v_count integer; v_i integer:=0; r record;
 v_share bigint; v_materials_owner uuid;
BEGIN
 IF coalesce(auth.jwt()->>'role','')<>'service_role' THEN RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501'; END IF;
 IF p_booking_id IS NULL OR p_order_id !~ '^order_[A-Za-z0-9]+$'
   OR p_payment_id !~ '^pay_[A-Za-z0-9]+$' OR p_amount_paise<100 THEN
   RAISE EXCEPTION 'INVALID_MASTER_ONLINE_PAYMENT' USING ERRCODE='22023';
 END IF;
 SELECT * INTO b FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND OR b.srk_service_category_code IS NULL OR b.status<>'completed'
   OR b.completion_approval_status<>'approved' OR b.customer_completed_at IS NULL THEN
   RAISE EXCEPTION 'CUSTOMER_CONFIRMED_MASTER_COMPLETION_REQUIRED' USING ERRCODE='55000';
 END IF;
 SELECT * INTO f FROM public.srk_booking_final_bills WHERE booking_id=p_booking_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'FINAL_BILL_REQUIRED' USING ERRCODE='55000'; END IF;
 SELECT * INTO t FROM public.srk_booking_tax_snapshots WHERE booking_id=p_booking_id;
 IF NOT FOUND OR t.total_due_paise<>p_amount_paise THEN RAISE EXCEPTION 'FINAL_BILL_TAX_AMOUNT_MISMATCH' USING ERRCODE='55000'; END IF;
 IF b.payment_status='refunded' THEN RAISE EXCEPTION 'PAYMENT_ALREADY_REFUNDED'; END IF;
 IF b.payment_status='paid' THEN
   SELECT * INTO p FROM public.srk_master_booking_payments WHERE booking_id=p_booking_id;
   IF FOUND AND p.razorpay_payment_id=p_payment_id AND p.razorpay_order_id=p_order_id AND p.amount_paise=p_amount_paise
     THEN RETURN jsonb_build_object('success',true,'already_processed',true,'payment_id',p.id); END IF;
   RAISE EXCEPTION 'BOOKING_ALREADY_PAID_WITH_DIFFERENT_PAYMENT';
 END IF;
 IF b.razorpay_order_id IS DISTINCT FROM p_order_id THEN RAISE EXCEPTION 'RAZORPAY_ORDER_BOOKING_MISMATCH'; END IF;

 INSERT INTO public.srk_master_booking_payments(booking_id,final_bill_id,payment_method,payment_status,
   amount_paise,razorpay_order_id,razorpay_payment_id)
 VALUES(p_booking_id,f.id,'razorpay','paid',p_amount_paise,p_order_id,p_payment_id)
 RETURNING id INTO v_payment_id;

 SELECT count(*) INTO v_count FROM (
   SELECT technician_id FROM public.srk_booking_technician_labour_ledger
    WHERE booking_id=p_booking_id GROUP BY technician_id
 ) q;
 IF v_count=0 THEN RAISE EXCEPTION 'TECHNICIAN_LEDGER_ALLOCATIONS_REQUIRED'; END IF;
 v_commission_left:=f.company_commission_paise;
 SELECT submitted_by_technician_id INTO v_materials_owner
   FROM public.srk_booking_material_requests WHERE booking_id=p_booking_id AND status='approved';
 FOR r IN
   SELECT technician_id,sum(total_labour_paise)::bigint AS gross
    FROM public.srk_booking_technician_labour_ledger
    WHERE booking_id=p_booking_id GROUP BY technician_id ORDER BY technician_id
 LOOP
   v_i:=v_i+1;
   IF v_i=v_count THEN v_share:=v_commission_left;
   ELSE
     v_share:=round(r.gross::numeric*f.company_commission_paise/f.labour_amount_paise)::bigint;
     v_share:=least(greatest(v_share,0),v_commission_left);
     v_commission_left:=v_commission_left-v_share;
   END IF;
   INSERT INTO public.srk_master_technician_payables(
    booking_id,payment_id,technician_id,labour_gross_paise,company_commission_paise,
    labour_payable_paise,materials_reimbursement_paise,total_payable_paise
   ) VALUES(p_booking_id,v_payment_id,r.technician_id,r.gross,v_share,r.gross-v_share,
    CASE WHEN r.technician_id=v_materials_owner THEN f.materials_amount_paise ELSE 0 END,
    r.gross-v_share+CASE WHEN r.technician_id=v_materials_owner THEN f.materials_amount_paise ELSE 0 END);
 END LOOP;

 INSERT INTO public.srk_master_payment_events(booking_id,payment_id,event_type,amount_paise,provider_reference,event_data)
 VALUES(p_booking_id,v_payment_id,'online_captured',p_amount_paise,p_payment_id,
   jsonb_build_object('order_id',p_order_id,'currency','INR'));
 UPDATE public.service_bookings SET payment_status='paid',amount_paid=p_amount_paise/100.0,
   razorpay_payment_id=p_payment_id,payment_verified_at=clock_timestamp()
 WHERE id=p_booking_id AND payment_status NOT IN ('paid','refunded');
 IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_PAYMENT_STATE_CHANGED' USING ERRCODE='40001'; END IF;
 RETURN jsonb_build_object('success',true,'already_processed',false,'payment_id',v_payment_id,
   'amount_paise',p_amount_paise,'commission_paise',f.company_commission_paise,
   'technician_payables_created',v_count);
END; $$;

CREATE OR REPLACE FUNCTION public.srk_admin_record_master_manual_payment(
 p_booking_id uuid,p_method text,p_reference text,p_note text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE b public.service_bookings%rowtype; f public.srk_booking_final_bills%rowtype; t public.srk_booking_tax_snapshots%rowtype;
 v_entry uuid; v_payment uuid; r record; v_count integer; v_i integer:=0; v_left bigint; v_share bigint;
 v_materials_owner uuid;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ONLY' USING ERRCODE='42501'; END IF;
 IF p_method NOT IN ('cash','upi','bank_transfer') OR char_length(btrim(coalesce(p_reference,'')))<4
   OR char_length(p_reference)>120 OR (p_note IS NOT NULL AND char_length(p_note)>250) THEN
   RAISE EXCEPTION 'INVALID_MANUAL_PAYMENT_EVIDENCE' USING ERRCODE='22023';
 END IF;
 SELECT * INTO b FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND OR b.srk_service_category_code IS NULL OR b.status<>'completed'
   OR b.completion_approval_status<>'approved' OR b.customer_completed_at IS NULL THEN
   RAISE EXCEPTION 'CUSTOMER_CONFIRMED_MASTER_COMPLETION_REQUIRED' USING ERRCODE='55000';
 END IF;
 SELECT * INTO f FROM public.srk_booking_final_bills WHERE booking_id=p_booking_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'MASTER_FINAL_BILL_REQUIRED'; END IF;
 SELECT * INTO t FROM public.srk_booking_tax_snapshots WHERE booking_id=p_booking_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'MASTER_TAX_SNAPSHOT_REQUIRED'; END IF;
 IF b.payment_status NOT IN ('unpaid','pending') OR b.payment_verified_at IS NOT NULL
   OR coalesce(b.amount_paid,0)<>0 OR b.razorpay_order_id IS NOT NULL OR b.razorpay_payment_id IS NOT NULL THEN
   RAISE EXCEPTION 'BOOKING_ALREADY_HAS_PAYMENT_STATE';
 END IF;
 INSERT INTO public.srk_manual_payment_entries(booking_id,payment_method,amount,payment_reference,note,recorded_by)
 VALUES(p_booking_id,p_method,t.total_due_paise/100.0,p_reference,nullif(btrim(coalesce(p_note,'')),''),auth.uid())
 RETURNING id INTO v_entry;
 INSERT INTO public.srk_master_booking_payments(booking_id,final_bill_id,payment_method,payment_status,
  amount_paise,manual_payment_entry_id,payment_reference,recorded_by)
 VALUES(p_booking_id,f.id,p_method,'paid',t.total_due_paise,v_entry,p_reference,auth.uid())
 RETURNING id INTO v_payment;
 SELECT count(*) INTO v_count FROM (SELECT technician_id FROM public.srk_booking_technician_labour_ledger
  WHERE booking_id=p_booking_id GROUP BY technician_id) q;
 v_left:=f.company_commission_paise;
 SELECT submitted_by_technician_id INTO v_materials_owner FROM public.srk_booking_material_requests
  WHERE booking_id=p_booking_id AND status='approved';
 FOR r IN SELECT technician_id,sum(total_labour_paise)::bigint gross
  FROM public.srk_booking_technician_labour_ledger WHERE booking_id=p_booking_id
  GROUP BY technician_id ORDER BY technician_id
 LOOP
  v_i:=v_i+1;
  IF v_i=v_count THEN v_share:=v_left;
  ELSE v_share:=least(round(r.gross::numeric*f.company_commission_paise/f.labour_amount_paise)::bigint,v_left);v_left:=v_left-v_share; END IF;
  INSERT INTO public.srk_master_technician_payables(booking_id,payment_id,technician_id,labour_gross_paise,
   company_commission_paise,labour_payable_paise,materials_reimbursement_paise,total_payable_paise)
  VALUES(p_booking_id,v_payment,r.technician_id,r.gross,v_share,r.gross-v_share,
   CASE WHEN r.technician_id=v_materials_owner THEN f.materials_amount_paise ELSE 0 END,
   r.gross-v_share+CASE WHEN r.technician_id=v_materials_owner THEN f.materials_amount_paise ELSE 0 END);
 END LOOP;
 INSERT INTO public.srk_master_payment_events(booking_id,payment_id,event_type,amount_paise,provider_reference,actor_user_id)
 VALUES(p_booking_id,v_payment,'manual_recorded',f.subtotal_paise,p_reference,auth.uid());
 UPDATE public.service_bookings SET payment_status='paid',amount_paid=t.total_due_paise/100.0,
  payment_method=p_method,payment_verified_at=clock_timestamp()
 WHERE id=p_booking_id AND payment_status IN ('unpaid','pending');
 IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_PAYMENT_STATE_CHANGED'; END IF;
 RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'payment_id',v_payment,
  'payment_entry_id',v_entry,'amount_paise',t.total_due_paise,'technician_payables_created',v_count);
END; $$;


REVOKE ALL ON FUNCTION public.srk_service_role_record_master_online_payment(uuid,text,text,bigint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_role_record_master_online_payment(uuid,text,text,bigint) TO service_role;
REVOKE ALL ON FUNCTION public.srk_admin_record_master_manual_payment(uuid,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_record_master_manual_payment(uuid,text,text,text) TO authenticated;
