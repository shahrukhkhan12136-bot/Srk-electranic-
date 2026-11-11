-- Assertions for 202611110002_timer_billing_integrity_extensions.sql.
-- Run only in the disposable PostgreSQL harness; all test rows are rolled back.

begin;

do $test$
declare
  v_user uuid := '30000000-0000-4000-8000-000000000001';
  v_booking uuid := '30000000-0000-4000-8000-000000000002';
  v_bill uuid := '30000000-0000-4000-8000-000000000003';
  v_revision uuid := '30000000-0000-4000-8000-000000000004';
  v_snapshot uuid := '30000000-0000-4000-8000-000000000005';
  v_other_booking uuid := '30000000-0000-4000-8000-000000000006';
begin
  insert into auth.users(id) values (v_user);
  insert into public.service_bookings(id) values (v_booking), (v_other_booking);

  insert into public.srk_final_bills(
    id, booking_id, category_code, category_label, hourly_rate,
    started_at, stopped_at, elapsed_seconds, billable_minutes, labour_amount
  ) values (
    v_bill, v_booking, 'helper', 'Helper', 112.375,
    '2026-01-01 10:00:00+00', '2026-01-01 10:01:00.1+00',
    61, 2, 3.75
  );

  insert into public.srk_bill_material_revisions(
    id, bill_id, revision, status, created_by
  ) values (v_revision, v_bill, 1, 'draft', v_user);

  insert into public.srk_bill_material_items(
    bill_id, revision_id, line_number, description, quantity,
    unit_price, line_total, supplied_by, created_by
  ) values (
    v_bill, v_revision, 1, 'Cable', 2, 10, 20, 'electrician', v_user
  );

  insert into public.srk_booking_payable_snapshots(
    id, booking_id, bill_id, material_revision_id, bill_version,
    labour_amount, materials_amount, total_amount, amount_paise,
    calculation_version, created_by
  ) values (
    v_snapshot, v_booking, v_bill, v_revision, 1,
    3.75, 20, 23.75, 2375, 'test-v1', v_user
  );

  -- A bill from booking A must never be usable as booking B's payable.
  begin
    insert into public.srk_booking_payable_snapshots(
      booking_id, bill_id, material_revision_id, bill_version,
      labour_amount, materials_amount, total_amount, amount_paise,
      calculation_version, created_by
    ) values (
      v_other_booking, v_bill, v_revision, 1,
      3.75, 20, 23.75, 2375, 'test-v1', v_user
    );
    raise exception 'cross-booking payable snapshot unexpectedly accepted';
  exception when foreign_key_violation then
    null;
  end;

  insert into public.srk_cash_receipts(
    payable_snapshot_id, booking_id, confirmed_by, amount_paise
  ) values (v_snapshot, v_booking, v_user, 2375);

  begin
    insert into public.srk_cash_receipts(
      payable_snapshot_id, booking_id, confirmed_by, amount_paise
    ) values (v_snapshot, v_other_booking, v_user, 2375);
    raise exception 'cross-booking cash receipt unexpectedly accepted';
  exception when foreign_key_violation then
    null;
  end;

  begin
    insert into public.srk_cash_receipts(
      payable_snapshot_id, booking_id, confirmed_by, amount_paise
    ) values (v_snapshot, v_booking, v_user, 2374);
    raise exception 'cash receipt with mismatched amount unexpectedly accepted';
  exception when check_violation then
    null;
  end;

  begin
    update public.srk_booking_payable_snapshots
    set total_amount = 24.00, amount_paise = 2400
    where id = v_snapshot;
    raise exception 'payable snapshot financial fields unexpectedly mutable';
  exception when object_not_in_prerequisite_state then
    null;
  end;

  insert into public.srk_payment_webhook_events(
    provider, provider_event_id, payload_sha256, event_type
  ) values (
    'razorpay', 'evt_test_unique_1',
    repeat('a', 64), 'payment.captured'
  );

  insert into public.srk_booking_audit_events(
    booking_id, actor_user_id, actor_kind, action, entity_type, entity_id,
    idempotency_key
  ) values (
    v_booking, v_user, 'customer', 'timer.test', 'booking', v_booking, 'audit-key-1'
  );

  insert into public.srk_final_bill_adjustments(
    bill_id, booking_id, adjustment_number, amount_delta, reason, proposed_by
  ) values (v_bill, v_booking, 1, 1.25, 'Synthetic test adjustment', v_user);

  if has_table_privilege('authenticated', 'public.srk_payment_webhook_events', 'SELECT') then
    raise exception 'authenticated unexpectedly has direct webhook ledger SELECT';
  end if;
  if not (select c.relrowsecurity from pg_class c where c.oid='public.srk_booking_payable_snapshots'::regclass) then
    raise exception 'payable snapshot RLS is not enabled';
  end if;
  if not exists (
    select 1 from public.srk_bill_material_items
    where bill_id=v_bill and revision_id=v_revision
  ) then
    raise exception 'material line is not attached to exact revision';
  end if;
  if not exists (
    select 1 from pg_trigger
    where tgrelid='public.srk_booking_audit_events'::regclass
      and tgname='srk_booking_audit_events_append_only_trigger'
      and not tgisinternal
  ) then
    raise exception 'append-only audit trigger is missing';
  end if;

  begin
    insert into public.srk_payment_webhook_events(
      provider, provider_event_id, payload_sha256, event_type
    ) values ('razorpay', 'evt_test_unique_1', repeat('b', 64), 'order.paid');
    raise exception 'duplicate provider event ID unexpectedly accepted';
  exception when unique_violation then
    null;
  end;
end
$test$;

rollback;
