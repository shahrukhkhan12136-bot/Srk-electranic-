\set ON_ERROR_STOP on
begin;
do $catalogue_test$
declare
  v_count integer;
  v_today_version integer;
  v_future_version integer;
begin
  if not (select relrowsecurity from pg_class where oid='public.srk_rate_catalogue'::regclass) then
    raise exception 'Rate catalogue RLS is not enabled';
  end if;
  if has_table_privilege('authenticated','public.srk_rate_catalogue','SELECT')
     or has_table_privilege('anon','public.srk_rate_catalogue','SELECT') then
    raise exception 'Rate catalogue is directly readable by client roles';
  end if;
  select count(*) into v_count from public.srk_rate_catalogue where version=1;
  if v_count <> 4 then raise exception 'Expected four seeded v1 category rates, found %',v_count; end if;
  if (select hourly_rate from public.srk_rate_catalogue where category_code='helper' and version=1) <> 112.375
     or (select hourly_rate from public.srk_rate_catalogue where category_code='ordinary' and version=1) <> 149.875
     or (select hourly_rate from public.srk_rate_catalogue where category_code='skilled' and version=1) <> 199.875
     or (select hourly_rate from public.srk_rate_catalogue where category_code='master' and version=1) <> 249.875 then
    raise exception 'Seeded catalogue v1 rates do not match approved rates';
  end if;
  insert into public.srk_rate_catalogue(category_code,category_label,version,hourly_rate,effective_from)
  values('helper','Helper',2,120.125,current_date+30);
  select version into v_today_version from public.srk_rate_catalogue
   where category_code='helper' and effective_from<=current_date order by effective_from desc limit 1;
  select version into v_future_version from public.srk_rate_catalogue
   where category_code='helper' and effective_from<=current_date+30 order by effective_from desc limit 1;
  if v_today_version <> 1 or v_future_version <> 2 then
    raise exception 'Effective-date version selection failed: today %, future %',v_today_version,v_future_version;
  end if;
end
$catalogue_test$;
select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000099',true);
set local role authenticated;
do $admin_rate_test$
declare
 v_rows jsonb;
 v_published jsonb;
begin
 v_rows := public.srk_admin_list_rate_catalogue();
 if jsonb_array_length(v_rows) <> 5 then
   raise exception 'Admin rate list should show the four seeded v1 rows plus the isolated future-effective test row: %',v_rows;
 end if;
 v_published := public.srk_admin_publish_rate_version(
   'master',299.999,current_date+45,'Approved annual pricing review by SRK admin'
 );
 if (v_published->>'version')::integer <> 2
    or (v_published->>'hourly_rate')::numeric <> 299.999 then
   raise exception 'Admin rate publish did not create version 2: %',v_published;
 end if;
 v_rows := public.srk_admin_list_rate_catalogue();
 if jsonb_array_length(v_rows) <> 6 then
   raise exception 'Admin rate history should contain six rows after publishing: %',v_rows;
 end if;
 if not exists(
   select 1 from jsonb_array_elements(v_rows) as item
   where item->>'category_code'='master' and (item->>'version')::integer=2
     and item->>'actor_user_id'='30000000-0000-0000-0000-000000000099'
     and item->>'action'='published'
     and item->>'reason'='Approved annual pricing review by SRK admin'
 ) then
   raise exception 'Published rate audit actor/reason missing from admin history: %',v_rows;
 end if;
end
$admin_rate_test$;
reset role;

select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000010',true);
set local role authenticated;
do $non_admin_rate_test$
begin
 begin
  perform public.srk_admin_publish_rate_version('helper',130,current_date+60,'Unauthorized user test attempt');
  raise exception 'Non-admin unexpectedly published a rate';
 exception when sqlstate '42501' then null;
 end;
 begin
  perform public.srk_admin_list_rate_catalogue();
  raise exception 'Non-admin unexpectedly read rate catalogue';
 exception when sqlstate '42501' then null;
 end;
