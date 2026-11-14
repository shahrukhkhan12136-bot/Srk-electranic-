-- Cancellation fee debt carry-forward and separate accounting.
-- Feature-branch source only. No production migration is applied by this commit.

alter table public.srk_wallet_ledger
  drop constraint if exists srk_wallet_ledger_entry_type_check;
alter table public.srk_wallet_ledger
  add constraint srk_wallet_ledger_entry_type_check
  check (entry_type in ('booking_payment','refund','earning','commission','payout','adjustment','topup','cancellation_fee'));

create table if not exists public.srk_customer_cancellation_fee_debts (
  id uuid primary key default gen_random_uuid(),
  cancellation_request_id uuid not null unique
    references public.srk_booking_cancellation_requests(id) on delete restrict,
  customer_user_id uuid not null references auth.users(id) on delete restrict,
  source_booking_id uuid not null references public.service_bookings(id) on delete restrict,
  amount_paise bigint not null check (amount_paise in (4900,9900)),
  status text not null default 'open'
    check (status in ('open','reserved','settled','reversed')),
  reserved_booking_id uuid references public.service_bookings(id) on delete restrict,
  created_at timestamptz not null default now(),
  settled_at timestamptz,
  reversed_at timestamptz,
  check (
    (status='open' and reserved_booking_id is null and settled_at is null and reversed_at is null)
    or (status='reserved' and reserved_booking_id is not null and settled_at is null and reversed_at is null)
    or (status='settled' and reserved_booking_id is not null and settled_at is not null and reversed_at is null)
    or (status='reversed' and reversed_at is not null)
  )
);
create index if not exists srk_cancellation_fee_debts_customer_status
  on public.srk_customer_cancellation_fee_debts(customer_user_id,status,created_at);

insert into public.srk_customer_cancellation_fee_debts
  (cancellation_request_id,customer_user_id,source_booking_id,amount_paise)
select r.id,r.customer_user_id,r.booking_id,round(r.fee_amount*100)::bigint
from public.srk_booking_cancellation_requests r
where r.request_status='approved' and r.fee_amount in (49,99)
on conflict(cancellation_request_id) do nothing;

create table if not exists public.srk_booking_cancellation_fee_items (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  debt_id uuid not null unique references public.srk_customer_cancellation_fee_debts(id) on delete restrict,
  customer_user_id uuid not null references auth.users(id) on delete restrict,
  amount_paise bigint not null check (amount_paise in (4900,9900)),
  status text not null default 'reserved'
    check (status in ('reserved','settled','released','reversed')),
  created_at timestamptz not null default now(),
  settled_at timestamptz,
  released_at timestamptz,
  unique(booking_id,debt_id),
  check (
    (status='reserved' and settled_at is null and released_at is null)
    or (status='settled' and settled_at is not null and released_at is null)
    or (status='released' and released_at is not null and settled_at is null)
    or status='reversed'
  )
);
create index if not exists srk_booking_cancellation_fee_items_booking
  on public.srk_booking_cancellation_fee_items(booking_id,status);

create table if not exists public.srk_cancellation_fee_ledger (
  id uuid primary key default gen_random_uuid(),
  debt_id uuid not null references public.srk_customer_cancellation_fee_debts(id) on delete restrict,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  source_booking_id uuid not null references public.service_bookings(id) on delete restrict,
  customer_user_id uuid not null references auth.users(id) on delete restrict,
  electrician_user_id uuid references auth.users(id) on delete restrict,
  entry_type text not null check (entry_type in ('online_collection','cash_electrician_debit','reversal')),
  direction text not null check (direction in ('credit','debit')),
  amount_paise bigint not null check (amount_paise in (4900,9900)),
  status text not null default 'posted' check (status in ('posted','reversed')),
  payment_reference text,
  idempotency_key text not null unique,
  note text not null,
  created_at timestamptz not null default now()
);
create index if not exists srk_cancellation_fee_ledger_created
  on public.srk_cancellation_fee_ledger(created_at desc);

create or replace function public.srk_guard_cancellation_fee_ledger_immutable()
returns trigger language plpgsql set search_path=''
as $
begin
  raise exception 'CANCELLATION_FEE_LEDGER_IS_APPEND_ONLY';
