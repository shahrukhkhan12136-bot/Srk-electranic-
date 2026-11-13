-- Admin reply integration and complaint-message attachment metadata.
-- Source-only; apply only after reviewed migration/test execution.

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
  if p_complaint_id is null or p_body is null
     or length(btrim(p_body)) < 1 or length(btrim(p_body)) > 4000 then
    raise exception 'INVALID_MESSAGE' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.srk_booking_complaints c
    where c.id = p_complaint_id and c.status <> 'closed'
  ) then
    raise exception 'COMPLAINT_NOT_AVAILABLE' using errcode = '22023';
  end if;

  insert into public.srk_booking_complaint_messages
    (complaint_id, sender_user_id, sender_role, body)
  values (p_complaint_id, v_admin_id, 'admin', btrim(p_body))
  returning id into v_message_id;
  return v_message_id;
end;
$function$;

create table if not exists public.srk_booking_complaint_message_attachments (
  id uuid primary key default gen_random_uuid(),
  complaint_id uuid not null references public.srk_booking_complaints(id) on delete cascade,
  message_id uuid not null references public.srk_booking_complaint_messages(id) on delete cascade,
  uploader_user_id uuid not null references auth.users(id),
  storage_path text not null unique,
  file_name text not null check (length(file_name) between 1 and 180),
  mime_type text not null check (mime_type in ('image/jpeg','image/png','image/webp','application/pdf')),
  file_size_bytes bigint not null check (file_size_bytes between 1 and 10485760),
  created_at timestamptz not null default now()
);

create index if not exists srk_complaint_message_attachments_message_idx
  on public.srk_booking_complaint_message_attachments(message_id, created_at);

alter table public.srk_booking_complaint_message_attachments enable row level security;
revoke all on public.srk_booking_complaint_message_attachments from anon, authenticated;

create or replace function public.srk_customer_link_complaint_message_attachment(
  p_complaint_id uuid,
  p_message_id uuid,
  p_storage_path text,
  p_file_name text,
  p_mime_type text,
  p_file_size_bytes bigint
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_attachment_id uuid;
  v_expected_prefix text;
begin
  if v_user_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '28000';
  end if;
  if p_complaint_id is null or p_message_id is null
     or p_storage_path is null or p_file_name is null
     or length(p_file_name) not between 1 and 180
     or p_mime_type not in ('image/jpeg','image/png','image/webp','application/pdf')
     or p_file_size_bytes not between 1 and 10485760 then
    raise exception 'INVALID_ATTACHMENT_METADATA' using errcode = '22023';
  end if;

  v_expected_prefix := v_user_id::text || '/' || p_complaint_id::text || '/';
  if left(p_storage_path, length(v_expected_prefix)) <> v_expected_prefix then
    raise exception 'INVALID_ATTACHMENT_PATH' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.srk_booking_complaints c
    where c.id=p_complaint_id and c.customer_user_id=v_user_id and c.status <> 'closed'
  ) or not exists (
    select 1 from public.srk_booking_complaint_messages m
    where m.id=p_message_id and m.complaint_id=p_complaint_id
      and m.sender_user_id=v_user_id and m.sender_role='customer'
  ) or not exists (
    select 1 from storage.objects o
    where o.bucket_id='srk-customer-support' and o.name=p_storage_path
  ) then
    raise exception 'ATTACHMENT_NOT_AVAILABLE' using errcode = '42501';
  end if;

  insert into public.srk_booking_complaint_message_attachments
    (complaint_id,message_id,uploader_user_id,storage_path,file_name,mime_type,file_size_bytes)
  values
    (p_complaint_id,p_message_id,v_user_id,p_storage_path,p_file_name,p_mime_type,p_file_size_bytes)
  returning id into v_attachment_id;
  return v_attachment_id;
end;
$function$;

create or replace function public.srk_customer_list_complaint_message_attachments(
  p_complaint_id uuid
)
returns table (
  id uuid,
  message_id uuid,
  file_name text,
  mime_type text,
  file_size_bytes bigint,
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
    select a.id,a.message_id,a.file_name,a.mime_type,a.file_size_bytes,a.created_at
    from public.srk_booking_complaint_message_attachments a
    where a.complaint_id=p_complaint_id
    order by a.created_at asc,a.id asc
    limit 100;
end;
$function$;

create or replace function public.srk_admin_list_complaint_message_attachments(
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
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_PERMISSION_REQUIRED' using errcode = '42501';
  end if;
  if not exists (select 1 from public.srk_booking_complaints c where c.id=p_complaint_id) then
    raise exception 'COMPLAINT_NOT_FOUND' using errcode = '22023';
  end if;
  return query
    select a.id,a.message_id,a.file_name,a.mime_type,a.file_size_bytes,a.storage_path,a.created_at
    from public.srk_booking_complaint_message_attachments a
    where a.complaint_id=p_complaint_id
    order by a.created_at asc,a.id asc
    limit 100;
end;
$function$;

revoke all on function public.srk_admin_send_booking_complaint_message(uuid,text) from public, anon;
grant execute on function public.srk_admin_send_booking_complaint_message(uuid,text) to authenticated;
revoke all on function public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint) from public, anon;
grant execute on function public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint) to authenticated;
revoke all on function public.srk_customer_list_complaint_message_attachments(uuid) from public, anon;
grant execute on function public.srk_customer_list_complaint_message_attachments(uuid) to authenticated;
revoke all on function public.srk_admin_list_complaint_message_attachments(uuid) from public, anon;
grant execute on function public.srk_admin_list_complaint_message_attachments(uuid) to authenticated;

-- Admin access to private attachment objects remains gated by the existing admin predicate.
create policy "admin reads customer support attachments"
on storage.objects for select to authenticated
using (bucket_id='srk-customer-support' and public.is_srk_admin());
