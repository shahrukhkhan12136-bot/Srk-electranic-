# SRK ELECTRONIC — Accounting Reconciliation Design

स्थिति: Design proposal / source audit. यह दस्तावेज़ किसी live accounting posting, provider transfer या payout को authorize नहीं करता।

## 1. अभी के authoritative records

| क्षेत्र | वर्तमान authoritative record | सीमा |
|---|---|---|
| ग्राहक भुगतान | `service_bookings` का verified payment और refund record | Booking payment truth; customer stored-value wallet नहीं |
| Company commission | Completed + paid booking पर `commission_amount` / Admin commission report | Report accrual/expected commission दिखाती है; अपने-आप cash receipt साबित नहीं करती |
| Electrician payable | `srk_electrician_payouts` | देयता और manual payout status; यह wallet balance नहीं |
| Electrician wallet | `srk_wallet_ledger` के posted entries | अलग internal ledger; payout/Route transfer से स्वतः reconcile नहीं |
| Route split | `srk_route_transfers` | Provider transfer status और settlement status अलग; केवल transfer row से bank settlement सिद्ध नहीं |

## 2. अनुशंसित नियम

1. **Customer balance:** Customer top-up बंद है। Booking payment को customer wallet credit न बनाएं। Refund केवल मूल payment/refund lifecycle से reconcile हो; customer wallet में duplicate refund credit न डालें।
2. **Company commission:** Commission केवल Labour पर; Materials पर नहीं। Commission report को “earned/expected” कहें, “received” तभी जब platform recipient का provider transfer processed और settled हो तथा provider reference से मिलान हो।
3. **Electrician payable:** `Labour + Materials − Labour-only Commission`। Payout row obligation है; wallet credit तभी हो जब approved business policy में wallet earning posting स्पष्ट रूप से चुनी जाए। Manual payout को wallet debit न बनाएं जब तक वही रकम पहले wallet में credit न हुई हो।
4. **Route:** प्रत्येक booking/payment/recipient पर अधिकतम एक logical transfer; amount integer paise में। `processed` और `settled` अलग-अलग states हैं। Refund के बाद transfer reversal/partial reversal को provider-confirmed evidence के बिना final न मानें।
5. **Refund:** Full refund पर customer payment/refund status, cancellation-fee reversal, electrician payout hold/refund और platform commission reversal एक ही booking reference से जुड़ें। Partial refund फिलहाल fail-closed रहे; proportional commission/payout allocation तय हुए बिना कोई अनुमानित adjustment न हो।
6. **Wallet:** Balance केवल `status='posted'` ledger entries का signed sum। हर credit/debit के लिए unique idempotency key, owner, currency INR और booking/reference अनिवार्य। Cached balance source of truth न बने।

## 3. प्रस्तावित read-only reconciliation report

हर booking के लिए एक row और ये integer-paise fields:

- verified customer collection / full refund / net collection;
- labour gross, materials gross, labour-only commission expected;
- electrician payable expected, payout obligation status, actual manual payout amount;
- Route electrician transfer expected / provider processed / settled / reversed;
- Route platform commission expected / provider processed / settled / reversed;
- wallet posted credits/debits by booking reference;
- cancellation fee collected / reversed / outstanding;
- `difference_paise` per component और overall exception code.

यह report read-only होगी। किसी mismatch को स्वतः balance करने, wallet entry डालने, transfer भेजने या payout paid करने की अनुमति नहीं होगी। पहले Admin review और source evidence चाहिए।

## 4. आवश्यक exception categories

- `MISSING_PAYOUT_ROW`, `PAYOUT_AMOUNT_MISMATCH`
- `COMMISSION_NOT_TRANSFERRED`, `COMMISSION_TRANSFER_NOT_SETTLED`
- `ELECTRICIAN_TRANSFER_MISMATCH`, `TRANSFER_DUPLICATE`
- `WALLET_ORPHAN_ENTRY`, `WALLET_DUPLICATE_REFERENCE`
- `REFUND_WITHOUT_TRANSFER_REVERSAL`, `PARTIAL_REFUND_UNSUPPORTED`
- `CANCELLATION_FEE_UNBALANCED`

## 5. Implementation से पहले आवश्यक business decision

