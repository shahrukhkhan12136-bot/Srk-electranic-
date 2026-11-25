
do $migration$
declare
  v_definition text;
  v_old text := $old$
  if v_amount<>v_request.amount then raise exception 'REFUND_AMOUNT_CHANGED_SINCE_REQUEST' using errcode='55000'; end if;
  if v_booking.quote_status<>'approved' then
$old$;
  v_new text := $new$
  if v_amount<>v_request.amount then raise exception 'REFUND_AMOUNT_CHANGED_SINCE_REQUEST' using errcode='55000'; end if;
  if exists(
    select 1
    from public.srk_worker_earnings e
    join public.srk_worker_payout_requests p on p.worker_id=e.worker_id
    where e.booking_id=v_booking.id and p.status='paid'
  ) then
    raise exception 'SHARED_WORKER_PAYOUT_ALREADY_PAID_RECONCILIATION_REQUIRED' using errcode='55000';
  end if;
  if v_booking.quote_status<>'approved' then
$new$;
begin
  select pg_get_functiondef('public.srk_admin_prepare_booking_refund(uuid)'::regprocedure)
    into v_definition;
  if position(v_old in v_definition)=0 then
    raise exception 'Expected Razorpay refund guard location not found; migration aborted';
  end if;
  v_definition:=replace(v_definition,v_old,v_new);
  execute v_definition;
end
$migration$;
