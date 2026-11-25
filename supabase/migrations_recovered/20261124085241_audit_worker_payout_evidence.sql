create trigger srk_audit_worker_payout_evidence_admin
after insert or update or delete on public.srk_worker_payout_evidence
for each row execute function public.srk_log_admin_entity_change('worker_payout_evidence');