
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values(
 'srk-emergency-evidence','srk-emergency-evidence',false,52428800,
 array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime','audio/mpeg','audio/mp4','audio/wav','audio/webm','application/pdf']
)
on conflict(id) do update set
 public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "srk_emergency_evidence_participant_upload" on storage.objects;
create policy "srk_emergency_evidence_participant_upload"
on storage.objects for insert to authenticated
with check (
 bucket_id='srk-emergency-evidence'
 and split_part(name,'/',1) ~* '^[0-9a-f-]{36}$'
 and exists(
   select 1 from public.srk_emergency_alerts a
   where a.id::text=split_part(name,'/',1)
     and (
       a.raised_by=auth.uid()
       or exists(select 1 from public.srk_booking_workers bw
         join public.srk_worker_profiles wp on wp.id=bw.worker_id
         where bw.booking_id=a.booking_id and wp.user_id=auth.uid())
     )
 )
);

drop policy if exists "srk_emergency_evidence_admin_read" on storage.objects;
create policy "srk_emergency_evidence_admin_read"
on storage.objects for select to authenticated
using (
 bucket_id='srk-emergency-evidence'
 and public.srk_has_admin_permission('support.manage')
);
