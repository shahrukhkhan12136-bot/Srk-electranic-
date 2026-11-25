
create or replace function public.srk_prevent_append_only_history_mutation()
returns trigger
language plpgsql
set search_path to 'pg_catalog','public'
as $function$
begin
 raise exception 'Historical audit records are append-only and cannot be updated or deleted';
end
$function$;
revoke all on function public.srk_prevent_append_only_history_mutation() from public,anon,authenticated;

do $migration$
declare t text;
begin
 foreach t in array array[
  'srk_system_setting_history',
  'srk_user_custom_setting_history',
  'srk_booking_skill_level_events',
  'srk_booking_cancellation_events',
  'srk_emergency_decision_events',
  'srk_admin_timer_override_events'
 ] loop
   if to_regclass('public.'||t) is not null then
     execute format('drop trigger if exists %I on public.%I',t||'_append_only',t);
     execute format('create trigger %I before update or delete on public.%I for each row execute function public.srk_prevent_append_only_history_mutation()',t||'_append_only',t);
   end if;
 end loop;
end
$migration$;
