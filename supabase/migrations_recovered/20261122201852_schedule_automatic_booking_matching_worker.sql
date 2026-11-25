
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule(
  'srk-process-booking-matching',
  '* * * * *',
  'select public.srk_process_booking_matching_queue();'
);
