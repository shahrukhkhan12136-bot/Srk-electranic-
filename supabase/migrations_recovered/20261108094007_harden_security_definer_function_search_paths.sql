
alter function public.is_srk_admin() set search_path = pg_catalog, public, auth, pg_temp;
alter function public.srk_get_my_offer_details() set search_path = pg_catalog, public, auth, pg_temp;

create or replace function public.srk_admin_review_application(p_application_id uuid, p_decision text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $$
declare
  a public.electrician_applications%rowtype;
  linked_user uuid;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin only';
  end if;
  if p_application_id is null or p_decision is null
     or p_decision not in ('approved','rejected','suspended') then
    raise exception 'Invalid decision';
  end if;

  select * into a
  from public.electrician_applications
  where id = p_application_id
  for update;
  if not found then raise exception 'Application not found'; end if;

  select u.id into linked_user
  from auth.users u
  where u.phone_confirmed_at is not null
    and right(regexp_replace(coalesce(u.phone,''), '[^0-9]', '', 'g'), 10) = a.phone
  order by u.created_at desc
  limit 1;

  update public.electrician_applications
  set verification_status = p_decision, active = false
  where id = p_application_id;

  if p_decision = 'approved' then
    update public.electrician_profiles
    set display_name = a.full_name,
        phone = a.phone,
        state = a.state,
        district = a.district,
        pincode = a.pincode,
        skills = case when nullif(trim(a.skills),'') is null then array[]::text[] else string_to_array(a.skills, ',') end,
        verification_status = 'approved',
        active = false,
        user_id = coalesce(user_id, linked_user),
        auth_user_id = coalesce(auth_user_id, linked_user)
    where application_id = p_application_id;

    if not found then
      insert into public.electrician_profiles
        (application_id,display_name,phone,state,district,pincode,skills,active,verification_status,user_id,auth_user_id)
      values
        (p_application_id,a.full_name,a.phone,a.state,a.district,a.pincode,
         case when nullif(trim(a.skills),'') is null then array[]::text[] else string_to_array(a.skills, ',') end,
         false,'approved',linked_user,linked_user);
    end if;
  else
    update public.electrician_profiles
    set active = false, verification_status = p_decision
    where application_id = p_application_id;
  end if;
end;
$$;

create or replace function public.srk_respond_to_offer(p_offer_id uuid, p_response text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $$
declare
  v_booking_id uuid;
  v_electrician_id uuid;
  v_offer_status text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_offer_id is null or p_response is null
     or p_response not in ('accepted','declined') then
    raise exception 'Invalid response';
  end if;

  select o.booking_id, o.electrician_id, o.status
    into v_booking_id, v_electrician_id, v_offer_status
  from public.job_offers o
  join public.electrician_profiles p on p.id = o.electrician_id
  where o.id = p_offer_id
    and p.user_id = auth.uid()
    and p.verification_status = 'approved'
    and p.active = true
  for update of o;

  if v_booking_id is null then
    raise exception 'Offer not found or profile not active';
  end if;
  if v_offer_status <> 'offered' then
    raise exception 'Offer already answered';
  end if;

  if p_response = 'accepted' then
    update public.service_bookings
       set assigned_electrician_id = v_electrician_id, status = 'assigned'
     where id = v_booking_id
       and assigned_electrician_id is null
       and status in ('new','confirmed');
    if not found then raise exception 'This job has already been assigned'; end if;
  end if;

  update public.job_offers
     set status = p_response, responded_at = now()
   where id = p_offer_id;

  if p_response = 'accepted' then
    update public.job_offers
       set status = 'expired', responded_at = now()
     where booking_id = v_booking_id
       and id <> p_offer_id
       and status = 'offered';
  end if;

  return jsonb_build_object('success', true, 'status', p_response);
end;
$$;

revoke all on function public.is_srk_admin() from public, anon;
revoke all on function public.srk_admin_review_application(uuid,text) from public, anon;
revoke all on function public.srk_get_my_offer_details() from public, anon;
revoke all on function public.srk_respond_to_offer(uuid,text) from public, anon;
grant execute on function public.is_srk_admin() to authenticated, service_role;
grant execute on function public.srk_admin_review_application(uuid,text) to authenticated, service_role;
grant execute on function public.srk_get_my_offer_details() to authenticated, service_role;
grant execute on function public.srk_respond_to_offer(uuid,text) to authenticated, service_role;
