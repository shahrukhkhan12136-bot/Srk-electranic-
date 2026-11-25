
do $migration$
declare
  v_definition text;
  v_old text := $old$and exists(
        select 1 from public.srk_worker_wallet_ledger l
        where l.worker_id=p.worker_id
          and l.entry_type='payout_paid'
          and l.idempotency_key='payout-paid:'||p.id::text
      )$old$;
begin
  select pg_get_functiondef(
    'public.srk_admin_record_manual_refund(uuid,text,text)'::regprocedure
  ) into v_definition;
  if position(v_old in v_definition)=0 then
    raise exception 'Expected shared payout guard fragment not found; migration aborted';
  end if;
  v_definition:=replace(v_definition,v_old,'');
  execute v_definition;
end
$migration$;
