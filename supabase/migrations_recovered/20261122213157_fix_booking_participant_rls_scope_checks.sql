
drop policy if exists srk_final_bills_participant_read on public.srk_booking_final_bills;
create policy srk_final_bills_participant_read on public.srk_booking_final_bills
for select to authenticated
using (
  srk_has_admin_permission('bookings.manage')
  or srk_has_admin_permission('payments.read')
  or exists (
    select 1 from public.service_bookings b
    where b.id = srk_booking_final_bills.booking_id
      and b.customer_user_id = (select auth.uid())
  )
  or exists (
    select 1
    from public.srk_booking_workers bw
    join public.srk_worker_profiles w on w.id = bw.worker_id
    where bw.booking_id = srk_booking_final_bills.booking_id
      and w.user_id = (select auth.uid())
  )
);

drop policy if exists srk_location_share_participant on public.srk_booking_location_shares;
create policy srk_location_share_participant on public.srk_booking_location_shares
for select to authenticated
using (
  srk_has_admin_permission('support.manage')
  or srk_has_admin_permission('bookings.manage')
  or exists (
    select 1 from public.service_bookings b
    where b.id = srk_booking_location_shares.booking_id
      and b.customer_user_id = (select auth.uid())
  )
  or exists (
    select 1
    from public.srk_booking_workers bw
    join public.srk_worker_profiles w on w.id = bw.worker_id
    where bw.booking_id = srk_booking_location_shares.booking_id
      and w.user_id = (select auth.uid())
  )
);

drop policy if exists srk_payment_disputes_participant_read on public.srk_booking_payment_disputes;
create policy srk_payment_disputes_participant_read on public.srk_booking_payment_disputes
for select to authenticated
using (
  srk_has_admin_permission('support.manage')
  or srk_has_admin_permission('payments.read')
  or raised_by = (select auth.uid())
  or exists (
    select 1 from public.service_bookings b
    where b.id = srk_booking_payment_disputes.booking_id
      and b.customer_user_id = (select auth.uid())
  )
  or exists (
    select 1
    from public.srk_booking_workers bw
    join public.srk_worker_profiles w on w.id = bw.worker_id
    where bw.booking_id = srk_booking_payment_disputes.booking_id
      and w.user_id = (select auth.uid())
  )
);

drop policy if exists srk_payment_evidence_participant_read on public.srk_booking_payment_evidence;
create policy srk_payment_evidence_participant_read on public.srk_booking_payment_evidence
for select to authenticated
using (
  srk_has_admin_permission('payments.read')
  or submitted_by = (select auth.uid())
  or exists (
    select 1 from public.service_bookings b
    where b.id = srk_booking_payment_evidence.booking_id
      and b.customer_user_id = (select auth.uid())
  )
  or exists (
    select 1
    from public.srk_booking_workers bw
    join public.srk_worker_profiles w on w.id = bw.worker_id
    where bw.booking_id = srk_booking_payment_evidence.booking_id
      and w.user_id = (select auth.uid())
  )
);

drop policy if exists srk_booking_receipts_participant on public.srk_booking_receipts;
create policy srk_booking_receipts_participant on public.srk_booking_receipts
for select to authenticated
using (
  srk_has_admin_permission('bookings.manage')
  or srk_has_admin_permission('payments.read')
  or exists (
    select 1 from public.service_bookings b
    where b.id = srk_booking_receipts.booking_id
      and b.customer_user_id = (select auth.uid())
  )
  or exists (
    select 1
    from public.srk_booking_workers bw
    join public.srk_worker_profiles w on w.id = bw.worker_id
    where bw.booking_id = srk_booking_receipts.booking_id
      and w.user_id = (select auth.uid())
  )
);
