
drop trigger if exists srk_refund_admin_notification_trigger on public.srk_booking_refund_requests;
create trigger srk_refund_admin_notification_trigger
after insert on public.srk_booking_refund_requests
for each row execute function public.srk_notify_admin_permission_team(
  'refunds.manage','New refund request','A new booking refund request needs Admin review.'
);

drop trigger if exists srk_payout_admin_notification_trigger on public.srk_worker_payout_requests;
create trigger srk_payout_admin_notification_trigger
after insert on public.srk_worker_payout_requests
for each row execute function public.srk_notify_admin_permission_team(
  'payouts.manage','New worker payout request','A worker submitted a payout request that needs Admin review.'
);
