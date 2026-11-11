-- Prevent timer-category bookings from entering legacy quote/status/Admin workflows.
-- All new timer bookings must use the customer-approved timer, materials,
-- payable snapshot, and dedicated cancellation RPCs.
begin;

create or replace function public.srk_submit_booking_quote(
  p_booking_id uuid,
  p_service_charge numeric,
  p_materials_amount numeric,
  p_quote_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
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

  select ep.id into v_profile_id
  from public.electrician_profiles ep
  where (ep.user_id = auth.uid() or ep.auth_user_id = auth.uid())
    and ep.verification_status = 'approved' and ep.active = true
  order by ep.created_at desc limit 1;
  if v_profile_id is null then raise exception 'Approved active electrician required'; end if;

  select b.* into v_booking
  from public.service_bookings b
  where b.id = p_booking_id and b.assigned_electrician_id = v_profile_id
  for update;
  if not found then raise exception 'Assigned booking not found'; end if;
  if v_booking.service_category_code is not null then
    raise exception 'TIMER_BOOKING_REQUIRES_TIMER_BILLING' using errcode = '55000';
  end if;
  if v_booking.status not in ('assigned','inspection','quote_rejected') then
    raise exception 'Booking is not ready for a quote';
  end if;

  v_total := round(p_service_charge + p_materials_amount, 2);
  update public.service_bookings
  set service_charge = round(p_service_charge, 2),
      materials_amount = round(p_materials_amount, 2),
      quoted_amount = v_total,
      quote_note = left(coalesce(p_quote_note, ''), 1000),
      quote_status = 'pending',
      quote_submitted_at = pg_catalog.now(),
      quote_responded_at = null,
      status = 'awaiting_quote_approval'
  where id = p_booking_id;

  return pg_catalog.jsonb_build_object('success',true,'total',v_total,'quote_status','pending');
end
$function$;

create or replace function public.srk_update_booking_work_status(
  p_booking_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_profile_id uuid;
  v_booking public.service_bookings%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_status not in ('inspection','in_progress','completed') then
    raise exception 'Invalid work status';
  end if;

  select ep.id into v_profile_id
  from public.electrician_profiles ep
  where ep.user_id = auth.uid()
    and ep.verification_status = 'approved' and ep.active = true;
  if v_profile_id is null then raise exception 'Approved active electrician required'; end if;

  select b.* into v_booking
  from public.service_bookings b
  where b.id = p_booking_id and b.assigned_electrician_id = v_profile_id
  for update;
  if not found then raise exception 'Assigned booking not found'; end if;
  if v_booking.service_category_code is not null then
    raise exception 'TIMER_BOOKING_REQUIRES_TIMER_BILLING' using errcode = '55000';
  end if;

  if p_status='inspection' and v_booking.status='assigned' then
    update public.service_bookings set status='inspection' where id=p_booking_id;
  elsif p_status='in_progress' and v_booking.status='quote_approved' and v_booking.quote_status='approved' then
    update public.service_bookings set status='in_progress',work_started_at=pg_catalog.now() where id=p_booking_id;
  elsif p_status='completed' and v_booking.status='in_progress' then
    update public.service_bookings set status='completed' where id=p_booking_id;
  else
    raise exception 'Invalid booking status transition';
  end if;
  return pg_catalog.jsonb_build_object('success',true,'status',p_status);
end
$function$;

create or replace function public.srk_customer_respond_booking_quote(
  p_booking_id uuid,
  p_response text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_booking public.service_bookings%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_response is null or p_response not in ('approved','rejected') then
    raise exception 'Invalid quote response';
  end if;

  select b.* into v_booking
  from public.service_bookings b
  where b.id=p_booking_id and b.customer_user_id=auth.uid()
  for update;
  if not found then raise exception 'Customer booking not found'; end if;
  if v_booking.service_category_code is not null then
    raise exception 'TIMER_BOOKING_REQUIRES_TIMER_BILLING' using errcode = '55000';
  end if;
  if v_booking.status <> 'awaiting_quote_approval' or v_booking.quote_status <> 'pending' then
    raise exception 'No quote is waiting for approval';
  end if;

  update public.service_bookings
  set quote_status=p_response,
      quote_responded_at=pg_catalog.now(),
      status=case when p_response='approved' then 'quote_approved' else 'quote_rejected' end
  where id=p_booking_id;
  return pg_catalog.jsonb_build_object('success',true,'quote_status',p_response);
end
$function$;

create or replace function public.srk_admin_update_booking(
  p_booking_id uuid,
  p_status text,
  p_address text,
  p_district text,
  p_state text,
  p_pincode text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_booking public.service_bookings%rowtype;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin permission required' using errcode='42501';
  end if;
  if p_booking_id is null then raise exception 'Booking ID required'; end if;
  if p_address is null or length(pg_catalog.btrim(p_address))=0 or length(p_address)>300
     or p_district is null or length(pg_catalog.btrim(p_district))=0 or length(p_district)>80
     or p_state is null or length(pg_catalog.btrim(p_state))=0 or length(p_state)>80
     or p_pincode is null or p_pincode !~ '^[0-9]{6}$' then
    raise exception 'Valid address, district, state and six-digit PIN required';
  end if;

  select b.* into v_booking
  from public.service_bookings b
  where b.id=p_booking_id
  for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_booking.service_category_code is not null then
    raise exception 'TIMER_BOOKING_REQUIRES_TIMER_ADMIN_WORKFLOW' using errcode='55000';
  end if;

  if p_status is not null then
    if p_status not in ('new','confirmed','assigned','inspection','awaiting_quote_approval',
      'quote_approved','quote_rejected','in_progress','completed','cancelled') then
      raise exception 'Invalid booking status';
    end if;
    if v_booking.status='new' and p_status not in ('new','confirmed','cancelled') then
      raise exception 'New booking can only remain new, be confirmed, or be cancelled';
    elsif v_booking.status='confirmed' and p_status not in ('confirmed','cancelled') then
      raise exception 'Confirmed booking can only remain confirmed or be cancelled';
    elsif v_booking.status not in ('new','confirmed') and p_status not in (v_booking.status,'cancelled') then
      raise exception 'Admin cannot skip booking workflow stages';
    end if;
    if p_status='assigned' and v_booking.assigned_electrician_id is null then
      raise exception 'Electrician assignment required';
    end if;
    if p_status='cancelled' and v_booking.payment_status='paid' then
      raise exception 'Paid booking requires the verified refund workflow before cancellation';
    end if;
  end if;

  update public.service_bookings
  set status=coalesce(p_status,status),
      address=pg_catalog.btrim(p_address),
      district=pg_catalog.btrim(p_district),
      state=pg_catalog.btrim(p_state),
      pincode=p_pincode
  where id=p_booking_id;
  return pg_catalog.jsonb_build_object('success',true);
end
$function$;

create or replace function public.srk_get_my_assigned_booking_quote_details()
returns table(
  booking_id uuid,
  service_type text,
  state text,
  district text,
  pincode text,
  booking_status text,
  quoted_amount numeric,
  service_charge numeric,
  materials_amount numeric,
  quote_status text,
  quote_note text,
  payment_method text,
  payment_status text,
  location_lat double precision,
  location_lng double precision,
  address text
)
language sql
stable
security definer
set search_path = ''
as $function$
  select b.id,b.service_type,b.state,b.district,b.pincode,b.status,
         b.quoted_amount,b.service_charge,b.materials_amount,
         b.quote_status,b.quote_note,b.payment_method,b.payment_status,
         b.location_lat,b.location_lng,b.address
  from public.electrician_profiles p
  join public.service_bookings b on b.assigned_electrician_id=p.id
  where auth.uid() is not null
    and (p.user_id=auth.uid() or p.auth_user_id=auth.uid())
    and p.verification_status='approved'
    and p.active=true
    and b.service_category_code is null
    and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved',
      'quote_rejected','in_progress','completed')
  order by b.created_at desc
  limit 100;
$function$;

revoke all on function public.srk_submit_booking_quote(uuid,numeric,numeric,text) from public,anon;
revoke all on function public.srk_update_booking_work_status(uuid,text) from public,anon;
revoke all on function public.srk_customer_respond_booking_quote(uuid,text) from public,anon;
revoke all on function public.srk_admin_update_booking(uuid,text,text,text,text,text) from public,anon;
revoke all on function public.srk_get_my_assigned_booking_quote_details() from public,anon;
grant execute on function public.srk_submit_booking_quote(uuid,numeric,numeric,text) to authenticated,service_role;
grant execute on function public.srk_update_booking_work_status(uuid,text) to authenticated,service_role;
grant execute on function public.srk_customer_respond_booking_quote(uuid,text) to authenticated,service_role;
grant execute on function public.srk_admin_update_booking(uuid,text,text,text,text,text) to authenticated,service_role;
grant execute on function public.srk_get_my_assigned_booking_quote_details() to authenticated,service_role;

commit;
