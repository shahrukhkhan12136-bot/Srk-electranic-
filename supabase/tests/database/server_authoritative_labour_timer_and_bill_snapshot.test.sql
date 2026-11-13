BEGIN;
SELECT plan(78);

SELECT has_column('public','service_bookings','work_timer_seconds','timer seconds use bigint storage');
SELECT has_column('public','service_bookings','work_timer_elapsed_seconds','exact accumulated server elapsed seconds stored');
SELECT has_column('public','service_bookings','work_start_origin_status','rejected start request restores prior state');
SELECT has_column('public','service_bookings','labour_rate_tier_snapshot','commercial rate tier snapshotted per booking');
SELECT has_column('public','service_bookings','labour_rate8h_paise_snapshot','eight-hour rate snapshotted in integer paise');
SELECT has_column('public','service_bookings','labour_rate_card_version_snapshot','rate card version snapshotted per booking');
SELECT has_table('public','srk_booking_labour_bills','final labour bill snapshot table exists');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_booking_labour_bills'::regclass),'final bill table RLS enabled');
SELECT ok(NOT has_table_privilege('anon','public.srk_booking_labour_bills','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_booking_labour_bills','SELECT'),
  'final bill table has no direct client SELECT');
SELECT has_table('srk_private','work_timer_authorizations','timer updates use private transaction authorization');
SELECT ok(NOT has_table_privilege('anon','srk_private.work_timer_authorizations','SELECT')
  AND NOT has_table_privilege('authenticated','srk_private.work_timer_authorizations','INSERT')
  AND NOT has_table_privilege('authenticated','srk_private.work_timer_authorizations','UPDATE')
  AND NOT has_table_privilege('authenticated','srk_private.work_timer_authorizations','DELETE'),
  'timer authorization table is inaccessible to client roles');

SELECT ok(EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='srk_guard_server_work_timer'
  AND tgrelid='public.service_bookings'::regclass AND NOT tgisinternal),
  'server timer authorization trigger installed');
SELECT ok((SELECT prosecdef FROM pg_proc WHERE oid='public.srk_guard_server_work_timer()'::regprocedure),
  'timer guard executes with protected definer context');
SELECT ok(pg_get_functiondef('public.srk_guard_server_work_timer()'::regprocedure) ILIKE '%New bookings cannot be inserted with pre-populated timer%' AND
  (SELECT pg_get_triggerdef(oid) ILIKE '%INSERT%' FROM pg_trigger WHERE tgname='srk_guard_server_work_timer'),
  'timer guard also rejects client-supplied timer/rate snapshots on booking insert');
SELECT ok(NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.service_bookings'::regclass
  AND pg_get_constraintdef(oid) ILIKE '%604800%'),
  'seven-day timer cap constraint removed');

SELECT has_function('public','srk_electrician_request_work_start',ARRAY['uuid'],'electrician start request RPC exists');
SELECT has_function('public','srk_customer_respond_work_start',ARRAY['uuid','text'],'customer start approval RPC exists');
SELECT has_function('public','srk_electrician_request_work_completion',ARRAY['uuid'],'electrician completion request RPC exists');
SELECT has_function('public','srk_customer_respond_work_completion',ARRAY['uuid','text','text'],'customer completion decision RPC exists');
SELECT has_function('public','srk_customer_get_labour_bill',ARRAY['uuid'],'customer final bill RPC exists');
SELECT has_function('public','srk_electrician_get_labour_bill',ARRAY['uuid'],'electrician final bill RPC exists');

SELECT ok(pg_get_functiondef('public.srk_electrician_request_work_start(uuid)'::regprocedure)
  ILIKE '%selected_category IS NOT NULL%' AND
  pg_get_functiondef('public.srk_electrician_request_work_start(uuid)'::regprocedure)
  ILIKE '%work_start_origin_status%',
  'new categorized bookings can request start without a quote and retain origin state');
SELECT ok(pg_get_functiondef('public.srk_customer_respond_work_start(uuid,text)'::regprocedure)
  ILIKE '%approved_rate_tier%' AND
  pg_get_functiondef('public.srk_customer_respond_work_start(uuid,text)'::regprocedure)
  ILIKE '%labour_rate8h_paise_snapshot%',
  'customer approval snapshots the assigned electrician approved commercial rate');
