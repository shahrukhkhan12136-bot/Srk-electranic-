-- Customer ownership: one customer can request only their own paid booking refund.
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',false);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',false);
select public.srk_customer_create_booking_refund_request('20000000-0000-4000-8000-000000000001','काम पूरा होने के बाद सेवा की गुणवत्ता से संबंधित पूर्ण Refund का अनुरोध।');
do $$ begin
 if (select count(*) from public.srk_customer_list_booking_refund_requests())<>1 then raise exception 'Customer refund request was not scoped correctly'; end if;
end $$;
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',false);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","is_srk_admin":"true"}',false);
do $$ begin
 if (select count(*) from public.srk_admin_list_booking_refund_requests(200))<>1 then raise exception 'Admin refund list missing request'; end if;
end $$;
select public.srk_admin_decide_booking_refund_request((select id from public.srk_admin_list_booking_refund_requests(200) where booking_id='20000000-0000-4000-8000-000000000001'),'approved','भुगतान और शिकायत की जाँच पूरी।');
select * from public.srk_admin_prepare_booking_refund((select id from public.srk_admin_list_booking_refund_requests(200) where booking_id='20000000-0000-4000-8000-000000000001'));
reset role;
set role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',false);
select public.srk_service_reconcile_booking_refund((select id from public.srk_razorpay_refunds where booking_id='20000000-0000-4000-8000-000000000001'),'rfnd_TEST123','processed',null);
reset role;
do $$ begin
 if (select payment_status from public.service_bookings where id='20000000-0000-4000-8000-000000000001')<>'refunded' then raise exception 'Processed Razorpay refund did not update booking'; end if;
 if (select status from public.srk_booking_refund_requests where booking_id='20000000-0000-4000-8000-000000000001')<>'processed' then raise exception 'Refund request did not reach processed state'; end if;
end $$;
-- Manual refund is only recorded after a traceable UTR/reference is supplied.
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',false);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',false);
select public.srk_customer_create_booking_refund_request('20000000-0000-4000-8000-000000000002','नकद भुगतान की वापसी के लिए पूर्ण Refund अनुरोध।');
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',false);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","is_srk_admin":"true"}',false);
select public.srk_admin_decide_booking_refund_request((select id from public.srk_admin_list_booking_refund_requests(200) where booking_id='20000000-0000-4000-8000-000000000002'),'approved','नकद Refund का UTR मिलने पर दर्ज करें।');
select public.srk_admin_finalize_manual_booking_refund((select id from public.srk_admin_list_booking_refund_requests(200) where booking_id='20000000-0000-4000-8000-000000000002'),'UTR-REFUND-12345','वास्तविक वापसी दर्ज');
reset role;
do $$ begin
 if (select payment_status from public.service_bookings where id='20000000-0000-4000-8000-000000000002')<>'refunded' then raise exception 'Manual refund did not update booking'; end if;
 if (select count(*) from public.srk_manual_refund_entries where booking_id='20000000-0000-4000-8000-000000000002')<>1 then raise exception 'Manual refund audit entry missing'; end if;
end $$;


-- Timer-category refund must be bound to its immutable payable snapshot and captured-payment ledger.
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',false);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',false);
select public.srk_customer_create_booking_refund_request('20000000-0000-4000-8000-000000000003','टाइमर बुकिंग के भुगतान पर सेवा विवाद के कारण पूर्ण Refund अनुरोध।');
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',false);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","is_srk_admin":"true"}',false);
select public.srk_admin_decide_booking_refund_request((select id from public.srk_admin_list_booking_refund_requests(200) where booking_id='20000000-0000-4000-8000-000000000003'),'approved','Immutable timer snapshot and captured payment ledger matched.');
select * from public.srk_admin_prepare_booking_refund((select id from public.srk_admin_list_booking_refund_requests(200) where booking_id='20000000-0000-4000-8000-000000000003'));
reset role;
set role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',false);
select public.srk_service_reconcile_booking_refund((select id from public.srk_razorpay_refunds where booking_id='20000000-0000-4000-8000-000000000003'),'rfnd_TIMER123','processed',null);
reset role;
do $$ begin
 if (select payment_status from public.service_bookings where id='20000000-0000-4000-8000-000000000003')<>'refunded' then raise exception 'Timer snapshot refund did not update booking'; end if;
 if (select amount_paise from public.srk_razorpay_refunds where booking_id='20000000-0000-4000-8000-000000000003')<>100000 then raise exception 'Timer refund amount does not match immutable snapshot'; end if;
end $$;
