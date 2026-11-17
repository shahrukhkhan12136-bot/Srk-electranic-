-- Allow Support Staff to read only attachments on Customer Complaints currently assigned to them.
-- Direct Storage reads are authorized on every request; do not mint long-lived signed URLs.

create or replace function public.srk_admin_staff_can_read_customer_attachment(
  p_object_name text
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_parts text[];
  v_complaint_id uuid;
begin
  if v_uid is null or p_object_name is null
     or not public.srk_has_admin_permission('support.customer.read') then
    return false;
  end if;

  -- Customer uploads use <customer-user-id>/<complaint-id>/<file-name>.
  v_parts := storage.foldername(p_object_name);
  if coalesce(array_length(v_parts,1),0) < 2
     or v_parts[1] is null or v_parts[2] is null then
    return false;
  end if;

  begin
    v_complaint_id := v_parts[2]::uuid;
  exception when invalid_text_representation then
    return false;
  end;

  -- Lock order matches Staff thread reads and Main Admin reassignment:
  -- authorization/session -> complaint row -> current assignment row.
  perform 1
    from public.srk_booking_complaints c
   where c.id=v_complaint_id
     and c.customer_user_id::text=v_parts[1]
   for share;
  if not found then
    return false;
  end if;

  perform 1
    from public.srk_admin_support_assignments a
   where a.case_type='customer_complaint'
     and a.case_id=v_complaint_id
     and a.assigned_staff_user_id=v_uid
   for share;
  if not found then
    return false;
  end if;

  -- Staff can read only objects already linked to a message in this complaint.
  return exists (
    select 1
      from public.srk_booking_complaint_message_attachments a
     where a.complaint_id=v_complaint_id
       and a.storage_path=p_object_name
  );
end;
$function$;

revoke all on function public.srk_admin_staff_can_read_customer_attachment(text) from public,anon;
grant execute on function public.srk_admin_staff_can_read_customer_attachment(text) to authenticated;

-- Keep existing Customer-owner and Main Admin access, adding only the current
-- assigned-Staff read path. Upload and DELETE policies remain unchanged.
drop policy if exists srk_customer_support_read_own_or_admin on storage.objects;
create policy srk_customer_support_read_own_or_admin on storage.objects
for select to authenticated
using (
  bucket_id='srk-customer-support'
  and (
    public.srk_customer_support_object_access(name,true)
    or public.srk_admin_staff_can_read_customer_attachment(name)
  )
);

create or replace function public.srk_admin_staff_list_customer_attachments(
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
volatile
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null
     or not public.srk_has_admin_permission('support.customer.read') then
    raise exception 'SUPPORT_CUSTOMER_READ_REQUIRED' using errcode='42501';
  end if;

  -- Match Staff message-read lock order so reassignment serializes with listing.
  perform 1
    from public.srk_booking_complaints c
   where c.id=p_complaint_id
   for share;
  if not found then
    raise exception 'CUSTOMER_COMPLAINT_NOT_FOUND' using errcode='P0002';
  end if;

  perform 1
    from public.srk_admin_support_assignments a
   where a.case_type='customer_complaint'
     and a.case_id=p_complaint_id
     and a.assigned_staff_user_id=auth.uid()
   for share;
  if not found then
    raise exception 'SUPPORT_CASE_NOT_ASSIGNED_TO_YOU' using errcode='42501';
  end if;

  return query
    select a.id,a.message_id,a.file_name,a.mime_type,a.file_size_bytes,a.storage_path,a.created_at
      from public.srk_booking_complaint_message_attachments a
     where a.complaint_id=p_complaint_id
     order by a.created_at asc,a.id asc
     limit 100;
end;
$function$;

revoke all on function public.srk_admin_staff_list_customer_attachments(uuid) from public,anon;
grant execute on function public.srk_admin_staff_list_customer_attachments(uuid) to authenticated;
