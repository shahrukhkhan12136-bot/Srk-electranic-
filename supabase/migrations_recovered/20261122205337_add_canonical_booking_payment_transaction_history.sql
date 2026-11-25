
create table if not exists public.srk_booking_transactions (
  id uuid primary key default gen_random_uuid(),
  transaction_code text unique,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  transaction_type text not null,
  payment_method text not null,
  amount numeric(12,2) not null,
  transaction_status text not null default 'pending',
  provider text not null,
  provider_reference text,
  order_reference text,
  idempotency_key text not null unique,
  created_at timestamptz not null default now(),
  verified_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  constraint srk_booking_transaction_type_valid check(transaction_type in ('payment','refund','adjustment')),
  constraint srk_booking_transaction_method_valid check(payment_method in ('cash','online','upi','card','manual')),
  constraint srk_booking_transaction_status_valid check(transaction_status in ('initiated','pending','success','failed','refunded','reversed')),
  constraint srk_booking_transaction_amount_valid check(amount>=0)
);
create unique index if not exists srk_booking_transaction_provider_reference_unique
  on public.srk_booking_transactions(provider,provider_reference)
  where provider_reference is not null;
create index if not exists srk_booking_transactions_booking_time_idx
  on public.srk_booking_transactions(booking_id,created_at desc);

alter table public.srk_booking_transactions enable row level security;
create policy srk_booking_transactions_participant_read on public.srk_booking_transactions
for select to authenticated using(
  public.srk_has_admin_permission('payments.read')
  or exists(select 1 from public.service_bookings b where b.id=booking_id and b.customer_user_id=(select auth.uid()))
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.booking_id=srk_booking_transactions.booking_id and w.user_id=(select auth.uid()))
);

drop trigger if exists srk_booking_transaction_code_trigger on public.srk_booking_transactions;
create trigger srk_booking_transaction_code_trigger before insert on public.srk_booking_transactions
for each row execute function public.srk_assign_transaction_code();

create or replace function public.srk_create_booking_payment_transaction()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_method text; v_provider text; v_reference text;
begin
  if new.status='completed' and lower(coalesce(new.payment_status,'')) in ('paid','completed')
     and not (old.status='completed' and lower(coalesce(old.payment_status,'')) in ('paid','completed')) then
    v_method:=case when lower(new.payment_method) in ('upi','card') then lower(new.payment_method)
      when lower(new.payment_method)='cash' then 'cash' else 'online' end;
    v_provider:=case when v_method='cash' then 'cash_confirmation'
      when new.razorpay_payment_id is not null then 'razorpay' else 'manual' end;
    v_reference:=coalesce(new.razorpay_payment_id,'');
    insert into public.srk_booking_transactions(
      booking_id,transaction_type,payment_method,amount,transaction_status,provider,
      provider_reference,order_reference,idempotency_key,verified_at,metadata
    ) values(
      new.id,'payment',v_method,coalesce(new.amount_paid,0),'success',v_provider,
      nullif(v_reference,''),new.razorpay_order_id,'booking-payment:'||new.id::text,
      coalesce(new.payment_verified_at,clock_timestamp()),
      jsonb_build_object('cash_evidence_count',(select count(*) from public.srk_booking_payment_evidence where booking_id=new.id and payment_method='cash'))
    ) on conflict(idempotency_key) do nothing;
  end if;
  return new;
end $$;
drop trigger if exists srk_create_booking_payment_transaction_trigger on public.service_bookings;
create trigger srk_create_booking_payment_transaction_trigger
after update of status,payment_status on public.service_bookings
for each row execute function public.srk_create_booking_payment_transaction();

revoke all on function public.srk_create_booking_payment_transaction() from public,anon,authenticated;
