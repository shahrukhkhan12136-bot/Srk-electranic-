
create or replace function public.srk_admin_offer_booking(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
declare
  v_booking public.service_bookings%rowtype;
  v_match_level text;
  v_eligible integer := 0;
  v_created integer := 0;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin permission required';
  end if;
  if p_booking_id is null then
    raise exception 'Booking ID required';
  end if;

  select * into v_booking
  from public.service_bookings
  where id = p_booking_id
  for update;

  if not found then raise exception 'Booking not found'; end if;
  if v_booking.assigned_electrician_id is not null then
    raise exception 'Booking already has an assigned electrician';
  end if;
  if v_booking.status not in ('new','confirmed') then
    raise exception 'Only new or confirmed bookings can be offered';
  end if;

  if exists (
    select 1 from public.electrician_profiles e
    where e.active = true
      and e.verification_status = 'approved'
      and e.auth_user_id is not null
      and e.user_id = e.auth_user_id
      and e.pincode = v_booking.pincode
      and lower(trim(e.state)) = lower(trim(v_booking.state))
  ) then
    v_match_level := 'pincode';
  else
    v_match_level := 'district';
  end if;

  with eligible as (
    select e.id
    from public.electrician_profiles e
    where e.active = true
      and e.verification_status = 'approved'
      and e.auth_user_id is not null
      and e.user_id = e.auth_user_id
      and lower(trim(e.state)) = lower(trim(v_booking.state))
      and (
        (v_match_level = 'pincode' and e.pincode = v_booking.pincode)
        or
        (v_match_level = 'district' and lower(trim(e.district)) = lower(trim(v_booking.district)))
      )
  ), inserted as (
    insert into public.job_offers (booking_id, electrician_id, status, match_level)
    select p_booking_id, eligible.id, 'offered', v_match_level
    from eligible
    on conflict (booking_id, electrician_id) do nothing
    returning id
  )
  select (select count(*) from eligible),
         (select count(*) from inserted)
    into v_eligible, v_created;

  if v_eligible = 0 then
    return jsonb_build_object(
      'success', false,
      'message', 'इस PIN और जिले में कोई Active एवं Approved लॉगिन वाला इलेक्ट्रिशियन उपलब्ध नहीं है।',
      'match_level', v_match_level,
      'eligible_count', 0,
      'offers_created', 0
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'message', case when v_match_level = 'pincode'
      then 'उसी PIN के योग्य इलेक्ट्रिशियनों को ऑफर भेजे गए।'
      else 'उसी PIN पर कोई योग्य इलेक्ट्रिशियन नहीं मिला; जिले के योग्य इलेक्ट्रिशियनों को ऑफर भेजे गए।'
    end,
    'match_level', v_match_level,
    'eligible_count', v_eligible,
    'offers_created', v_created
  );
end;
$function$;

revoke all on function public.srk_admin_offer_booking(uuid) from public, anon, authenticated;
grant execute on function public.srk_admin_offer_booking(uuid) to authenticated;
