
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_process_booking_matching_queue()'::regprocedure);
 v_old:='v_timeout integer; v_max_attempts integer;';
 v_new:='v_timeout integer; v_max_attempts integer; v_default_timeout integer; v_default_max_attempts integer;';
 if position(v_old in v_def)=0 then raise exception 'Matching function declarations not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:=' from public.srk_system_settings where setting_key=''offer_timeout_seconds'';
 select coalesce(nullif(setting_value::text,''null'')::integer,10) into v_max_attempts';
 v_new:=' from public.srk_system_settings where setting_key=''offer_timeout_seconds'';
 v_default_timeout:=v_timeout;
 select coalesce(nullif(setting_value::text,''null'')::integer,10) into v_max_attempts';
 if position(v_old in v_def)=0 then raise exception 'Matching default settings lookup not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:=' v_max_attempts:=coalesce(v_max_attempts,10);
';
 v_new:=' v_max_attempts:=coalesce(v_max_attempts,10);
 v_default_max_attempts:=v_max_attempts;
';
 if position(v_old in v_def)=0 then raise exception 'Matching max attempts default assignment not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:='v_timeout:=coalesce((v_booking.operational_settings_snapshot->>''offer_timeout_seconds'')::integer,v_timeout);
   v_max_attempts:=coalesce((v_booking.operational_settings_snapshot->>''max_matching_attempts'')::integer,v_max_attempts);';
 v_new:='v_timeout:=coalesce((v_booking.operational_settings_snapshot->>''offer_timeout_seconds'')::integer,v_default_timeout);
   v_max_attempts:=coalesce((v_booking.operational_settings_snapshot->>''max_matching_attempts'')::integer,v_default_max_attempts);';
 if position(v_old in v_def)=0 then raise exception 'Matching per-booking settings assignment not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
