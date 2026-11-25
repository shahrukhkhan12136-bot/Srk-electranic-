
alter table public.srk_booking_workers
  add column if not exists on_the_way_at timestamptz,
  add column if not exists arrived_at timestamptz;
alter table public.service_bookings
  add column if not exists pending_cancellation_fee_amount numeric(12,2) not null default 0
    check (pending_cancellation_fee_amount>=0);
alter table public.srk_booking_final_bills
  add column if not exists cancellation_fee_amount numeric(12,2) not null default 0
    check (cancellation_fee_amount>=0);

alter table public.srk_booking_final_bill_items
  drop constraint if exists srk_booking_final_bill_items_item_type_check;
alter table public.srk_booking_final_bill_items
  add constraint srk_booking_final_bill_items_item_type_check
  check (item_type in ('service','labour','material','discount','other','cancellation_fee'));

create table if not exists public.srk_booking_cancellation_fees (
 id uuid primary key default gen_random_uuid(),
 cancelled_booking_id uuid not null unique references public.service_bookings(id) on delete restrict,
 customer_user_id uuid not null,
 fee_amount numeric(12,2) not null check (fee_amount>0),
 fee_basis text not null check (fee_basis in ('technician_on_the_way','technician_arrived')),
 status text not null default 'pending'
   check (status in ('pending','added_to_next_booking','paid','waived','under_review')),
 next_booking_id uuid references public.service_bookings(id) on delete restrict,
 created_at timestamptz not null default now(),
 added_to_next_booking_at timestamptz,
 paid_at timestamptz,
 waived_by uuid,
 waiver_reason text
);
create index if not exists srk_booking_cancellation_fees_customer_status_idx
 on public.srk_booking_cancellation_fees(customer_user_id,status,created_at);
create index if not exists srk_booking_cancellation_fees_next_booking_idx
 on public.srk_booking_cancellation_fees(next_booking_id);
alter table public.srk_booking_cancellation_fees enable row level security;

create or replace function public.srk_set_final_bill_total()
returns trigger
language plpgsql
set search_path to 'pg_catalog','public'
as $function$
begin
 new.total_amount:=round(new.service_amount+new.materials_amount
   +coalesce(new.cancellation_fee_amount,0)-new.discount_amount+new.tax_amount,2);
 return new;
end
$function$;
