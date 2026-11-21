# GPT-2 Migration Dependency Ordering — Quote/Commission Chain (16 Nov 2026)

स्थिति: केवल Feature Branch source का read-only audit। कोई migration/test/database execution या Production बदलाव नहीं।

## 1. जाँची गई source chain

Branch: `feat/customer-login-first-dashboard-20261114`

| क्रम/फ़ाइल | Source में काम | निर्भरता / टिप्पणी |
|---|---|---|
| `20261108121115_add_customer_account_booking_access.sql` | `service_bookings.customer_user_id` जोड़ती है; Auth FK, customer-own-booking SELECT policy और index | पहले से `service_bookings` और Supabase `auth.users` चाहिए |
| `20261109000500_harden_electrician_profile_identity_linking.sql` | `electrician_profiles.auth_user_id`, identity sync/guard triggers और unique index | `electrician_profiles.user_id`, `phone`, `verification_status`; Auth users fields पर निर्भर |
| `20261109001000_add_google_maps_location_support.sql` | Booking/application/profile GPS columns और constraints; Admin application review RPC | उपरोक्त profile identity migration के बाद होना चाहिए; source comment भी ऐसा कहता है |
| `20261109002000_expose_assigned_booking_map_pin.sql` | `srk_get_my_offer_details()` को map coordinates सहित बनाती है | `job_offers`, profile, booking और location columns |
| `20261109_electrician_inspection_quotes_and_service_only_commission.sql` | Quote fields, commission trigger, quote/customer/work RPCs, विस्तारित offer-details RPC और booking status constraints | customer_user_id, profile identity, location fields, job_offers और कई base columns |
| `20261109003000_secure_commission_reporting.sql` | Commission reports/RPCs और authenticated column-level UPDATE grants | `amount_paid`, `commission_amount`, `commission_rate`, payment/status columns और `public.is_srk_admin()` |
| `20261116200000_restore_service_bookings_amount_paid.sql` | `service_bookings.amount_paid` जोड़ती है और nonnegative CHECK बनाती है | पुराने commission trigger/reporting code से पहले उपलब्ध होना चाहिए, यदि baseline में पहले से मौजूद न हो |

## 2. महत्वपूर्ण ordering observations

### A. Map function का replacement क्रम

`20261109002000_expose_assigned_booking_map_pin.sql` पुरानी return signature वाली `srk_get_my_offer_details()` बनाती है। Quote migration वही function drop करके नई return signature बनाती है, जिसमें quote fields भी हैं।

इस source chain में 090020 का function definition quote migration से पहले होना चाहिए। यदि बाद में 090020 दोबारा replay हो तो वह quote वाली विस्तारित signature को downgrade कर सकती है। वास्तविक migration inventory/history की पुष्टि के बिना कोई reorder सुझाव नहीं है।

### B. Profile identity और GPS

`20261109000500_harden_electrician_profile_identity_linking.sql` का comment साफ कहता है कि इसे `20261109001000_add_google_maps_location_support.sql` से पहले चलना चाहिए, क्योंकि बाद वाली migration identity fields दोनों लिखती है।

Quote migration की offer-details RPC `location_lat` और `location_lng` पढ़ती है; इसलिए map-support migration source chain में पहले होनी चाहिए, जब तक approved baseline में ये fields पहले से न हों।

### C. Customer ownership

Quote response RPC booking को `customer_user_id = auth.uid()` से खोजती है। इसलिए `20261108121115_add_customer_account_booking_access.sql` या उसके बराबर approved baseline, quote workflow से पहले जरूरी है।

### D. `amount_paid` का order risk — अभी unresolved

Quote migration का trigger `NEW.amount_paid` पढ़ता है। Commission reporting migration भी `amount_paid` पढ़ती है और authenticated update grant में इसे शामिल करती है।

लेकिन current branch में explicit restore file `20261116200000_restore_service_bookings_amount_paid.sql` है। यदि starter baseline में यह column नहीं है, तो restore migration को उन dependent functions/triggers के runtime use से पहले लागू करना होगा।

यह static source-level order risk है। PL/pgSQL trigger function की creation सफल हो सकती है, जबकि missing field वाला execution path बाद में विफल हो; इस audit ने कोई runtime claim/test नहीं किया।

### E. Commission report और Admin helper

`20261109003000_secure_commission_reporting.sql` `public.is_srk_admin()` को call करती है। इस helper का authoritative introducing migration/baseline इस सीमित audit में स्थापित नहीं हुआ। Historical `PORTAL_SCHEMA.sql` में अलग नाम `srk_is_admin()` भी दिखता है; इसे `is_srk_admin()` के बराबर मानना सुरक्षित नहीं।

## 3. फिलहाल सिद्ध और असिद्ध बातें

सिद्ध (Git source से):
- ऊपर सूचीबद्ध migrations के source effects और direct object references।
- 09000500 का 09001000 से पहले होना source comment और field writes से समर्थित है।
- 09002000 के बाद quote migration उसी offer-details function को विस्तारित करती है।
- customer ownership और GPS fields quote RPC dependencies हैं।
- amount_paid restore migration current branch में मौजूद है, जबकि dependent quote/commission source उसे पढ़ता है।

अभी सिद्ध नहीं:
- कौन-सा exact starter schema clean replay का approved baseline है।
- remote Production migration version/order और इन files की applied status।
- `is_srk_admin()` helper का canonical source और exact grants.
- `amount_paid` Production में किस approved path से आया या आया भी है।
- सभी referenced base columns, indexes, policies, roles, extensions, triggers और grants का पूर्ण parity।

## 4. निष्कर्ष / Gate

इस chain को अभी replay-ready घोषित नहीं किया जा सकता। विशेष blockers:
1. authoritative starter schema और migration lineage;
2. duplicate 8-digit `20261109` version identity/order reconciliation;
3. `amount_paid` prerequisite placement;
4. `is_srk_admin()` helper provenance;
5. full dependency/grant/RLS map और isolated local harness.

कोई migration rename/delete/merge/reorder/repair/replay नहीं किया गया। कोई Production query/write, DDL, deployment, customer/Auth/payment data access या secret access नहीं हुआ। GPT-1 application source untouched है।

## 5. अगला सुरक्षित कदम

Base setup और हर dependency के exact introducing source को सभी 87 migrations में reconcile करना; फिर अलग से approved replay graph draft बनाना। DBA/Database Owner से Production provenance केवल read-only authoritative logs/change ticket के माध्यम से लेना। Gates बंद होने तक `supabase db reset`, migration replay और pgTAP runtime test निषिद्ध/स्थगित रहेंगे।
