
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values
 ('srk-chat-attachments','srk-chat-attachments',false,10485760,array['image/jpeg','image/png','application/pdf']),
 ('srk-support-attachments','srk-support-attachments',false,10485760,array['image/jpeg','image/png','application/pdf'])
on conflict(id) do update set public=false;

create policy srk_chat_attachment_upload on storage.objects
for insert to authenticated
with check(
  bucket_id='srk-chat-attachments'
  and (storage.foldername(name))[2]=(select auth.uid())::text
  and exists(select 1 from public.srk_booking_chat_members m
    where m.room_id=((storage.foldername(name))[1])::uuid
      and m.user_id=(select auth.uid()) and m.left_at is null)
);

create policy srk_chat_attachment_read on storage.objects
for select to authenticated
using(
  bucket_id='srk-chat-attachments'
  and (public.srk_has_admin_permission('bookings.manage')
    or exists(select 1 from public.srk_booking_chat_members m
      where m.room_id=((storage.foldername(name))[1])::uuid
        and m.user_id=(select auth.uid()) and m.left_at is null))
);

create policy srk_support_attachment_upload on storage.objects
for insert to authenticated
with check(
  bucket_id='srk-support-attachments'
  and (storage.foldername(name))[2]=(select auth.uid())::text
  and exists(select 1 from public.srk_support_cases c
    where c.id=((storage.foldername(name))[1])::uuid
      and (c.raised_by=(select auth.uid()) or c.assigned_staff=(select auth.uid())
        or public.srk_has_admin_permission('support.manage')))
);

create policy srk_support_attachment_read on storage.objects
for select to authenticated
using(
  bucket_id='srk-support-attachments'
  and exists(select 1 from public.srk_support_cases c
    where c.id=((storage.foldername(name))[1])::uuid
      and (c.raised_by=(select auth.uid()) or c.assigned_staff=(select auth.uid())
        or public.srk_has_admin_permission('support.manage')))
);

create or replace function public.srk_submit_worker_application(
 p_worker_type text,p_category_id uuid,p_full_name text,p_phone text,p_father_name text,
 p_date_of_birth date,p_photo_path text,p_address text,p_state text,p_district text,
 p_pincode text,p_experience_years integer,p_about text
) returns public.srk_worker_applications
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_app public.srk_worker_applications%rowtype; v_auth_phone text;
begin
  if auth.uid() is null then raise exception 'OTP login required'; end if;
  if p_worker_type not in ('technician','helper') then raise exception 'Invalid worker type'; end if;
  if not exists(select 1 from public.srk_service_categories where id=p_category_id and is_active) then raise exception 'Active category required'; end if;
  if length(btrim(coalesce(p_full_name,'')))<2 or p_phone !~ '^[0-9]{10}$' or p_pincode !~ '^[0-9]{6}$' then
    raise exception 'Valid name, 10-digit mobile and 6-digit PIN code required';
  end if;
  v_auth_phone:=right(regexp_replace(coalesce(auth.jwt()->>'phone',''),'[^0-9]','','g'),10);
  if v_auth_phone<>'' and v_auth_phone<>p_phone then raise exception 'Mobile number does not match verified OTP login'; end if;
  insert into public.srk_worker_applications(user_id,worker_type,category_id,full_name,phone,father_name,date_of_birth,
    photo_path,address,state,district,pincode,experience_years,about,status)
  values(auth.uid(),p_worker_type,p_category_id,btrim(p_full_name),p_phone,p_father_name,p_date_of_birth,
    p_photo_path,btrim(p_address),btrim(p_state),btrim(p_district),p_pincode,p_experience_years,p_about,'pending')
  on conflict(user_id,category_id,worker_type) do update set full_name=excluded.full_name,phone=excluded.phone,
    father_name=excluded.father_name,date_of_birth=excluded.date_of_birth,photo_path=excluded.photo_path,
    address=excluded.address,state=excluded.state,district=excluded.district,pincode=excluded.pincode,
    experience_years=excluded.experience_years,about=excluded.about,status='pending',updated_at=clock_timestamp()
  returning * into v_app;
  return v_app;
end $$;

create or replace function public.srk_submit_worker_document(
 p_document_type text,p_storage_path text,p_file_name text,p_mime_type text,p_file_size_bytes bigint,
 p_application_id uuid default null
) returns public.srk_worker_documents
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_worker uuid; v_doc public.srk_worker_documents%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select id into v_worker from public.srk_worker_profiles where user_id=auth.uid();
  if p_application_id is not null and not exists(select 1 from public.srk_worker_applications where id=p_application_id and user_id=auth.uid()) then
    raise exception 'Application does not belong to you';
  end if;
  if v_worker is null and p_application_id is null then raise exception 'Worker application or profile required'; end if;
  if p_storage_path like '/%' or p_storage_path like '%..%' or split_part(p_storage_path,'/',1)<>auth.uid()::text then
    raise exception 'Document path must be inside your private folder';
  end if;
  if p_document_type not in ('photo','identity_proof','address_proof','experience_certificate','trade_certificate','bank_proof','other') then
    raise exception 'Unsupported document type';
  end if;
  insert into public.srk_worker_documents(worker_id,application_id,document_type,storage_path,file_name,mime_type,file_size_bytes)
  values(v_worker,p_application_id,p_document_type,p_storage_path,p_file_name,p_mime_type,p_file_size_bytes)
  returning * into v_doc;
  return v_doc;
end $$;

drop policy if exists srk_booking_receipts_read on storage.objects;
create policy srk_booking_receipts_read on storage.objects
for select to authenticated
using(
  bucket_id='srk-booking-receipts'
  and exists(select 1 from public.srk_booking_receipts r join public.service_bookings b on b.id=r.booking_id
    where r.storage_path=storage.objects.name
      and (b.customer_user_id=(select auth.uid())
        or public.srk_has_admin_permission('bookings.manage')
        or public.srk_has_admin_permission('payments.read')
        or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
          where bw.booking_id=b.id and w.user_id=(select auth.uid()))))
);
