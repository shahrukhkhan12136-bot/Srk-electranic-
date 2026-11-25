
insert into public.srk_system_settings(setting_key,setting_value,admin_note)
values
 ('razorpay_processing_fee_rate_percent','2'::jsonb,
  'Owner-confirmed provider fee assumption: 2 percent. Track actual fee from Razorpay settlement records; do not treat this as Company Commission or automatically deduct it from Customer/Worker amounts.'),
 ('razorpay_processing_fee_gst_applicable','true'::jsonb,
  'GST applies to Razorpay processing fee. Do not hard-code GST percentage; record actual tax from Razorpay invoice/settlement records.')
on conflict (setting_key) do update
set setting_value=excluded.setting_value,
    admin_note=excluded.admin_note,
    updated_at=now();
