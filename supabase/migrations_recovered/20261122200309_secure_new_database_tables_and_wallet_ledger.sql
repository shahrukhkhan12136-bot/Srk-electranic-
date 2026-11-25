
alter table public.srk_worker_earnings
  add column if not exists payment_method text,
  add column if not exists settlement_status text not null default 'pending';

alter table public.srk_worker_earnings
  add constraint srk_worker_earnings_payment_method_valid
  check(payment_method is null or payment_method in ('cash','online','upi','card')),
  add constraint srk_worker_earnings_settlement_status_valid
  check(settlement_status in ('pending','available','cash_commission_due','cash_split_pending','paid','held','reversed'));

create or replace function public.srk_post_worker_earning_to_ledger()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public
as $$
begin
  if new.payment_method in ('online','upi','card') then
    insert into public.srk_worker_wallet_ledger
      (worker_id,booking_id,earning_id,entry_type,amount,balance_effect,description,idempotency_key)
    values
      (new.worker_id,new.booking_id,new.id,'earning',new.net_earning,new.net_earning,
       'Online booking net earning after 15% company commission','earning:'||new.id::text)
    on conflict(idempotency_key) do nothing;
    update public.srk_worker_earnings set settlement_status='available' where id=new.id;
  elsif new.payment_method='cash' and new.worker_role='technician' then
    insert into public.srk_worker_wallet_ledger
      (worker_id,booking_id,earning_id,entry_type,amount,balance_effect,description,idempotency_key)
    values
      (new.worker_id,new.booking_id,new.id,'cash_commission_due',new.company_commission,-new.company_commission,
       'Cash booking company commission due from technician','cash-commission:'||new.id::text)
    on conflict(idempotency_key) do nothing;
    update public.srk_worker_earnings set settlement_status='cash_commission_due' where id=new.id;
  elsif new.payment_method='cash' and new.worker_role='helper' then
    update public.srk_worker_earnings set settlement_status='cash_split_pending' where id=new.id;
  end if;
  return new;
end $$;

drop trigger if exists srk_post_worker_earning_ledger_trigger on public.srk_worker_earnings;
create trigger srk_post_worker_earning_ledger_trigger
after insert on public.srk_worker_earnings
for each row execute function public.srk_post_worker_earning_to_ledger();

-- Public, non-sensitive service catalog reads.
drop policy if exists srk_categories_read_active on public.srk_service_categories;
create policy srk_categories_read_active on public.srk_service_categories
for select to anon,authenticated using (is_active);

drop policy if exists srk_services_read_active on public.srk_service_types;
create policy srk_services_read_active on public.srk_service_types
for select to anon,authenticated using (is_active);

drop policy if exists srk_skills_read_active on public.srk_service_skills;
create policy srk_skills_read_active on public.srk_service_skills
for select to anon,authenticated using (is_active);

drop policy if exists srk_skill_levels_read_active on public.srk_skill_levels;
create policy srk_skill_levels_read_active on public.srk_skill_levels
for select to anon,authenticated using (is_active);

drop policy if exists srk_rates_read_approved on public.srk_service_rates;
create policy srk_rates_read_approved on public.srk_service_rates
for select to anon,authenticated using (rate_status='approved' and effective_from<=now() and (effective_to is null or effective_to>now()));

drop policy if exists srk_customer_profile_self_read on public.srk_customer_profiles;
create policy srk_customer_profile_self_read on public.srk_customer_profiles
for select to authenticated using(user_id=auth.uid() or public.is_srk_admin());

drop policy if exists srk_worker_profile_self_read on public.srk_worker_profiles;
create policy srk_worker_profile_self_read on public.srk_worker_profiles
for select to authenticated using(user_id=auth.uid() or public.is_srk_admin());

drop policy if exists srk_worker_skills_self_read on public.srk_worker_skills;
create policy srk_worker_skills_self_read on public.srk_worker_skills
for select to authenticated using(
  exists(select 1 from public.srk_worker_profiles w where w.id=worker_id and w.user_id=auth.uid())
  or public.is_srk_admin()
);

drop policy if exists srk_booking_workers_participant_read on public.srk_booking_workers;
create policy srk_booking_workers_participant_read on public.srk_booking_workers
for select to authenticated using(
  public.is_srk_admin()
  or exists(select 1 from public.srk_worker_profiles w where w.id=worker_id and w.user_id=auth.uid())
  or exists(select 1 from public.service_bookings b where b.id=booking_id and b.customer_user_id=auth.uid())
);

drop policy if exists srk_worker_sessions_participant_read on public.srk_worker_work_sessions;
create policy srk_worker_sessions_participant_read on public.srk_worker_work_sessions
for select to authenticated using(
  public.is_srk_admin()
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id where bw.id=booking_worker_id and w.user_id=auth.uid())
  or exists(select 1 from public.srk_booking_workers bw join public.service_bookings b on b.id=bw.booking_id where bw.id=booking_worker_id and b.customer_user_id=auth.uid())
);

