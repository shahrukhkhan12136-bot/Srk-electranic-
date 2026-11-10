-- Assigned electricians may read destination coordinates and payment state for their own jobs.
drop function if exists public.srk_get_my_assigned_booking_quote_details();
create function public.srk_get_my_assigned_booking_quote_details()
returns table(
 booking_id uuid, service_type text, state text, district text, pincode text,
 booking_status text, quoted_amount numeric, service_charge numeric, materials_amount numeric,
 quote_status text, quote_note text, payment_method text, payment_status text,
 location_lat double precision, location_lng double precision, address text
)
language sql stable security definer
set search_path = pg_catalog, public, auth, pg_temp
as $$
 select b.id,b.service_type,b.state,b.district,b.pincode,b.status,b.quoted_amount,
        b.service_charge,b.materials_amount,b.quote_status,b.quote_note,b.payment_method,
        b.payment_status,b.location_lat,b.location_lng,b.address
 from public.electrician_profiles p
 join public.service_bookings b on b.assigned_electrician_id=p.id
 where auth.uid() is not null
   and (p.user_id=auth.uid() or p.auth_user_id=auth.uid())
   and p.verification_status='approved' and p.active=true
   and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed')
 order by b.created_at desc limit 100;
$$;
revoke all on function public.srk_get_my_assigned_booking_quote_details() from public,anon;
grant execute on function public.srk_get_my_assigned_booking_quote_details() to authenticated;

-- Cash is confirmed only by the assigned, approved electrician after completed work.
create or replace function public.srk_electrician_confirm_cash_payment(p_booking_id uuid)
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public, auth, pg_temp
as $$
declare v_uid uuid:=auth.uid(); v_booking public.service_bookings%rowtype;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 select b.* into v_booking
 from public.service_bookings b
 join public.electrician_profiles p on p.id=b.assigned_electrician_id
 where b.id=p_booking_id and (p.user_id=v_uid or p.auth_user_id=v_uid)
   and p.verification_status='approved' and p.active=true
 for update of b;
 if not found then raise exception 'Assigned booking not found'; end if;
 if v_booking.status<>'completed' or v_booking.quote_status<>'approved' then
   raise exception 'Completed work and approved quote required';
 end if;
 if lower(coalesce(v_booking.payment_method,'')) not in ('cash','नकद (cash)','नकद') then
   raise exception 'This booking is not marked for cash payment';
 end if;
 if v_booking.payment_status='paid' then return jsonb_build_object('success',true,'already_paid',true); end if;
 if v_booking.payment_status not in ('unpaid','pending') or coalesce(v_booking.quoted_amount,0)<=0 then
   raise exception 'Payment state or amount is invalid';
 end if;
 update public.service_bookings
 set payment_status='paid',amount_paid=v_booking.quoted_amount,payment_verified_at=now()
 where id=p_booking_id;
 return jsonb_build_object('success',true,'payment_method','cash','amount_paid',v_booking.quoted_amount);
end;
$$;
revoke all on function public.srk_electrician_confirm_cash_payment(uuid) from public,anon;
grant execute on function public.srk_electrician_confirm_cash_payment(uuid) to authenticated;