**क्या electrician की कमाई को SRK wallet में internal earning credit करना है, या payout table + direct bank/UPI payout ही authoritative रहेगा?**

मौजूदा wallet foundation स्पष्ट रूप से कहता है कि wallet internal-only है और payouts disabled हैं। इसलिए सुरक्षित default: अभी payout table ही electrician payable का source रहेगा; wallet में कोई नई earning/payout posting नहीं। इसी तरह company commission को तब तक “expected/earned” कहा जाए, “received” नहीं, जब तक settled Route/provider proof न हो।

## 6. Verification boundary

Source और schema audit ही हुआ है। pgTAP assertions source में जोड़े गए हैं; runtime pgTAP/Node tests अभी execute नहीं हुए। कोई migration apply, live row mutation, Razorpay request, Route transfer, wallet posting, payout, deploy या mobile QA नहीं किया गया।


## 7. Read-only live catalog cross-check (2026-11-15)

Feature Branch source को Production catalog से अलग रखते हुए read-only catalog query में निम्न बातें सत्यापित हुईं:

- srk_electrician_payouts में प्रति booking unique constraint है; payout row में labour gross, materials, platform commission और electrician payable अलग numeric fields हैं। Status constraint में pending/paid/blocked/refunded हैं। Paid row के लिए method, कम-से-कम 4-character reference, paid timestamp और paid actor अनिवार्य हैं।
- Payout table पर RLS enabled है। Anonymous SELECT बंद है; authenticated SELECT केवल srk_read_authorized_electrician_payouts policy के माध्यम से सीमित है।
- srk_admin_mark_electrician_payout_paid(uuid,text,text,text) Main Admin check, booking-first row lock, verified paid booking, completed status और payout snapshot बनाम booking के labour/materials/commission/payable amount का पुनर्मिलान करता है। यह payout record को Paid तभी दर्ज करता है जब Admin वास्तविक transfer reference देता है; यह RPC स्वयं बैंक ट्रांसफर नहीं करता।
- Wallet ledger पर RLS enabled है और owner-read policy है। Route transfer ledger पर RLS enabled है तथा authenticated direct SELECT privilege नहीं है। Route amount column bigint paise है।
- Live catalog में इस जाँच के समय srk_booking_cancellation_fee_items और srk_cancellation_fee_ledger tables उपलब्ध नहीं मिलीं; ये Feature Branch की बाद की migration chain का हिस्सा हैं। इसलिए live पर cancellation-fee side को join करके कोई reconciliation view बनाना अभी schema-safe नहीं होगा।

नई static pgTAP contract file: supabase/tests/database/accounting_reconciliation_readonly_contract.test.sql — उस शुरुआती audit चरण में 20 assertions; बाद में यह 43 assertions तक बढ़ाई गई। यह payout authorization/row-lock/payment proof, owner-scoped wallet access, Route client isolation और integer-paise schema guard करती है। Test अभी runtime में execute नहीं हुआ है।

## 8. अगला सुरक्षित implementation gate

Read-only per-booking reconciliation RPC/view को Feature Branch में जोड़ने से पहले पूरे Feature Branch migration chain में cancellation-fee, refund, payout generation और Route transfer tables/columns की exact definitions और ordering को एक बार फिर मिलाना होगा। उसके बाद report को केवल Main Admin के लिए expose किया जाएगा। अभी कोई नया reconciliation RPC/view, कोई financial write या live schema change नहीं बनाया गया है।


## 9. Feature Branch migration-chain cross-check (2026-11-15)

PR #8 की वास्तविक changed-file सूची से migration ordering निकालकर इन exact definitions को पढ़ा गया: 20261114125844 financial audit core, 20261114280000 cancellation-fee carry-forward/accounting, 20261114290000 full-refund reversal, और 20261114360000 new-category electrician payout reconciliation।

