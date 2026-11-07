# SRK ELECTRONIC – All India Marketplace: नया चरण

## इस अपडेट में क्या जोड़ा गया
- ग्राहक बुकिंग अब `/api/create-booking` server function को भेजी जाती है।
- बुकिंग Supabase `service_bookings` में सेव होती है।
- उसी PIN Code के सभी approved + active इलेक्ट्रिशियन को `job_offers` में offer बनाया जाता है।
- PIN Code में कोई provider न मिले तो उसी राज्य और जिले के सभी approved + active providers को offer queue किया जाता है।
- इलेक्ट्रिशियन आवेदन `/api/apply-electrician` से Supabase में सेव होता है।
- Razorpay checkout का मौजूदा flow रखा गया है।

## अभी क्या वास्तविक रूप से नहीं जुड़ा है
- यह offer queue है; अभी SMS, WhatsApp या मोबाइल push notification अपने-आप नहीं जाता। उसके लिए messaging provider की API credentials और electrician dashboard/app में offer inbox व Accept/Decline flow जोड़ना होगा।
- Admin dashboard/login अभी नहीं है; approval और profile activation फिलहाल सुरक्षित admin प्रक्रिया/SQL से करनी होगी।
- अभी PIN Code और जिला/राज्य matching है, GPS दूरी आधारित nearby matching नहीं।
- ZIP deploy किए बिना live website नहीं बदलेगी। Supabase schema और Netlify secrets पहले configure करने होंगे।

## जरूरी सेटअप
1. Supabase में `SUPABASE_SCHEMA.sql` पूरा चलाएँ।
2. Netlify environment variables: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` जोड़ें। Service-role key निजी रखें। Razorpay की keys भी Netlify में ही रहें।
3. ZIP deploy करें और पहले एक पायलट जिले में टेस्ट करें।
4. इलेक्ट्रिशियन आवेदन जाँचने के बाद profile बनाएँ; केवल सत्यापित व्यक्ति को `verification_status='approved'` और `active=true` करें।
5. आगे Admin dashboard, electrician login, offer inbox, Accept/Decline, expiry/reassignment और SMS/WhatsApp/push notification जोड़ना बाकी है।

**कमीशन:** 15% केवल प्रस्तावित मॉडल है। ग्राहक को कुल कीमत/फीस पहले बतानी होगी। इलेक्ट्रिशियन payout/marketplace settlement अलग से compliant payment integration के बाद ही संभव होगा।
