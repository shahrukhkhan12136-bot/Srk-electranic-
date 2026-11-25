
do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  v_def := pg_get_functiondef('public.srk_customer_choose_payment_method(uuid,text)'::regprocedure);
  v_old := E'  select exists(\n    select 1\n    from public.srk_booking_workers bw\n    join public.srk_technician_booking_cycle c on c.technician_id=bw.worker_id\n    where bw.booking_id=p_booking_id\n      and bw.worker_role=''technician''\n      and mod(c.completed_booking_count,3)=0\n  ) into v_forced_online;';
  v_new := E'  select exists(\n    select 1\n    from public.srk_technician_booking_sequence s\n    where s.booking_id=p_booking_id\n      and mod(s.sequence_number,3)=0\n  ) into v_forced_online;';
  if position(v_old in v_def)=0 then
    raise exception 'Customer payment cycle block not found';
  end if;
  execute replace(v_def,v_old,v_new);

  v_def := pg_get_functiondef('public.srk_confirm_cash_payment(uuid,numeric,text)'::regprocedure);
  v_old := E'  select count(*) into v_forced_online\n  from public.srk_booking_workers bw\n  join public.srk_worker_profiles wp on wp.id=bw.worker_id\n  join public.srk_technician_booking_cycle c on c.technician_id=wp.id\n  where bw.booking_id=p_booking_id\n    and bw.worker_role=''technician''\n    and mod(c.completed_booking_count,3)=0;';
  v_new := E'  select count(*) into v_forced_online\n  from public.srk_technician_booking_sequence s\n  where s.booking_id=p_booking_id\n    and mod(s.sequence_number,3)=0;';
  if position(v_old in v_def)=0 then
    raise exception 'Cash confirmation cycle block not found';
  end if;
  execute replace(v_def,v_old,v_new);
end
$migration$;
