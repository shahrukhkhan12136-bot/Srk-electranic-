\\set ON_ERROR_STOP on
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
  exception when sqlstate '22023' then null;
  end;
end
$test$;
rollback;
select 'customer date-only + legacy-time RPC tests passed' as result;
