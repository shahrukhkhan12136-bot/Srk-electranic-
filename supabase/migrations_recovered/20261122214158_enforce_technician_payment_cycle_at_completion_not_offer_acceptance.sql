
do $migration$
declare
  v_def text;
  v_block text;
begin
  v_def := pg_get_functiondef('public.srk_worker_respond_assignment(uuid,boolean)'::regprocedure);
  v_block := E'  if p_accept and v_worker.worker_type=''technician'' then\n    select completed_booking_count into v_count from public.srk_technician_booking_cycle where technician_id=v_worker.id;\n    if mod(coalesce(v_count,0)+1,3)=0 then\n      update public.service_bookings set payment_method=''Online'' where id=v_assignment.booking_id;\n    end if;\n  end if;\n';
  if position(v_block in v_def)=0 then
    raise exception 'Expected pre-acceptance payment forcing block not found';
  end if;
  v_def := replace(v_def,v_block,'');
  execute v_def;
end
$migration$;
