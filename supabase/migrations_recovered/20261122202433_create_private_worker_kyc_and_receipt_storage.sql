
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values
 ('srk-worker-kyc','srk-worker-kyc',false,20971520,array['image/jpeg','image/png','application/pdf']),
 ('srk-booking-receipts','srk-booking-receipts',false,10485760,array['application/pdf'])
on conflict(id) do update set public=false;

create policy srk_worker_kyc_upload on storage.objects
for insert to authenticated
with check(
  bucket_id='srk-worker-kyc'
  and (storage.foldername(name))[1]=(select auth.uid())::text
  and (
    exists(select 1 from public.srk_worker_applications a where a.user_id=(select auth.uid()))
    or exists(select 1 from public.srk_worker_profiles w where w.user_id=(select auth.uid()))
  )
);

create policy srk_worker_kyc_read on storage.objects
for select to authenticated
using(
  bucket_id='srk-worker-kyc'
  and (
    (storage.foldername(name))[1]=(select auth.uid())::text
    or public.srk_has_admin_permission('workers.verify')
  )
);

create policy srk_booking_receipts_read on storage.objects
for select to authenticated
using(
  bucket_id='srk-booking-receipts'
  and exists(
    select 1 from public.srk_booking_receipts r
    join public.service_bookings b on b.id=r.booking_id
    where r.storage_path=storage.objects.name
      and (b.customer_user_id=(select auth.uid())
        or public.is_srk_admin()
        or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
          where bw.booking_id=b.id and w.user_id=(select auth.uid())))
  )
);

create or replace function public.srk_admin_review_worker_document(
  p_document_id uuid,p_decision text,p_note text default null
) returns public.srk_worker_documents
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.srk_worker_documents%rowtype;
begin
  if not public.srk_has_admin_permission('workers.verify') then raise exception 'Worker verification permission required'; end if;
  if p_decision not in ('approved','rejected','more_info') then raise exception 'Invalid document decision'; end if;
  update public.srk_worker_documents set review_status=p_decision,reviewed_by=auth.uid(),
    reviewed_at=clock_timestamp(),admin_note=p_note
  where id=p_document_id returning * into v;
  if not found then raise exception 'Worker document not found'; end if;
  insert into public.srk_worker_document_events(document_id,actor_user_id,action,note)
  values(p_document_id,auth.uid(),p_decision,p_note);
  if v.worker_id is not null then
    insert into public.srk_app_notifications(user_id,notification_type,title,body)
    select user_id,'document_review','Document review update','Your submitted document was marked: '||p_decision
    from public.srk_worker_profiles where id=v.worker_id;
  elsif v.application_id is not null then
    insert into public.srk_app_notifications(user_id,notification_type,title,body)
    select user_id,'document_review','Document review update','Your submitted document was marked: '||p_decision
    from public.srk_worker_applications where id=v.application_id;
  end if;
  return v;
end $$;

revoke all on function public.srk_admin_review_worker_document(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_review_worker_document(uuid,text,text) to authenticated;
