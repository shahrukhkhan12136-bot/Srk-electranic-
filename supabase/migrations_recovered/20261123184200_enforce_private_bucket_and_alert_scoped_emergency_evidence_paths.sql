
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_add_emergency_evidence(uuid,text,text,text,text,text,bigint,timestamptz,jsonb)'::regprocedure);
 v_old:=' if not found then raise exception ''Emergency alert not found''; end if;

 if v_alert.raised_by=auth.uid() then';
 v_new:=' if not found then raise exception ''Emergency alert not found''; end if;
 if p_storage_bucket<>''srk-emergency-evidence''
    or split_part(p_storage_path,''/'',1)<>p_alert_id::text
    or coalesce(p_file_size_bytes,0)>52428800
    or p_mime_type not in (''image/jpeg'',''image/png'',''image/webp'',''video/mp4'',''video/quicktime'',''audio/mpeg'',''audio/mp4'',''audio/wav'',''audio/webm'',''application/pdf'') then
   raise exception ''Evidence must be stored in the private SRK emergency bucket, under its alert folder, and within file limits'';
 end if;

 if v_alert.raised_by=auth.uid() then';
 if position(v_old in v_def)=0 then raise exception 'Emergency evidence validation insertion point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
