
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_admin_review_worker_payout_details(uuid,boolean,text)'::regprocedure);
 v_old:='case when p_approve then ''approved'' else ''rejected'' end,';
 v_new:='''updated'',';
 if position(v_old in v_def)=0 then raise exception 'Payout audit action expression not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
