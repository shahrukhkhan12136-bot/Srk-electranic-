
do $migration$
declare
  v_def text;
  v_name text;
  v_sig text;
begin
  foreach v_sig in array array[
    'public.srk_worker_request_payout(numeric)',
    'public.srk_admin_review_worker_payout(uuid,boolean,numeric,text)',
    'public.srk_admin_mark_worker_payout_paid(uuid,text,text,text)'
  ]
  loop
    v_def:=pg_get_functiondef(v_sig::regprocedure);
    if position('payout_status=''held''' in v_def)=0 then
      raise exception 'Expected held-state check not found in %',v_sig;
    end if;
    v_def:=replace(v_def,'payout_status=''held''','settlement_status=''held''');
    execute v_def;
  end loop;
end
$migration$;
