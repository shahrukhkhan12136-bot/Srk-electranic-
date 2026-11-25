
do $migration$
declare v_def text; v_start integer; v_rel_end integer; v_end integer; v_prefix text; v_middle text; v_suffix text;
begin
 v_def:=pg_get_functiondef('public.srk_admin_finalize_booking_bill(uuid)'::regprocedure);
 v_start:=strpos(v_def,'if v_is_fixed then'||E'\n    for v_worker in'||E'\n      select a.booking_worker_id');
 if v_start=0 then raise exception 'Fixed price earnings branch not found'; end if;
 v_rel_end:=strpos(substring(v_def from v_start),'else'||E'\n    for v_worker in'||E'\n      select bw.id booking_worker_id');
 if v_rel_end=0 then raise exception 'Timer earnings branch boundary not found'; end if;
 v_end:=v_start+v_rel_end-1;
 v_prefix:=substring(v_def from 1 for v_start-1);
 v_middle:=substring(v_def from v_start for v_end-v_start);
 v_suffix:=substring(v_def from v_end);
 v_middle:=replace(v_middle,
  'billable_seconds,normal_billable_seconds,overtime_billable_seconds,overtime_multiplier,gross_service_earning,company_commission_rate,',
  'billable_seconds,gross_service_earning,company_commission_rate,');
 execute v_prefix||v_middle||v_suffix;
end
$migration$;

do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_customer_get_higher_skill_level_options(uuid)'::regprocedure);
 v_old:=' STABLE SECURITY DEFINER';
 v_new:=' VOLATILE SECURITY DEFINER';
 if position(v_old in v_def)=0 then raise exception 'Higher level options volatility marker not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;

 v_def:=pg_get_functiondef('public.srk_raise_booking_complaint(uuid,uuid,text,text)'::regprocedure);
 v_old:=' v_reporter_worker_id uuid;';
 if position(v_old in v_def)=0 then raise exception 'Complaint variable not found'; end if;
 v_def:=replace(v_def,v_old,'');
 v_old:='select wp.id,wp.worker_type into v_reporter_worker_id,v_reporter_role';
 v_new:='select wp.worker_type into v_reporter_role';
 if position(v_old in v_def)=0 then raise exception 'Complaint reporter lookup not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
