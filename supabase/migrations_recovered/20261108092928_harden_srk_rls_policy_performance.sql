
-- Preserve existing access rules while reducing duplicate SELECT policy evaluation.
drop policy if exists "electrician_view_own_profile" on public.electrician_profiles;
drop policy if exists "srk_electrician_read_own_profile" on public.electrician_profiles;
drop policy if exists "srk_admin_manage_profiles" on public.electrician_profiles;

create policy "electrician_and_admin_read_profiles"
on public.electrician_profiles
for select to authenticated
using (
  auth_user_id = (select auth.uid())
  or user_id = (select auth.uid())
  or (select public.is_srk_admin())
);

create policy "srk_admin_insert_profiles"
on public.electrician_profiles
for insert to authenticated
with check ((select public.is_srk_admin()));

create policy "srk_admin_update_profiles"
on public.electrician_profiles
for update to authenticated
using ((select public.is_srk_admin()))
with check ((select public.is_srk_admin()));

create policy "srk_admin_delete_profiles"
on public.electrician_profiles
for delete to authenticated
using ((select public.is_srk_admin()));

-- Combine electrician-owned and admin-read access into one SELECT policy.
drop policy if exists "electrician_view_own_offers" on public.job_offers;
drop policy if exists "srk_admin_read_offers" on public.job_offers;

create policy "electrician_and_admin_read_offers"
on public.job_offers
for select to authenticated
using (
  (select public.is_srk_admin())
  or exists (
    select 1
    from public.electrician_profiles e
    where e.id = job_offers.electrician_id
      and e.auth_user_id = (select auth.uid())
      and e.active = true
      and e.verification_status = 'approved'
  )
);

-- Cache auth.uid() per statement in the own-admin-row policy.
drop policy if exists "admin can view own record" on public.srk_admin_users;
create policy "admin can view own record"
on public.srk_admin_users
for select to authenticated
using (user_id = (select auth.uid()));
