
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_admin_review_worker_payout_details(uuid,boolean,text)'::regprocedure);
 v_old:='payout_details_change_status=''updated'',';
 v_new:='payout_details_change_status=case when p_approve then ''approved'' else ''rejected'' end,';
 if position(v_old in v_def)=0 then raise exception 'Payout review status assignment not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
