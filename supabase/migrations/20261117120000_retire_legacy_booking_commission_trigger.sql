-- Retire the legacy completion-time commission calculation.
-- The authoritative labour-only commission is now assigned by
-- zz_srk_set_booking_commission_before_payout after verified payment evidence.
-- Keep the legacy trigger function in place for compatibility; it is no longer
-- attached to service_bookings and therefore cannot overwrite commission_amount.

drop trigger if exists srk_booking_commission_trigger on public.service_bookings;
