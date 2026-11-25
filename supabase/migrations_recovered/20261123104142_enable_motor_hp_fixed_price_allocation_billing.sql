
do $migration$
declare v_def text;
begin
 select pg_get_functiondef('public.srk_admin_set_fixed_price_worker_allocations(uuid,jsonb,text)'::regprocedure) into v_def;
 v_def:=replace(v_def,
  $a$v_booking.pricing_unit_snapshot is distinct from 'per_item'$a$,
  $a$v_booking.pricing_unit_snapshot not in ('per_item','motor_hp')$a$);
 v_def:=replace(v_def,
  $a$'This allocation RPC currently supports only valid per-item fixed-price bookings'$a$,
  $a$'This allocation RPC supports only valid fixed-price per-item or motor HP bookings'$a$);
 v_def:=replace(v_def,
  $a$where id=v_booking.pricing_rule_id and pricing_unit='per_item' for share;$a$,
  $a$where id=v_booking.pricing_rule_id and pricing_unit=v_booking.pricing_unit_snapshot for share;$a$);
 v_def:=replace(v_def,
  $a$if not found or v_rule.technician_rate is null or v_rule.technician_rate <= 0 then$a$,
  $a$if not found or (v_booking.pricing_unit_snapshot='per_item' and (v_rule.technician_rate is null or v_rule.technician_rate <= 0)) then$a$);
 v_def:=replace(v_def,
  $a$v_expected := round(v_rule.technician_rate * v_booking.pricing_quantity,2);$a$,
  $a$if v_booking.pricing_unit_snapshot='motor_hp' then
    select t.fixed_price into v_expected from public.srk_service_pricing_hp_tiers t where t.pricing_rule_id=v_rule.id and t.motor_hp=v_booking.motor_hp;
    if v_expected is null then raise exception 'Approved fixed price for this Motor/Pump HP is missing'; end if;
  else
    v_expected := round(v_rule.technician_rate * v_booking.pricing_quantity,2);
  end if;$a$);
 if position('srk_service_pricing_hp_tiers' in v_def)=0 then raise exception 'HP allocation patch failed'; end if;
 execute v_def;

 select pg_get_functiondef('public.srk_admin_finalize_booking_bill(uuid)'::regprocedure) into v_def;
 v_def:=replace(v_def,
  $a$if v_booking.pricing_unit_snapshot='per_item' then$a$,
  $a$if v_booking.pricing_unit_snapshot in ('per_item','motor_hp') then$a$);
 v_def:=replace(v_def,
  $a$where id=v_booking.pricing_rule_id and pricing_unit='per_item' for share;$a$,
  $a$where id=v_booking.pricing_rule_id and pricing_unit=v_booking.pricing_unit_snapshot for share;$a$);
 v_def:=replace(v_def,
  $a$if not found or v_rule.technician_rate is null or v_rule.technician_rate<=0 then$a$,
  $a$if not found or (v_booking.pricing_unit_snapshot='per_item' and (v_rule.technician_rate is null or v_rule.technician_rate<=0)) then$a$);
 v_def:=replace(v_def,
  $a$v_expected_fixed_amount:=round(v_rule.technician_rate*v_booking.pricing_quantity,2);$a$,
  $a$if v_booking.pricing_unit_snapshot='motor_hp' then
      select t.fixed_price into v_expected_fixed_amount from public.srk_service_pricing_hp_tiers t where t.pricing_rule_id=v_rule.id and t.motor_hp=v_booking.motor_hp;
      if v_expected_fixed_amount is null then raise exception 'Approved fixed price for this Motor/Pump HP is missing'; end if;
    else
      v_expected_fixed_amount:=round(v_rule.technician_rate*v_booking.pricing_quantity,2);
    end if;$a$);
 if position('srk_service_pricing_hp_tiers' in v_def)=0 then raise exception 'HP final billing patch failed'; end if;
 execute v_def;
end
$migration$;
