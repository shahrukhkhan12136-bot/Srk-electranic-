-- Close remaining direct Admin writes to legacy booking quote and customer location.
-- Feature Branch only. Do not apply to Production without separate owner approval.

create or replace function public.srk_admin_update_legacy_booking_quote(
  p_booking_id uuid,
  p_quoted_amount numeric
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_booking public.service_bookings%rowtype;
  v_amount_paise bigint;
  v_split_paise bigint;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ONLY' using errcode='42501';
  end if;
  if p_booking_id is null then
    raise exception 'BOOKING_ID_REQUIRED' using errcode='22023';
  end if;
  if p_quoted_amount is not null and
     (p_quoted_amount<0 or p_quoted_amount>10000000
      or p_quoted_amount*100<>trunc(p_quoted_amount*100)) then
    raise exception 'INVALID_QUOTE_AMOUNT' using errcode='22023';
  end if;

  select * into v_booking
    from public.service_bookings
   where id=p_booking_id
   for update;
  if not found then raise exception 'BOOKING_NOT_FOUND' using errcode='P0002'; end if;
  if v_booking.selected_category is not null then
    raise exception 'NEW_CATEGORY_BOOKING_USES_SERVER_WORKFLOW' using errcode='55000';
  end if;
  if v_booking.status='cancelled' then
    raise exception 'CANCELLED_BOOKING_QUOTE_IS_LOCKED' using errcode='55000';
  end if;
  if coalesce(v_booking.payment_status,'unpaid') not in ('unpaid','pending')
     or v_booking.payment_verified_at is not null
     or coalesce(v_booking.amount_paid,0)<>0
     or v_booking.razorpay_order_id is not null
     or v_booking.razorpay_payment_id is not null then
    raise exception 'PAID_OR_ONLINE_BOOKING_QUOTE_IS_LOCKED' using errcode='55000';
  end if;
  if v_booking.quote_status='approved'
     and p_quoted_amount is distinct from v_booking.quoted_amount then
    raise exception 'CUSTOMER_APPROVED_QUOTE_IS_IMMUTABLE' using errcode='55000';
  end if;

  if v_booking.service_charge is not null then
    if p_quoted_amount is null or v_booking.service_charge<=0
       or coalesce(v_booking.materials_amount,0)<0 then
      raise exception 'APPROVED_LABOUR_AND_MATERIAL_BREAKDOWN_REQUIRED' using errcode='55000';
    end if;
    v_amount_paise:=round(p_quoted_amount*100)::bigint;
    v_split_paise:=round(v_booking.service_charge*100)::bigint
      +round(coalesce(v_booking.materials_amount,0)*100)::bigint;
    if v_amount_paise<>v_split_paise then
      raise exception 'QUOTE_MUST_MATCH_LABOUR_PLUS_MATERIALS' using errcode='55000';
    end if;
  end if;

  if p_quoted_amount is distinct from v_booking.quoted_amount then
    update public.service_bookings
       set quoted_amount=p_quoted_amount
     where id=p_booking_id;
  end if;
  return jsonb_build_object('success',true,'booking_id',p_booking_id,
    'quoted_amount',p_quoted_amount,
    'changed',p_quoted_amount is distinct from v_booking.quoted_amount);
end;
$function$;

revoke all on function public.srk_admin_update_legacy_booking_quote(uuid,numeric) from public,anon;
grant execute on function public.srk_admin_update_legacy_booking_quote(uuid,numeric) to authenticated;

create or replace function public.srk_admin_update_booking_customer_location(
  p_booking_id uuid,
  p_address text,
  p_district text,
  p_state text,
  p_pincode text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_booking public.service_bookings%rowtype;
  v_changed text[]:=array[]::text[];
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ONLY' using errcode='42501';
  end if;
  if p_booking_id is null then raise exception 'BOOKING_ID_REQUIRED' using errcode='22023'; end if;
  if char_length(btrim(coalesce(p_address,''))) not between 1 and 300
     or char_length(btrim(coalesce(p_district,''))) not between 1 and 80
     or char_length(btrim(coalesce(p_state,''))) not between 1 and 80
     or btrim(coalesce(p_pincode,'')) !~ '^[0-9]{6}$' then
    raise exception 'INVALID_CUSTOMER_LOCATION' using errcode='22023';
  end if;

  select * into v_booking
    from public.service_bookings
   where id=p_booking_id
   for update;
  if not found then raise exception 'BOOKING_NOT_FOUND' using errcode='P0002'; end if;

  if v_booking.address is distinct from btrim(p_address) then v_changed:=array_append(v_changed,'address'); end if;
  if v_booking.district is distinct from btrim(p_district) then v_changed:=array_append(v_changed,'district'); end if;
  if v_booking.state is distinct from btrim(p_state) then v_changed:=array_append(v_changed,'state'); end if;
  if v_booking.pincode is distinct from btrim(p_pincode) then v_changed:=array_append(v_changed,'pincode'); end if;

  if cardinality(v_changed)>0 then
    update public.service_bookings
       set address=btrim(p_address),district=btrim(p_district),
           state=btrim(p_state),pincode=btrim(p_pincode)
     where id=p_booking_id;

    insert into public.srk_admin_audit_events
      (entity_type,entity_id,booking_id,action,actor_user_id,actor_role,
       changed_fields,before_data,after_data)
    values
      ('booking',p_booking_id,p_booking_id,'updated',auth.uid(),'admin',v_changed,
       jsonb_build_object('address',v_booking.address,'district',v_booking.district,
         'state',v_booking.state,'pincode',v_booking.pincode),
       jsonb_build_object('address',btrim(p_address),'district',btrim(p_district),
         'state',btrim(p_state),'pincode',btrim(p_pincode)));
  end if;

  return jsonb_build_object('success',true,'booking_id',p_booking_id,
    'changed',cardinality(v_changed)>0,'changed_fields',to_jsonb(v_changed));
end;
$function$;

revoke all on function public.srk_admin_update_booking_customer_location(uuid,text,text,text,text) from public,anon;
grant execute on function public.srk_admin_update_booking_customer_location(uuid,text,text,text,text) to authenticated;

-- All customer-booking writes now pass through validated, Main-Admin-only RPCs
-- or existing server/service-role payment workflows.
revoke update on table public.service_bookings from authenticated;
revoke update (status,quoted_amount,amount_paid,payment_status,address,district,state,pincode)
  on table public.service_bookings from authenticated;

notify pgrst,'reload schema';
