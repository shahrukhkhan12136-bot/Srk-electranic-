
create index if not exists service_bookings_higher_skill_consent_level_idx on public.service_bookings(higher_skill_consent_level_id);
create index if not exists service_bookings_requested_skill_level_idx on public.service_bookings(requested_skill_level_id);
create index if not exists srk_admin_timer_override_events_booking_idx on public.srk_admin_timer_override_events(booking_id);
create index if not exists srk_admin_timer_override_events_booking_worker_idx on public.srk_admin_timer_override_events(booking_worker_id);
create index if not exists srk_admin_timer_override_events_worker_idx on public.srk_admin_timer_override_events(worker_id);
create index if not exists srk_booking_complaints_reported_to_worker_idx on public.srk_booking_complaints(reported_to_worker_id);
create index if not exists srk_booking_no_show_reports_booking_idx on public.srk_booking_no_show_reports(booking_id);
create index if not exists srk_booking_no_show_reports_booking_worker_idx on public.srk_booking_no_show_reports(booking_worker_id);
create index if not exists srk_booking_skill_level_events_from_level_idx on public.srk_booking_skill_level_events(from_skill_level_id);
create index if not exists srk_booking_skill_level_events_to_level_idx on public.srk_booking_skill_level_events(to_skill_level_id);
create index if not exists srk_policy_consents_document_idx on public.srk_policy_consents(policy_document_id);

drop policy if exists srk_worker_profile_self_read on public.srk_worker_profiles;
create policy srk_worker_profile_self_read on public.srk_worker_profiles
for select to authenticated using (user_id=(select auth.uid()));

drop policy if exists srk_worker_documents_owner on public.srk_worker_documents;
create policy srk_worker_documents_owner on public.srk_worker_documents
for select to authenticated using (
 exists(select 1 from public.srk_worker_applications a
   where a.id=srk_worker_documents.application_id and a.user_id=(select auth.uid()))
 or exists(select 1 from public.srk_worker_profiles w
   where w.id=srk_worker_documents.worker_id and w.user_id=(select auth.uid()))
 or (select public.is_srk_admin())
);

drop policy if exists srk_worker_application_self on public.srk_worker_applications;
create policy srk_worker_application_self on public.srk_worker_applications
for select to authenticated using (user_id=(select auth.uid()) or (select public.is_srk_admin()));
