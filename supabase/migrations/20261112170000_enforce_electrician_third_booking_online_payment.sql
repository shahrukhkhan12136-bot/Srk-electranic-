-- Enforce the electrician's every-third-booking online-only rule atomically.
-- This migration is committed to the feature branch only; it is not applied to production.
-- A booking slot is reserved when an approved electrician accepts the offer.
-- Cancelled/refunded bookings are excluded from subsequent counts.
create or replace function public.srk_respond_to_offer(p_offer_id uuid, p_response text)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'auth', 'pg_temp'
as $function$
declare
  v_booking_id uuid;
  v_electrician_id uuid;
  v_offer_status text;
  v_payment_method text;
  v_prior_booking_count bigint;
  v_booking_status text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

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
    -- Serialize all offer acceptances for this electrician. This prevents
    -- simultaneous offers from both seeing the same booking sequence number.
    perform 1
      from public.electrician_profiles
     where id = v_electrician_id
     for update;

    -- Lock the booking before checking and assigning it.
    select payment_method, status
      into v_payment_method, v_booking_status
      from public.service_bookings
     where id = v_booking_id
       and assigned_electrician_id is null
       and status in ('new','confirmed')
     for update;

    if not found then
      raise exception 'This job has already been assigned or is no longer available';
    end if;

    select count(*)
      into v_prior_booking_count
      from public.service_bookings b
     where b.assigned_electrician_id = v_electrician_id
       and b.id <> v_booking_id
       and b.status not in ('cancelled')
       and b.payment_status not in ('refunded');

    -- Booking numbers 3, 6, 9, ... must use the Razorpay online method.
    if mod(v_prior_booking_count + 1, 3) = 0
       and lower(btrim(coalesce(v_payment_method, ''))) <> lower('Razorpay ऑनलाइन भुगतान') then
      raise exception 'इस इलेक्ट्रिशियन की हर तीसरी बुकिंग में ऑनलाइन भुगतान अनिवार्य है। कृपया ग्राहक से Razorpay ऑनलाइन भुगतान चुनवाएँ।'
        using errcode = '23514';
    end if;

    update public.service_bookings
       set assigned_electrician_id = v_electrician_id,
           status = 'assigned'
     where id = v_booking_id
       and assigned_electrician_id is null
       and status in ('new','confirmed');

    if not found then
      raise exception 'This job has already been assigned';
    end if;
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
$function$;

comment on function public.srk_respond_to_offer(uuid, text) is
'Secure offer response. Serializes electrician offer acceptance and requires Razorpay online payment on every third non-cancelled/non-refunded assigned booking.';
