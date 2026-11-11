-- SRK ELECTRONIC timer billing arithmetic regression tests.
-- Run only against a disposable PostgreSQL database with psql:
--   psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/timer_billing_math.sql
-- This file creates no persistent objects and performs no application data writes.

begin;

do $test$
declare
  v_case record;
  v_elapsed bigint;
  v_minutes bigint;
  v_amount numeric(12,2);
begin
  for v_case in
    select * from (values
      (0::numeric,   0::bigint,   0::bigint),
      (1::numeric,   1::bigint,   1::bigint),
      (59::numeric, 59::bigint,   1::bigint),
      (59.1::numeric,60::bigint,  1::bigint),
      (60::numeric, 60::bigint,   1::bigint),
      (60.1::numeric,61::bigint,  2::bigint),
      (61::numeric, 61::bigint,   2::bigint),
      (119::numeric,119::bigint,  2::bigint),
      (119.1::numeric,120::bigint,2::bigint),
      (120::numeric,120::bigint,  2::bigint),
      (28800::numeric,28800::bigint,480::bigint)
    ) as t(duration_seconds, expected_elapsed, expected_minutes)
  loop
    v_elapsed := greatest(0, ceil(v_case.duration_seconds)::bigint);
    v_minutes := case when v_elapsed = 0 then 0 else (v_elapsed + 59) / 60 end;

    if v_elapsed <> v_case.expected_elapsed then
      raise exception 'elapsed seconds mismatch for %: got %, expected %',
        v_case.duration_seconds, v_elapsed, v_case.expected_elapsed;
    end if;
    if v_minutes <> v_case.expected_minutes then
      raise exception 'billable minutes mismatch for %: got %, expected %',
        v_case.duration_seconds, v_minutes, v_case.expected_minutes;
    end if;
  end loop;

  -- Fixed category rates; labour is rate / 60 * whole billable minutes.
  if round((112.375::numeric * 1) / 60, 2) <> 1.87 then
    raise exception 'Helper one-minute paise rounding regression';
  end if;
  if round((112.375::numeric * 2) / 60, 2) <> 3.75 then
    raise exception 'Helper two-minute half-up rounding regression';
  end if;
  if round((149.875::numeric * 1) / 60, 2) <> 2.50 then
    raise exception 'Ordinary one-minute rounding regression';
  end if;
  if round((199.875::numeric * 1) / 60, 2) <> 3.33 then
    raise exception 'Skilled one-minute rounding regression';
  end if;
  if round((249.875::numeric * 1) / 60, 2) <> 4.16 then
    raise exception 'Master one-minute rounding regression';
  end if;
  if round((249.875::numeric * 0) / 60, 2) <> 0.00 then
    raise exception 'Zero duration must not create a minimum labour charge';
  end if;
end
$test$;

rollback;