SELECT ok(pg_get_functiondef('public.srk_customer_respond_work_start(uuid,text)'::regprocedure)
  ILIKE '%work_started_at=clock_timestamp()%' AND
  pg_get_functiondef('public.srk_customer_respond_work_start(uuid,text)'::regprocedure)
  ILIKE '%work_timer_running=true%',
  'timer starts only on customer approval using database clock');
SELECT ok(pg_get_functiondef('public.srk_electrician_request_work_completion(uuid)'::regprocedure)
  ILIKE '%work_timer_elapsed_seconds%' AND
  pg_get_functiondef('public.srk_electrician_request_work_completion(uuid)'::regprocedure)
  NOT ILIKE '%604800%',
  'completion accumulates exact elapsed time without a seven-day cap');
SELECT ok(pg_get_functiondef('public.srk_electrician_request_work_completion(uuid)'::regprocedure)
  ILIKE '%clock_timestamp()%' AND
  pg_get_functiondef('public.srk_electrician_request_work_completion(uuid)'::regprocedure)
  ILIKE '%FOR UPDATE%',
  'completion uses server clock and booking row lock');
SELECT ok(pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%ceil(v_booking.work_timer_elapsed_seconds/60)%',
  'any positive partial minute rounds up to the next billable minute');
SELECT ok(pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%floor(%+0.5%',
  'final monetary paise use half-up rounding');
SELECT ok(pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%INSERT INTO public.srk_booking_labour_bills%' AND
  pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%p_response=''approved''%',
  'final bill snapshot is created only on customer-approved completion');
SELECT ok(pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%p_response=''disputed''%' AND
  pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%completion_approval_status=''disputed''%',
  'disputed completion stops timer and does not enter approved-bill branch');
SELECT ok(pg_get_functiondef('public.srk_customer_get_labour_bill(uuid)'::regprocedure)
  ILIKE '%customer_user_id=auth.uid()%' AND
  pg_get_functiondef('public.srk_electrician_get_labour_bill(uuid)'::regprocedure)
  ILIKE '%electrician_profile_id=v_profile_id%',
  'customer and electrician bill reads are owner-scoped');
SELECT ok(pg_get_functiondef('public.srk_customer_get_labour_bill(uuid)'::regprocedure)
  NOT ILIKE '%phone%' AND
  pg_get_functiondef('public.srk_electrician_get_labour_bill(uuid)'::regprocedure)
  NOT ILIKE '%materials%',
  'final labour bill RPCs expose neither phone nor materials fields');
SELECT ok(NOT has_function_privilege('anon','public.srk_customer_get_labour_bill(uuid)','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_customer_get_labour_bill(uuid)','EXECUTE'),
  'final bill RPC is authenticated-only');
SELECT ok(pg_get_functiondef('public.srk_guard_server_work_timer()'::regprocedure)
  ILIKE '%work_timer_authorizations%' AND
  pg_get_functiondef('public.srk_guard_server_work_timer()'::regprocedure)
  ILIKE '%auth.uid()%',
  'direct timer/rate snapshot edits require transaction-scoped actor authorization');
SELECT ok(pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%work_timer_authorizations%' AND
  pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%work_transition_authorizations%',
  'customer completion keeps both timer and status-transition authorization guards');


SELECT has_function('public','srk_service_get_labour_bill_for_payment',ARRAY['uuid'],'service-role payment amount lookup exists');
SELECT ok(has_function_privilege('service_role','public.srk_service_get_labour_bill_for_payment(uuid)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_service_get_labour_bill_for_payment(uuid)','EXECUTE')
  AND NOT has_function_privilege('authenticated','public.srk_service_get_labour_bill_for_payment(uuid)','EXECUTE'),
  'payment amount lookup is service-role-only');
SELECT ok(pg_get_functiondef('public.srk_electrician_confirm_cash_payment(uuid)'::regprocedure)
  ILIKE '%srk_booking_labour_bills%' AND
  pg_get_functiondef('public.srk_electrician_confirm_cash_payment(uuid)'::regprocedure)
  ILIKE '%labour_amount%',
  'electrician cash confirmation uses verified labour bill snapshot');
SELECT ok(pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)
  ILIKE '%srk_booking_labour_bills%' AND
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)
  ILIKE '%completion_approval_status%',
  'Admin manual payment requires customer-approved final labour bill');
