create or replace function public.srk_service_reserve_razorpay_qr_for_technician(
  p_booking_id uuid,
  p_user_id uuid,
  p_final_bill_id uuid,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_customer_user_id uuid;
  v_assignment_count integer;
begin
  if coalesce(auth.role(),'') <> 'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;
  if p_booking_id is null or p_user_id is null or p_final_bill_id is null
     or p_idempotency_key is null or length(p_idempotency_key) not between 8 and 160 then
    raise exception 'INVALID_QR_RESERVATION_INPUT' using errcode='22023';
  end if;

  select b.customer_user_id into v_customer_user_id
  from public.service_bookings b
  where b.id=p_booking_id
    and b.status='completed'
    and lower(coalesce(b.payment_status,'')) not in ('paid','completed','refunded')
    and lower(coalesce(b.payment_method,'')) in ('online','upi','card');

  if not found or v_customer_user_id is null then
    raise exception 'BOOKING_NOT_PAYABLE';
  end if;

  select count(*) into v_assignment_count
  from public.srk_booking_workers bw
  join public.srk_worker_profiles wp on wp.id=bw.worker_id
  where bw.booking_id=p_booking_id
    and wp.user_id=p_user_id
    and wp.worker_type='technician'
    and bw.worker_role='technician'
    and bw.assignment_status='completed'
    and bw.worker_completed_at is not null;

  if v_assignment_count < 1 then
    raise exception 'TECHNICIAN_NOT_AUTHORIZED_FOR_BOOKING' using errcode='42501';
  end if;

  return public.srk_service_reserve_razorpay_qr(
    p_booking_id, v_customer_user_id, p_final_bill_id, p_idempotency_key
  );
end;
$function$;

revoke all on function public.srk_service_reserve_razorpay_qr_for_technician(uuid,uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.srk_service_reserve_razorpay_qr_for_technician(uuid,uuid,uuid,text) to service_role;