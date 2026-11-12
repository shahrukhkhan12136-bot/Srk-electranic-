\set ON_ERROR_STOP on

do $tests$
declare
  v_id text;
  v_count integer;
begin
  select electrician_display_id into v_id
  from public.electrician_profiles
  where user_id = '00000000-0000-0000-0000-000000000001';
  if v_id <> 'SRK-EL-000001' then
    raise exception 'Backfill should issue first readable ID, got %', v_id;
  end if;

  insert into public.electrician_profiles (display_name,phone,state,district,pincode,verification_status,active,user_id)
  values ('Pending Fixture','9000000002','Uttar Pradesh','Balrampur','271861','pending',false,'00000000-0000-0000-0000-000000000002');
  if (select electrician_display_id from public.electrician_profiles where user_id = '00000000-0000-0000-0000-000000000002') is not null then
    raise exception 'Pending/inactive profile must not receive an ID';
  end if;

  insert into public.electrician_profiles (display_name,phone,state,district,pincode,verification_status,active,auth_user_id)
  values ('Auth Only Fixture','9000000003','Uttar Pradesh','Balrampur','271861','approved',true,'00000000-0000-0000-0000-000000000003');
  select electrician_display_id into v_id from public.electrician_profiles where auth_user_id = '00000000-0000-0000-0000-000000000003';
  if v_id <> 'SRK-EL-000002' then raise exception 'auth_user_id-only profile should receive next ID, got %', v_id; end if;

  insert into public.electrician_profiles (display_name,phone,state,district,pincode,verification_status,active,user_id,auth_user_id)
  values ('Mismatched Fixture','9000000004','Uttar Pradesh','Balrampur','271861','approved',true,'00000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000005');
  if (select electrician_display_id from public.electrician_profiles where user_id = '00000000-0000-0000-0000-000000000004') is not null then
    raise exception 'Ambiguous mismatched Auth links must not receive an ID';
  end if;

  insert into public.electrician_profiles (display_name,phone,state,district,pincode,verification_status,active)
  values ('Late Link Fixture','9000000007','Uttar Pradesh','Balrampur','271861','approved',true);
  update public.electrician_profiles
     set auth_user_id = '00000000-0000-0000-0000-000000000007'
   where verification_status = 'approved'
     and active is true
     and auth_user_id is null
     and user_id is null;
  if (select electrician_display_id from public.electrician_profiles where auth_user_id = '00000000-0000-0000-0000-000000000007') <> 'SRK-EL-000003' then
    raise exception 'Adding auth_user_id to an approved active profile should issue an ID';
  end if;

  update public.electrician_profiles set verification_status = 'suspended'
  where user_id = '00000000-0000-0000-0000-000000000001';
  if (select electrician_display_id from public.electrician_profiles where user_id = '00000000-0000-0000-0000-000000000001') <> 'SRK-EL-000001' then
    raise exception 'Issued ID must remain permanent after status changes';
  end if;

  begin
    update public.electrician_profiles
       set electrician_display_id = 'SRK-EL-999999'
     where user_id = '00000000-0000-0000-0000-000000000001';
    raise exception 'Expected immutable ID guard to reject overwrite';
  exception when sqlstate '22000' then
    null;
  end;

  begin
    insert into public.electrician_profiles (display_name,phone,state,district,pincode,verification_status,active,user_id,electrician_display_id)
    values ('Client ID Fixture','9000000006','Uttar Pradesh','Balrampur','271861','approved',true,'00000000-0000-0000-0000-000000000006','SRK-EL-999998');
    raise exception 'Expected server-only issuance guard to reject client-supplied ID';
  exception when sqlstate '22000' then
    null;
  end;

  select count(distinct electrician_display_id) into v_count
  from public.electrician_profiles where electrician_display_id is not null;
  if v_count <> 3 then raise exception 'Expected three retained IDs before deletion/recreation, got %', v_count; end if;

  delete from public.electrician_profiles
   where auth_user_id = '00000000-0000-0000-0000-000000000007';
  insert into public.electrician_profiles (display_name,phone,state,district,pincode,verification_status,active,auth_user_id)
  values ('Recreated Fixture','9000000008','Uttar Pradesh','Balrampur','271861','approved',true,'00000000-0000-0000-0000-000000000008');
  if (select electrician_display_id from public.electrician_profiles where auth_user_id = '00000000-0000-0000-0000-000000000008') <> 'SRK-EL-000004' then
    raise exception 'Deleting and recreating a profile must not recycle a previously issued ID';
  end if;

  insert into public.electrician_profiles (display_name,phone,state,district,pincode,verification_status,active,user_id)
  values ('Legacy User Link Fixture','9000000009','Uttar Pradesh','Balrampur','271861','approved',true,'00000000-0000-0000-0000-000000000009');
  if (select electrician_display_id from public.electrician_profiles where user_id = '00000000-0000-0000-0000-000000000009') <> 'SRK-EL-000005' then
    raise exception 'A single unambiguous legacy user_id link should receive an ID';
  end if;

  insert into public.electrician_profiles (display_name,phone,state,district,pincode,verification_status,active,auth_user_id)
  values ('Duplicate Auth Link Fixture','9000000010','Uttar Pradesh','Balrampur','271861','approved',true,'00000000-0000-0000-0000-000000000009');
  if (select electrician_display_id from public.electrician_profiles where phone = '9000000010') is not null then
    raise exception 'A duplicate Auth identity across profile link columns must not receive an ID';
  end if;

  -- A profile that already has a permanent ID must not be relinked to an Auth
  -- identity already attached to another profile through the legacy user_id column.
  begin
    update public.electrician_profiles
       set auth_user_id = '00000000-0000-0000-0000-000000000009'
     where user_id = '00000000-0000-0000-0000-000000000001';
    raise exception 'Expected duplicate Auth identity relink to be rejected';
  exception when unique_violation then
    null;
  end;
  if (select auth_user_id from public.electrician_profiles
      where user_id = '00000000-0000-0000-0000-000000000001')
     <> '00000000-0000-0000-0000-000000000001' then
    raise exception 'Rejected identity relink unexpectedly changed the existing profile';
  end if;

  select count(distinct electrician_display_id) into v_count
  from public.electrician_profiles where electrician_display_id is not null;
  if v_count <> 4 then raise exception 'Expected four retained unique IDs after legacy-link tests, got %', v_count; end if;

  if has_sequence_privilege('anon', 'public.electrician_display_id_seq', 'USAGE')
     or has_sequence_privilege('authenticated', 'public.electrician_display_id_seq', 'USAGE') then
    raise exception 'Client roles must not consume ID sequence';
  end if;
end;
$tests$;

select 'electrician display ID behavior tests passed' as result;