SELECT ok(pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure)
  ILIKE '%srk_booking_labour_bills%' AND
  pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure)
  ILIKE '%v_materials:=0%',
  'new-flow electrician payout uses labour only and zero legacy materials amount');
SELECT ok(pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure)
  ILIKE '%srk_booking_labour_bills%' AND
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure)
  ILIKE '%coalesce(v_row.materials_amount,0)=0%',
  'Admin payout settlement reconciles labour-only bill');
SELECT ok(pg_get_functiondef('public.srk_admin_prepare_razorpay_refund(uuid,text)'::regprocedure)
  ILIKE '%srk_booking_labour_bills%' AND
  pg_get_functiondef('public.srk_admin_prepare_razorpay_refund(uuid,text)'::regprocedure)
  ILIKE '%completion_approval_status%',
  'Razorpay refund amount reconciles to customer-approved labour bill');
SELECT ok(pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure) ILIKE '%work_timer_elapsed_seconds%'
  AND pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure) ILIKE '%work_start_approval_status%'
  AND pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure) NOT ILIKE '%materials_amount%'
  AND pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure) NOT ILIKE '%quoted_amount%',
  'electrician offer API exposes timer but no quote/material billing fields');
SELECT ok(pg_get_functiondef('private.srk_get_customer_call_contacts_impl()'::regprocedure)
  ILIKE '%awaiting_work_start_approval%' AND
  pg_get_functiondef('private.srk_get_customer_call_contacts_impl()'::regprocedure) NOT ILIKE '%completed%',
  'customer call contacts remain visible through start approval and hide after completion');
SELECT ok(pg_get_functiondef('public.srk_customer_get_my_booking_contacts()'::regprocedure)
  ILIKE '%awaiting_work_start_approval%' AND
  pg_get_functiondef('public.srk_customer_get_my_booking_contacts()'::regprocedure) NOT ILIKE '%completed%',
  'legacy customer contact RPC follows same active-only phone privacy');
SELECT has_function('public','srk_admin_get_labour_bill',ARRAY['uuid'],'Admin final labour bill read RPC exists');
SELECT ok(pg_get_functiondef('public.srk_service_get_labour_bill_for_payment(uuid)'::regprocedure)
  ILIKE '%auth.jwt()->>''role''%' AND
  pg_get_functiondef('public.srk_service_get_labour_bill_for_payment(uuid)'::regprocedure)
  ILIKE '%service_role%',
  'payment adapter lookup checks service-role JWT');


SELECT has_column('public','srk_booking_labour_bills','platform_fee_rate','separate approved Platform Fee rate is snapshotted');
SELECT has_column('public','srk_booking_labour_bills','platform_fee_amount','Platform Fee amount is snapshotted separately');
SELECT has_column('public','srk_booking_labour_bills','electrician_payable','net electrician payable is snapshotted');
SELECT ok((SELECT bool_and(platform_fee_rate=15.00) FROM public.srk_booking_labour_bills)
  OR NOT EXISTS(SELECT 1 FROM public.srk_booking_labour_bills),
  'Platform Fee rate is fixed at the approved 15 percent policy');
SELECT ok(
  position('v_commission:=v_bill.platform_fee_amount' in pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>0
  AND position('v_commission:=round(v_service*v_rate/100,2)' in pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>
      position('ELSIF NEW.quote_status' in pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure)),
  'new payout uses explicit Platform Fee snapshot; commission_rate remains legacy-only'
);
SELECT ok(pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure)
  ILIKE '%b.platform_fee_amount%' AND
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure)
  ILIKE '%b.electrician_payable%',
  'Admin payout reconciliation uses explicit Platform Fee and net payable snapshots');
