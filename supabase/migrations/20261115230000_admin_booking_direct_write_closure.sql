-- Close remaining direct Admin writes to legacy booking quote and customer location.
-- Feature Branch only. Do not apply to Production without separate owner approval.

-- The quote editor is retired. Historical amounts are read-only in srk_private archive.
DROP FUNCTION IF EXISTS public.srk_admin_update_legacy_booking_quote(uuid,numeric);

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
