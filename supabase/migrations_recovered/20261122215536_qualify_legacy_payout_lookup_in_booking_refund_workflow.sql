
do $fix$
declare v_def text;
begin
  v_def:=pg_get_functiondef('public.srk_admin_prepare_booking_refund(uuid)'::regprocedure);
  if position('from public.srk_electrician_payouts where booking_id=v_booking.id for update' in v_def)=0 then
    raise exception 'Expected payout lookup not found; stop for manual review';
  end if;
  v_def:=replace(
    v_def,
    'from public.srk_electrician_payouts where booking_id=v_booking.id for update',
    'from public.srk_electrician_payouts ep where ep.booking_id=v_booking.id for update'
  );
  execute v_def;
end
$fix$;
