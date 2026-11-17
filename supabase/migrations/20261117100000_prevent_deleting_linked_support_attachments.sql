-- Prevent generic Customer Storage deletes from breaking linked support attachments.
-- Unlinked pending uploads remain deletable by their owning Customer.
-- A coordinated linked-attachment deletion workflow is intentionally not added here.

create or replace function public.srk_customer_support_object_delete_access(
  p_object_name text
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_owner_id text;
begin
  if v_user_id is null or p_object_name is null then
    return false;
  end if;

  -- Preserve the existing Customer-only path and complaint ownership boundary.
  -- Main Admin is intentionally not granted generic deletion by this helper.
  if not public.srk_customer_support_object_access(p_object_name,false) then
    return false;
  end if;

  -- Serialize deletion with the attachment-link RPC. Whichever operation locks
  -- the object first decides whether it can be linked or deleted.
  select o.owner_id
    into v_owner_id
    from storage.objects o
   where o.bucket_id='srk-customer-support'
     and o.name=p_object_name
   for update;

  if not found or v_owner_id is distinct from v_user_id::text then
    return false;
  end if;

  -- Once metadata references this object, generic Storage deletion is denied.
  return not exists (
    select 1
      from public.srk_booking_complaint_message_attachments a
     where a.storage_path=p_object_name
  );
end;
$function$;

revoke all on function public.srk_customer_support_object_delete_access(text) from public, anon;
grant execute on function public.srk_customer_support_object_delete_access(text) to authenticated;

drop policy if exists srk_customer_support_delete_own on storage.objects;
-- Remove the earlier unlinked-only policy too: permissive Storage policies OR together,
-- and that policy does not take the row lock required for link/delete serialization.
drop policy if exists srk_customer_support_delete_unlinked_own on storage.objects;
create policy srk_customer_support_delete_own on storage.objects
for delete to authenticated
using (
  bucket_id='srk-customer-support'
  and public.srk_customer_support_object_delete_access(name)
);

-- Lock the uploaded object before linking metadata. This closes the race where
-- a concurrent Storage delete could otherwise pass its unlinked check while
-- this RPC is attaching the same object to a support message.
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
begin
  if v_user_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '28000';
  end if;
  if p_complaint_id is null or p_message_id is null
     or p_storage_path is null
     or p_storage_path not like v_user_id::text || '/' || p_complaint_id::text || '/%'
     or p_file_name is null or length(p_file_name) not between 1 and 180
     or p_mime_type is null or p_mime_type not in ('image/jpeg','image/png','image/webp','application/pdf')
     or p_file_size_bytes is null or p_file_size_bytes not between 1 and 10485760 then
    raise exception 'INVALID_SUPPORT_ATTACHMENT' using errcode = '22023';
  end if;
  if not exists(
    select 1
      from public.srk_booking_complaints c
      join public.srk_booking_complaint_messages m
        on m.complaint_id=c.id and m.id=p_message_id
     where c.id=p_complaint_id and c.customer_user_id=v_user_id
       and m.sender_role='customer'
  ) then
    raise exception 'ATTACHMENT_NOT_ALLOWED' using errcode = '42501';
  end if;

  -- Lock the exact Customer-owned Storage row before inserting its metadata.
  -- The Storage DELETE policy takes the same lock before checking metadata.
  perform 1
    from storage.objects o
   where o.bucket_id='srk-customer-support'
     and o.name=p_storage_path
     and o.owner_id=v_user_id::text
   for update;
  if not found then
    raise exception 'SUPPORT_ATTACHMENT_OBJECT_NOT_OWNED' using errcode = '42501';
  end if;

  insert into public.srk_booking_complaint_message_attachments
    (complaint_id,message_id,file_name,mime_type,file_size_bytes,storage_path)
  values
    (p_complaint_id,p_message_id,btrim(p_file_name),p_mime_type,p_file_size_bytes,p_storage_path)
  returning id into v_attachment_id;
  return v_attachment_id;
end;
$function$;

revoke all on function public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint) from public,anon;
grant execute on function public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint) to authenticated;
