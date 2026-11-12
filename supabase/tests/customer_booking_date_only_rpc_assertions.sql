\set ON_ERROR_STOP on
begin;
select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000010',true);
select set_config('request.jwt.claim.phone','+919000000010',true);
set local role authenticated;
do $test$
declare
  v_date text := to_char(current_date + 10,'YYYY-MM-DD');
  v_date_only jsonb;
  v_legacy jsonb;
  v_replay jsonb;
  v_date_id uuid;
  v_legacy_id uuid;
  v_time time;
  v_duration smallint;
  v_estimate numeric(12,2);
begin
  v_date_only := public.srk_create_customer_booking(
    jsonb_build_object(
      'customer_name','Date Only Test','phone','9000000010','state','Uttar Pradesh',
      'district','Balrampur','pincode','271861','address','Test address',
      'service_type','Wiring','preferred_date',v_date,'work_details','Date-only RPC test',
      'service_category_code','helper'
    ),
    '51000000-0000-0000-0000-000000000001'
  );
  v_date_id := (v_date_only->>'booking_id')::uuid;
  if v_date_only->>'success' <> 'true' or v_date_only->>'replayed' <> 'false' then
    raise exception 'Date-only RPC did not create a new booking: %',v_date_only;
  end if;
  select preferred_time into v_time from public.service_bookings where id=v_date_id;
  if v_time is not null then raise exception 'Date-only RPC unexpectedly stored a preferred time: %',v_time; end if;
  select duration_hours,estimated_labour_amount_snapshot into v_duration,v_estimate
  from public.service_bookings where id=v_date_id;
  if v_duration <> 8 or v_estimate <> 899.00 then
    raise exception 'Legacy caller duration default or authoritative estimate incorrect: duration %, estimate %',v_duration,v_estimate;
  end if;

  v_replay := public.srk_create_customer_booking(
    jsonb_build_object(
      'customer_name','Date Only Test','phone','9000000010','state','Uttar Pradesh',
      'district','Balrampur','pincode','271861','address','Test address',
      'service_type','Wiring','preferred_date',v_date,'service_category_code','helper'
    ),
    '51000000-0000-0000-0000-000000000001'
  );
  if (v_replay->>'booking_id')::uuid <> v_date_id or v_replay->>'replayed' <> 'true' then
    raise exception 'Idempotent replay did not return the original date-only booking: %',v_replay;
  end if;

  v_legacy := public.srk_create_customer_booking(
    jsonb_build_object(
      'customer_name','Legacy Time Test','phone','9000000010','state','Uttar Pradesh',
      'district','Balrampur','pincode','271861','address','Test address',
      'service_type','Wiring','preferred_date',v_date,'preferred_time','14:30',
      'service_category_code','helper'
    ),
    '51000000-0000-0000-0000-000000000002'
  );
  v_legacy_id := (v_legacy->>'booking_id')::uuid;
  select preferred_time into v_time from public.service_bookings where id=v_legacy_id;
  if v_time <> time '14:30' then raise exception 'Legacy explicit preferred_time was not preserved: %',v_time; end if;

  -- Explicit customer duration is calculated by the database from the approved category rate.
  v_legacy := public.srk_create_customer_booking(
    jsonb_build_object(
      'customer_name','Duration Pricing Test','phone','9000000010','state','Uttar Pradesh',
      'district','Balrampur','pincode','271861','address','Test address',
      'service_type','Wiring','preferred_date',v_date,'service_category_code','helper',
      'duration_hours',3
    ),
    '51000000-0000-0000-0000-000000000004'
  );
  v_legacy_id := (v_legacy->>'booking_id')::uuid;
  select duration_hours,estimated_labour_amount_snapshot into v_duration,v_estimate
  from public.service_bookings where id=v_legacy_id;
  if v_duration <> 3 or v_estimate <> 337.13 or (v_legacy->>'estimated_labour_amount_snapshot')::numeric <> 337.13 then
    raise exception 'Server duration calculation/paise half-up estimate incorrect: duration %, estimate %, response %',v_duration,v_estimate,v_legacy;
  end if;

  -- Half-paise ties are rounded up to the next paise by PostgreSQL numeric round.
  v_legacy := public.srk_create_customer_booking(
    jsonb_build_object(
      'customer_name','Half Paise Test','phone','9000000010','state','Uttar Pradesh',
      'district','Balrampur','pincode','271861','address','Test address',
      'service_type','Wiring','preferred_date',v_date,'service_category_code','ordinary',
      'duration_hours',1
    ),
    '51000000-0000-0000-0000-000000000005'
  );
  if (v_legacy->>'estimated_labour_amount_snapshot')::numeric <> 149.88 then
    raise exception 'Half-paise estimate was not rounded half-up: %',v_legacy;
  end if;

  foreach v_duration in array array[0,9] loop
    begin
      perform public.srk_create_customer_booking(
        jsonb_build_object(
          'customer_name','Invalid Duration Test','phone','9000000010','state','Uttar Pradesh',
          'district','Balrampur','pincode','271861','address','Test address',
          'service_type','Wiring','preferred_date',v_date,'service_category_code','helper',
          'duration_hours',v_duration
        ),
        gen_random_uuid()
      );
      raise exception 'Invalid duration unexpectedly accepted: %',v_duration;
    exception when sqlstate '22023' then null;
    end;
  end loop;

  reset role;
  begin
    update public.service_bookings set duration_hours=4 where id=v_legacy_id;
    raise exception 'Immutable duration snapshot was unexpectedly editable';
  exception when sqlstate '55000' then null;
  end;
  begin
    update public.service_bookings set estimated_labour_amount_snapshot=1 where id=v_legacy_id;
    raise exception 'Immutable estimate snapshot was unexpectedly editable';
  exception when sqlstate '55000' then null;
  end;

  begin
    perform public.srk_create_customer_booking(
      jsonb_build_object(
        'customer_name','Invalid Time Test','phone','9000000010','state','Uttar Pradesh',
        'district','Balrampur','pincode','271861','address','Test address',
        'service_type','Wiring','preferred_date',v_date,'preferred_time','25:99',
        'service_category_code','helper'
      ),
      '51000000-0000-0000-0000-000000000003'
    );
    raise exception 'Invalid legacy time was unexpectedly accepted';
  exception when sqlstate '22023' or sqlstate '22008' then null;
  end;
end
$test$;
rollback;
select 'customer date-only + legacy-time RPC tests passed' as result;
