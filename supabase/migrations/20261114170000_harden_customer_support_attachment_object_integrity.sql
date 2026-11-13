-- Verify attachment metadata against the actual private Storage object and
-- prevent customers from deleting files already linked into support history.
-- Source-only; test on an isolated schema before any deployment.

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
  v_object_mime text;
  v_object_size bigint;
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
  if left(p_storage_path, length(v_expected_prefix)) <> v_expected_prefix
     or p_storage_path !~ ('^' || v_user_id::text || '/' || p_complaint_id::text ||
       '/[0-9a-fA-F-]{36}\.(jpg|png|webp|pdf)$') then
    raise exception 'INVALID_ATTACHMENT_PATH' using errcode = '42501';
  end if;

  select o.metadata->>'mimetype',
         case when coalesce(o.metadata->>'size','') ~ '^[0-9]+$'
              then (o.metadata->>'size')::bigint else null end
    into v_object_mime, v_object_size
    from storage.objects o
   where o.bucket_id='srk-customer-support'
     and o.name=p_storage_path;

  if not found
     or v_object_mime is distinct from p_mime_type
     or v_object_size is distinct from p_file_size_bytes then
    raise exception 'ATTACHMENT_OBJECT_METADATA_MISMATCH' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.srk_booking_complaints c
    where c.id=p_complaint_id and c.customer_user_id=v_user_id and c.status <> 'closed'
  ) or not exists (
    select 1 from public.srk_booking_complaint_messages m
    where m.id=p_message_id and m.complaint_id=p_complaint_id
      and m.sender_user_id=v_user_id and m.sender_role='customer'
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

drop policy if exists "customer deletes support attachments for own complaint" on storage.objects;
create policy "customer deletes only unlinked support attachments"
on storage.objects for delete to authenticated
using (
  bucket_id='srk-customer-support'
  and (storage.foldername(name))[1]=(select auth.uid())::text
  and exists (
    select 1 from public.srk_booking_complaints c
    where c.id::text=(storage.foldername(name))[2]
      and c.customer_user_id=(select auth.uid())
  )
  and not exists (
    select 1 from public.srk_booking_complaint_message_attachments a
    where a.storage_path=storage.objects.name
  )
);
