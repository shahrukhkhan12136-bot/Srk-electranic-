
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_add_emergency_evidence(uuid,text,text,text,text,text,bigint,timestamptz,jsonb)'::regprocedure);
 v_old:='or p_mime_type not in (''image/jpeg''';
 v_new:='or p_mime_type is null or p_mime_type not in (''image/jpeg''';
 if position(v_old in v_def)=0 then raise exception 'Evidence MIME validation not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
