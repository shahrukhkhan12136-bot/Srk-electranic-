CREATE OR REPLACE FUNCTION public.srk_guard_fixed_price_timer_disabled()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'pg_catalog','public'
AS $function$
declare v_pricing_unit text;
begin
 select b.pricing_unit_snapshot into v_pricing_unit
 from public.srk_booking_workers bw
 join public.service_bookings b on b.id=bw.booking_id
 where bw.id=new.booking_worker_id;
 if v_pricing_unit in ('per_item','motor_hp')
  and new.session_status in ('running','paused') then
  raise exception 'Timer is disabled for fixed-price bookings';
 end if;
 return new;
end
$function$;

DROP TRIGGER IF EXISTS srk_guard_fixed_price_timer_disabled
ON public.srk_worker_work_sessions;
CREATE TRIGGER srk_guard_fixed_price_timer_disabled
BEFORE INSERT OR UPDATE OF session_status,booking_worker_id
ON public.srk_worker_work_sessions
FOR EACH ROW
EXECUTE FUNCTION public.srk_guard_fixed_price_timer_disabled();