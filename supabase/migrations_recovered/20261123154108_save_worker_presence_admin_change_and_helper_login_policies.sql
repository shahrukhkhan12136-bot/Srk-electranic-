
INSERT INTO public.srk_system_settings(setting_key,setting_value,admin_note)
VALUES
('worker_offline_timeout_minutes','5'::jsonb,'User-provided 5-minute offline timeout; heartbeat enforcement must be connected to the worker presence scheduler.'),
('admin_can_edit_confirmed_booking_staff_and_schedule','true'::jsonb,'User-approved: Admin may change assigned Technician/Helper counts and Schedule after Booking confirmation.'),
('helper_login_mode','"separate_auth_user"'::jsonb,'User-approved: each Helper has a separate login identity.')
ON CONFLICT(setting_key)
DO UPDATE SET setting_value=EXCLUDED.setting_value,
              admin_note=EXCLUDED.admin_note,
              updated_at=clock_timestamp();
