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

  insert into public.electrician_profiles (verification_status, active, user_id)
  values ('pending', false, '00000000-0000-0000-0000-000000000002');
  if (select electrician_display_id from public.electrician_profiles where user_id = '00000000-0000-0000-0000-000000000002') is not null then
    raise exception 'Pending/inactive profile must not receive an ID';
  end if;

  insert into public.electrician_profiles (verification_status, active, auth_user_id)
  values ('approved', true, '00000000-0000-0000-0000-000000000003');
  select electrician_display_id into v_id from public.electrician_profiles where auth_user_id = '00000000-0000-0000-0000-000000000003';
  if v_id <> 'SRK-EL-000002' then raise exception 'auth_user_id-only profile should receive next ID, got %', v_id; end if;

  insert into public.electrician_profiles (verification_status, active, user_id, auth_user_id)
  values ('approved', true, '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000005');
  if (select electrician_display_id from public.electrician_profiles where user_id = '00000000-0000-0000-0000-000000000004') is not null then
    raise exception 'Ambiguous mismatched Auth links must not receive an ID';
  end if;

  insert into public.electrician_profiles (verification_status, active)
  values ('approved', true);
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
    insert into public.electrician_profiles (verification_status, active, user_id, electrician_display_id)
    values ('approved', true, '00000000-0000-0000-0000-000000000006', 'SRK-EL-999998');
    raise exception 'Expected server-only issuance guard to reject client-supplied ID';
  exception when sqlstate '22000' then
    null;
  end;

  select count(distinct electrician_display_id) into v_count
  from public.electrician_profiles where electrician_display_id is not null;
  if v_count <> 3 then raise exception 'Expected three currently retained distinct IDs after deleting one profile, got %', v_count; end if;

  delete from public.electrician_profiles
   where auth_user_id = '00000000-0000-0000-0000-000000000007';
  insert into public.electrician_profiles (verification_status, active, auth_user_id)
  values ('approved', true, '00000000-0000-0000-0000-000000000008');
  if (select electrician_display_id from public.electrician_profiles where auth_user_id = '00000000-0000-0000-0000-000000000008') <> 'SRK-EL-000004' then
    raise exception 'Deleting and recreating a profile must not recycle a previously issued ID';
  end if;

  if has_sequence_privilege('anon', 'public.electrician_display_id_seq', 'USAGE')
     or has_sequence_privilege('authenticated', 'public.electrician_display_id_seq', 'USAGE') then
    raise exception 'Client roles must not consume ID sequence';
  end if;
end;
$tests$;

select 'electrician display ID behavior tests passed' as result;