end
$non_admin_rate_test$;
reset role;

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
  v_rate_version integer;
  v_rate_id uuid;
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
  select rate_version_snapshot,rate_catalogue_id into v_rate_version,v_rate_id from public.service_bookings where id=v_date_id;
  if v_duration <> 8 or v_estimate <> 899.00 or v_rate_version <> 1 or v_rate_id is null then
    raise exception 'Legacy duration/estimate/version snapshot incorrect: duration %, estimate %, version %, catalogue %',v_duration,v_estimate,v_rate_version,v_rate_id;
  end if;
  if (v_date_only->>'rate_version')::integer <> 1 or (v_date_only->>'rate_catalogue_id')::uuid <> v_rate_id then
    raise exception 'RPC did not return the selected catalogue version and id: %',v_date_only;
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

  -- Publish a same-day rate through the Admin RPC, then prove customer booking
  -- creation resolves the new effective version rather than a hardcoded rate.
  reset role;
  perform set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000099',true);
  set local role authenticated;
  perform public.srk_admin_publish_rate_version(
    'helper',120.125,current_date,'Approved same-day rate version selection regression'
  );
  reset role;
  perform set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000010',true);
  perform set_config('request.jwt.claim.phone','+919000000010',true);
  set local role authenticated;
  v_legacy := public.srk_create_customer_booking(
    jsonb_build_object(
      'customer_name','Current Rate Version Test','phone','9000000010','state','Uttar Pradesh',
      'district','Balrampur','pincode','271861','address','Test address',
      'service_type','Wiring','preferred_date',v_date,'service_category_code','helper',
      'duration_hours',1
    ),
    '51000000-0000-0000-0000-000000000006'
  );
  if (v_legacy->>'rate_version')::integer <> 3
     or (v_legacy->>'hourly_rate_snapshot')::numeric <> 120.125
     or (v_legacy->>'estimated_labour_amount_snapshot')::numeric <> 120.13 then
    raise exception 'Customer booking did not resolve the newly effective catalogue rate/version: %',v_legacy;
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
    update public.service_bookings set rate_version_snapshot=2 where id=v_legacy_id;
    raise exception 'Immutable rate version snapshot was unexpectedly editable';
  exception when sqlstate '55000' then null;
  end;
  begin
    update public.srk_rate_catalogue set hourly_rate=1 where id=v_rate_id;
    raise exception 'Rate catalogue row was unexpectedly editable';
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

-- Public customer pricing RPC returns only the four currently effective rates.
-- Anonymous users still cannot read the underlying catalogue table directly.
set local role anon;
do $public_rate_api_test$
declare v_rates jsonb;
begin
  if has_table_privilege('anon','public.srk_rate_catalogue','SELECT') then
    raise exception 'Anonymous role can directly read the private rate catalogue table';
  end if;
  if not has_function_privilege('anon','public.srk_get_current_customer_rates()','EXECUTE') then
    raise exception 'Anonymous role cannot execute the customer pricing RPC';
  end if;
  v_rates := public.srk_get_current_customer_rates();
  if jsonb_array_length(v_rates) <> 4 then
    raise exception 'Customer pricing RPC must return exactly four active categories: %',v_rates;
  end if;
  if not exists(select 1 from jsonb_array_elements(v_rates) r
    where r->>'category_code'='helper' and (r->>'version')::integer=3
      and (r->>'hourly_rate')::numeric=120.125
      and (r->>'eight_hour_amount')::numeric=961.00) then
    raise exception 'Public RPC did not return latest same-day Helper rate: %',v_rates;
  end if;
  if not exists(select 1 from jsonb_array_elements(v_rates) r
    where r->>'category_code'='master' and (r->>'version')::integer=1) then
    raise exception 'Public RPC exposed a future Master rate prematurely: %',v_rates;
  end if;
end
$public_rate_api_test$;
reset role;
rollback;
select 'customer date-only + legacy-time RPC tests passed' as result;
