-- Phase 1: evidence intake/review must be append-only and financially inert.
insert into auth.users(id,phone)
values('10000000-0000-4000-8000-000000000004','919999999994')
on conflict(id) do nothing;

set role authenticated;
do $test$
declare
 v_refund public.srk_razorpay_refunds%rowtype;
 v_case_id uuid;
 v_evidence_id uuid;
 v_mismatch_evidence_id uuid;
 v_before_booking_status text;
 v_before_refund_status text;
 v_result jsonb;
begin
 select * into v_refund from public.srk_razorpay_refunds
 where booking_id='20000000-0000-4000-8000-000000000002';
 if not found then raise exception 'TEST_REFUND_RECORD_MISSING'; end if;
 select payment_status into v_before_booking_status from public.service_bookings where id=v_refund.booking_id;
 v_before_refund_status:=v_refund.status;

 -- Admin 3 opens case and submits exact provider evidence.
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',false);
 perform set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","is_srk_admin":"true"}',false);
 v_result:=public.srk_admin_open_refund_reconciliation_case(v_refund.id,'51000000-0000-4000-8000-000000000001');
 v_case_id:=(v_result->>'case_id')::uuid;
 if v_result->>'created'<>'true' then raise exception 'CASE_NOT_CREATED'; end if;
 v_result:=public.srk_admin_submit_refund_reconciliation_evidence(
  v_case_id,'51000000-0000-4000-8000-000000000002',v_refund.refund_id,
  v_refund.payment_id,v_refund.amount_paise,v_refund.currency,'processed',now(),now(),
  'Razorpay Dashboard evidence reference TEST-REF-001');
 v_evidence_id:=(v_result->>'evidence_id')::uuid;
 if v_result->>'replayed'<>'false' then raise exception 'EVIDENCE_FIRST_SUBMISSION_NOT_CREATED'; end if;

 -- Same Admin cannot independently review their own evidence or case.
 begin
  perform public.srk_admin_review_refund_reconciliation_evidence(
   v_evidence_id,'51000000-0000-4000-8000-000000000003','verified_match','self review must fail');
  raise exception 'SELF_REVIEW_WAS_ACCEPTED';
 exception when sqlstate '42501' then null;
 end;

 -- Non-admin cannot read the case.
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',false);
 perform set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',false);
 begin
  perform public.srk_admin_get_refund_reconciliation_case(v_case_id);
  raise exception 'NON_ADMIN_READ_WAS_ACCEPTED';
 exception when sqlstate '42501' then null;
 end;

 -- Distinct Admin 4 independently reviews exact evidence.
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000004',false);
 perform set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","is_srk_admin":"true"}',false);
 v_result:=public.srk_admin_review_refund_reconciliation_evidence(
  v_evidence_id,'51000000-0000-4000-8000-000000000004','verified_match','Identifiers, amount and currency match');
 if v_result->>'financial_state_changed'<>'false' or v_result->>'ledger_match'<>'true' then
  raise exception 'REVIEW_DID_NOT_REMAIN_ADVISORY';
 end if;
 v_result:=public.srk_admin_review_refund_reconciliation_evidence(
  v_evidence_id,'51000000-0000-4000-8000-000000000004','verified_match','Identifiers, amount and currency match');
 if v_result->>'replayed'<>'true' then raise exception 'REVIEW_REPLAY_NOT_IDEMPOTENT'; end if;

 -- A mismatched amount cannot be called a verified match; it can only be marked blocked.
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',false);
 perform set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","is_srk_admin":"true"}',false);
 v_result:=public.srk_admin_submit_refund_reconciliation_evidence(
  v_case_id,'51000000-0000-4000-8000-000000000005',v_refund.refund_id,
  v_refund.payment_id,v_refund.amount_paise+100,v_refund.currency,'processed',now(),now(),
  'Razorpay Dashboard evidence reference TEST-REF-MISMATCH');
 v_mismatch_evidence_id:=(v_result->>'evidence_id')::uuid;
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000004',false);
 perform set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","is_srk_admin":"true"}',false);
 begin
  perform public.srk_admin_review_refund_reconciliation_evidence(
   v_mismatch_evidence_id,'51000000-0000-4000-8000-000000000006','verified_match','must fail');
  raise exception 'MISMATCHED_EVIDENCE_WAS_VERIFIED';
 exception when sqlstate '55000' then null;
 end;
 perform public.srk_admin_review_refund_reconciliation_evidence(
  v_mismatch_evidence_id,'51000000-0000-4000-8000-000000000007','mismatch_blocked','Amount mismatch');
 
 if (select status from public.srk_razorpay_refunds where id=v_refund.id)<>v_before_refund_status then
  raise exception 'EVIDENCE_REVIEW_CHANGED_REFUND_LEDGER';
 end if;
 if (select payment_status from public.service_bookings where id=v_refund.booking_id)<>v_before_booking_status then
  raise exception 'EVIDENCE_REVIEW_CHANGED_BOOKING_PAYMENT_STATUS';
 end if;
 if (select count(*) from public.srk_refund_reconciliation_reviews where case_id=v_case_id)<>2 then
  raise exception 'EXPECTED_TWO_ADVISORY_REVIEW_RECORDS';
 end if;
 if (select count(*) from public.srk_refund_reconciliation_audit where case_id=v_case_id)<>5 then
  raise exception 'EXPECTED_APPEND_ONLY_AUDIT_EVENTS';
 end if;
 if has_table_privilege('authenticated','public.srk_refund_reconciliation_evidence','select')
    or has_table_privilege('authenticated','public.srk_refund_reconciliation_evidence','insert')
    or has_table_privilege('anon','public.srk_refund_reconciliation_cases','select') then
  raise exception 'CLIENT_ROLE_HAS_DIRECT_RECONCILIATION_TABLE_ACCESS';
 end if;
end
$test$;
reset role;
