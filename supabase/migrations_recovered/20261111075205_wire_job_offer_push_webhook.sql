create or replace function private.srk_notify_job_offer_push()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $function$
declare
  v_secret text;
  v_payload jsonb;
begin
  select decrypted_secret into v_secret
  from vault.decrypted_secrets
  where name = 'PUSH_WEBHOOK_SECRET'
  limit 1;

  if v_secret is null or length(v_secret) < 24 then
    raise warning 'SRK push webhook secret is missing or too short; notification request was not queued';
    return coalesce(new, old);
  end if;

  v_payload := jsonb_build_object(
    'type', tg_op,
    'table', tg_table_name,
    'schema', tg_table_schema,
    'record', case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end,
    'old_record', case when tg_op = 'UPDATE' or tg_op = 'DELETE' then to_jsonb(old) else null end
  );

  perform net.http_post(
    url := 'https://gnqhoaqatmoiwwhgzkgm.supabase.co/functions/v1/push-job-offer',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-srk-push-secret', v_secret
    ),
    body := v_payload,
    timeout_milliseconds := 5000
  );

  return coalesce(new, old);
end;
$function$;

revoke all on function private.srk_notify_job_offer_push() from public, anon, authenticated;

drop trigger if exists trg_srk_push_job_offer on public.job_offers;
create trigger trg_srk_push_job_offer
after insert or update on public.job_offers
for each row execute function private.srk_notify_job_offer_push();