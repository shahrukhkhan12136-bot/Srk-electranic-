
do $$
declare v_def text; v_old text; v_new text;
begin
 v_old:=$old$entry_type in ('cash_commission_due','cash_commission_collected')$old$;
 v_new:=$new$entry_type in ('cash_commission_due','cash_commission_collected','cash_commission_refund_credit')$new$;
 v_def:=pg_get_functiondef('public.srk_admin_finance_dashboard(text,date)'::regprocedure);
 if position(v_old in v_def)=0 then
  raise exception 'Expected cash commission dashboard expression not found; no change made';
 end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$$;
