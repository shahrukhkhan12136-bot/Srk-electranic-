create or replace function public.srk_service_verify_qr_reconcile_secret(p_token text)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select coalesce(auth.role(), '') = 'service_role'
     and p_token is not null
     and length(p_token) between 32 and 256
     and exists (
       select 1 from vault.decrypted_secrets
       where name = 'SRK_QR_RECONCILE_SECRET'
         and decrypted_secret = p_token
     );
$$;
revoke all on function public.srk_service_verify_qr_reconcile_secret(text) from public, anon, authenticated;
grant execute on function public.srk_service_verify_qr_reconcile_secret(text) to service_role;