इससे पुष्टि हुई:
- Cancellation debt, booking fee-item allocation और cancellation-fee ledger अलग tables हैं; ledger integer paise, unique idempotency key और append-only mutation trigger रखता है। Authenticated clients को direct table access नहीं; service_role-only grants हैं।
- New-category payable immutable labour bill से आता है। Labour gross में cancellation fee शामिल नहीं; materials शून्य हैं; commission केवल labour पर है। Customer का कुल captured payment labour + reserved/settled cancellation fee हो सकता है, पर fee electrician payable नहीं बनती।
- Payout upsert केवल pending row को refresh कर सकता है; paid/blocked/refunded payout को recalculate करके overwrite नहीं कर सकता। Admin paid RPC booking-first locks और exact payout snapshot reconciliation करता है।
- Live catalog और Feature Branch migration chain अलग हैं: ऊपर की नई fee tables live में अभी मौजूद नहीं थीं। इस कारण read-only reconciliation RPC को live schema पर लागू करना निषिद्ध रहेगा; उसे केवल पूरी reviewed migration chain वाले approved isolated test environment में validate किया जा सकता है।

Security contract pgTAP अब 30 planned assertions तक बढ़ा है; cancellation-fee private ledger, append-only guard, integer-paise amount और new-category payable separation भी शामिल हैं। Runtime execution अभी pending है।


## 10. Feature Branch implementation — read-only Admin booking report (2026-11-15)

नई migration source: `20261115130000_admin_readonly_booking_accounting_reconciliation.sql`

RPC: `public.srk_admin_get_booking_accounting_reconciliation(uuid)`

- `SECURITY DEFINER`, `STABLE`, fixed empty search_path; authenticated execution grant के बावजूद function के अंदर `auth.uid()` + `is_srk_admin()` Main Admin gate अनिवार्य है। anon/public execute revoke।
- एक booking UUID पर एक JSON report देता है। Customer verified collection/refund/net, immutable labour bill या legacy approved quote के Labour/Materials, labour-only commission, expected electrician payable, payout snapshot/status, Route transfer + provider processed + settlement amounts, cancellation-fee allocation/ledger, और केवल posted wallet entries अलग दिखाता है।
- Route payment ID और assigned electrician recipient identity भी booking से मिलाए जाते हैं। Duplicate Route rows, missing payout/transfer, transfer mismatch, provider processing/settlement gap, payout/refund closure mismatch, invalid commission rate, partial refund, verified collection mismatch, cancellation-fee ledger mismatch अलग exception codes बनते हैं।
- Cancellation fee के लिए settled allocation बनाम append-only ledger net का मिलान होता है। New-category booking में customer collection = immutable labour + settled carry-forward fees होना चाहिए; fee electrician payable/commission में नहीं जुड़ती।
- Function body में कोई INSERT/UPDATE/DELETE नहीं है। कोई wallet posting, transfer, refund, payout status change या auto-repair नहीं।
- `admin.html` में Main Admin के लिए Booking UUID आधारित panel जोड़ा गया; रिपोर्ट और exception list पढ़ सकता है। यह केवल UI source integration है, runtime browser test नहीं।

pgTAP contract अब 43 planned assertions है। Static count/plan verification: 43/43। pgTAP runtime अभी execute नहीं हुआ। Production catalog में नई cancellation-fee tables अनुपस्थित हैं, इसलिए यह migration live पर apply नहीं की गई; report source Feature Branch में ही है।


## 11. Refund / Wallet / Payout evidence cross-check (2026-11-15)

अगली गहरी source समीक्षा में रिपोर्ट के तीन blind spots ठीक किए:
- Cash/manual payment को verified मानने से पहले matching `srk_manual_payment_entries` row और exact captured amount आवश्यक है; Razorpay payment ID मौजूद हो तो वह provider payment evidence के रूप में उपयोग होता है। Missing/mismatched evidence exception बनता है।
- Refund record का Razorpay payment ID मूल booking payment से match होना चाहिए; manual refund row का payment_entry_id उसी booking की matching amount वाली manual payment entry से match होना चाहिए।
- Cash cancellation-fee wallet refund credit का reference debt_id होता है, जबकि original electrician debit fee_item_id से जुड़ा होता है। Report अब दोनों references पढ़ती है, जिससे reversal credit छूटता नहीं।
- Payout record में electrician_profile_id वर्तमान assigned electrician से match होना चाहिए और booking completed होनी चाहिए; अन्यथा exception।

इस समीक्षा के बाद pgTAP contract **47 assertions** पर है। Plan/count static check अगली verification pass में दोबारा चलाया जाएगा। Runtime pgTAP अभी भी execute नहीं हुआ।
