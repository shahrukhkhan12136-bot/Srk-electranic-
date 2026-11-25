
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_find_eligible_workers(uuid,text)'::regprocedure);
 v_old:='and w.location_lat is not null and w.location_lng is not null';
 v_new:='and (v_booking.booking_latitude is null or (w.location_lat is not null and w.location_lng is not null))';
 if position(v_old in v_def)=0 then raise exception 'Worker GPS presence filter not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
