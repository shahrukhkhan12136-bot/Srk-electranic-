-- Admin replies in the existing private customer complaint thread.
-- Source-only: do not apply until the complete migration set is reviewed and approved.

create or replace function public.srk_admin_send_booking_complaint_message(
  p_complaint_id uuid,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_admin_id uuid := auth.uid();
  v_message_id uuid;
begin
  if v_admin_id is null or not public.is_srk_admin() then
    raise exception 'ADMIN_PERMISSION_REQUIRED' using errcode = '42501';
  end if;

  if p_complaint_id is null
     or p_body is null
     or length(btrim(p_body)) not between 1 and 4000 then
    raise exception 'MESSAGE_MUST_BE_1_TO_4000_CHARACTERS'
      using errcode = '22023';
  end if;

  perform 1
    from public.srk_booking_complaints c
   where c.id = p_complaint_id
   for update;

  if not found then
    raise exception 'COMPLAINT_NOT_FOUND' using errcode = '22023';
  end if;

  insert into public.srk_booking_complaint_messages
    (complaint_id, sender_role, sender_user_id, body)
  values
    (p_complaint_id, 'admin', v_admin_id, btrim(p_body))
  returning id into v_message_id;

  return v_message_id;
end;
$function$;

revoke all on function public.srk_admin_send_booking_complaint_message(uuid,text)
  from public, anon;
grant execute on function public.srk_admin_send_booking_complaint_message(uuid,text)
  to authenticated;
