
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON TABLE public.srk_booking_final_bill_revisions,
          public.srk_booking_payment_disputes,
          public.srk_booking_payment_evidence
FROM PUBLIC, anon, authenticated;
