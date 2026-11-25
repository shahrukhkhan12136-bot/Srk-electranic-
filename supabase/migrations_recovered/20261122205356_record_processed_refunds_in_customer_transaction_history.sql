
create or replace function public.srk_create_booking_refund_transaction()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_method text;
begin
  if new.status='processed' and (tg_op='INSERT' or old.status is distinct from 'processed') then
    select case when lower(payment_method) in ('upi','card') then lower(payment_method)
      when lower(payment_method)='cash' then 'cash' else 'online' end
    into v_method from public.service_bookings where id=new.booking_id;
    insert into public.srk_booking_transactions(
      booking_id,transaction_type,payment_method,amount,transaction_status,provider,
      provider_reference,idempotency_key,verified_at,metadata
    ) values(
      new.booking_id,'refund',coalesce(v_method,'online'),new.amount,'refunded','refund_workflow',
      new.refund_code,'booking-refund:'||new.id::text,coalesce(new.processed_at,clock_timestamp()),
      jsonb_build_object('refund_request_id',new.id,'refund_record_id',new.refund_record_id)
    ) on conflict(idempotency_key) do nothing;
  end if;
  return new;
end $$;
drop trigger if exists srk_create_booking_refund_transaction_trigger on public.srk_booking_refund_requests;
create trigger srk_create_booking_refund_transaction_trigger
after insert or update of status on public.srk_booking_refund_requests
for each row execute function public.srk_create_booking_refund_transaction();
revoke all on function public.srk_create_booking_refund_transaction() from public,anon,authenticated;
