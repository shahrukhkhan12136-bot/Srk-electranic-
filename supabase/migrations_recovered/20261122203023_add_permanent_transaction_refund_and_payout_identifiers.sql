
create sequence if not exists public.srk_txn_id_seq start 1;
create sequence if not exists public.srk_refund_id_seq start 1;
create sequence if not exists public.srk_payout_id_seq start 1;
create sequence if not exists public.srk_support_case_id_seq start 1;

alter table public.srk_booking_payment_evidence add column if not exists transaction_code text unique;
alter table public.srk_worker_wallet_ledger add column if not exists transaction_code text unique;
alter table public.srk_booking_refund_requests add column if not exists refund_code text unique;

create or replace function public.srk_assign_transaction_code()
returns trigger language plpgsql set search_path=pg_catalog,public as $$
begin
  if new.transaction_code is null then
    new.transaction_code:='SRK-TXN-'||lpad(nextval('public.srk_txn_id_seq')::text,6,'0');
  end if;
  return new;
end $$;

create or replace function public.srk_assign_refund_code()
returns trigger language plpgsql set search_path=pg_catalog,public as $$
begin
  if new.refund_code is null then
    new.refund_code:='SRK-REF-'||lpad(nextval('public.srk_refund_id_seq')::text,6,'0');
  end if;
  return new;
end $$;

create or replace function public.srk_assign_payout_code()
returns trigger language plpgsql set search_path=pg_catalog,public as $$
begin
  if new.payout_code is null then
    new.payout_code:='SRK-PAY-'||lpad(nextval('public.srk_payout_id_seq')::text,6,'0');
  end if;
  return new;
end $$;

create or replace function public.srk_assign_support_case_number()
returns trigger language plpgsql set search_path=pg_catalog,public as $$
begin
  if new.case_number is null then
    new.case_number:='SRK-CASE-'||lpad(nextval('public.srk_support_case_id_seq')::text,6,'0');
  end if;
  return new;
end $$;

drop trigger if exists srk_payment_evidence_transaction_code_trigger on public.srk_booking_payment_evidence;
create trigger srk_payment_evidence_transaction_code_trigger before insert on public.srk_booking_payment_evidence
for each row execute function public.srk_assign_transaction_code();

drop trigger if exists srk_wallet_ledger_transaction_code_trigger on public.srk_worker_wallet_ledger;
create trigger srk_wallet_ledger_transaction_code_trigger before insert on public.srk_worker_wallet_ledger
for each row execute function public.srk_assign_transaction_code();

drop trigger if exists srk_booking_refund_code_trigger on public.srk_booking_refund_requests;
create trigger srk_booking_refund_code_trigger before insert on public.srk_booking_refund_requests
for each row execute function public.srk_assign_refund_code();

drop trigger if exists srk_worker_payout_code_trigger on public.srk_worker_payout_requests;
create trigger srk_worker_payout_code_trigger before insert on public.srk_worker_payout_requests
for each row execute function public.srk_assign_payout_code();

drop trigger if exists srk_support_case_number_trigger on public.srk_support_cases;
create trigger srk_support_case_number_trigger before insert on public.srk_support_cases
for each row execute function public.srk_assign_support_case_number();

revoke all on function public.srk_assign_transaction_code() from public,anon,authenticated;
revoke all on function public.srk_assign_refund_code() from public,anon,authenticated;
revoke all on function public.srk_assign_payout_code() from public,anon,authenticated;
revoke all on function public.srk_assign_support_case_number() from public,anon,authenticated;
