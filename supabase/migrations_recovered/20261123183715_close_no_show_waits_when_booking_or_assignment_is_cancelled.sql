
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_customer_cancel_booking_v2(uuid,text)'::regprocedure);
 v_old:=' update public.srk_booking_matching_queue set queue_status=''cancelled'',updated_at=clock_timestamp()
 where booking_id=p_booking_id;';
 v_new:=v_old||'
 update public.srk_booking_no_show_reports set status=''cancelled'',resolved_at=clock_timestamp(),
   resolution_note=''Booking cancelled by customer during no-show wait''
 where booking_id=p_booking_id and status=''waiting'';';
 if position(v_old in v_def)=0 then raise exception 'Customer cancel no-show cleanup point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;

 v_def:=pg_get_functiondef('public.srk_worker_cancel_booking(uuid,text)'::regprocedure);
 v_old:=' if v_remaining<v_requested then';
 v_new:=' update public.srk_booking_no_show_reports set status=''cancelled'',resolved_at=clock_timestamp(),
   resolution_note=''Worker assignment cancelled during no-show wait''
 where booking_worker_id=p_booking_worker_id and status=''waiting'';
 if v_remaining<v_requested then';
 if position(v_old in v_def)=0 then raise exception 'Worker cancel no-show cleanup point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
