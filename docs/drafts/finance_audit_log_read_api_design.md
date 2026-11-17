# Finance Audit Log — सुरक्षित Read API Design (Draft)

स्थिति: DESIGN ONLY — लागू नहीं किया गया; SQL executable migration नहीं है।

## उद्देश्य

`public.srk_admin_audit_events` के लिए Main Admin-only, read-only API देना। मौजूदा table पर `PUBLIC`, `anon`, `authenticated` की direct privileges revoked रहें; authenticated clients को table SELECT न दें।

## प्रस्तावित RPC

नाम: `public.srk_admin_list_financial_audit_events`

प्रस्तावित इनपुट:
- `p_limit integer DEFAULT 50` — server-side clamp 1..100.
- `p_before_created_at timestamptz DEFAULT NULL`
- `p_before_id uuid DEFAULT NULL` — deterministic keyset pagination के लिए timestamp के साथ।
- `p_entity_type text DEFAULT NULL` — allow-listed entity types only.
- `p_booking_id uuid DEFAULT NULL`
- `p_actor_user_id uuid DEFAULT NULL`
- `p_action text DEFAULT NULL` — created/updated/deleted only.

प्रस्तावित आउटपुट:
- `id, entity_type, entity_id, booking_id, action, actor_user_id, actor_role, changed_fields, before_data, after_data, created_at`.
- Output में sensitive values को raw रूप में expose न करें। पहले से allow-listed audit fields भी API boundary पर redact/omit हों, जब तक Finance/Admin owner लिखित रूप से उनकी जरूरत और retention स्वीकार न करे।

## Authorization और hardening

1. RPC `SECURITY DEFINER`, `SET search_path = ''`; सभी objects schema-qualified हों।
2. सबसे पहले `auth.uid() IS NOT NULL AND public.is_srk_admin()` अनिवार्य; अन्यथा SQLSTATE 42501 / `MAIN_ADMIN_ONLY`.
3. Support Staff permissions या generic `authenticated` role को इस RPC से स्वतः access न मिले।
4. `PUBLIC` और `anon` से EXECUTE revoke; जरूरत के अनुसार केवल `authenticated` को EXECUTE grant, जबकि function के अंदर Main Admin gate बना रहे।
5. Table SELECT grant न जोड़ें; केवल function owner की SECURITY DEFINER privilege से पढ़ें।
6. Limit clamp 1..100; user-supplied SQL fragments/order clauses स्वीकार न करें।
7. Stable order `created_at DESC, id DESC`; keyset cursor दोनों columns से।
8. Search/filter optional और parameterized; कोई arbitrary JSON path या arbitrary column filter नहीं।
9. Actor UUID दिखाने से पहले role/sensitivity review; raw `before_data/after_data` को बिना redaction return न करें।
10. Audit read itself को उसी financial audit table में event बनाकर न लिखें; यदि access monitoring चाहिए तो अलग minimal access log design करें, ताकि recursive audit न बने।

## न्यूनतम regression test matrix

- unauthenticated/anon caller: denied.
- authenticated customer: denied.
- authenticated electrician: denied.
- Support Staff, भले support permissions हों: denied.
- Main Admin: allowed.
- Direct authenticated SELECT on audit table: denied.
- EXECUTE privileges: anon/public revoked; authenticated call function तक पहुँच सके, पर role gate bypass न हो।
- p_limit NULL, 0, 1, 100, 101: output cap 1..100 लागू।
- entity/action invalid filters: clean validation error; arbitrary SQL input निष्प्रभावी।
- pagination ties: same created_at वाले records id के आधार पर duplicate/skip के बिना।
- redaction: payment/refund references, free-text notes/errors, idempotency keys और provider payload secrets expose न हों।
- empty result और NULL optional filters सही काम करें।
- actor attribution: returned actor UUID/role वही हो जो stored row में है; RPC caller को actor field बदलने की क्षमता न हो।

## लागू करने से पहले निर्णय

- कौन से entity types/fields Admin UI में दिखेंगे?
- क्या Admin को raw before/after JSON चाहिए या केवल changed_fields + redacted summary?
- कितने दिनों का default lookback और retention policy?
- क्या read-access अलग security log में record होगा?
- Main Admin पहचान `is_srk_admin()` से ही रहेगी या permission key की जरूरत है?

## स्पष्ट निषेध

यह draft कोई migration नहीं है। कोई function/table/policy/grant बनाया या बदला नहीं गया। SQL, pgTAP, CI, database या production पर कुछ execute नहीं किया गया।
