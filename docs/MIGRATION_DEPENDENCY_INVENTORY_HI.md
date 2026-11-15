# SRK ELECTRONIC — Migration Dependency Inventory (प्रारंभिक source audit)

**Branch:** `feat/customer-login-first-dashboard-20261114`  
**Migration files:** 71  
**pgTAP SQL contracts:** 33  
**स्थिति:** सभी migration files का source fetch और प्रारंभिक dependency scan किया गया; यह अभी executable baseline नहीं है। SQL parser/runtime से पुष्टि बाकी है।

## 1. Clean-room baseline में पहले से उपलब्ध होने वाले मुख्य application objects

शुरुआती migrations में निम्न objects पर `ALTER TABLE`, policies, indexes, triggers या RPC queries निर्भर हैं; ये इसी migration chain में पहले से पूर्ण base-table definitions के रूप में निर्मित नहीं दिखे:

| Object | क्यों चाहिए | प्रमाणित निर्भरता का उदाहरण |
|---|---|---|
| `public.service_bookings` | सबसे केंद्रीय booking table; अनेक migrations columns/constraints/policies/functions जोड़ती हैं | customer ownership, GPS, booking states, quote compatibility, timer, bill, payment, refund, cancellation, accounting |
| `public.electrician_applications` | आवेदन और KYC/स्थान data | public insert restrictions, GPS, Admin review/activation |
| `public.electrician_profiles` | सक्रिय electrician identity, location, assignment, KYC, phone, rate-tier और availability | GPS, offer matching, timer, payout, recipient validation |
| `public.job_offers` | booking-to-electrician offer queue | offer detail RPC, sequential dispatch, availability, offer expiry/acceptance |
| `public.srk_admin_users` | legacy Main Admin identity/authorization bridge | Admin RBAC/session/financial authorization code |
| `public.srk_booking_complaints` | customer complaints and dispute linkage | support messaging, timer dispute, Admin review |
| `public.srk_booking_complaint_events` | complaint history/event projection | customer-safe complaint history / support review |
| `public.srk_push_subscriptions` | registered push subscriptions | durable push outbox and per-subscription delivery |

**महत्वपूर्ण:** ऊपर के सभी columns, keys और constraints का complete baseline अभी प्रमाणित नहीं है। Table names को source references से पहचाना गया है; exact DDL contract अगला काम है। यदि किसी object की CREATE definition किसी दूसरे branch/environment में है, तो उसे इस branch की उपलब्ध migration chain का प्रमाण नहीं मानना है।

## 2. इस migration chain में बनाए जाने वाले प्रमुख objects

ये उदाहरण baseline में duplicate CREATE नहीं होने चाहिए; इन्हें ordered migrations स्वयं बनाएँगी:

- Rate limiting: `private.srk_public_api_rate_limits`.
- Wallet/Route ledger: `srk_wallet_accounts`, `srk_wallet_ledger`, `srk_wallet_bank_links`, `srk_route_transfers`.
- Financial core: `srk_booking_labour_bills`, `srk_manual_payment_entries`, `srk_electrician_payouts`, `srk_admin_audit_events`, `srk_razorpay_refunds`, `srk_booking_refund_requests`, `srk_manual_refund_entries`.
- Customer/support: `srk_customer_profiles`, `srk_customer_saved_addresses`, `srk_booking_complaint_messages`, `srk_booking_complaint_message_attachments`.
- Dispatch/workflow: `srk_booking_offer_dispatch`, `srk_booking_offer_candidates`, `srk_booking_work_events`, `srk_booking_cancellation_requests`, cancellation fee/debt/ledger tables.
- Admin/staff: `srk_admin_staff`, permissions, role-permission mappings, sessions, audit events and support assignments.
- Refund/push: `srk_razorpay_refund_recovery_audits`, webhook inbox events, `srk_push_delivery_outbox`, subscription delivery ledger.
- Electrician operations: verification documents/events, support tickets/messages, availability events, phone-change requests, profile-name events.

यह सूची representative है, full CREATE inventory नहीं। हर table का exact owning migration, columns और FK order manifest में दर्ज करना बाकी है।

## 3. Supabase platform test doubles

Disposable test database में निम्न platform contract अलग bootstrap layer में चाहिए:

- Roles: `anon`, `authenticated`, `service_role` (केवल local test database में)।
- Schemas: `auth`, `storage`, `private`, `srk_private`; `extensions` यदि source में प्रयुक्त extension setup इसकी माँग करे।
- Auth: `auth.users` के migration-referenced fields और `auth.uid()` का deterministic test implementation, test JWT/session claim से।
- Storage: `storage.buckets`, `storage.objects` के केवल प्रयुक्त fields; policies/owner_id व्यवहार test double में।
- Authorization helpers: `public.is_srk_admin()` और source में प्रयुक्त अन्य platform/helper functions का वास्तविक contract या explicitly test-only stub।
- PostgreSQL built-ins/extensions: UUID generation, crypto/hash, trigger helpers, geospatial operators/functions आदि का exact dependency scan; अनुमान से extension install नहीं।

Test doubles को Production schema का प्रतिनिधि न कहा जाए। RLS tests में वास्तविक role switching और claims set किए जाएँ।

## 4. Migration dependency order के जोखिम

1. शुरुआती migrations core tables पर निर्भर हैं; baseline को उन tables की exact columns/PK/FK/check constraints देने होंगे।
2. बाद के migrations में अनेक SECURITY DEFINER functions हैं; सिर्फ table creation पर्याप्त नहीं—roles, schema USAGE, function grants, search_path और helper functions भी चाहिए।
3. Storage और Auth references के कारण plain PostgreSQL bootstrap अपने आप Supabase-compatible नहीं बनता।
4. कुछ migrations में catalog introspection (`pg_constraint`, `pg_trigger`, `information_schema`) है; local fixture में PostgreSQL version/permissions consistent होने चाहिए।
5. दो filenames `20261109` से शुरू होते हैं और version prefix टकराता है। Migration history reconcile किए बिना rename/reorder नहीं।
6. Static text scanning में PL/pgSQL bodies, dynamic SQL, CTE aliases और SQL keywords को table names समझने की संभावना है। इसीलिए automated regex output को अंतिम dependency truth नहीं माना जाएगा।

## 5. अगला कार्य — exact DDL contract extraction

हर baseline dependency के लिए यह evidence table बनानी होगी:

- source file + exact SQL statement/line range;
- referenced table and exact columns;
- primary/foreign keys and referenced columns;
- expected enum/check constraints;
- policies, triggers and functions required before first use;
- owning migration, यदि उसी chain में create होता है;
- synthetic fixture rows required by pgTAP;
- test identity/role/JWT assumptions।

फिर एक अलग disposable database में bootstrap → legacy baseline → migration replay → 33 pgTAP files execute होंगे। कोई Production URL/secret या real customer/payment data नहीं।

## 6. सत्यापन की वर्तमान सीमा

- 71 migration files का branch tree inventory और source fetch किया गया।
- 33 pgTAP test files की संख्या पहले के tree inventory से ज्ञात है; इन SQL tests का PostgreSQL runtime execution अभी नहीं हुआ।
- प्रारंभिक dependency scan में regex false positives संभव हैं; इस दस्तावेज़ की सूची reviewable working inventory है, final schema specification नहीं।
- इस environment में PostgreSQL/Docker/Podman executables उपलब्ध न होने के कारण runtime execution अभी संभव नहीं।
- GPT-2 checklist: 27/39 = 69%; यह dependency audit checklist item closure नहीं है, इसलिए प्रतिशत अपरिवर्तित।
