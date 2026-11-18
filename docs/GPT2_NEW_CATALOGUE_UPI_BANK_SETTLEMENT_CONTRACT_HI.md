# GPT-2 — New Catalogue UPI / Bank Transfer Source Contract

**Date:** 18 November 2026  
**Scope:** Source-only implementation proposal landed as a feature-branch migration. No migration was applied and no runtime payment was recorded.

## Implemented in source

Migration: `20261118140000_add_catalogue_admin_manual_digital_settlement.sql`

RPC:
`public.srk_admin_record_new_booking_manual_digital_payment(uuid,text,text,text)`

Parameters:
- `p_booking_id`: completed new-Catalogue booking UUID.
- `p_method`: exactly `upi` or `bank_transfer`.
- `p_reference`: required UPI transaction reference / bank UTR, 4–120 characters.
- `p_note`: optional Admin note, maximum 250 characters.

Controls:
1. Authenticated Main Admin only (`auth.uid()` and `is_srk_admin()`).
2. Locks the booking row; requires completed, assigned, `selected_category IS NOT NULL`, and immutable labour bill.
3. Requires booking's preselected payment method to match the RPC method.
4. Requires payment state exactly `unpaid` or `pending`; rejects NULL and any existing paid evidence, Razorpay order/payment IDs.
5. Acquires a transaction advisory lock on the normalized reference and rejects an already-used manual payment reference.
6. Inserts manual payment evidence before updating booking payment fields. Booking method is stored as `UPI` or `Bank Transfer`, matching the evidence method under the existing case-insensitive method-equality trigger.
7. Uses the existing booking payment trigger chain to calculate commission and create/reconcile the electrician payout from the immutable labour bill.
8. Settles reserved cancellation-fee items as SRK-direct electronic collection entries. Unlike cash collected by the electrician, it does not debit the electrician wallet for a digital payment collected by SRK.
9. The RPC returns the labour, cancellation-fee, and total amounts in paise; it does not expose or change the 85% pre-payment offer contract.

The cash RPC remains separate. The legacy manual-payment RPC remains legacy-only and continues to reject new Catalogue bookings.

## Important evidence limitation

This RPC is an **Admin-recorded verification** workflow. It does not independently query a UPI/bank provider or verify a bank statement. The Admin must inspect the actual received transaction and enter the correct UPI reference / UTR. The reference is audit evidence, not proof by itself.

The UPI/bank RPC and the new-Catalogue cash hardening RPC now take the same transaction advisory lock and check the shared manual-payment evidence table before insert. This serializes duplicate references between these two new-Catalogue RPCs. The source does not yet add a global unique index over all historical manual references; legacy/manual or other insertion paths that do not take this lock, and existing duplicate data, must be reviewed before claiming global uniqueness.

## Regression test

Added source assertions in `tests/new-catalogue-settlement-rpc-contract.test.js` for method allow-list, Catalogue scope, strict payment state, no prior evidence, reference locking/reuse rejection, SRK fee-ledger credit, no electrician cash-wallet debit, and execute grants.

The tests have **not** been executed. SQL syntax, trigger interaction, transaction rollback, duplicate-reference concurrency, and runtime behaviour remain unverified until the approved test/DB environment is available.

## Deployment boundary

Feature-branch source only. No Production DB changes, migration application, deployment, paid DB branch, or expense.


## 18 नवंबर का अतिरिक्त method-normalization सुधार

Manual-payment trigger में booking और evidence के payment_method का normalized text exact match होना आवश्यक है। इसलिए bank transfer के लिए RPC अब दोनों जगह canonical `bank_transfer` सहेजता है; UI/receipt इसे “बैंक ट्रांसफर” के रूप में दिखा सकती है। इससे draft का `Bank Transfer` बनाम `bank_transfer` mismatch ठीक हुआ। Regression contract भी canonical value की जाँच करता है। यह source-level सुधार है; PostgreSQL runtime test अभी नहीं हुआ।


## Admin Dashboard routing audit (18 नवंबर)

`admin.html` अब नई Catalogue booking में:
- Cash के लिए `srk_admin_record_new_booking_cash_payment`
- UPI / Bank Transfer के लिए `srk_admin_record_new_booking_manual_digital_payment`
- अन्य manual digital methods के लिए रोक; Razorpay केवल verified online flow से

Regression contract में Admin UI routing assertion जोड़ा गया है।

**सीमा:** Customer की नई booking form अभी payment method के रूप में केवल Cash और Razorpay चुनने देती है। इसलिए UPI / Bank Transfer RPC तभी सफल होगा जब booking का पहले से दर्ज `payment_method` ग्राहक की अनुमति से `upi` या `bank_transfer` हो। केवल Admin dropdown बदलना पर्याप्त नहीं है; इससे customer की मूल payment choice नहीं बदली जाती। UPI ID / bank account / QR details उपलब्ध और स्वीकृत हुए बिना customer form में नए payment विकल्प नहीं जोड़े गए हैं।


## अतिरिक्त source hardening (18 नवंबर)

Digital settlement RPC में अब payment update से पहले दो स्पष्ट guards हैं:
1. Immutable labour bill का `electrician_profile_id` उसी booking के `assigned_electrician_id` से मिलना चाहिए।
2. हर reserved cancellation-fee item के debt record का `status='reserved'`, `reserved_booking_id` मौजूदा booking और `customer_user_id` booking customer से मेल खाना चाहिए; debt row lock भी लिया जाता है।

Mismatch होने पर पूरी RPC transaction असफल होगी; payment entry या fee settlement आधा लागू नहीं होना चाहिए। इनके लिए regression contract assertions जोड़े गए हैं। यह source-level सुरक्षा है; PostgreSQL runtime और वास्तविक transaction व्यवहार अभी प्रमाणित नहीं हैं।
