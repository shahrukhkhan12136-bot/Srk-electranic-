
drop policy if exists srk_customer_profile_self_read on public.srk_customer_profiles;
create policy srk_customer_profile_self_read on public.srk_customer_profiles
for select to authenticated using(user_id=auth.uid() or public.srk_has_admin_permission('customers.manage'));

drop policy if exists srk_worker_profile_self_read on public.srk_worker_profiles;
create policy srk_worker_profile_self_read on public.srk_worker_profiles
for select to authenticated using(user_id=auth.uid() or public.srk_has_admin_permission('workers.verify') or public.srk_has_admin_permission('workers.manage'));

drop policy if exists srk_worker_skills_self_read on public.srk_worker_skills;
create policy srk_worker_skills_self_read on public.srk_worker_skills
for select to authenticated using(
  exists(select 1 from public.srk_worker_profiles w where w.id=worker_id and w.user_id=auth.uid())
  or public.srk_has_admin_permission('workers.verify') or public.srk_has_admin_permission('workers.manage')
);

drop policy if exists srk_booking_workers_participant_read on public.srk_booking_workers;
create policy srk_booking_workers_participant_read on public.srk_booking_workers
for select to authenticated using(
  public.srk_has_admin_permission('bookings.manage')
  or exists(select 1 from public.srk_worker_profiles w where w.id=worker_id and w.user_id=auth.uid())
  or exists(select 1 from public.service_bookings b where b.id=booking_id and b.customer_user_id=auth.uid())
);

drop policy if exists srk_worker_sessions_participant_read on public.srk_worker_work_sessions;
create policy srk_worker_sessions_participant_read on public.srk_worker_work_sessions
for select to authenticated using(
  public.srk_has_admin_permission('bookings.manage')
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id where bw.id=booking_worker_id and w.user_id=auth.uid())
  or exists(select 1 from public.srk_booking_workers bw join public.service_bookings b on b.id=bw.booking_id where bw.id=booking_worker_id and b.customer_user_id=auth.uid())
);

drop policy if exists srk_worker_session_events_participant_read on public.srk_worker_session_events;
create policy srk_worker_session_events_participant_read on public.srk_worker_session_events
for select to authenticated using(
  public.srk_has_admin_permission('bookings.manage')
  or exists(select 1 from public.srk_worker_work_sessions s join public.srk_booking_workers bw on bw.id=s.booking_worker_id join public.srk_worker_profiles w on w.id=bw.worker_id where s.id=session_id and w.user_id=auth.uid())
  or exists(select 1 from public.srk_worker_work_sessions s join public.srk_booking_workers bw on bw.id=s.booking_worker_id join public.service_bookings b on b.id=bw.booking_id where s.id=session_id and b.customer_user_id=auth.uid())
);

drop policy if exists srk_worker_schedule_self_read on public.srk_worker_schedule_blocks;
create policy srk_worker_schedule_self_read on public.srk_worker_schedule_blocks
for select to authenticated using(public.srk_has_admin_permission('bookings.manage') or exists(select 1 from public.srk_worker_profiles w where w.id=worker_id and w.user_id=auth.uid()));

drop policy if exists srk_final_bills_participant_read on public.srk_booking_final_bills;
create policy srk_final_bills_participant_read on public.srk_booking_final_bills
for select to authenticated using(
  public.srk_has_admin_permission('bookings.manage')
  or public.srk_has_admin_permission('payments.read')
  or exists(select 1 from public.service_bookings b where b.id=booking_id and b.customer_user_id=auth.uid())
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id where bw.booking_id=booking_id and w.user_id=auth.uid())
);

drop policy if exists srk_final_bill_items_participant_read on public.srk_booking_final_bill_items;
create policy srk_final_bill_items_participant_read on public.srk_booking_final_bill_items
for select to authenticated using(
  exists(select 1 from public.srk_booking_final_bills f join public.service_bookings b on b.id=f.booking_id where f.id=bill_id and b.customer_user_id=auth.uid())
  or exists(select 1 from public.srk_booking_final_bills f join public.srk_booking_workers bw on bw.booking_id=f.booking_id join public.srk_worker_profiles w on w.id=bw.worker_id where f.id=bill_id and w.user_id=auth.uid())
  or public.srk_has_admin_permission('bookings.manage') or public.srk_has_admin_permission('payments.read')
);

drop policy if exists srk_worker_earnings_self_read on public.srk_worker_earnings;
create policy srk_worker_earnings_self_read on public.srk_worker_earnings
for select to authenticated using(
  public.srk_has_admin_permission('payments.read') or public.srk_has_admin_permission('payouts.manage')
  or exists(select 1 from public.srk_worker_profiles w where w.id=worker_id and w.user_id=auth.uid())
);

drop policy if exists srk_worker_wallet_self_read on public.srk_worker_wallet_ledger;
create policy srk_worker_wallet_self_read on public.srk_worker_wallet_ledger
for select to authenticated using(
  public.srk_has_admin_permission('payments.read') or public.srk_has_admin_permission('payouts.manage')
  or exists(select 1 from public.srk_worker_profiles w where w.id=worker_id and w.user_id=auth.uid())
);

drop policy if exists srk_worker_payout_self_read on public.srk_worker_payout_requests;
create policy srk_worker_payout_self_read on public.srk_worker_payout_requests
for select to authenticated using(
  public.srk_has_admin_permission('payouts.manage')
  or exists(select 1 from public.srk_worker_profiles w where w.id=worker_id and w.user_id=auth.uid())
);

