-- Post-migration assertions for the synthetic timer foundation harness.
-- All inserted synthetic rows are rolled back at the end.

begin;

do $assert$
declare
  v_booking uuid := '10000000-0000-4000-8000-000000000001';
  v_bill uuid := '20000000-0000-4000-8000-000000000001';
begin
  if not (select c.relrowsecurity from pg_class c where c.oid = 'public.srk_final_bills'::regclass) then
    raise exception 'RLS is not enabled on srk_final_bills';
  end if;
  if has_table_privilege('authenticated', 'public.srk_final_bills', 'SELECT') then
    raise exception 'authenticated unexpectedly has direct SELECT on srk_final_bills';
  end if;
  if not has_table_privilege('service_role', 'public.srk_final_bills', 'INSERT') then
    raise exception 'service_role is missing INSERT on srk_final_bills';
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.service_bookings'::regclass
      and conname = 'service_bookings_final_bill_fk'
  ) then
    raise exception 'booking -> final bill FK is missing';
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.srk_final_bills'::regclass
      and conname = 'srk_final_bills_booking_id_key'
  ) then
    raise exception 'one-bill-per-booking unique constraint is missing';
  end if;

  insert into public.service_bookings(id) values (v_booking);
  insert into public.srk_final_bills(
    id, booking_id, category_code, category_label, hourly_rate,
    started_at, stopped_at, elapsed_seconds, billable_minutes, labour_amount
  ) values (
    v_bill, v_booking, 'helper', 'Helper', 112.375,
    '2026-01-01 10:00:00+00', '2026-01-01 10:01:00.1+00',
    61, 2, 3.75
  );
  update public.service_bookings set final_bill_id = v_bill where id = v_booking;

  if not exists (
    select 1 from public.service_bookings
    where id = v_booking and final_bill_id = v_bill
  ) then
    raise exception 'circular booking/final-bill link failed';
  end if;
end
$assert$;

rollback;
