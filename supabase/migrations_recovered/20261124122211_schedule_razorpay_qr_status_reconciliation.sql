select cron.schedule(
  'srk-razorpay-qr-reconcile-every-five-minutes',
  '*/5 * * * *',
  $job$
    select net.http_post(
      url := 'https://gnqhoaqatmoiwwhgzkgm.supabase.co/functions/v1/razorpay-qr-reconcile',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-srk-qr-reconcile-secret',
        (select decrypted_secret from vault.decrypted_secrets where name = 'SRK_QR_RECONCILE_SECRET' limit 1)
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 20000
    );
  $job$
);