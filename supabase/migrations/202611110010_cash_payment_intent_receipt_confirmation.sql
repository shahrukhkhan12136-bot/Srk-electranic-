-- SRK ELECTRONIC: customer-selected cash payment with electrician receipt confirmation.
-- Feature Branch only. Do not apply to shared TEST/Production without explicit approval.
begin;

create table if not exists public.srk_cash_payment_intents (
  id uuid primary key default gen_random_uuid(),
  payable_snapshot_id uuid not null unique references public.srk_booking_payable_snapshots(id) on delete restrict,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  customer_user_id uuid not null references auth.users(id) on delete restrict,
  amount_paise bigint not null check (amount_paise > 0),
  currency text not null default 'INR' check (currency='INR'),
  status text not null default 'pending' check (status in ('pending','confirmed')),
  selected_at timestamptz not null default clock_timestamp(),
  confirmed_by uuid references auth.users(id) on delete restrict,
  confirmed_at timestamptz,
  receipt_id uuid references public.srk_cash_receipts(id) on delete restrict,
  constraint srk_cash_intent_snapshot_booking_fk
    foreign key (payable_snapshot_id,booking_id)
    references public.srk_booking_payable_snapshots(id,booking_id) on delete restrict,
  constraint srk_cash_intent_state_shape_check check (
    (status='pending' and confirmed_by is null and confirmed_at is null and receipt_id is null)
    or (status='confirmed' and confirmed_by is not null and confirmed_at is not null and receipt_id is not null)
  )
);

create unique index if not exists srk_cash_payment_intents_booking_unique
  on public.srk_cash_payment_intents(booking_id);

create index if not exists srk_cash_payment_intents_booking_idx
  on public.srk_cash_payment_intents(booking_id,selected_at desc);

alter table public.srk_cash_payment_intents enable row level security;
revoke all on public.srk_cash_payment_intents from public,anon,authenticated;
grant all on public.srk_cash_payment_intents to service_role;

create or replace function public.srk_guard_cash_payment_intent()
returns trigger
language plpgsql
set search_path=''
as $function$
begin
  if row(new.payable_snapshot_id,new.booking_id,new.customer_user_id,new.amount_paise,new.currency,new.selected_at)
     is distinct from
     row(old.payable_snapshot_id,old.booking_id,old.customer_user_id,old.amount_paise,old.currency,old.selected_at) then
    raise exception 'CASH_PAYMENT_INTENT_BINDING_IMMUTABLE' using errcode='55000';
  end if;
  if old.status='confirmed' and row(new.status,new.confirmed_by,new.confirmed_at,new.receipt_id)
     is distinct from row(old.status,old.confirmed_by,old.confirmed_at,old.receipt_id) then
    raise exception 'CASH_PAYMENT_INTENT_CONFIRMED_IMMUTABLE' using errcode='55000';
  end if;
  if old.status='pending' and new.status not in ('pending','confirmed') then
    raise exception 'INVALID_CASH_PAYMENT_INTENT_TRANSITION' using errcode='55000';
  end if;
  return new;
end
$function$;

drop trigger if exists srk_cash_payment_intent_guard_trigger on public.srk_cash_payment_intents;
create trigger srk_cash_payment_intent_guard_trigger
before update on public.srk_cash_payment_intents
for each row execute function public.srk_guard_cash_payment_intent();

-- Prevent a Razorpay order from racing with or following a customer cash selection.
create or replace function public.srk_guard_razorpay_order_cash_exclusivity()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
begin
  if exists (
    select 1 from public.srk_cash_payment_intents ci
    where ci.booking_id=new.booking_id
  ) then
    raise exception 'CASH_PAYMENT_ALREADY_SELECTED' using errcode='55000';
  end if;
  return new;
end
$function$;

drop trigger if exists srk_razorpay_order_cash_exclusivity_trigger on public.srk_razorpay_orders;
create trigger srk_razorpay_order_cash_exclusivity_trigger
before insert on public.srk_razorpay_orders
for each row execute function public.srk_guard_razorpay_order_cash_exclusivity();

