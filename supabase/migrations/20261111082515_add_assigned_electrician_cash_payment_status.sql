create or replace function public.srk_get_my_assigned_cash_payment(p_booking_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
declare
  v_uid uuid := auth.uid();
  v_profile_id uuid;
  v_booking public.service_bookings%rowtype;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select p.id into v_profile_id
  from public.electrician_profiles p
  where (p.user_id = v_uid or p.auth_user_id = v_uid)
    and p.verification_status = 'approved'
    and p.active = true
  limit 1;

  if v_profile_id is null then
    raise exception 'Approved active electrician required' using errcode = '42501';
  end if;

  select b.* into v_booking
  from public.service_bookings b
  where b.id = p_booking_id
    and b.assigned_electrician_id = v_profile_id
  limit 1;

  if not found then
    raise exception 'Assigned booking not found' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'booking_id', v_booking.id,
    'status', v_booking.status,
    'payment_method', v_booking.payment_method,
    'payment_status', v_booking.payment_status,
    'quote_status', v_booking.quote_status,
    'quoted_amount', v_booking.quoted_amount,
    'can_confirm_cash',
      v_booking.status = 'completed'
      and v_booking.quote_status = 'approved'
      and lower(coalesce(v_booking.payment_method, '')) in ('cash', 'नकद (cash)', 'नकद')
      and coalesce(v_booking.payment_status, 'unpaid') in ('unpaid', 'pending')
      and coalesce(v_booking.quoted_amount, 0) > 0
  );
end;
$function$;

revoke all on function public.srk_get_my_assigned_cash_payment(uuid) from public, anon;
grant execute on function public.srk_get_my_assigned_cash_payment(uuid) to authenticated;
