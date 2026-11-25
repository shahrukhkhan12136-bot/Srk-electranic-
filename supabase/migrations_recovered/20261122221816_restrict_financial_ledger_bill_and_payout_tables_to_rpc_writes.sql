
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON TABLE public.srk_worker_wallet_ledger,
          public.srk_worker_earnings,
          public.srk_worker_payout_requests,
          public.srk_worker_refund_allocations,
          public.srk_booking_final_bills,
          public.srk_booking_receipts
FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.srk_worker_wallet_ledger,
          public.srk_worker_earnings,
          public.srk_worker_payout_requests,
          public.srk_worker_refund_allocations,
          public.srk_booking_final_bills,
          public.srk_booking_receipts
TO authenticated;
