
drop policy if exists srk_worker_read_assigned_bookings on public.service_bookings;
create policy srk_worker_read_assigned_bookings on public.service_bookings
for select to authenticated using(
  public.srk_has_admin_permission('bookings.manage')
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.booking_id=service_bookings.id and w.user_id=auth.uid())
);

drop policy if exists srk_booking_history_participant_read on public.service_booking_status_history;
create policy srk_booking_history_participant_read on public.service_booking_status_history
for select to authenticated using(
  public.srk_has_admin_permission('bookings.manage')
  or exists(select 1 from public.service_bookings b where b.id=service_booking_status_history.booking_id and b.customer_user_id=auth.uid())
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.booking_id=service_booking_status_history.booking_id and w.user_id=auth.uid())
);
