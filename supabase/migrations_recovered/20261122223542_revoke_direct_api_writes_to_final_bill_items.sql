
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON TABLE public.srk_booking_final_bill_items
FROM PUBLIC, anon, authenticated;
