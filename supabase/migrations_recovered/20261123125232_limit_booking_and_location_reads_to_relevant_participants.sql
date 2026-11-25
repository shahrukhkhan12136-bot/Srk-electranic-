drop policy if exists srk_booking_participant_read on public.service_bookings;
create policy srk_booking_participant_read
on public.service_bookings
for select to authenticated
using (
  is_srk_admin()
  or srk_has_admin_permission('bookings.manage')
  or customer_user_id = (select auth.uid())
  or exists (
    select 1
    from public.srk_booking_workers bw
    join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.booking_id=service_bookings.id
      and w.user_id=(select auth.uid())
      and bw.assignment_status in ('offered','accepted','assigned','working','paused','completed','released')
  )
);

drop policy if exists srk_booking_history_participant_read on public.service_booking_status_history;
create policy srk_booking_history_participant_read
on public.service_booking_status_history
for select to authenticated
using (
  srk_has_admin_permission('bookings.manage')
  or exists (
    select 1 from public.service_bookings b
    where b.id=service_booking_status_history.booking_id
      and b.customer_user_id=(select auth.uid())
  )
  or exists (
    select 1
    from public.srk_booking_workers bw
    join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.booking_id=service_booking_status_history.booking_id
      and w.user_id=(select auth.uid())
      and bw.assignment_status in ('offered','accepted','assigned','working','paused','completed','released')
  )
);

drop policy if exists srk_location_share_participant on public.srk_booking_location_shares;
create policy srk_location_share_participant
on public.srk_booking_location_shares
for select to authenticated
using (
  srk_has_admin_permission('support.manage')
  or srk_has_admin_permission('bookings.manage')
  or started_by=(select auth.uid())
  or exists (
    select 1 from public.service_bookings b
    where b.id=srk_booking_location_shares.booking_id
      and b.customer_user_id=(select auth.uid())
      and b.status in ('assigned','in_progress')
  )
  or exists (
    select 1 from public.srk_booking_workers bw
    join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.booking_id=srk_booking_location_shares.booking_id
      and w.user_id=(select auth.uid())
      and bw.assignment_status in ('accepted','assigned','working','paused')
  )
);

drop policy if exists srk_live_location_participant on public.srk_booking_live_locations;
create policy srk_live_location_participant
on public.srk_booking_live_locations
for select to authenticated
using (
  srk_has_admin_permission('support.manage')
  or srk_has_admin_permission('bookings.manage')
  or exists (
    select 1
    from public.srk_booking_location_shares sh
    join public.service_bookings b on b.id=sh.booking_id
    where sh.id=srk_booking_live_locations.share_id
      and (
        (b.customer_user_id=(select auth.uid()) and b.status in ('assigned','in_progress'))
        or exists (
          select 1 from public.srk_booking_workers bw
          join public.srk_worker_profiles w on w.id=bw.worker_id
          where bw.booking_id=b.id and w.user_id=(select auth.uid())
            and bw.assignment_status in ('accepted','assigned','working','paused')
        )
      )
  )
);