drop policy if exists "srk_electricians_read_own_payouts" on public.srk_electrician_payouts;
create policy "srk_electricians_read_own_payouts"
on public.srk_electrician_payouts
for select
to authenticated
using (
  exists (
    select 1
    from public.electrician_profiles ep
    where ep.id = srk_electrician_payouts.electrician_profile_id
      and ep.user_id = (select auth.uid())
  )
);