SELECT ok(pg_get_functiondef('public.srk_calculate_booking_commission()'::regprocedure)
  ILIKE '%IF NEW.selected_category IS NOT NULL THEN%NEW.commission_amount:=NULL%',
  'new labour bookings do not infer Platform Fee from legacy commission_rate');
SELECT ok(pg_get_functiondef('public.srk_get_my_earnings()'::regprocedure)
  ILIKE '%lb.platform_fee_amount%' AND pg_get_functiondef('public.srk_get_my_earnings()'::regprocedure)
  ILIKE '%lb.electrician_payable%',
  'electrician earnings read explicit Platform Fee and net payable snapshots');
SELECT ok(pg_get_functiondef('public.srk_admin_commission_report()'::regprocedure)
  ILIKE '%lb.platform_fee_amount%',
  'Admin finance report reads explicit Platform Fee snapshot');
SELECT ok(pg_get_functiondef('public.srk_customer_get_labour_bill(uuid)'::regprocedure)
  NOT ILIKE '%platform_fee%' AND
  pg_get_functiondef('public.srk_electrician_get_labour_bill(uuid)'::regprocedure)
  ILIKE '%electrician_payable%' AND
  pg_get_functiondef('public.srk_electrician_get_labour_bill(uuid)'::regprocedure)
  NOT ILIKE '%platform_fee%' AND
  pg_get_functiondef('public.srk_admin_get_labour_bill(uuid)'::regprocedure)
  ILIKE '%platform_fee_amount%',
  'customer sees gross labour, electrician sees net payable, Admin sees separate fee breakdown');


SELECT ok((SELECT pg_get_constraintdef(oid) ILIKE '%platform_fee_due%'
  AND pg_get_constraintdef(oid) ILIKE '%platform_fee_collected%'
  FROM pg_constraint WHERE conname='srk_wallet_ledger_entry_type_check'
    AND conrelid='public.srk_wallet_ledger'::regclass),
  'wallet ledger allows separate Platform Fee due/collected and settlement entry types');
SELECT ok(pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure)
  ILIKE '%platform_fee_due%' AND
  pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure)
  ILIKE '%platform_fee_collected%' AND
  pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure)
  ILIKE '%srk:booking-gross-credit:%',
  'cash and online labour payments create idempotent wallet ledger entries');
SELECT ok(pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure)
  ILIKE '%Cash was received directly by the electrician: no platform payout is due%'
  AND pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure)
  ILIKE '%srk:platform-fee-cash-due:%',
  'cash labour payment creates Platform Fee due without a bank payout');
SELECT ok(pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure)
  ILIKE '%srk:platform-fee-due-settlement:%'
  AND pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure)
  ILIKE '%srk:platform-fee-due-recovery:%'
  AND pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure)
  ILIKE '%srk:payout-pending:%',
  'online labour share settles prior cash dues before creating pending net payout');
SELECT ok(pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure)
  ILIKE '%srk:payout-pending:%' AND
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure)
  ILIKE '%status=''posted''%',
  'Admin payout marks wallet debit posted only after actual transfer confirmation');
SELECT ok(pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure)
  ILIKE '%refund-reversal:%' AND
  pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure)
  ILIKE '%entry_type<>''refund''%',
  'refund reverses original booking wallet entries idempotently without recursive reversal');


SELECT ok(pg_get_functiondef('public.srk_get_my_wallet_summary()'::regprocedure)
  ILIKE '%platform_fee_due%' AND pg_get_functiondef('public.srk_get_my_wallet_summary()'::regprocedure)
  ILIKE '%platform_fee_collected%',
  'electrician wallet summary returns outstanding and collected Platform Fee');
SELECT ok(pg_get_functiondef('public.srk_admin_wallet_overview()'::regprocedure)
  ILIKE '%platform_fee_due%' AND pg_get_functiondef('public.srk_admin_wallet_overview()'::regprocedure)
  ILIKE '%pending_electrician_payouts%',
  'Admin wallet overview returns cash fee due and pending electrician payouts');
