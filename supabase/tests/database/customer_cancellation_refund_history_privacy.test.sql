begin;

select plan(14);

select ok(
  position('auth.uid()' in pg_get_functiondef('public.srk_customer_cancel_my_booking(uuid)'::regprocedure)) > 0,
  'customer cancellation requires an authenticated identity'
);

select ok(
  position('customer_user_id = auth.uid()' in pg_get_functiondef('public.srk_customer_cancel_my_booking(uuid)'::regprocedure)) > 0,
  'customer cancellation is restricted to the booking owner'
);

select ok(
  position('for update' in lower(pg_get_functiondef('public.srk_customer_cancel_my_booking(uuid)'::regprocedure))) > 0,
  'booking row is locked while cancellation is validated'
);

select ok(
  position('assigned_electrician_id is not null' in lower(pg_get_functiondef('public.srk_customer_cancel_my_booking(uuid)'::regprocedure))) > 0
  and position('status not in (''new'',''confirmed'')' in lower(pg_get_functiondef('public.srk_customer_cancel_my_booking(uuid)'::regprocedure))) > 0,
  'only unassigned new or confirmed bookings can be cancelled'
);

select ok(
  position('payment_status, ''unpaid'') not in (''unpaid'',''failed'')' in lower(pg_get_functiondef('public.srk_customer_cancel_my_booking(uuid)'::regprocedure))) > 0,
  'pending, paid and refunded payment states cannot be cancelled directly'
);

select ok(
  position('coalesce(v_booking.amount_paid, 0) > 0' in lower(pg_get_functiondef('public.srk_customer_cancel_my_booking(uuid)'::regprocedure))) > 0,
  'positive recorded payments require refund workflow'
);

select ok(
  position('v_booking.payment_verified_at is not null' in lower(pg_get_functiondef('public.srk_customer_cancel_my_booking(uuid)'::regprocedure))) > 0,
  'verified payments require refund workflow'
);

select ok(
  position('v_booking.razorpay_payment_id is not null' in lower(pg_get_functiondef('public.srk_customer_cancel_my_booking(uuid)'::regprocedure))) > 0,
  'provider payment reference prevents direct cancellation'
);

select ok(
  not has_function_privilege('anon', 'public.srk_customer_cancel_my_booking(uuid)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.srk_customer_cancel_my_booking(uuid)', 'EXECUTE'),
  'customer cancellation RPC is authenticated-only'
);

select ok(
  position('auth.uid()' in pg_get_functiondef('public.srk_customer_list_my_booking_refund_requests()'::regprocedure)) > 0,
  'refund request history requires authentication'
);

select ok(
  position('r.customer_user_id = auth.uid()' in pg_get_functiondef('public.srk_customer_list_my_booking_refund_requests()'::regprocedure)) > 0,
  'refund request history is scoped to the authenticated customer'
);

select ok(
  position('admin_note' in lower(pg_get_functiondef('public.srk_customer_list_my_booking_refund_requests()'::regprocedure))) = 0,
  'refund request history does not expose internal admin notes'
);

select ok(
  position('decided_by' in lower(pg_get_functiondef('public.srk_customer_list_my_booking_refund_requests()'::regprocedure))) = 0,
  'refund request history does not expose staff identity'
);

select ok(
  not has_function_privilege('anon', 'public.srk_customer_list_my_booking_refund_requests()', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.srk_customer_list_my_booking_refund_requests()', 'EXECUTE'),
  'refund request history RPC is authenticated-only'
);

select * from finish();
rollback;
