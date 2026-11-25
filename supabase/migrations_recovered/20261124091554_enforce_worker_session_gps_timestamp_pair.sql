alter table public.srk_worker_work_sessions
 add constraint srk_worker_sessions_last_gps_timestamp_pair_check
 check ((last_gps_latitude is null)=(last_gps_at is null));