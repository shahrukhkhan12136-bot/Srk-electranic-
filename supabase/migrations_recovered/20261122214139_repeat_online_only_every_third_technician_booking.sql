
do $migration$
declare
  v_def text;
begin
  v_def := pg_get_functiondef('public.srk_on_booking_payment_completed()'::regprocedure);
  if position('v_next in (3,6)' in v_def)=0
     or position('s.sequence_number in (3,6)' in v_def)=0 then
    raise exception 'Expected cycle checks not found in booking completion trigger';
  end if;
  v_def := replace(v_def,'v_next in (3,6)','mod(v_next,3)=0');
  v_def := replace(v_def,'s.sequence_number in (3,6)','mod(s.sequence_number,3)=0');
  execute v_def;

  v_def := pg_get_functiondef('public.srk_customer_choose_payment_method(uuid,text)'::regprocedure);
  if position('c.completed_booking_count in (3,6)' in v_def)=0 then
    raise exception 'Expected cycle check not found in customer payment selection';
  end if;
  v_def := replace(v_def,'c.completed_booking_count in (3,6)','mod(c.completed_booking_count,3)=0');
  execute v_def;

  v_def := pg_get_functiondef('public.srk_confirm_cash_payment(uuid,numeric,text)'::regprocedure);
  if position('c.completed_booking_count in (3,6)' in v_def)=0 then
    raise exception 'Expected cycle check not found in cash confirmation';
  end if;
  v_def := replace(v_def,'c.completed_booking_count in (3,6)','mod(c.completed_booking_count,3)=0');
  execute v_def;

  v_def := pg_get_functiondef('public.srk_worker_respond_assignment(uuid,boolean)'::regprocedure);
  if position('coalesce(v_count,0)+1 in (3,6)' in v_def)=0 then
    raise exception 'Expected cycle check not found in worker assignment response';
  end if;
  v_def := replace(v_def,'coalesce(v_count,0)+1 in (3,6)','mod(coalesce(v_count,0)+1,3)=0');
  execute v_def;
end
$migration$;
