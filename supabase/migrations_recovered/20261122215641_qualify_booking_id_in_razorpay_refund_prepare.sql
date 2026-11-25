
do $fix$
declare v_def text;
begin
  v_def:=pg_get_functiondef('public.srk_admin_prepare_razorpay_refund(uuid,text)'::regprocedure);
  if position('FROM public.srk_razorpay_refunds WHERE booking_id=p_booking_id FOR UPDATE' in v_def)=0 then
    raise exception 'Expected ambiguous Razorpay refund lookup not found; stop for manual review';
  end if;
  v_def:=replace(
    v_def,
    'FROM public.srk_razorpay_refunds WHERE booking_id=p_booking_id FOR UPDATE',
    'FROM public.srk_razorpay_refunds rr WHERE rr.booking_id=p_booking_id FOR UPDATE'
  );
  execute v_def;
end
$fix$;
