-- Labour-only quote policy: customers source and supply all materials themselves.
-- Keep the legacy column and RPC signature for backward compatibility, but reject
-- any non-zero materials amount and persist zero for all newly submitted quotes.
create or replace function public.srk_submit_booking_quote(
  p_booking_id uuid,
  p_service_charge numeric,
  p_materials_amount numeric,
  p_quote_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'auth', 'pg_temp'
as $function$
declare
  v_profile_id uuid;
  v_booking public.service_bookings%rowtype;
  v_total numeric(12,2);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_booking_id is null or p_service_charge is null or p_service_charge <= 0
     or p_service_charge > 10000000 then
    raise exception 'Invalid labour quote amount';
  end if;
  if p_materials_amount is null or round(p_materials_amount,2) <> 0 then
    raise exception 'Materials are not part of SRK ELECTRONIC quotes. Customer supplies materials.';
  end if;

  select id into v_profile_id
    from public.electrician_profiles
   where (user_id = auth.uid() or auth_user_id = auth.uid())
     and verification_status = 'approved' and active = true
   order by created_at desc limit 1;

  if v_profile_id is null then raise exception 'Approved active electrician required'; end if;

  select * into v_booking from public.service_bookings
   where id = p_booking_id and assigned_electrician_id = v_profile_id
   for update;
  if not found then raise exception 'Assigned booking not found'; end if;
  if v_booking.status not in ('assigned','inspection','quote_rejected') then
    raise exception 'Booking is not ready for a quote';
  end if;

  v_total := round(p_service_charge, 2);
  update public.service_bookings
     set service_charge = round(p_service_charge, 2),
         materials_amount = 0,
         quoted_amount = v_total,
         quote_note = left(coalesce(p_quote_note, ''), 1000),
         quote_status = 'pending',
         quote_submitted_at = pg_catalog.now(),
         quote_responded_at = null,
         status = 'awaiting_quote_approval'
   where id = p_booking_id;

  return pg_catalog.jsonb_build_object('success', true, 'total', v_total, 'quote_status', 'pending');
end;
$function$;

comment on function public.srk_submit_booking_quote(uuid,numeric,numeric,text) is
'Labour-only quotation. Customer supplies all materials; non-zero materials amounts are rejected and new quotes persist materials_amount=0.';