end;
$$;
revoke all on function public.srk_guard_cancellation_fee_ledger_immutable() from public,anon,authenticated;
drop trigger if exists srk_cancellation_fee_ledger_no_mutation on public.srk_cancellation_fee_ledger;
create trigger srk_cancellation_fee_ledger_no_mutation
before update or delete or truncate on public.srk_cancellation_fee_ledger
for each statement execute function public.srk_guard_cancellation_fee_ledger_immutable();
alter table public.srk_customer_cancellation_fee_debts enable row level security;
alter table public.srk_booking_cancellation_fee_items enable row level security;
alter table public.srk_cancellation_fee_ledger enable row level security;
revoke all on public.srk_customer_cancellation_fee_debts from public,anon,authenticated;
revoke all on public.srk_booking_cancellation_fee_items from public,anon,authenticated;
revoke all on public.srk_cancellation_fee_ledger from public,anon,authenticated;
grant all on public.srk_customer_cancellation_fee_debts to service_role;
grant all on public.srk_booking_cancellation_fee_items to service_role;
grant all on public.srk_cancellation_fee_ledger to service_role;

create or replace function public.srk_reserve_customer_cancellation_fees_for_booking()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_debt record;
begin
  if new.customer_user_id is null then return new; end if;
  perform pg_advisory_xact_lock(hashtextextended(new.customer_user_id::text, 61027));
  for v_debt in
    select d.id,d.amount_paise
    from public.srk_customer_cancellation_fee_debts d
    where d.customer_user_id=new.customer_user_id and d.status='open'
    order by d.created_at,d.id
    for update
  loop
    insert into public.srk_booking_cancellation_fee_items
      (booking_id,debt_id,customer_user_id,amount_paise)
    values(new.id,v_debt.id,new.customer_user_id,v_debt.amount_paise)
    on conflict(debt_id) do nothing;
    update public.srk_customer_cancellation_fee_debts
      set status='reserved',reserved_booking_id=new.id
      where id=v_debt.id and status='open';
  end loop;
  return new;
end;
$$;
revoke all on function public.srk_reserve_customer_cancellation_fees_for_booking() from public,anon,authenticated;
drop trigger if exists srk_reserve_customer_cancellation_fees_for_booking on public.service_bookings;
create trigger srk_reserve_customer_cancellation_fees_for_booking
after insert on public.service_bookings
for each row execute function public.srk_reserve_customer_cancellation_fees_for_booking();

create or replace function public.srk_release_cancellation_fees_on_booking_cancel()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if old.status is distinct from new.status and new.status='cancelled'
     and coalesce(new.payment_status,'unpaid') not in ('paid','refunded') then
    perform pg_advisory_xact_lock(hashtextextended(coalesce(new.customer_user_id::text,new.id::text),61027));
    update public.srk_customer_cancellation_fee_debts d
      set status='open',reserved_booking_id=null
      from public.srk_booking_cancellation_fee_items i
      where i.booking_id=new.id and i.status='reserved'
        and d.id=i.debt_id and d.status='reserved' and d.reserved_booking_id=new.id;
    update public.srk_booking_cancellation_fee_items
      set status='released',released_at=now()
      where booking_id=new.id and status='reserved';
  end if;
  return new;
end;
$$;
revoke all on function public.srk_release_cancellation_fees_on_booking_cancel() from public,anon,authenticated;
drop trigger if exists srk_release_cancellation_fees_on_booking_cancel on public.service_bookings;
create trigger srk_release_cancellation_fees_on_booking_cancel
after update of status on public.service_bookings
for each row execute function public.srk_release_cancellation_fees_on_booking_cancel();

