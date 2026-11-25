drop policy if exists srk_route_transfers_deny_client_api on public.srk_route_transfers;
create policy srk_route_transfers_deny_client_api on public.srk_route_transfers for all to anon, authenticated using (false) with check (false);
revoke all on public.srk_route_transfers from anon, authenticated;