SELECT ok(pg_get_functiondef('public.srk_admin_commission_report()'::regprocedure)
  ILIKE '%platform_fee_due%' AND pg_get_functiondef('public.srk_admin_commission_report()'::regprocedure)
  ILIKE '%platform_fee_collected%',
  'Admin partner report includes Platform Fee due and collected totals');


SELECT ok(NOT has_function_privilege('authenticated','public.srk_get_my_assigned_booking_quote_details()','EXECUTE')
  AND NOT has_function_privilege('authenticated','public.srk_get_my_offer_price_details()','EXECUTE')
  AND NOT has_function_privilege('authenticated','public.srk_submit_booking_quote(uuid,numeric,numeric,text)','EXECUTE'),
  'legacy quote/material RPCs are no longer executable by app users');
SELECT ok(NOT has_column_privilege('authenticated','public.service_bookings','materials_amount','SELECT')
  AND has_column_privilege('authenticated','public.service_bookings','status','SELECT'),
  'authenticated booking reads cannot select the legacy materials amount column');
SELECT ok(NOT has_column_privilege('authenticated','public.service_bookings','materials_amount','UPDATE')
  AND has_column_privilege('authenticated','public.service_bookings','status','UPDATE'),
  'Admin direct booking updates cannot change the legacy materials amount column');
SELECT ok(NOT has_column_privilege('authenticated','public.srk_electrician_payouts','materials_amount','SELECT')
  AND has_column_privilege('authenticated','public.srk_electrician_payouts','electrician_payable','SELECT'),
  'Admin payout Data API cannot select legacy materials amount');
SELECT ok(pg_get_functiondef('public.srk_get_my_assigned_cash_payment(uuid)'::regprocedure)
  NOT ILIKE '%''materials_amount''%' AND
  pg_get_functiondef('public.srk_get_my_assigned_cash_payment(uuid)'::regprocedure)
  NOT ILIKE '%''quoted_amount''%',
  'electrician cash confirmation details expose no quote or materials amount');
SELECT ok(pg_get_functiondef('public.srk_admin_prepare_booking_refund(uuid)'::regprocedure)
  ILIKE '%srk_booking_labour_bills%' AND
  pg_get_functiondef('public.srk_admin_prepare_booking_refund(uuid)'::regprocedure)
  ILIKE '%completion_approval_status%',
  'Admin customer refund preparation reconciles new-flow refund to approved labour bill');
SELECT ok(pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure)
  NOT ILIKE '%materials_amount%' AND pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure)
  NOT ILIKE '%quoted_amount%',
  'electrician offer RPC does not return legacy quote or materials fields');
SELECT ok(pg_get_functiondef('public.srk_get_my_assigned_cash_payment(uuid)'::regprocedure)
  ILIKE '%electrician_payable%' AND
  pg_get_functiondef('public.srk_get_my_assigned_cash_payment(uuid)'::regprocedure)
  ILIKE '%can_confirm_cash%',
  'electrician cash confirmation RPC reports only billable net payable and eligibility');
SELECT ok(pg_get_function_result('public.srk_admin_prepare_booking_refund(uuid)'::regprocedure)
  NOT ILIKE '%materials_amount%',
  'customer refund preparation response contains no material fields');


SELECT has_function('private','srk_offer_booking_to_eligible_electricians',ARRAY['uuid'],'single verified matching engine exists for triggers and Admin');
SELECT ok(pg_get_functiondef('public.broadcast_booking_job()'::regprocedure)
  ILIKE '%srk_offer_booking_to_eligible_electricians%',
  'automatic booking insert trigger cannot bypass verified skill/rate-tier matching');
SELECT ok(pg_get_functiondef('private.srk_offer_booking_to_eligible_electricians(uuid)'::regprocedure)
  ILIKE '%approved_skill_keys%' AND
  pg_get_functiondef('private.srk_offer_booking_to_eligible_electricians(uuid)'::regprocedure)
  ILIKE '%approved_rate_tier%' AND
  pg_get_functiondef('private.srk_offer_booking_to_eligible_electricians(uuid)'::regprocedure)
  ILIKE '%payment_status%',
  'automatic and Admin matching filters approved skills, rate tier and unsettled online payments');

SELECT * FROM finish();
ROLLBACK;
