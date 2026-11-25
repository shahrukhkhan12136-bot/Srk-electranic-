create or replace function public.srk_service_attach_razorpay_qr(
 p_qr_id uuid,p_razorpay_qr_code_id text,p_image_url text,p_short_url text,
 p_close_by timestamptz,p_provider_payload jsonb
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_qr public.srk_razorpay_qr_codes%rowtype;
begin
 if coalesce(auth.role(),'')<>'service_role' then
  raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
 end if;
 if p_qr_id is null or coalesce(p_razorpay_qr_code_id,'') !~ '^qr_[A-Za-z0-9]+$'
    or p_image_url not like 'https://%' or p_short_url not like 'https://%'
    or p_close_by is null or p_close_by<clock_timestamp()+interval '15 minutes'
    or jsonb_typeof(p_provider_payload)<>'object' then
  raise exception 'INVALID_QR_PROVIDER_RESPONSE' using errcode='22023';
 end if;
 select * into v_qr from public.srk_razorpay_qr_codes where id=p_qr_id for update;
 if not found then raise exception 'QR_RESERVATION_NOT_FOUND'; end if;
 if v_qr.provider_status<>'creating' then
  if v_qr.razorpay_qr_code_id=p_razorpay_qr_code_id then
   return jsonb_build_object('success',true,'already_attached',true);
  end if;
  raise exception 'QR_RESERVATION_NOT_ATTACHABLE';
 end if;
 update public.srk_razorpay_qr_codes
 set razorpay_qr_code_id=p_razorpay_qr_code_id,image_url=p_image_url,
     short_url=p_short_url,close_by=p_close_by,provider_status='active',
     provider_payload=p_provider_payload,updated_at=clock_timestamp()
 where id=p_qr_id;
 -- A created webhook can arrive before the API response is attached locally.
 -- Reconcile that early event now that the provider QR ID is mapped.
 update public.srk_razorpay_webhook_events
 set processing_status='reconciled',processed_at=clock_timestamp(),
     reconciliation_reason=null,updated_at=clock_timestamp()
 where razorpay_qr_code_id=p_razorpay_qr_code_id
   and event_type='qr_code.created'
   and processing_status='exception'
   and reconciliation_reason='Unknown Razorpay QR code';
 return jsonb_build_object('success',true,'already_attached',false);
end;
$function$;
revoke all on function public.srk_service_attach_razorpay_qr(uuid,text,text,text,timestamptz,jsonb) from public,anon,authenticated;
grant execute on function public.srk_service_attach_razorpay_qr(uuid,text,text,text,timestamptz,jsonb) to service_role;