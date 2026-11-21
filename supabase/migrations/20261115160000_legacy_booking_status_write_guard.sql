-- Restrict legacy booking status changes to audited SECURITY DEFINER workflows.
-- Feature branch only: do not apply to Production without explicit approval.

create or replace function public.srk_admin_confirm_legacy_booking(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_booking public.service_bookings%rowtype;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ONLY' using errcode='42501';
  end if;
  if p_booking_id is null then
    raise exception 'BOOKING_ID_REQUIRED' using errcode='22023';
  end if;

  select * into v_booking
  from public.service_bookings
  where id=p_booking_id
  for update;

  if not found then
    raise exception 'BOOKING_NOT_FOUND' using errcode='P0002';
  end if;
  if v_booking.selected_category is not null then
    raise exception 'NEW_CATEGORY_BOOKING_USES_SERVER_WORKFLOW' using errcode='55000';
  end if;
  if v_booking.status is distinct from 'new' then
    raise exception 'ONLY_NEW_LEGACY_BOOKINGS_CAN_BE_CONFIRMED' using errcode='55000';
  end if;
  if v_booking.assigned_electrician_id is not null then
    raise exception 'UNEXPECTED_ELECTRICIAN_ASSIGNMENT_ON_NEW_BOOKING' using errcode='55000';
  end if;
  if v_booking.payment_status in ('paid','refunded') then
    raise exception 'PAYMENT_STATE_REQUIRES_PAYMENT_WORKFLOW' using errcode='55000';
  end if;
  if v_booking.razorpay_order_id is not null or v_booking.razorpay_payment_id is not null then
    raise exception 'ONLINE_PAYMENT_BOOKING_REQUIRES_PAYMENT_WORKFLOW' using errcode='55000';
  end if;

  update public.service_bookings
  set status='confirmed'
  where id=p_booking_id and status='new' and selected_category is null;

  if not found then
    raise exception 'BOOKING_CONFIRMATION_CONFLICT' using errcode='40001';
  end if;

  return jsonb_build_object('success',true,'booking_id',p_booking_id,'status','confirmed');
end;
$$;

revoke all on function public.srk_admin_confirm_legacy_booking(uuid) from public,anon;
grant execute on function public.srk_admin_confirm_legacy_booking(uuid) to authenticated;

-- Remove table-wide/column status write capability from clients. Keep the
-- existing Admin quote/payment columns; payment transitions remain RPC-owned.
revoke update on table public.service_bookings from authenticated;
revoke update (status) on table public.service_bookings from authenticated;
grant update (quoted_amount,amount_paid,payment_status)
  on table public.service_bookings to authenticated;
