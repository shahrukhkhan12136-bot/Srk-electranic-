create index if not exists srk_worker_cancel_approval_booking_fk_idx
  on public.srk_worker_cancellation_approval_requests (booking_id);
create index if not exists srk_worker_cancel_approval_support_case_fk_idx
  on public.srk_worker_cancellation_approval_requests (support_case_id);
create index if not exists srk_worker_cancel_approval_worker_fk_idx
  on public.srk_worker_cancellation_approval_requests (worker_id);