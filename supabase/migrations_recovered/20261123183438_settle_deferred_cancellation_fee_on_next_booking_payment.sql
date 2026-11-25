
update public.srk_booking_cancellation_fees f
set fee_basis=fee_basis
where false;

do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_on_booking_payment_completed()'::regprocedure);
 v_old:='  return new;
end
$function$';
 v_new:='  if v_payment_done then
    update public.srk_booking_cancellation_fees
    set status=''paid'',paid_at=clock_timestamp()
    where next_booking_id=new.id and status=''added_to_next_booking'';
  end if;
  return new;
end
$function$';
 if position(v_old in v_def)=0 then raise exception 'Payment completion trigger return point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;

do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_customer_cancel_booking_v2(uuid,text)'::regprocedure);
 v_old:='where bw.booking_id=p_booking_id and bw.arrived_at is not null';
 v_new:='where bw.booking_id=p_booking_id and bw.worker_role=''technician'' and bw.arrived_at is not null';
 if position(v_old in v_def)=0 then raise exception 'Technician arrived fee check not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 v_old:='where bw.booking_id=p_booking_id and bw.on_the_way_at is not null';
 v_new:='where bw.booking_id=p_booking_id and bw.worker_role=''technician'' and bw.on_the_way_at is not null';
 if position(v_old in v_def)=0 then raise exception 'Technician on-the-way fee check not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
