
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_worker_cancel_booking(uuid,text)'::regprocedure);
 v_old:='where booking_id=v_booking.id and queue_status not in (''cancelled'',''fulfilled'');';
 v_new:='where booking_id=v_booking.id and queue_status<>''cancelled'';';
 if position(v_old in v_def)=0 then raise exception 'Worker cancellation queue update not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