drop policy if exists srk_worker_session_events_participant_read on public.srk_worker_session_events;
create policy srk_worker_session_events_participant_read on public.srk_worker_session_events
for select to authenticated using(
  public.is_srk_admin()
  or exists(select 1 from public.srk_worker_work_sessions s join public.srk_booking_workers bw on bw.id=s.booking_worker_id join public.srk_worker_profiles w on w.id=bw.worker_id where s.id=session_id and w.user_id=auth.uid())
  or exists(select 1 from public.srk_worker_work_sessions s join public.srk_booking_workers bw on bw.id=s.booking_worker_id join public.service_bookings b on b.id=bw.booking_id where s.id=session_id and b.customer_user_id=auth.uid())
);

drop policy if exists srk_worker_schedule_self_read on public.srk_worker_schedule_blocks;
create policy srk_worker_schedule_self_read on public.srk_worker_schedule_blocks
for select to authenticated using(
  public.is_srk_admin() or exists(select 1 from public.srk_worker_profiles w where w.id=worker_id and w.user_id=auth.uid())
);

drop policy if exists srk_final_bills_participant_read on public.srk_booking_final_bills;
create policy srk_final_bills_participant_read on public.srk_booking_final_bills
for select to authenticated using(
  public.is_srk_admin()
  or exists(select 1 from public.service_bookings b where b.id=booking_id and b.customer_user_id=auth.uid())
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id where bw.booking_id=booking_id and w.user_id=auth.uid())
);

drop policy if exists srk_final_bill_items_participant_read on public.srk_booking_final_bill_items;
create policy srk_final_bill_items_participant_read on public.srk_booking_final_bill_items
for select to authenticated using(
  exists(select 1 from public.srk_booking_final_bills f join public.service_bookings b on b.id=f.booking_id where f.id=bill_id and b.customer_user_id=auth.uid())
  or exists(select 1 from public.srk_booking_final_bills f join public.srk_booking_workers bw on bw.booking_id=f.booking_id join public.srk_worker_profiles w on w.id=bw.worker_id where f.id=bill_id and w.user_id=auth.uid())
  or public.is_srk_admin()
);

drop policy if exists srk_worker_earnings_self_read on public.srk_worker_earnings;
create policy srk_worker_earnings_self_read on public.srk_worker_earnings
for select to authenticated using(
  public.is_srk_admin() or exists(select 1 from public.srk_worker_profiles w where w.id=worker_id and w.user_id=auth.uid())
);

drop policy if exists srk_worker_wallet_self_read on public.srk_worker_wallet_ledger;
create policy srk_worker_wallet_self_read on public.srk_worker_wallet_ledger
for select to authenticated using(
  public.is_srk_admin() or exists(select 1 from public.srk_worker_profiles w where w.id=worker_id and w.user_id=auth.uid())
);

drop policy if exists srk_worker_payout_self_read on public.srk_worker_payout_requests;
create policy srk_worker_payout_self_read on public.srk_worker_payout_requests
for select to authenticated using(
  public.is_srk_admin() or exists(select 1 from public.srk_worker_profiles w where w.id=worker_id and w.user_id=auth.uid())
);

drop policy if exists srk_technician_cycle_self_read on public.srk_technician_booking_cycle;
create policy srk_technician_cycle_self_read on public.srk_technician_booking_cycle
for select to authenticated using(
  public.is_srk_admin() or exists(select 1 from public.srk_worker_profiles w where w.id=technician_id and w.user_id=auth.uid())
);

drop policy if exists srk_technician_sequence_self_read on public.srk_technician_booking_sequence;
create policy srk_technician_sequence_self_read on public.srk_technician_booking_sequence
for select to authenticated using(
  public.is_srk_admin() or exists(select 1 from public.srk_worker_profiles w where w.id=technician_id and w.user_id=auth.uid())
);

drop policy if exists srk_payment_evidence_participant_read on public.srk_booking_payment_evidence;
create policy srk_payment_evidence_participant_read on public.srk_booking_payment_evidence
for select to authenticated using(
  public.is_srk_admin()
  or submitted_by=auth.uid()
  or exists(select 1 from public.service_bookings b where b.id=booking_id and b.customer_user_id=auth.uid())
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id where bw.booking_id=booking_id and w.user_id=auth.uid())
);

drop policy if exists srk_payment_disputes_participant_read on public.srk_booking_payment_disputes;
create policy srk_payment_disputes_participant_read on public.srk_booking_payment_disputes
for select to authenticated using(
  public.is_srk_admin()
  or raised_by=auth.uid()
  or exists(select 1 from public.service_bookings b where b.id=booking_id and b.customer_user_id=auth.uid())
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id where bw.booking_id=booking_id and w.user_id=auth.uid())
);

drop policy if exists srk_admin_booking_changes_admin_read on public.srk_booking_admin_changes;
create policy srk_admin_booking_changes_admin_read on public.srk_booking_admin_changes
for select to authenticated using(public.is_srk_admin());