create or replace function public.srk_customer_select_cash_payment(p_snapshot_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_snapshot public.srk_booking_payable_snapshots%rowtype;
  v_booking public.service_bookings%rowtype;
  v_intent public.srk_cash_payment_intents%rowtype;
  v_now timestamptz;
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  if p_snapshot_id is null then raise exception 'PAYABLE_SNAPSHOT_ID_REQUIRED' using errcode='22023'; end if;

  select ps.* into v_snapshot from public.srk_booking_payable_snapshots ps
  where ps.id=p_snapshot_id for update;
  if not found then raise exception 'PAYABLE_SNAPSHOT_NOT_FOUND' using errcode='P0002'; end if;

  select b.* into v_booking from public.service_bookings b
  where b.id=v_snapshot.booking_id for update;
  if not found or v_booking.customer_user_id<>v_uid then
    raise exception 'CUSTOMER_BOOKING_ACCESS_DENIED' using errcode='42501';
  end if;

  if v_booking.service_category_code is null
     or v_booking.timer_state<>'stopped' or v_booking.final_bill_id is distinct from v_snapshot.bill_id then
    raise exception 'FINAL_BILL_SNAPSHOT_MISMATCH' using errcode='55000';
  end if;

  select ci.* into v_intent from public.srk_cash_payment_intents ci
  where ci.booking_id=v_booking.id for update;
  if found then
    if v_intent.payable_snapshot_id<>p_snapshot_id then
      raise exception 'CASH_PAYMENT_ALREADY_SELECTED_FOR_BOOKING' using errcode='55000';
    end if;
    return jsonb_build_object(
      'success',true,'intent_id',v_intent.id,'status',v_intent.status,
      'amount_paise',v_intent.amount_paise,'currency',v_intent.currency,'replayed',true
    );
  end if;

  if v_snapshot.amount_paise<=0 then raise exception 'NO_CASH_PAYMENT_DUE' using errcode='22023'; end if;
  if v_booking.payment_status='paid' then raise exception 'BOOKING_ALREADY_PAID' using errcode='55000'; end if;
  if exists(select 1 from public.srk_razorpay_orders ro where ro.booking_id=v_booking.id) then
    raise exception 'RAZORPAY_PAYMENT_ALREADY_STARTED' using errcode='55000';
  end if;

  v_now:=clock_timestamp();
  insert into public.srk_cash_payment_intents(
    payable_snapshot_id,booking_id,customer_user_id,amount_paise,currency,status,selected_at
  ) values (
    p_snapshot_id,v_booking.id,v_uid,v_snapshot.amount_paise,v_snapshot.currency,'pending',v_now
  ) returning * into v_intent;

  update public.service_bookings set payment_method='Cash' where id=v_booking.id;

  insert into public.srk_booking_audit_events(
    booking_id,actor_user_id,actor_kind,action,entity_type,entity_id,idempotency_key,metadata
  ) values (
    v_booking.id,v_uid,'customer','cash_payment.selected','cash_payment_intent',
    v_intent.id,'cash-select:'||p_snapshot_id::text,
    jsonb_build_object('snapshot_id',p_snapshot_id,'amount_paise',v_snapshot.amount_paise,'currency',v_snapshot.currency)
  );

  return jsonb_build_object(
    'success',true,'intent_id',v_intent.id,'status','pending',
    'amount_paise',v_intent.amount_paise,'currency',v_intent.currency,'replayed',false
  );
end
$function$;

create or replace function public.srk_electrician_confirm_snapshot_cash_payment(
  p_snapshot_id uuid,
  p_receipt_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_snapshot public.srk_booking_payable_snapshots%rowtype;
  v_booking public.service_bookings%rowtype;
  v_profile_id uuid;
  v_intent public.srk_cash_payment_intents%rowtype;
  v_receipt public.srk_cash_receipts%rowtype;
  v_now timestamptz;
  v_note text:=nullif(btrim(coalesce(p_receipt_note,'')),'');
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  if p_snapshot_id is null then raise exception 'PAYABLE_SNAPSHOT_ID_REQUIRED' using errcode='22023'; end if;
  if v_note is not null and length(v_note)>120 then raise exception 'RECEIPT_NOTE_TOO_LONG' using errcode='22023'; end if;

  select ci.* into v_intent from public.srk_cash_payment_intents ci
  where ci.payable_snapshot_id=p_snapshot_id;
  if not found then raise exception 'CUSTOMER_CASH_SELECTION_NOT_FOUND' using errcode='P0002'; end if;

  select b.* into v_booking from public.service_bookings b
  where b.id=v_intent.booking_id for update;
  if not found then raise exception 'BOOKING_NOT_FOUND' using errcode='P0002'; end if;

  select ep.id into v_profile_id from public.electrician_profiles ep
  where ep.id=v_booking.assigned_electrician_id
    and (ep.user_id=v_uid or ep.auth_user_id=v_uid)
    and ep.active=true and ep.verification_status='approved';
  if v_profile_id is null or not exists (
    select 1 from public.job_offers jo
    where jo.booking_id=v_booking.id and jo.electrician_id=v_profile_id and jo.status='accepted'
  ) then
    raise exception 'ASSIGNED_APPROVED_ELECTRICIAN_REQUIRED' using errcode='42501';
  end if;

  select ci.* into v_intent from public.srk_cash_payment_intents ci
  where ci.payable_snapshot_id=p_snapshot_id and ci.booking_id=v_booking.id for update;
  if not found then raise exception 'CUSTOMER_CASH_SELECTION_NOT_FOUND' using errcode='P0002'; end if;

  if v_intent.status='confirmed' then
    if v_intent.confirmed_by<>v_uid then raise exception 'CASH_PAYMENT_ALREADY_CONFIRMED' using errcode='55000'; end if;
    return jsonb_build_object('success',true,'status','confirmed','receipt_id',v_intent.receipt_id,'replayed',true);
  end if;

  select ps.* into v_snapshot from public.srk_booking_payable_snapshots ps
  where ps.id=p_snapshot_id and ps.booking_id=v_booking.id;
  if not found or v_booking.service_category_code is null or v_booking.timer_state<>'stopped' or v_booking.final_bill_id is distinct from v_snapshot.bill_id then
    raise exception 'FINAL_BILL_SNAPSHOT_MISMATCH' using errcode='55000';
  end if;
  if v_booking.payment_status='paid' then raise exception 'BOOKING_ALREADY_PAID' using errcode='55000'; end if;
  if exists(select 1 from public.srk_razorpay_orders ro where ro.booking_id=v_booking.id) then
    raise exception 'RAZORPAY_ORDER_EXISTS_CASH_CONFIRMATION_BLOCKED' using errcode='55000';
  end if;

  v_now:=clock_timestamp();
  insert into public.srk_cash_receipts(
    payable_snapshot_id,booking_id,confirmed_by,confirmed_at,amount_paise,currency,receipt_note
  ) values (
    p_snapshot_id,v_booking.id,v_uid,v_now,v_intent.amount_paise,v_intent.currency,v_note
  ) returning * into v_receipt;

  update public.srk_cash_payment_intents
  set status='confirmed',confirmed_by=v_uid,confirmed_at=v_now,receipt_id=v_receipt.id
  where id=v_intent.id;

  update public.service_bookings
  set payment_status='paid',payment_method='Cash',
      amount_paid=(v_intent.amount_paise::numeric/100),
      status='completed'
  where id=v_booking.id and payment_status is distinct from 'paid';
  if not found then raise exception 'BOOKING_PAYMENT_STATE_CONFLICT' using errcode='55000'; end if;

  insert into public.srk_booking_audit_events(
    booking_id,actor_user_id,actor_kind,action,entity_type,entity_id,idempotency_key,metadata
  ) values (
    v_booking.id,v_uid,'electrician','cash_payment.confirmed','cash_receipt',
    v_receipt.id,'cash-confirm:'||p_snapshot_id::text,
    jsonb_build_object('snapshot_id',p_snapshot_id,'amount_paise',v_intent.amount_paise,'currency',v_intent.currency,'receipt_note',v_note)
  );

  return jsonb_build_object(
    'success',true,'status','confirmed','receipt_id',v_receipt.id,
    'amount_paise',v_intent.amount_paise,'currency',v_intent.currency,'confirmed_at',v_now,'replayed',false
  );
end
$function$;

-- Replace the scoped detail RPC only after the cash-intent table exists.
create or replace function public.srk_get_booking_timer_bill_details(p_booking_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_booking public.service_bookings%rowtype;
  v_profile_id uuid;
  v_is_admin boolean := false;
  v_result jsonb;
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  if p_booking_id is null then raise exception 'BOOKING_ID_REQUIRED' using errcode='22023'; end if;

  select b.* into v_booking
  from public.service_bookings b
  where b.id=p_booking_id;
  if not found then raise exception 'BOOKING_NOT_FOUND' using errcode='P0002'; end if;

  if v_booking.customer_user_id=v_uid then
    null;
  else
    select ep.id into v_profile_id
    from public.electrician_profiles ep
    where ep.id=v_booking.assigned_electrician_id
      and (ep.user_id=v_uid or ep.auth_user_id=v_uid)
      and ep.active=true and ep.verification_status='approved';
    if v_profile_id is not null and exists (
      select 1 from public.job_offers jo
      where jo.booking_id=p_booking_id and jo.electrician_id=v_profile_id and jo.status='accepted'
    ) then
      null;
    else
      v_is_admin := public.is_srk_admin();
      if not v_is_admin then raise exception 'BOOKING_ACCESS_DENIED' using errcode='42501'; end if;
    end if;
  end if;

  select jsonb_build_object(
    'booking_id',b.id,
    'timer_state',b.timer_state,
    'service_category_code',b.service_category_code,
    'service_category_label',b.service_category_label,
    'hourly_rate_snapshot',b.hourly_rate_snapshot,
    'electrician_arrived_at',b.electrician_arrived_at,
    'timer_started_at',b.timer_started_at,
    'timer_start_approved_at',b.timer_start_approved_at,
    'timer_stop_requested_at',b.timer_stop_requested_at,
    'timer_stopped_at',b.timer_stopped_at,
    'timer_stop_approved_at',b.timer_stop_approved_at,
    'timer_elapsed_seconds',b.timer_elapsed_seconds,
    'timer_billable_minutes',b.timer_billable_minutes,
    'final_bill_id',b.final_bill_id,
    'timer_decisions',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',d.id,'action',d.action,'decision',d.decision,
        'requested_at',d.requested_at,'decided_at',d.decided_at,
        'effective_at',d.effective_at
      ) order by d.requested_at)
      from public.srk_booking_timer_decisions d where d.booking_id=b.id
    ),'[]'::jsonb),
    'final_bill',(
      select jsonb_build_object(
        'id',fb.id,'bill_version',fb.bill_version,
        'category_code',fb.category_code,'category_label',fb.category_label,
        'hourly_rate',fb.hourly_rate,'started_at',fb.started_at,
        'stopped_at',fb.stopped_at,'elapsed_seconds',fb.elapsed_seconds,
        'billable_minutes',fb.billable_minutes,'labour_amount',fb.labour_amount,
        'calculation_version',fb.calculation_version,'generated_at',fb.generated_at
      )
      from public.srk_final_bills fb where fb.id=b.final_bill_id
    ),
    'material_revisions',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',r.id,'revision',r.revision,'status',r.status,
        'created_at',r.created_at,'submitted_at',r.submitted_at,
        'decided_at',r.decided_at,
        'items',coalesce((
          select jsonb_agg(jsonb_build_object(
            'id',i.id,'line_number',i.line_number,'description',i.description,
            'quantity',i.quantity,'unit_price',i.unit_price,'line_total',i.line_total,
            'supplied_by',i.supplied_by,'receipt_reference',i.receipt_reference
          ) order by i.line_number)
          from public.srk_bill_material_items i where i.revision_id=r.id
        ),'[]'::jsonb)
      ) order by r.revision)
      from public.srk_bill_material_revisions r
      join public.srk_final_bills fb on fb.id=r.bill_id
      where fb.id=b.final_bill_id
    ),'[]'::jsonb),
    'payable_snapshots',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',ps.id,'bill_id',ps.bill_id,'bill_version',ps.bill_version,
        'material_revision_id',ps.material_revision_id,
        'labour_amount',ps.labour_amount,'materials_amount',ps.materials_amount,
        'total_amount',ps.total_amount,'amount_paise',ps.amount_paise,
        'currency',ps.currency,'created_at',ps.created_at
      ) order by ps.created_at)
      from public.srk_booking_payable_snapshots ps where ps.booking_id=b.id
    ),'[]'::jsonb),
    'cash_receipts',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',cr.id,'payable_snapshot_id',cr.payable_snapshot_id,
        'amount_paise',cr.amount_paise,'currency',cr.currency,
        'confirmed_at',cr.confirmed_at,'receipt_note',cr.receipt_note
      ) order by cr.confirmed_at)
      from public.srk_cash_receipts cr where cr.booking_id=b.id
    ),'[]'::jsonb),
    'cash_payment_intent',(
      select jsonb_build_object(
        'id',ci.id,'payable_snapshot_id',ci.payable_snapshot_id,
        'amount_paise',ci.amount_paise,'currency',ci.currency,
        'status',ci.status,'selected_at',ci.selected_at,
        'confirmed_at',ci.confirmed_at,'receipt_id',ci.receipt_id
      )
      from public.srk_cash_payment_intents ci
      where ci.booking_id=b.id
      order by ci.selected_at desc limit 1
    ),
    'is_admin_view',v_is_admin
  ) into v_result
  from public.service_bookings b
  where b.id=p_booking_id;

  return v_result;
end
$function$;

revoke all on function public.srk_guard_cash_payment_intent() from public,anon,authenticated;
revoke all on function public.srk_guard_razorpay_order_cash_exclusivity() from public,anon,authenticated;
revoke all on function public.srk_customer_select_cash_payment(uuid) from public,anon;
revoke all on function public.srk_electrician_confirm_snapshot_cash_payment(uuid,text) from public,anon;
grant execute on function public.srk_customer_select_cash_payment(uuid) to authenticated;
grant execute on function public.srk_electrician_confirm_snapshot_cash_payment(uuid,text) to authenticated;

commit;
