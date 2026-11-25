
insert into public.srk_ai_language_test_cases(language_code,language_name,test_prompt,expected_behavior)
values
 ('bho','Bhojpuri','Explain how to book an electrician in Bhojpuri.','Respond in Bhojpuri where reliable; ask clarification or gracefully fall back if uncertain.'),
 ('awa','Awadhi','Explain how to book a plumber in Awadhi.','Respond in Awadhi where reliable; ask clarification or gracefully fall back if uncertain.'),
 ('mag','Magahi','Explain how to check booking status in Magahi.','Respond in Magahi where reliable; ask clarification or gracefully fall back if uncertain.'),
 ('hne','Chhattisgarhi','Explain how to pause a work timer in Chhattisgarhi.','Respond in Chhattisgarhi where reliable; ask clarification or gracefully fall back if uncertain.'),
 ('raj','Rajasthani','Explain how to request a technician in Rajasthani.','Respond in the requested Rajasthani variety where reliable; clarify dialect if needed.'),
 ('bgc','Haryanvi','Explain how to view a final bill in Haryanvi.','Respond in Haryanvi where reliable; ask clarification or gracefully fall back if uncertain.'),
 ('tcy','Tulu','Explain how to raise a payment dispute in Tulu.','Respond in Tulu where reliable; ask clarification or gracefully fall back if uncertain.'),
 ('kha','Khasi','Explain how to reschedule a booking in Khasi.','Respond in Khasi where reliable; ask clarification or gracefully fall back if uncertain.'),
 ('grt','Garo','Explain how to contact support in Garo.','Respond in Garo where reliable; ask clarification or gracefully fall back if uncertain.'),
 ('lus','Mizo','Explain how to request a payout in Mizo.','Respond in Mizo where reliable; ask clarification or gracefully fall back if uncertain.'),
 ('en','English','Explain how to create a service booking.','Respond in English.'),
 ('hi-Latn','Hinglish','Explain how to create a service booking using Hinglish.','Understand Roman Hindi/Hinglish and respond naturally; clarify ambiguity.'),
 ('mixed','Mixed-language/code-switching','User mixes Hindi and English while asking about a booking.','Preserve the user language mix where appropriate and clarify unclear terms.')
on conflict do nothing;