create or replace function public.srk_admin_decide_booking_cancellation(
  p_request_id uuid,p_decision text,p_verified_stage text default null,
  p_stage_evidence text default null,p_admin_reason text default null
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  v_request public.srk_booking_cancellation_requests%rowtype;
  v_fee numeric(10,2);
  v_fee_paise bigint;
  v_reason text:=btrim(coalesce(p_admin_reason,''));
  v_evidence text:=btrim(coalesce(p_stage_evidence,''));
begin
  if auth.uid() is null or not public.is_srk_admin() then raise exception 'ADMIN_ONLY' using errcode='42501'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'INVALID_DECISION'; end if;
  if length(v_reason)<10 or length(v_reason)>1000 then raise exception 'ADMIN_REASON_REQUIRED_10_TO_1000'; end if;
  select * into v_request from public.srk_booking_cancellation_requests where id=p_request_id for update;
  if not found then raise exception 'CANCELLATION_REQUEST_NOT_FOUND'; end if;
  if v_request.request_status<>'pending' then raise exception 'CANCELLATION_REQUEST_ALREADY_DECIDED'; end if;
  perform 1 from public.service_bookings b
    where b.id=v_request.booking_id and b.status not in ('completed','cancelled') for update;
  if not found then raise exception 'BOOKING_NO_LONGER_CANCELLABLE'; end if;

  if p_decision='approved' then
    if p_verified_stage not in ('not_departed','en_route','arrived') then raise exception 'INVALID_VERIFIED_STAGE'; end if;
    if length(v_evidence)<10 or length(v_evidence)>1000 then raise exception 'STAGE_EVIDENCE_REQUIRED_10_TO_1000'; end if;
    v_fee:=case p_verified_stage when 'not_departed' then 0 when 'en_route' then 49 when 'arrived' then 99 end;
    v_fee_paise:=round(v_fee*100)::bigint;
    update public.srk_booking_cancellation_requests
      set request_status='approved',verified_stage=p_verified_stage,fee_amount=v_fee,
          stage_evidence=v_evidence,admin_reason=v_reason,decided_by=auth.uid(),decided_at=now(),updated_at=now()
      where id=p_request_id;
    perform set_config('srk.cancel_request_id',v_request.id::text,true);
    update public.service_bookings set status='cancelled' where id=v_request.booking_id;
    if v_fee_paise>0 then
      insert into public.srk_customer_cancellation_fee_debts
        (cancellation_request_id,customer_user_id,source_booking_id,amount_paise)
      values(v_request.id,v_request.customer_user_id,v_request.booking_id,v_fee_paise)
      on conflict(cancellation_request_id) do nothing;
    end if;
    insert into public.srk_booking_cancellation_events(request_id,booking_id,actor_user_id,actor_role,event_type,event_data)
    values(v_request.id,v_request.booking_id,auth.uid(),'admin','approved',
      jsonb_build_object('verified_stage',p_verified_stage,'fee_amount',v_fee,'stage_evidence',v_evidence,'admin_reason',v_reason));
  else
    update public.srk_booking_cancellation_requests
      set request_status='rejected',admin_reason=v_reason,decided_by=auth.uid(),decided_at=now(),updated_at=now()
      where id=p_request_id;
    insert into public.srk_booking_cancellation_events(request_id,booking_id,actor_user_id,actor_role,event_type,event_data)
    values(v_request.id,v_request.booking_id,auth.uid(),'admin','rejected',jsonb_build_object('admin_reason',v_reason));
  end if;
  return jsonb_build_object('success',true,'request_id',v_request.id,'decision',p_decision,'fee_amount',v_fee);
end;
$$;

create or replace function public.srk_customer_get_payment_receipt(p_booking_id uuid)
returns jsonb language plpgsql stable security definer
set search_path=pg_catalog,public,auth,pg_temp
as $function$
declare
  v_uid uuid:=auth.uid();
  v_booking public.service_bookings%rowtype;
  v_bill public.srk_booking_labour_bills%rowtype;
  v_fee_paise bigint:=0;
  v_fee_items jsonb:='[]'::jsonb;
  v_total_paise bigint;
begin
  if v_uid is null then raise exception 'Customer login required' using errcode='42501'; end if;
  if p_booking_id is null then raise exception 'Booking ID required' using errcode='22023'; end if;
  select * into v_booking from public.service_bookings
    where id=p_booking_id and customer_user_id=v_uid;
  if not found then raise exception 'Booking not found' using errcode='42501'; end if;
  if v_booking.payment_status<>'paid' or v_booking.payment_verified_at is null or coalesce(v_booking.amount_paid,0)<=0
    then raise exception 'Only verified paid bookings have a payment receipt' using errcode='55000'; end if;

  if v_booking.selected_category is not null then
    select * into v_bill from public.srk_booking_labour_bills where booking_id=p_booking_id and customer_user_id=v_uid;
    if not found then raise exception 'Immutable labour bill not found' using errcode='55000'; end if;
    select coalesce(sum(i.amount_paise),0),
      coalesce(jsonb_agg(jsonb_build_object('source_booking_id',i.source_booking_id,
        'amount_paise',i.amount_paise,'amount',i.amount_paise/100.0) order by i.created_at,i.id),'[]'::jsonb)
    into v_fee_paise,v_fee_items
    from public.srk_booking_cancellation_fee_items i
    where i.booking_id=p_booking_id and i.status='settled';
    v_total_paise:=v_bill.labour_amount_paise+v_fee_paise;
    if round(v_booking.amount_paid*100)::bigint<>v_total_paise then
      raise exception 'Paid amount does not match immutable labour and cancellation fee ledger' using errcode='55000';
    end if;
    return jsonb_build_object(
      'receipt_reference','SRK-PAY-'||upper(left(replace(v_booking.id::text,'-',''),12)),
      'booking_id',v_booking.id,'customer_name',v_booking.customer_name,
      'service_type',v_booking.service_type,'address',v_booking.address,
      'district',v_booking.district,'state',v_booking.state,'pincode',v_booking.pincode,
      'booking_date',v_booking.created_at,'payment_date',v_booking.payment_verified_at,
      'payment_method',case when lower(coalesce(v_booking.payment_method,'')) in
        ('cash','upi','card','online','razorpay','bank_transfer','bank transfer')
        then lower(v_booking.payment_method) else 'other' end,
      'amount_paid',round(v_booking.amount_paid,2),
      'labour_amount',v_bill.labour_amount,
      'cancellation_fee_amount',v_fee_paise/100.0,
      'cancellation_fee_items',v_fee_items,
      'total_amount',v_total_paise/100.0,
      'description','सत्यापित भुगतान रसीद — मेहनताना और पुरानी cancellation fee अलग-अलग',
      'document_type','payment_receipt'
    );
  end if;

  if v_booking.service_charge is not null and round(v_booking.service_charge,2)=round(v_booking.amount_paid,2) then
    return jsonb_build_object(
      'receipt_reference','SRK-PAY-'||upper(left(replace(v_booking.id::text,'-',''),12)),
      'booking_id',v_booking.id,'customer_name',v_booking.customer_name,
      'service_type',v_booking.service_type,'address',v_booking.address,
      'district',v_booking.district,'state',v_booking.state,'pincode',v_booking.pincode,
      'booking_date',v_booking.created_at,'payment_date',v_booking.payment_verified_at,
      'payment_method',lower(coalesce(v_booking.payment_method,'other')),
      'amount_paid',round(v_booking.amount_paid,2),'labour_amount',round(v_booking.service_charge,2),
      'cancellation_fee_amount',0,'cancellation_fee_items','[]'::jsonb,
      'total_amount',round(v_booking.amount_paid,2),
      'description','सत्यापित बुकिंग भुगतान की रसीद','document_type','payment_receipt'
    );
  end if;
  raise exception 'Payment receipt does not reconcile to approved service amount' using errcode='55000';
end;
$function$;
revoke all on function public.srk_customer_get_payment_receipt(uuid) from public,anon;
grant execute on function public.srk_customer_get_payment_receipt(uuid) to authenticated;

create or replace function public.srk_customer_list_my_cancellation_fee_debts()
returns setof jsonb language sql stable security definer set search_path=''
as $
  select jsonb_build_object(
    'id',d.id,'source_booking_id',d.source_booking_id,'reserved_booking_id',d.reserved_booking_id,
    'amount_paise',d.amount_paise,'amount',d.amount_paise/100.0,'status',d.status,
    'created_at',d.created_at,'settled_at',d.settled_at
  )
  from public.srk_customer_cancellation_fee_debts d
  where d.customer_user_id=auth.uid()
  order by d.created_at desc,d.id;
$$;

create or replace function public.srk_admin_get_cancellation_fee_ledger_summary()
returns jsonb language plpgsql stable security definer set search_path=''
as $
begin
  if auth.uid() is null or not public.is_srk_admin() then raise exception 'ADMIN_ONLY' using errcode='42501'; end if;
  return jsonb_build_object(
    'open_debt_paise',coalesce((select sum(amount_paise) from public.srk_customer_cancellation_fee_debts where status='open'),0),
    'reserved_debt_paise',coalesce((select sum(amount_paise) from public.srk_customer_cancellation_fee_debts where status='reserved'),0),
    'settled_debt_paise',coalesce((select sum(amount_paise) from public.srk_customer_cancellation_fee_debts where status='settled'),0),
    'online_collected_paise',coalesce((select sum(amount_paise) from public.srk_cancellation_fee_ledger where entry_type='online_collection' and status='posted'),0),
    'cash_electrician_debit_paise',coalesce((select sum(amount_paise) from public.srk_cancellation_fee_ledger where entry_type='cash_electrician_debit' and status='posted'),0),
    'ledger_entries',(select count(*) from public.srk_cancellation_fee_ledger)
  );
end;
$$;

create or replace function public.srk_customer_list_booking_cancellation_fee_items()
returns setof jsonb language sql stable security definer set search_path=''
as $
  select jsonb_build_object(
    'booking_id',i.booking_id,'debt_id',i.debt_id,'source_booking_id',i.source_booking_id,
    'amount_paise',i.amount_paise,'amount',i.amount_paise/100.0,'status',i.status,
    'created_at',i.created_at
  )
  from public.srk_booking_cancellation_fee_items i
  where i.customer_user_id=auth.uid()
  order by i.created_at,i.id;
$$;

create or replace function public.srk_service_role_get_booking_payment_breakdown(p_booking_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare
  v_booking public.service_bookings%rowtype;
  v_labour public.srk_booking_labour_bills%rowtype;
  v_fees jsonb;
  v_fee_paise bigint;
begin
  if auth.role()<>'service_role' then raise exception 'SERVICE_ROLE_ONLY' using errcode='42501'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
  if v_booking.status<>'completed' then raise exception 'BOOKING_NOT_COMPLETED'; end if;
  if lower(coalesce(v_booking.payment_method,'')) not like '%razorpay%'
     and lower(coalesce(v_booking.payment_method,'')) not like '%online%' then
    raise exception 'BOOKING_PAYMENT_METHOD_IS_NOT_ONLINE';
  end if;
  select * into v_labour from public.srk_booking_labour_bills where booking_id=p_booking_id;
  if not found then raise exception 'IMMUTABLE_LABOUR_BILL_REQUIRED'; end if;
  select coalesce(sum(i.amount_paise),0),
    coalesce(jsonb_agg(jsonb_build_object('debt_id',i.debt_id,'source_booking_id',i.source_booking_id,
      'amount_paise',i.amount_paise,'amount',i.amount_paise/100.0) order by i.created_at,i.id),'[]'::jsonb)
  into v_fee_paise,v_fees
  from public.srk_booking_cancellation_fee_items i
  where i.booking_id=p_booking_id and i.status='reserved';
  return jsonb_build_object(
    'booking_id',p_booking_id,'customer_user_id',v_booking.customer_user_id,
    'payment_method',v_booking.payment_method,'payment_status',v_booking.payment_status,
    'labour_amount_paise',v_labour.labour_amount_paise,
    'cancellation_fee_amount_paise',v_fee_paise,
    'total_amount_paise',v_labour.labour_amount_paise+v_fee_paise,
    'cancellation_fee_items',v_fees
  );
end;
$$;

create or replace function public.srk_admin_record_new_booking_cash_payment(
  p_booking_id uuid,p_reference text,p_note text default null
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  v_booking public.service_bookings%rowtype;
  v_labour public.srk_booking_labour_bills%rowtype;
  v_profile public.electrician_profiles%rowtype;
  v_electrician_user uuid;
  v_wallet uuid;
  v_fee bigint;
  v_total bigint;
  v_reference text:=btrim(coalesce(p_reference,''));
  v_item record;
begin
  if auth.uid() is null or not public.is_srk_admin() then raise exception 'ADMIN_ONLY' using errcode='42501'; end if;
  if length(v_reference)<4 or length(v_reference)>120 then raise exception 'VALID_CASH_RECEIPT_REFERENCE_REQUIRED'; end if;
  if p_note is not null and length(p_note)>250 then raise exception 'PAYMENT_NOTE_TOO_LONG'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
  if v_booking.status<>'completed' or v_booking.assigned_electrician_id is null then raise exception 'COMPLETED_ASSIGNED_BOOKING_REQUIRED'; end if;
  if lower(coalesce(v_booking.payment_method,'')) not like '%cash%' then raise exception 'BOOKING_PAYMENT_METHOD_IS_NOT_CASH'; end if;
  if v_booking.payment_status in ('paid','refunded') then raise exception 'BOOKING_ALREADY_PAID_OR_REFUNDED'; end if;
  if v_booking.razorpay_order_id is not null or v_booking.razorpay_payment_id is not null then raise exception 'RAZORPAY_BOOKING_MUST_USE_ONLINE_VERIFICATION'; end if;
  select * into v_labour from public.srk_booking_labour_bills where booking_id=p_booking_id;
  if not found then raise exception 'IMMUTABLE_LABOUR_BILL_REQUIRED'; end if;
  select coalesce(sum(amount_paise),0) into v_fee from public.srk_booking_cancellation_fee_items
    where booking_id=p_booking_id and status='reserved';
  v_total:=v_labour.labour_amount_paise+v_fee;
  if v_total<=0 or v_total>1000000000 then raise exception 'INVALID_BOOKING_TOTAL'; end if;
  if exists(select 1 from public.srk_manual_payment_entries where booking_id=p_booking_id) then raise exception 'MANUAL_PAYMENT_ALREADY_RECORDED'; end if;
  select * into v_profile from public.electrician_profiles where id=v_labour.electrician_profile_id;
  v_electrician_user:=coalesce(v_profile.auth_user_id,v_profile.user_id);
  if v_electrician_user is null then raise exception 'ELECTRICIAN_AUTH_USER_REQUIRED'; end if;
  insert into public.srk_wallet_accounts(user_id,wallet_type) values(v_electrician_user,'electrician')
    on conflict(user_id,wallet_type) do nothing;
  select id into v_wallet from public.srk_wallet_accounts where user_id=v_electrician_user and wallet_type='electrician' for update;

  insert into public.srk_manual_payment_entries(booking_id,payment_method,amount,payment_reference,note,recorded_by)
  values(p_booking_id,'cash',v_total/100.0,v_reference,nullif(btrim(coalesce(p_note,'')),''),auth.uid());
  update public.service_bookings set payment_method='Cash',payment_status='paid',
    amount_paid=v_total/100.0,payment_verified_at=now() where id=p_booking_id;

  for v_item in select * from public.srk_booking_cancellation_fee_items
    where booking_id=p_booking_id and status='reserved' order by created_at,id for update
  loop
    insert into public.srk_wallet_ledger(wallet_id,user_id,wallet_type,entry_type,direction,amount,status,
      reference_type,reference_id,idempotency_key,description,posted_at)
    values(v_wallet,v_electrician_user,'electrician','cancellation_fee','debit',
      v_item.amount_paise/100.0,'posted','cancellation_fee_debt',v_item.debt_id::text,
      'cancel-fee:cash:electrician-debit:'||v_item.debt_id::text,
      'Customer paid prior cancellation fee in cash; SRK recovery from electrician wallet',now())
    on conflict(idempotency_key) do nothing;
    insert into public.srk_cancellation_fee_ledger(debt_id,booking_id,source_booking_id,customer_user_id,
      electrician_user_id,entry_type,direction,amount_paise,idempotency_key,note)
    values(v_item.debt_id,p_booking_id,v_item.source_booking_id,v_booking.customer_user_id,
      v_electrician_user,'cash_electrician_debit','credit',v_item.amount_paise,
      'cancel-fee:cash:srk-credit:'||v_item.debt_id::text,
      'Cash cancellation fee collected by electrician and credited to SRK receivable ledger')
    on conflict(idempotency_key) do nothing;
    update public.srk_booking_cancellation_fee_items set status='settled',settled_at=now()
      where id=v_item.id and status='reserved';
    update public.srk_customer_cancellation_fee_debts set status='settled',settled_at=now()
      where id=v_item.debt_id and status='reserved';
  end loop;
  return jsonb_build_object('success',true,'booking_id',p_booking_id,
    'labour_amount_paise',v_labour.labour_amount_paise,'cancellation_fee_amount_paise',v_fee,
    'total_amount_paise',v_total,'electrician_wallet_debit_paise',v_fee);
end;
$$;

create or replace function public.srk_service_role_record_online_booking_payment(
  p_booking_id uuid,p_order_id text,p_payment_id text,p_amount_paise bigint
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  v_booking public.service_bookings%rowtype;
  v_labour public.srk_booking_labour_bills%rowtype;
  v_fee bigint;
  v_expected bigint;
  v_item record;
begin
  if auth.role()<>'service_role' then raise exception 'SERVICE_ROLE_ONLY' using errcode='42501'; end if;
  if p_payment_id is null or p_order_id is null
     or p_payment_id !~ '^pay_[A-Za-z0-9]+$'
     or p_order_id !~ '^order_[A-Za-z0-9]+$' then
    raise exception 'INVALID_PROVIDER_PAYMENT_OR_ORDER_ID';
  end if;
  if p_amount_paise is null or p_amount_paise<1 then
    raise exception 'INVALID_CAPTURED_AMOUNT';
  end if;
  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
  if v_booking.status<>'completed' then raise exception 'BOOKING_NOT_COMPLETED'; end if;
  if lower(coalesce(v_booking.payment_method,'')) not like '%razorpay%'
     and lower(coalesce(v_booking.payment_method,'')) not like '%online%' then
    raise exception 'BOOKING_PAYMENT_METHOD_IS_NOT_ONLINE';
  end if;
  select * into v_labour from public.srk_booking_labour_bills where booking_id=p_booking_id;
  if not found then raise exception 'IMMUTABLE_LABOUR_BILL_REQUIRED'; end if;
  select coalesce(sum(amount_paise),0) into v_fee from public.srk_booking_cancellation_fee_items
    where booking_id=p_booking_id and status='reserved';
  v_expected:=v_labour.labour_amount_paise+v_fee;
  if p_amount_paise<>v_expected then raise exception 'CAPTURED_AMOUNT_DOES_NOT_MATCH_LABOUR_PLUS_CANCELLATION_FEES'; end if;
  if v_booking.payment_status='paid' then
    if v_booking.razorpay_payment_id=p_payment_id then
      return jsonb_build_object('success',true,'already_processed',true,'total_amount_paise',v_expected);
    end if;
    raise exception 'BOOKING_ALREADY_PAID_WITH_DIFFERENT_PAYMENT';
  end if;
  if v_booking.razorpay_order_id is null or v_booking.razorpay_order_id<>p_order_id then raise exception 'RAZORPAY_ORDER_MISMATCH'; end if;
  update public.service_bookings set payment_status='paid',amount_paid=p_amount_paise/100.0,
    razorpay_payment_id=p_payment_id,payment_verified_at=now() where id=p_booking_id;

  for v_item in select * from public.srk_booking_cancellation_fee_items
    where booking_id=p_booking_id and status='reserved' order by created_at,id for update
  loop
    insert into public.srk_cancellation_fee_ledger(debt_id,booking_id,source_booking_id,
      customer_user_id,entry_type,direction,amount_paise,payment_reference,idempotency_key,note)
    values(v_item.debt_id,p_booking_id,v_item.source_booking_id,v_booking.customer_user_id,
      'online_collection','credit',v_item.amount_paise,p_payment_id,
      'cancel-fee:online:srk-credit:'||v_item.debt_id::text,
      'Online payment cancellation-fee component credited to SRK cancellation ledger')
    on conflict(idempotency_key) do nothing;
    update public.srk_booking_cancellation_fee_items set status='settled',settled_at=now()
      where id=v_item.id and status='reserved';
    update public.srk_customer_cancellation_fee_debts set status='settled',settled_at=now()
      where id=v_item.debt_id and status='reserved';
  end loop;
  return jsonb_build_object('success',true,'already_processed',false,
    'labour_amount_paise',v_labour.labour_amount_paise,
    'cancellation_fee_amount_paise',v_fee,'total_amount_paise',v_expected);
end;
$$;

revoke all on function public.srk_customer_list_my_cancellation_fee_debts() from public,anon;
grant execute on function public.srk_customer_list_my_cancellation_fee_debts() to authenticated;
revoke all on function public.srk_admin_get_cancellation_fee_ledger_summary() from public,anon;
grant execute on function public.srk_admin_get_cancellation_fee_ledger_summary() to authenticated;
revoke all on function public.srk_customer_list_booking_cancellation_fee_items() from public,anon;
grant execute on function public.srk_customer_list_booking_cancellation_fee_items() to authenticated;
revoke all on function public.srk_service_role_get_booking_payment_breakdown(uuid) from public,anon,authenticated;
grant execute on function public.srk_service_role_get_booking_payment_breakdown(uuid) to service_role;
revoke all on function public.srk_admin_record_new_booking_cash_payment(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_record_new_booking_cash_payment(uuid,text,text) to authenticated;
revoke all on function public.srk_service_role_record_online_booking_payment(uuid,text,text,bigint) from public,anon,authenticated;
grant execute on function public.srk_service_role_record_online_booking_payment(uuid,text,text,bigint) to service_role;
