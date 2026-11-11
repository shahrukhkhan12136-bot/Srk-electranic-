do $$ begin
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
 if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role nologin; end if;
end $$;
create schema auth;
create table auth.users(id uuid primary key,phone text);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb) $$;
create function auth.role() returns text language sql stable as $$ select coalesce(auth.jwt()->>'role',current_user) $$;
create table public.service_bookings(
 id uuid primary key,customer_user_id uuid not null references auth.users(id),customer_name text not null,phone text not null,
 payment_status text not null,payment_verified_at timestamptz,amount_paid numeric(12,2),quote_status text,
 quoted_amount numeric(12,2),service_charge numeric(12,2),materials_amount numeric(12,2),
 razorpay_payment_id text,payment_method text,status text default 'completed',service_category_code text
);
create table public.srk_razorpay_refunds(
 id uuid primary key default gen_random_uuid(),booking_id uuid not null unique references public.service_bookings(id),
 payment_id text not null,refund_id text unique,amount numeric(12,2) not null,amount_paise bigint not null,
 currency text not null default 'INR',idempotency_key text not null unique,status text not null default 'requested',
 provider_status text,reason text not null,admin_user_id uuid not null references auth.users(id),
 previous_payout_note text,last_error text,created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),processed_at timestamptz
);
create table public.srk_booking_payable_snapshots(
 id uuid primary key,booking_id uuid not null references public.service_bookings(id),
 total_amount numeric(12,2) not null,amount_paise bigint not null,currency text not null,created_at timestamptz not null default now()
);
create table public.srk_razorpay_payments(
 id uuid primary key default gen_random_uuid(),provider_payment_id text not null,booking_id uuid not null references public.service_bookings(id),
 snapshot_id uuid not null references public.srk_booking_payable_snapshots(id),amount_paise bigint not null,currency text not null
);
create table public.srk_manual_payment_entries(
 id uuid primary key default gen_random_uuid(),booking_id uuid not null references public.service_bookings(id),
 payment_method text not null,amount numeric not null,payment_reference text not null,note text,
 recorded_by uuid not null references auth.users(id),recorded_at timestamptz not null default now()
);
create table public.srk_manual_refund_entries(
 id uuid primary key default gen_random_uuid(),booking_id uuid not null unique references public.service_bookings(id),
 payment_entry_id uuid not null unique references public.srk_manual_payment_entries(id),
 amount numeric not null,refund_reference text not null,note text,recorded_by uuid not null references auth.users(id),recorded_at timestamptz not null default now()
);
create table public.srk_electrician_payouts(
 id uuid primary key default gen_random_uuid(),booking_id uuid unique references public.service_bookings(id),
 payout_status text not null,payout_note text,updated_at timestamptz default now()
);
create function public.is_srk_admin() returns boolean language sql stable as $$ select coalesce(auth.jwt()->>'is_srk_admin','false')='true' $$;
create function public.srk_admin_record_manual_refund(p_booking_id uuid,p_reference text,p_note text default null)
returns jsonb language plpgsql security definer as $$
declare v_booking public.service_bookings%rowtype;v_payment public.srk_manual_payment_entries%rowtype;
begin
 select * into v_booking from public.service_bookings where id=p_booking_id for update;
 select * into v_payment from public.srk_manual_payment_entries where booking_id=p_booking_id for update;
 if not found then raise exception 'Manual payment audit record not found'; end if;
 if exists(select 1 from public.srk_manual_refund_entries where booking_id=p_booking_id) then raise exception 'Refund exists'; end if;
 insert into public.srk_manual_refund_entries(booking_id,payment_entry_id,amount,refund_reference,note,recorded_by)
 values(p_booking_id,v_payment.id,v_payment.amount,p_reference,p_note,auth.uid());
 update public.service_bookings set payment_status='refunded' where id=p_booking_id;
 return jsonb_build_object('success',true,'amount',v_payment.amount,'refund_reference',p_reference);
end $$;
insert into auth.users(id,phone) values
 ('10000000-0000-4000-8000-000000000001','919999999991'),
 ('10000000-0000-4000-8000-000000000002','919999999992'),
 ('10000000-0000-4000-8000-000000000003','919999999993');
insert into public.service_bookings(id,customer_user_id,customer_name,phone,payment_status,payment_verified_at,amount_paid,quote_status,quoted_amount,service_charge,materials_amount,razorpay_payment_id,payment_method)
values
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','Razorpay Customer','9999999991','paid',now(),1250,'approved',1250,1000,250,'pay_TEST123','Online'),
 ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','Manual Customer','9999999992','paid',now(),500,'approved',500,450,50,null,'Cash');
insert into public.srk_manual_payment_entries(booking_id,payment_method,amount,payment_reference,recorded_by)
values('20000000-0000-4000-8000-000000000002','cash',500,'CASH-RECEIPT-1','10000000-0000-4000-8000-000000000003');

insert into public.service_bookings(id,customer_user_id,customer_name,phone,payment_status,payment_verified_at,amount_paid,quote_status,quoted_amount,service_charge,materials_amount,razorpay_payment_id,payment_method,service_category_code)
values('20000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','Timer Customer','9999999991','paid',now(),1000,'not_submitted',null,null,null,'pay_TIMER123','Online','skilled');
insert into public.srk_booking_payable_snapshots(id,booking_id,total_amount,amount_paise,currency)
values('30000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000003',1000,100000,'INR');
insert into public.srk_razorpay_payments(provider_payment_id,booking_id,snapshot_id,amount_paise,currency)
values('pay_TIMER123','20000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000003',100000,'INR');
