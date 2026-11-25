
create or replace function public.srk_guard_company_commission_refund_credit_total()
returns trigger language plpgsql security definer
set search_path to 'pg_catalog','public'
as $$
declare v_allocated numeric(14,2);
begin
 select coalesce(sum(a.amount),0)::numeric(14,2) into v_allocated
 from public.srk_worker_cash_commission_refund_allocations a
 where a.refund_request_id=new.refund_request_id;
 if v_allocated>new.commission_refund_amount then
  raise exception 'Company commission refund cannot be reduced below worker cash commission credits already issued';
 end if;
 return new;
end
$$;
drop trigger if exists srk_guard_company_commission_refund_credit_total_trg
 on public.srk_company_commission_refund_reconciliations;
create trigger srk_guard_company_commission_refund_credit_total_trg
before update of commission_refund_amount on public.srk_company_commission_refund_reconciliations
for each row execute function public.srk_guard_company_commission_refund_credit_total();
revoke all on function public.srk_guard_company_commission_refund_credit_total() from public,anon,authenticated;
