
do $migration$
declare
  v_definition text;
  v_old text := $old$
  if found then
    if v_existing.status in ('issued','approved','disputed') then raise exception 'An active final bill already exists'; end if;
$old$;
  v_new text := $new$
  if found then
    if exists(
      select 1 from public.srk_worker_earnings e
      join public.srk_worker_wallet_ledger l on l.earning_id=e.id
      where e.booking_id=p_booking_id
    ) then
      raise exception 'Final bill cannot be reissued after worker earnings have entered the wallet ledger; use refund/reconciliation';
    end if;
    if exists(
      select 1 from public.srk_booking_refund_requests r
      where r.booking_id=p_booking_id and r.status<>'rejected'
    ) then
      raise exception 'Final bill cannot be reissued while a refund request is active';
    end if;
    if v_existing.status in ('issued','approved','disputed') then raise exception 'An active final bill already exists'; end if;
$new$;
begin
  select pg_get_functiondef(
    'public.srk_admin_finalize_booking_bill(uuid)'::regprocedure
  ) into v_definition;
  if position(v_old in v_definition)=0 then
    raise exception 'Expected bill reissue guard location not found; migration aborted';
  end if;
  v_definition:=replace(v_definition,v_old,v_new);
  execute v_definition;
end
$migration$;
