
do $migration$
declare v_def text; v_old text;
begin
 v_def:=pg_get_functiondef('public.srk_admin_acknowledge_emergency_alert(uuid,text)'::regprocedure);
 v_old:=' insert into public.srk_emergency_decision_events(alert_id,decision_status,decision_reason,decided_by,evidence_summary)
 values(p_alert_id,''insufficient_evidence'',''Acknowledgement only; no final emergency decision has been made. ''||btrim(p_note),auth.uid(),''Admin acknowledged response; final classification pending.'');';
 if position(v_old in v_def)=0 then raise exception 'Acknowledgement decision insert not found'; end if;
 v_def:=replace(v_def,v_old,'');
 execute v_def;
end
$migration$;
