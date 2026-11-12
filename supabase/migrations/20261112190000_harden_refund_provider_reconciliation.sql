-- Harden provider refund reconciliation against ID replacement and out-of-order terminal states.
-- Forward-only migration: the original refund workflow migration is already present in Production history.
begin;

create or replace function public.srk_service_reconcile_booking_refund(
 p_refund_record_id uuid,
 p_provider_refund_id text,
 p_provider_status text,
 p_error text default null
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
 v_refund public.srk_razorpay_refunds%rowtype;
 v_status text;
begin
 if auth.role()<>'service_role' then
  raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
 end if;
 if p_refund_record_id is null
    or p_provider_status not in ('pending','processed','failed')
    or (p_provider_refund_id is not null and p_provider_refund_id !~ '^rfnd_[A-Za-z0-9]+$') then
  raise exception 'INVALID_PROVIDER_REFUND_RESULT' using errcode='22023';
 end if;

 select * into v_refund
 from public.srk_razorpay_refunds
 where id=p_refund_record_id
 for update;
 if not found then
  raise exception 'REFUND_RECORD_NOT_FOUND';
 end if;

 -- A provider refund ID is immutable once first bound, including after completion.
 if v_refund.refund_id is not null
    and p_provider_refund_id is not null
    and v_refund.refund_id<>p_provider_refund_id then
  raise exception 'PROVIDER_REFUND_ID_CONFLICT' using errcode='23505';
 end if;

 -- Processed and failed are terminal provider states. Ignore stale pending
 -- notifications after failure; do not silently reopen or downgrade a refund.
 if v_refund.status='processed' then
  -- Legacy processed rows may not yet have a provider refund ID. Bind the
  -- first verified ID without changing the terminal status or timestamps.
  if v_refund.refund_id is null and p_provider_refund_id is not null then
   update public.srk_razorpay_refunds
   set refund_id=p_provider_refund_id,updated_at=clock_timestamp()
   where id=p_refund_record_id and refund_id is null;
  end if;
  return jsonb_build_object('success',true,'status','processed','replayed',true);
 end if;
 if v_refund.status='failed' then
  if p_provider_status='pending' then
   return jsonb_build_object('success',true,'status','failed','stale_event_ignored',true);
  end if;
  if p_provider_status='processed' then
   raise exception 'TERMINAL_REFUND_STATUS_CONFLICT' using errcode='55000';
  end if;
 end if;

 v_status:=case p_provider_status
  when 'pending' then 'processing'
  when 'processed' then 'processed'
  else 'failed'
 end;

 update public.srk_razorpay_refunds
 set refund_id=coalesce(p_provider_refund_id,refund_id),
     provider_status=p_provider_status,
     status=v_status,
     last_error=case when p_provider_status='failed' then left(coalesce(p_error,'Refund failed'),500) else null end,
     processed_at=case when p_provider_status='processed' then clock_timestamp() else null end,
     updated_at=clock_timestamp()
 where id=p_refund_record_id;

 update public.srk_booking_refund_requests
 set status=case when p_provider_status='processed' then 'processed'
                 when p_provider_status='failed' then 'unknown'
                 else 'processing' end,
     updated_at=clock_timestamp(),
     processed_at=case when p_provider_status='processed' then clock_timestamp() else null end
 where refund_record_id=p_refund_record_id;

 if p_provider_status='processed' then
  update public.service_bookings
  set payment_status='refunded'
  where id=v_refund.booking_id and payment_status='paid';
 end if;

 return jsonb_build_object('success',true,'status',v_status,'booking_id',v_refund.booking_id);
end
$function$;

revoke all on function public.srk_service_reconcile_booking_refund(uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.srk_service_reconcile_booking_refund(uuid,text,text,text) to service_role;

commit;
