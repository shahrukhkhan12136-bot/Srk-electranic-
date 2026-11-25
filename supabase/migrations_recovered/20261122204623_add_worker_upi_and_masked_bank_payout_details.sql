
create or replace function public.srk_worker_update_payout_details(p_upi_id text,p_bank_account_last4 text)
returns public.srk_worker_profiles
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.srk_worker_profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_upi_id is not null and p_upi_id !~ '^[A-Za-z0-9._-]{2,100}@[A-Za-z0-9.-]{2,50}$' then
    raise exception 'Invalid UPI ID format';
  end if;
  if p_bank_account_last4 is not null and p_bank_account_last4 !~ '^[0-9]{4}$' then
    raise exception 'Bank account last four digits must be four numbers';
  end if;
  update public.srk_worker_profiles set upi_id=p_upi_id,bank_account_last4=p_bank_account_last4,updated_at=clock_timestamp()
  where user_id=auth.uid() returning * into v;
  if not found then raise exception 'Worker profile not found'; end if;
  return v;
end $$;
revoke all on function public.srk_worker_update_payout_details(text,text) from public,anon;
grant execute on function public.srk_worker_update_payout_details(text,text) to authenticated;
