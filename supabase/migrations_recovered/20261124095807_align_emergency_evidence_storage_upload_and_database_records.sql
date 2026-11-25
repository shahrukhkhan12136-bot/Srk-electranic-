CREATE POLICY srk_emergency_evidence_admin_upload
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
 bucket_id='srk-emergency-evidence'
 AND split_part(name,'/',1) ~* '^[0-9a-f-]{36}$'
 AND public.srk_has_admin_permission('support.manage')
);

CREATE OR REPLACE FUNCTION public.srk_add_emergency_evidence(
 p_alert_id uuid,p_evidence_type text,p_storage_bucket text,p_storage_path text,
 p_file_name text,p_mime_type text,p_file_size_bytes bigint,
 p_captured_at timestamptz DEFAULT NULL,p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS public.srk_emergency_evidence
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_alert public.srk_emergency_alerts%rowtype;
 v_uploader_role text;
 v_evidence public.srk_emergency_evidence%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_alert_id is null or p_evidence_type not in ('photo','video','audio','document','other')
  or p_storage_bucket is null or length(btrim(p_storage_bucket)) not between 1 and 100
  or p_storage_path is null or length(btrim(p_storage_path)) not between 1 and 1000
  or p_storage_path like '/%' or p_storage_path like '%..%'
  or (p_file_size_bytes is not null and p_file_size_bytes<0) then
  raise exception 'Invalid emergency evidence details' using errcode='22023';
 end if;
 select * into v_alert from public.srk_emergency_alerts where id=p_alert_id;
 if not found then raise exception 'Emergency alert not found'; end if;
 if p_storage_bucket<>'srk-emergency-evidence'
  or split_part(p_storage_path,'/',1)<>p_alert_id::text
  or coalesce(p_file_size_bytes,0)>52428800
  or p_mime_type is null
  or p_mime_type not in ('image/jpeg','image/png','image/webp','video/mp4','video/quicktime','audio/mpeg','audio/mp4','audio/wav','audio/webm','application/pdf') then
  raise exception 'Evidence must be stored in the private SRK emergency bucket, under its alert folder, and within file limits';
 end if;
 if not exists(select 1 from storage.objects o
  where o.bucket_id='srk-emergency-evidence' and o.name=p_storage_path) then
  raise exception 'Emergency evidence file must be uploaded before its record is created';
 end if;

 if v_alert.raised_by=auth.uid() then
  v_uploader_role:=v_alert.raised_by_role;
 elsif exists(select 1 from public.srk_booking_workers bw
  join public.srk_worker_profiles wp on wp.id=bw.worker_id
  where bw.booking_id=v_alert.booking_id and wp.user_id=auth.uid()) then
  select wp.worker_type into v_uploader_role
  from public.srk_booking_workers bw join public.srk_worker_profiles wp on wp.id=bw.worker_id
  where bw.booking_id=v_alert.booking_id and wp.user_id=auth.uid() limit 1;
 elsif public.srk_has_admin_permission('support.manage') then
  v_uploader_role:='admin';
 else
  raise exception 'Only the alert participant or authorized Admin can attach evidence' using errcode='42501';
 end if;

 insert into public.srk_emergency_evidence(
  alert_id,uploaded_by,uploader_role,evidence_type,storage_bucket,storage_path,
  original_file_name,mime_type,file_size_bytes,captured_at,legal_hold,retention_until,metadata
 ) values(
  p_alert_id,auth.uid(),v_uploader_role,p_evidence_type,btrim(p_storage_bucket),btrim(p_storage_path),
  p_file_name,p_mime_type,p_file_size_bytes,p_captured_at,
  v_alert.legal_hold or exists(select 1 from public.srk_emergency_legal_holds h where h.alert_id=p_alert_id and h.released_at is null),
  coalesce(v_alert.retention_until,clock_timestamp()+interval '3 years'),
  coalesce(p_metadata,'{}'::jsonb)
 ) returning * into v_evidence;
 return v_evidence;
end
$function$;