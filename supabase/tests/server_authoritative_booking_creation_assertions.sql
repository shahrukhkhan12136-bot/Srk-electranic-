-- Disposable PostgreSQL assertions for server-authoritative booking creation.
-- All rows are rolled back. This is not a Production schema integration test.
begin;

do $test$
declare
  v_customer uuid := '50000000-0000-4000-8000-000000000001';
  v_electrician uuid := '50000000-0000-4000-8000-000000000002';
  v_profile uuid := '50000000-0000-4000-8000-000000000003';
  v_result jsonb;
  v_replay jsonb;
  v_booking uuid;
  v_count integer;
  v_category text;
  v_expected numeric(12,6);
  v_actual numeric(12,6);
  v_key uuid;
  v_payload jsonb;
begin
  insert into auth.users(id,phone) values
    (v_customer,'+919876543210'),
    (v_electrician,'+919999999999');

  insert into public.electrician_profiles(id,user_id,active,verification_status)
  values (v_profile,v_electrician,true,'approved');

  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claims','{}',true);
  begin
    perform public.srk_create_customer_booking('{}'::jsonb,gen_random_uuid());
    raise exception 'unauthenticated booking creation unexpectedly succeeded';
  exception when sqlstate '28000' then null;
  end;

  perform set_config('request.jwt.claim.sub',v_customer::text,true);
  perform set_config('request.jwt.claims','{"phone":"+919876543210"}',true);
  perform set_config('test.broadcast_new_booking','on',true);

  -- Authenticated phone mismatch must fail before any booking insert.
  begin
    perform public.srk_create_customer_booking(
      jsonb_build_object('customer_name','Test','phone','9000000000',
        'state','Uttar Pradesh','district','Balrampur','pincode','271861',
        'address','Test address','service_type','Electrical repair',
        'preferred_date','2026-12-01','preferred_time','10:00',
        'service_category_code','helper'),
      gen_random_uuid());
    raise exception 'phone mismatch unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;

  -- Invalid category must not be inferred or silently defaulted.
  begin
    perform public.srk_create_customer_booking(
      jsonb_build_object('customer_name','Test','phone','9876543210',
        'state','Uttar Pradesh','district','Balrampur','pincode','271861',
        'address','Test address','service_type','Electrical repair',
        'preferred_date','2026-12-01','preferred_time','10:00',
        'service_category_code','unknown'),
      gen_random_uuid());
    raise exception 'invalid category unexpectedly succeeded';
  exception when sqlstate '22023' then null;
  end;

  -- Client cannot smuggle booking-time payment selection or quote amounts.
  begin
    perform public.srk_create_customer_booking(
      jsonb_build_object('customer_name','Test','phone','9876543210',
        'state','Uttar Pradesh','district','Balrampur','pincode','271861',
        'address','Test address','service_type','Electrical repair',
        'preferred_date','2026-12-01','preferred_time','10:00',
        'service_category_code','helper','payment_method','Online',
        'quoted_amount',1),
      gen_random_uuid());
    raise exception 'client payment/quote fields unexpectedly accepted';
  exception when sqlstate '22023' then null;
  end;

  for v_category,v_expected in
    select * from (values
      ('helper',112.375::numeric),
      ('ordinary',149.875::numeric),
      ('skilled',199.875::numeric),
      ('master',249.875::numeric)
    ) rates(code,rate)
  loop
    v_key := gen_random_uuid();
    v_payload := jsonb_build_object(
      'customer_name','Test Customer',
      'phone','9876543210',
      'state','Uttar Pradesh',
      'district','Balrampur',
      'pincode','271861',
      'address','House 1, Test Road',
      'service_type','Electrical repair',
      'preferred_date','2026-12-01',
      'preferred_time','10:00',
      'work_details','Fan repair',
      'location_lat',27.43,
      'location_lng',82.18,
      'service_category_code',v_category
    );

    v_result := public.srk_create_customer_booking(v_payload,v_key);
    v_booking := (v_result->>'booking_id')::uuid;
    if coalesce((v_result->>'success')::boolean,false) is not true
       or coalesce((v_result->>'replayed')::boolean,true) then
      raise exception 'booking creation failed or unexpectedly replayed: %',v_result;
    end if;

    select hourly_rate_snapshot into v_actual
    from public.service_bookings where id=v_booking;
    if v_actual<>v_expected then
      raise exception 'wrong server category rate for %: expected %, got %',v_category,v_expected,v_actual;
    end if;
    if not exists (
      select 1 from public.service_bookings
      where id=v_booking and customer_user_id=v_customer
        and phone='9876543210' and service_category_code=v_category
        and quoted_amount is null and payment_method='Cash'
    ) then
      raise exception 'booking row missing identity, category snapshot, or safe legacy defaults';
    end if;

    select count(*) into v_count from public.job_offers
    where booking_id=v_booking and electrician_id=v_profile;
    if v_count<>1 then
      raise exception 'broadcast trigger must create exactly one offer, got %',v_count;
    end if;

    v_replay := public.srk_create_customer_booking(v_payload,v_key);
    if (v_replay->>'booking_id')::uuid<>v_booking
       or coalesce((v_replay->>'replayed')::boolean,false) is not true then
      raise exception 'idempotent booking retry did not return original booking: %',v_replay;
    end if;
    select count(*) into v_count from public.service_bookings
    where customer_user_id=v_customer and service_category_code=v_category;
    if v_count<>1 then raise exception 'idempotent retry created duplicate booking'; end if;
    select count(*) into v_count from public.job_offers where booking_id=v_booking;
    if v_count<>1 then raise exception 'idempotent retry duplicated broadcast offers'; end if;
  end loop;
end
$test$;

rollback;
