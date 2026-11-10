-- Safe minimal assigned-booking data for the electrician quote composer.
-- Excludes customer name, phone, address and coordinates.
create or replace function public.srk_get_my_assigned_booking_quote_details()
returns table (
  booking_id uuid, service_type text, state text, district text, pincode text,
  booking_status text, quoted_amount numeric, service_charge numeric,
  materials_amount numeric, quote_status text, quote_note text
)
language sql stable security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
  select b.id, b.service_type, b.state, b.district, b.pincode, b.status,
         b.quoted_amount, b.service_charge, b.materials_amount,
         b.quote_status, b.quote_note
    from public.electrician_profiles p
    join public.service_bookings b on b.assigned_electrician_id = p.id
   where auth.uid() is not null
     and (p.user_id = auth.uid() or p.auth_user_id = auth.uid())
     and p.verification_status = 'approved' and p.active = true
     and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed')
   order by b.created_at desc limit 100;
$function$;
revoke all on function public.srk_get_my_assigned_booking_quote_details() from public, anon;
grant execute on function public.srk_get_my_assigned_booking_quote_details() to authenticated;

-- Allow either supported verified profile-to-auth link when submitting a quote.
create or replace function public.srk_submit_booking_quote(
  p_booking_id uuid, p_service_charge numeric, p_materials_amount numeric,
  p_quote_note text default null
)
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
declare
  v_profile_id uuid;
  v_booking public.service_bookings%rowtype;
  v_total numeric(12,2);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_booking_id is null or p_service_charge is null or p_service_charge <= 0
     or p_materials_amount is null or p_materials_amount < 0
     or p_service_charge > 10000000 or p_materials_amount > 10000000 then
    raise exception 'Invalid quote amounts';
  end if;
  select id into v_profile_id from public.electrician_profiles
   where (user_id = auth.uid() or auth_user_id = auth.uid())
     and verification_status = 'approved' and active = true
   order by created_at desc limit 1;
  if v_profile_id is null then raise exception 'Approved active electrician required'; end if;
  select * into v_booking from public.service_bookings
   where id = p_booking_id and assigned_electrician_id = v_profile_id for update;
  if not found then raise exception 'Assigned booking not found'; end if;
  if v_booking.status not in ('assigned','inspection','quote_rejected') then
    raise exception 'Booking is not ready for a quote';
  end if;
  v_total := round(p_service_charge + p_materials_amount, 2);
  update public.service_bookings set service_charge = round(p_service_charge, 2),
    materials_amount = round(p_materials_amount, 2), quoted_amount = v_total,
    quote_note = left(coalesce(p_quote_note, ''), 1000), quote_status = 'pending',
    quote_submitted_at = pg_catalog.now(), quote_responded_at = null,
    status = 'awaiting_quote_approval'
   where id = p_booking_id;
  return pg_catalog.jsonb_build_object('success', true, 'total', v_total, 'quote_status', 'pending');
end;
$function$;
revoke all on function public.srk_submit_booking_quote(uuid,numeric,numeric,text) from public, anon;
grant execute on function public.srk_submit_booking_quote(uuid,numeric,numeric,text) to authenticated;
