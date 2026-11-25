drop policy if exists "srk_admin_read_electrician_payouts" on public.srk_electrician_payouts;
drop policy if exists "srk_electricians_read_own_payouts" on public.srk_electrician_payouts;
create policy "srk_read_authorized_electrician_payouts"
on public.srk_electrician_payouts
for select
to authenticated
using (
  (select public.is_srk_admin())
  or exists (
    select 1
    from public.electrician_profiles ep
    where ep.id = srk_electrician_payouts.electrician_profile_id
      and ep.user_id = (select auth.uid())
  )
);