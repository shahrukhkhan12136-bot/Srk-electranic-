# GPT-2 Admin/Staff Security Audit — 2026-11-16

स्थिति: Feature Branch source review; कोई Production परिवर्तन नहीं।

## Scope
- Branch: `feat/customer-login-first-dashboard-20261114`
- Main Admin allow-list और अलग Support Staff registry
- Permission helper, exact Auth-session binding, session revocation
- Staff invitation/status lifecycle, support-case assignment, scoped inbox/reply RPCs
- SOS Admin/Support permissions और append-only event history

## Confirmed source safeguards
1. `srk_admin_users` Main Admin identity के लिए अलग है; Staff को उसमें जोड़ने का रास्ता नहीं है।
2. `srk_admin_staff` में अभी केवल `support` role स्वीकार है; नए Staff का default status `invited` है।
3. Browser roles को Staff, permission catalog, role mapping, session metadata और Staff audit tables पर direct privileges नहीं दिए गए; RLS enabled है।
4. `srk_has_admin_permission` Main Admin को अलग branch से पहचानता है। Support Staff के लिए active registry record, JWT `session_id`, matching non-revoked tracked session, live `auth.sessions` row और explicit role permission आवश्यक हैं।
5. Permission helper registry और session rows पर `FOR SHARE` locks लेता है; suspension/disable/revoke paths corresponding rows lock/update करते हैं, ताकि concurrent privileged requests और revocation serialize हों।
6. Migration `20261116100000_fix_staff_permission_helper_volatility.sql` helper को `VOLATILE` करती है। कारण: PostgreSQL में row-locking SELECT वाला function `STABLE` नहीं रह सकता।
7. Staff invite Edge Function Bearer token को `auth.getUser` से verify करती है और `is_srk_admin` से Main Admin authorization लेती है। Client-supplied role स्वीकार नहीं होता; role fixed `support` है। Registry registration RPC केवल `service_role` के लिए granted है।
8. Staff activation केवल verified email के बाद Main Admin RPC से; suspend/disable पर tracked sessions revoke होते हैं।
9. Support inboxes current assigned Staff owner तक सीमित हैं। Staff-safe inbox projections customer phone/electrician private identity fields नहीं लौटाते। Reply/status mutations explicit permission और current assignment जाँचते हैं।
10. Support assignment/reassignment Main Admin-only है। Closed cases को Staff दोबारा नहीं खोल सकता; audit history append-only है।
11. SOS cases/events direct browser table access से बंद हैं। Support को केवल `support.sos.read` और `support.sos.acknowledge` permissions मिलती हैं; acknowledgement में case lock, event history और Staff audit event शामिल हैं। SMS/Push status अभी `not_configured` है।

## Review notes / residual risks
- Edge invite flow Auth invitation भेजने के बाद Staff registry insert करता है। यदि registry insert विफल हो, code Auth identity हटाने की कोशिश करता है; भेजा हुआ invitation email वापस नहीं लिया जा सकता। Error response इस स्थिति को बताता है। यह known partial-side-effect boundary है, न कि invitation delivery की guarantee।
- CORS में `Access-Control-Allow-Origin: *` है; authorization Bearer token और server-side Main Admin check पर निर्भर है। इसे अकेले authorization control नहीं माना गया।
- SOS Support permission actor का नाम/फोन और reason queue में लौटाती है। यह SOS के लिए न्यूनतम संपर्क संदर्भ के घोषित उद्देश्य से जुड़ा है; Support access assignment/need-to-know सीमाओं के साथ review होना चाहिए।
- इस pass में सभी 30 पुराने Main Admin-only RPCs की permission-by-permission exhaustive inventory/runtime negative tests दोबारा execute नहीं किए गए। Existing design rule के अनुसार पुराने broad Admin RPCs Staff के लिए स्वतः नहीं खोले जाने चाहिए।
- Node/source inspection से database behavior सिद्ध नहीं होता। pgTAP, isolated PostgreSQL migration replay और JWT role/session runtime cases अभी अलग से चलाने होंगे।

## Validation status
- Reviewed source: RBAC foundation migration, volatility-fix migration, RBAC pgTAP contract, Staff management Edge Function, RBAC design document, SOS migration and SOS pgTAP contract.
- Source-level review: safeguards above confirmed in code.
- PostgreSQL/pgTAP runtime: NOT RUN in this audit.
- Full migration replay / Production schema parity: NOT VERIFIED.
- CI for this audit document commit: check separately; no CI pass is claimed here.

## Safety boundary
No Production database query/export/migration, no Staff invitation/account mutation, no payment/refund/payout action, no merge/deployment, and no GPT-1 Customer/Electrician source change was performed.
