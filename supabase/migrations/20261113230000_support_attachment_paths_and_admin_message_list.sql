-- Complete private attachment navigation and Admin message thread reads.
-- Source-only; do not apply until the full migration set has been reviewed and approved.

create or replace function public.srk_customer_list_complaint_message_attachments(
  p_complaint_id uuid
)
returns table (
  id uuid,
  message_id uuid,
  file_name text,
  mime_type text,
  file_size_bytes bigint,
  storage_path text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '28000';
  end if;
  if not exists (
    select 1 from public.srk_booking_complaints c
    where c.id=p_complaint_id and c.customer_user_id=v_user_id
  ) then
    raise exception 'COMPLAINT_NOT_AVAILABLE' using errcode = '42501';
  end if;
  return query
    select a.id,a.message_id,a.file_name,a.mime_type,a.file_size_bytes,a.storage_path,a.created_at
    from public.srk_booking_complaint_message_attachments a
    where a.complaint_id=p_complaint_id
    order by a.created_at asc,a.id asc
    limit 100;
end;
$function$;

create or replace function public.srk_admin_list_booking_complaint_messages(
  p_complaint_id uuid
)
returns table (
  id uuid,
  sender_role text,
  body text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_PERMISSION_REQUIRED' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.srk_booking_complaints c where c.id=p_complaint_id
  ) then
    raise exception 'COMPLAINT_NOT_FOUND' using errcode = '22023';
  end if;
  return query
    select m.id,m.sender_role,m.body,m.created_at
    from public.srk_booking_complaint_messages m
    where m.complaint_id=p_complaint_id
    order by m.created_at asc,m.id asc
    limit 200;
end;
$function$;

revoke all on function public.srk_customer_list_complaint_message_attachments(uuid) from public, anon;
grant execute on function public.srk_customer_list_complaint_message_attachments(uuid) to authenticated;
revoke all on function public.srk_admin_list_booking_complaint_messages(uuid) from public, anon;
grant execute on function public.srk_admin_list_booking_complaint_messages(uuid) to authenticated;
