do $migration$
declare
 v_definition text;
 v_old text := $old$or (bw.assignment_status='released' and exists(
       select 1 from public.srk_worker_work_sessions s
       where s.booking_worker_id=bw.id and s.billable_seconds>0
     ))$old$;
begin
 select pg_get_functiondef('public.srk_on_booking_payment_completed()'::regprocedure) into v_definition;
 if position(v_old in v_definition)>0 then
  v_definition := replace(v_definition, v_old, '');
  execute v_definition;
 elsif position('bw.assignment_status=''released''' in v_definition)>0 then
  raise exception 'Payment cycle trigger has an unexpected released-assignment condition';
 end if;
end
$migration$;
