
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON TABLE public.srk_booking_transactions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.srk_booking_transactions TO authenticated;
