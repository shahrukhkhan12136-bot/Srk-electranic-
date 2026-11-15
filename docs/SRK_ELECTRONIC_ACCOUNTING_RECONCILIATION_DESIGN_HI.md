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
