# SRK ELECTRONIC — Admin Cash Commission Due Report
Date: 21 November 2026
Branch: `feature/master-gst-accounting-20261121`

- Main Admin-only, read-only RPC: `srk_admin_list_master_commission_dues()`.
- Returns original 15% cash commission, amount recovered from later company-collected Technician earnings, outstanding balance, count of open dues, Technician-wise totals, and booking-wise history.
- Admin Panel now has a dedicated **Master Cash Commission — SRK का 15% बकाया** section with totals and Technician/booking tables.
- Refresh runs automatically alongside the existing Master payout queue refresh.
- This report cannot edit, waive, or mark dues paid. Recovery continues only through the payable trigger when new company-collected Technician earnings are created.
- Direct table access remains revoked; RPC execution is granted to authenticated role but checks `is_srk_admin()` internally.
- This is source-only. Database migration replay and pgTAP runtime remain pending.
- Cash-collected booking refunds are not handled by the Razorpay-only refund function. A separate audited cash refund/reversal process must be designed before cash refund cases are treated as supported.