drop policy if exists srk_payment_evidence_participant_read on public.srk_booking_payment_evidence;
create policy srk_payment_evidence_participant_read on public.srk_booking_payment_evidence
for select to authenticated using(
  public.srk_has_admin_permission('payments.read')
  or submitted_by=auth.uid()
  or exists(select 1 from public.service_bookings b where b.id=booking_id and b.customer_user_id=auth.uid())
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id where bw.booking_id=booking_id and w.user_id=auth.uid())
);

drop policy if exists srk_payment_disputes_participant_read on public.srk_booking_payment_disputes;
create policy srk_payment_disputes_participant_read on public.srk_booking_payment_disputes
for select to authenticated using(
  public.srk_has_admin_permission('support.manage') or public.srk_has_admin_permission('payments.read')
  or raised_by=auth.uid()
  or exists(select 1 from public.service_bookings b where b.id=booking_id and b.customer_user_id=auth.uid())
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id where bw.booking_id=booking_id and w.user_id=auth.uid())
);

drop policy if exists srk_location_share_participant on public.srk_booking_location_shares;
create policy srk_location_share_participant on public.srk_booking_location_shares
for select to authenticated using(
  public.srk_has_admin_permission('support.manage') or public.srk_has_admin_permission('bookings.manage')
  or exists(select 1 from public.service_bookings b where b.id=booking_id and b.customer_user_id=auth.uid())
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id where bw.booking_id=booking_id and w.user_id=auth.uid())
);

drop policy if exists srk_live_location_participant on public.srk_booking_live_locations;
create policy srk_live_location_participant on public.srk_booking_live_locations
for select to authenticated using(
  public.srk_has_admin_permission('support.manage') or public.srk_has_admin_permission('bookings.manage')
  or exists(select 1 from public.srk_booking_location_shares sh join public.service_bookings b on b.id=sh.booking_id
    where sh.id=share_id and (b.customer_user_id=auth.uid()
      or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id where bw.booking_id=b.id and w.user_id=auth.uid())))
);

drop policy if exists srk_chat_rooms_participant on public.srk_booking_chat_rooms;
create policy srk_chat_rooms_participant on public.srk_booking_chat_rooms
for select to authenticated using(exists(select 1 from public.srk_booking_chat_members m where m.room_id=id and m.user_id=auth.uid() and m.left_at is null)
  or public.srk_has_admin_permission('bookings.manage'));

drop policy if exists srk_chat_members_participant on public.srk_booking_chat_members;
create policy srk_chat_members_participant on public.srk_booking_chat_members
for select to authenticated using(user_id=auth.uid() or public.srk_has_admin_permission('bookings.manage'));

drop policy if exists srk_chat_messages_participant on public.srk_booking_chat_messages;
create policy srk_chat_messages_participant on public.srk_booking_chat_messages
for select to authenticated using(exists(select 1 from public.srk_booking_chat_members m where m.room_id=srk_booking_chat_messages.room_id and m.user_id=auth.uid() and m.left_at is null)
  or public.srk_has_admin_permission('bookings.manage'));

drop policy if exists srk_booking_receipts_participant on public.srk_booking_receipts;
create policy srk_booking_receipts_participant on public.srk_booking_receipts
for select to authenticated using(
  public.srk_has_admin_permission('bookings.manage') or public.srk_has_admin_permission('payments.read')
  or exists(select 1 from public.service_bookings b where b.id=booking_id and b.customer_user_id=auth.uid())
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id where bw.booking_id=booking_id and w.user_id=auth.uid())
);

drop policy if exists srk_booking_schedule_proposals_participant on public.srk_booking_schedule_proposals;
create policy srk_booking_schedule_proposals_participant on public.srk_booking_schedule_proposals
for select to authenticated using(
  public.srk_has_admin_permission('bookings.manage')
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id where bw.id=booking_worker_id and w.user_id=auth.uid())
  or exists(select 1 from public.srk_booking_workers bw join public.service_bookings b on b.id=bw.booking_id where bw.id=booking_worker_id and b.customer_user_id=auth.uid())
);

drop policy if exists srk_booking_schedule_events_participant on public.srk_booking_schedule_events;
create policy srk_booking_schedule_events_participant on public.srk_booking_schedule_events
for select to authenticated using(
  public.srk_has_admin_permission('bookings.manage')
  or exists(select 1 from public.srk_booking_schedule_proposals p join public.srk_booking_workers bw on bw.id=p.booking_worker_id
    join public.srk_worker_profiles w on w.id=bw.worker_id where p.id=proposal_id and w.user_id=auth.uid())
  or exists(select 1 from public.srk_booking_schedule_proposals p join public.srk_booking_workers bw on bw.id=p.booking_worker_id
    join public.service_bookings b on b.id=bw.booking_id where p.id=proposal_id and b.customer_user_id=auth.uid())
);

drop policy if exists srk_booking_bill_revisions_admin_read on public.srk_booking_final_bill_revisions;
create policy srk_booking_bill_revisions_admin_read on public.srk_booking_final_bill_revisions
for select to authenticated using(public.srk_has_admin_permission('bookings.manage') or public.srk_has_admin_permission('payments.read'));

drop policy if exists srk_worker_offline_timer_participant_read on public.srk_worker_offline_timer_events;
create policy srk_worker_offline_timer_participant_read on public.srk_worker_offline_timer_events
for select to authenticated using(
  public.srk_has_admin_permission('bookings.manage')
  or exists(select 1 from public.srk_worker_profiles w where w.id=worker_id and w.user_id=auth.uid())
);

drop policy if exists srk_system_settings_admin_read on public.srk_system_settings;
create policy srk_system_settings_admin_read on public.srk_system_settings
for select to authenticated using(public.srk_has_admin_permission('bookings.manage'));

