
create or replace function public.srk_add_emergency_evidence(
 p_alert_id uuid,p_evidence_type text,p_storage_bucket text,p_storage_path text,
 p_file_name text,p_mime_type text,p_file_size_bytes bigint,p_captured_at timestamptz default null,
 p_metadata jsonb default '{}'::jsonb
)
returns public.srk_emergency_evidence
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
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
revoke all on function public.srk_add_emergency_evidence(uuid,text,text,text,text,text,bigint,timestamptz,jsonb) from public,anon;
grant execute on function public.srk_add_emergency_evidence(uuid,text,text,text,text,text,bigint,timestamptz,jsonb) to authenticated;
