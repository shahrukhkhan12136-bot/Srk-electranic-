
drop trigger if exists srk_booking_worker_push_webhook_trigger on public.srk_booking_workers;
create trigger srk_booking_worker_push_webhook_trigger
after insert or update of assignment_status on public.srk_booking_workers
for each row execute function private.srk_notify_job_offer_push();
