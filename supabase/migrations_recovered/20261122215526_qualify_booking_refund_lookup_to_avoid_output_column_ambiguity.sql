
do $fix$
declare v_def text;
begin
  v_def:=pg_get_functiondef('public.srk_admin_prepare_booking_refund(uuid)'::regprocedure);
  if position('from public.srk_razorpay_refunds where booking_id=v_booking.id for update' in v_def)=0 then
    raise exception 'Expected ambiguous refund lookup not found; stop for manual review';
  end if;
  v_def:=replace(
    v_def,
    'from public.srk_razorpay_refunds where booking_id=v_booking.id for update',
    'from public.srk_razorpay_refunds rr where rr.booking_id=v_booking.id for update'
  );
  execute v_def;
end
$fix$;
