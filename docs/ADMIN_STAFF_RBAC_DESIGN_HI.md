# SRK ELECTRONIC — Admin Staff RBAC Design (Hindi)

स्थिति: प्रस्तावित implementation contract — source/design only। इसे अभी Supabase पर लागू नहीं किया गया है।

## 1. सुरक्षा का मूल नियम

- `srk_admin_users` मौजूदा Main Admin allowlist है। इसमें Staff को कभी insert नहीं करना है।
- `is_srk_admin()` को Main Admin-only authority check ही रहने देना है।
- Staff की पहचान अलग registry में Auth user UUID से होगी। Email/password या UI role label अपने-आप अधिकार नहीं देंगे।
- हर संवेदनशील RPC में server-side permission check अनिवार्य होगा। Frontend में button छिपाना सुरक्षा नियंत्रण नहीं है।
- Default deny: नया Staff बिना स्पष्ट permission के कोई Admin action नहीं कर सकेगा।
- Staff को स्वयं role/permission बदलने, नया Staff बनाने, Main Admin बदलने, audit log edit/delete करने या अपने निष्क्रिय access को बहाल करने की अनुमति नहीं होगी।

## 2. प्रारंभिक भूमिकाएँ

| भूमिका | दायरा | सीमा |
|---|---|---|
| Main Admin | सभी Admin Portal और Staff Management कार्य | केवल मौजूदा Main Admin allowlist |
| Support Staff | ग्राहक/इलेक्ट्रिशियन सहायता टिकट देखना, जवाब देना, स्थिति अपडेट करना | भुगतान, Refund, Payout, KYC, अकाउंट एक्टिवेशन, कैंसिलेशन फीस मंजूरी और Staff Management नहीं |
| Operations Staff (भविष्य) | बुकिंग संचालन/offer queue और गैर-वित्तीय संचालन | अलग explicit approval और permission matrix के बाद |
| Finance Staff (भविष्य) | सीमित finance read/reconciliation tasks | वास्तविक भुगतान, refund, payout release केवल Main Admin; अलग approval के बिना role enable नहीं |

पहले चरण में केवल Support Staff role implement किया जाएगा। Operations और Finance roles को schema में स्वतः सक्रिय नहीं किया जाएगा।

## 3. Permission catalog — प्रथम चरण

| Permission key | Support Staff | Main Admin |
|---|---:|---:|
| `support.customer.read` | हाँ | हाँ |
| `support.customer.reply` | हाँ | हाँ |
| `support.customer.update_status` | हाँ | हाँ |
| `support.electrician.read` | हाँ | हाँ |
| `support.electrician.reply` | हाँ | हाँ |
| `support.electrician.update_status` | हाँ | हाँ |
| `booking.read_basic` | केवल सहायता टिकट से जुड़ी न्यूनतम जानकारी | हाँ |
| `booking.read_private_contacts` | नहीं | हाँ |
| `finance.*` | नहीं | हाँ |
| `refund.*` | नहीं | हाँ |
| `payout.*` | नहीं | हाँ |
| `kyc.*` | नहीं | हाँ |
| `booking.cancel_decide` | नहीं | हाँ |
| `staff.manage` | नहीं | हाँ |
| `audit.read` | नहीं | हाँ |
| `audit.manage` | कभी नहीं | append-only/system controlled |

Support Staff को ग्राहक/electrician के निजी फोन, पूर्ण पता, बैंक/UPI विवरण, payment identifiers या KYC दस्तावेज़ों का व्यापक access नहीं दिया जाएगा। टिकट की सहायता के लिए आवश्यक सीमित जानकारी ही अलग RPC से लौटेगी।

## 4. प्रस्तावित Backend संरचना

- `srk_admin_staff`: Auth user UUID, display name, role key, active/disabled status, invited/created by, created/updated timestamps।
- `srk_admin_permissions`: स्थिर permission catalog।
- `srk_admin_role_permissions`: role और permission mapping; client write निषिद्ध।
- `srk_admin_staff_sessions` या समकक्ष server-controlled session metadata: session identifiers/last-seen/revocation metadata; raw access/refresh tokens कभी store नहीं होंगे।
- `srk_admin_staff_audit_events`: actor UUID, actor role, action key, target type/ID, reason, safe before/after diff, timestamp, request correlation ID। Append-only; client UPDATE/DELETE निषिद्ध।

Tables पर RLS enable होगा और authenticated client को direct write grant नहीं मिलेगा। Main Admin-only RPCs ही Staff lifecycle और permission mapping बदल सकेंगे।

## 5. RPC और Auth सुरक्षा

- `srk_has_admin_permission(permission_key)` केवल active Staff registry + role mapping से अनुमति देगा; Main Admin को अलग explicit branch से full access मिलेगा।
- `is_srk_admin()` को Staff membership से true नहीं करना है।
- प्रत्येक मौजूदा Admin RPC की inventory (वर्तमान read-only catalog में 30 functions सीधे `is_srk_admin()` जाँचते हैं) को permission matrix में classify करना होगा।
- Finance/refund/payout/KYC/activation/cancellation/Staff-management/emergency RPCs Main Admin-only रहेंगे।
- Support Staff के लिए अलग सीमित RPCs बनाए जाएँगे; पुराने broad Admin RPCs को Staff के लिए खुला नहीं किया जाएगा।
- Staff account create/invite/disable Auth Admin API या सुरक्षित server-side Edge Function से होगा। Service-role secret कभी browser में नहीं जाएगा।
- Disable action के बाद सभी sessions revoke/invalid किए जाएँगे; केवल UI logout पर निर्भर नहीं रहना है।
- Staff access token की मौजूदा validity अवधि के दौरान भी privileged RPCs हर बार active status जाँचेंगे।

## 6. Audit और privacy

- हर Staff reply/status change/assignment/login/failed privileged attempt/disable/session revoke का audit event।
- Reason जहाँ आवश्यक हो, server-side validate और store होगा।
- Password, OTP, access/refresh token, full bank details, full phone numbers और sensitive document contents audit JSON में नहीं लिखे जाएँगे।
- IP/device metadata केवल security आवश्यकता के अनुपात में, सीमित access और घोषित retention policy के साथ; fingerprinting नहीं।
- Audit read Main Admin-only; Staff अपने audit record बदल/मिटा नहीं सकते।

## 7. कार्यान्वयन क्रम और acceptance gates

1. Migration source: tables, enums/check constraints, indexes, RLS, no client writes, Main Admin-only management RPCs।
2. pgTAP: anonymous/authenticated denial, inactive staff denial, unknown permission denial, role escalation denial, self-promotion denial, audit immutability।
3. Auth invite/disable Edge Function: JWT validation, Main Admin authorization, idempotency, no secret exposure, session invalidation।
4. Support-only RPCs: row scoping, minimal fields, assignment boundaries, safe reply/status actions।
5. Admin UI: Staff list, invite, role, active/disabled state, permission summary, activity history; no public fourth login option।
6. Existing 30 Admin RPCs and relevant RLS policies: per-function decision; no blanket replacement of `is_srk_admin()` with a weaker helper.
7. Consolidated end-to-end tests at the project's final QA stage.

## 8. निषिद्ध कार्य

- अभी live migration apply नहीं करनी।
- अभी कोई Staff Auth user invite/create नहीं करना।
- अभी Main Admin allowlist या production Auth settings नहीं बदलनी।
- Staging/Development Branch या paid subscription अभी नहीं बनानी।
- कोई वास्तविक booking/payment/refund/payout operation नहीं करना।
