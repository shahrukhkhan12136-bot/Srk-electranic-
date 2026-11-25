
do $migration$
declare v_def text;
begin
 select pg_get_functiondef('public.srk_admin_set_fixed_price_worker_allocations(uuid,jsonb,text)'::regprocedure) into v_def;
 v_def:=replace(v_def,
  $a$v_booking.pricing_unit_snapshot not in ('per_item','motor_hp')$a$,
  $a$v_booking.pricing_unit_snapshot is distinct from 'per_item' and v_booking.pricing_unit_snapshot is distinct from 'motor_hp'$a$);
 if position($a$is distinct from 'per_item' and v_booking.pricing_unit_snapshot is distinct from 'motor_hp'$a$ in v_def)=0 then
  raise exception 'Could not harden fixed allocation pricing-unit guard';
 end if;
 execute v_def;
end
$migration$;
