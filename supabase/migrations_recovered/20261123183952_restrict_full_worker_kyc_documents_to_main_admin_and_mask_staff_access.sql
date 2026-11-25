
drop policy if exists srk_worker_kyc_read on storage.objects;
create policy srk_worker_kyc_read
on storage.objects for select to authenticated
using (bucket_id='srk-worker-kyc' and public.is_srk_admin());

drop policy if exists srk_worker_documents_owner on public.srk_worker_documents;
create policy srk_worker_documents_owner
on public.srk_worker_documents for select to authenticated
using (
  exists(select 1 from public.srk_worker_applications a
    where a.id=srk_worker_documents.application_id and a.user_id=auth.uid())
  or exists(select 1 from public.srk_worker_profiles w
    where w.id=srk_worker_documents.worker_id and w.user_id=auth.uid())
  or public.is_srk_admin()
);

drop policy if exists srk_worker_document_events_admin on public.srk_worker_document_events;
create policy srk_worker_document_events_admin
on public.srk_worker_document_events for select to authenticated
using (public.is_srk_admin());

create or replace function public.srk_admin_list_worker_documents_masked(p_worker_id uuid)
returns table(
 document_id uuid,document_type text,review_status text,mime_type text,
 file_size_bytes bigint,uploaded_at timestamptz,reviewed_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
begin
 if auth.uid() is null or not public.srk_has_admin_permission('workers.verify') then
   raise exception 'Worker verification permission required' using errcode='42501';
 end if;
 return query
 select d.id,d.document_type,d.review_status,d.mime_type,d.file_size_bytes,d.created_at,d.reviewed_at
 from public.srk_worker_documents d
 where d.worker_id=p_worker_id
 order by d.created_at desc;
end
$function$;
revoke all on function public.srk_admin_list_worker_documents_masked(uuid) from public,anon;
grant execute on function public.srk_admin_list_worker_documents_masked(uuid) to authenticated;

revoke all on function public.srk_admin_review_worker_document(uuid,text,text) from public,anon,authenticated;

create or replace function public.srk_admin_review_worker_document_masked(
 p_document_id uuid,p_decision text,p_note text
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v public.srk_worker_documents%rowtype;
begin
 if auth.uid() is null or not public.srk_has_admin_permission('workers.verify') then
   raise exception 'Worker verification permission required' using errcode='42501';
 end if;
 if p_document_id is null or p_decision not in ('approved','rejected','more_info')
    or length(btrim(coalesce(p_note,'')))<5 then
   raise exception 'Document, decision and review note are required';
 end if;
 update public.srk_worker_documents set review_status=p_decision,reviewed_by=auth.uid(),
   reviewed_at=clock_timestamp(),admin_note=btrim(p_note)
 where id=p_document_id returning * into v;
 if not found then raise exception 'Worker document not found'; end if;
 insert into public.srk_worker_document_events(document_id,actor_user_id,action,note)
 values(p_document_id,auth.uid(),p_decision,btrim(p_note));
 if v.worker_id is not null then
   insert into public.srk_app_notifications(user_id,notification_type,title,body)
   select user_id,'document_review','Document review update','Your submitted document was marked: '||p_decision
   from public.srk_worker_profiles where id=v.worker_id;
 elsif v.application_id is not null then
   insert into public.srk_app_notifications(user_id,notification_type,title,body)
   select user_id,'document_review','Document review update','Your submitted document was marked: '||p_decision
   from public.srk_worker_applications where id=v.application_id;
 end if;
 return jsonb_build_object('document_id',v.id,'document_type',v.document_type,
   'review_status',v.review_status,'reviewed_at',v.reviewed_at);
end
$function$;
revoke all on function public.srk_admin_review_worker_document_masked(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_review_worker_document_masked(uuid,text,text) to authenticated;
