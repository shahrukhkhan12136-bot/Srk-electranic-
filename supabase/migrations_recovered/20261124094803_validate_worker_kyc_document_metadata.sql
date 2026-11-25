CREATE OR REPLACE FUNCTION public.srk_submit_worker_document(
 p_document_type text,p_storage_path text,p_file_name text,p_mime_type text,
 p_file_size_bytes bigint,p_application_id uuid DEFAULT NULL
) RETURNS public.srk_worker_documents
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare v_worker uuid; v_doc public.srk_worker_documents%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select id into v_worker from public.srk_worker_profiles where user_id=auth.uid();
 if p_application_id is not null and not exists(
  select 1 from public.srk_worker_applications where id=p_application_id and user_id=auth.uid()
 ) then raise exception 'Application does not belong to you'; end if;
 if v_worker is null and p_application_id is null then raise exception 'Worker application or profile required'; end if;
 if p_storage_path is null or p_storage_path like '/%' or p_storage_path like '%..%'
  or split_part(p_storage_path,'/',1)<>auth.uid()::text
  or p_storage_path ~ '[\\\\]' then
  raise exception 'Document path must be inside your private folder';
 end if;
 if p_document_type not in ('photo','identity_proof','address_proof','experience_certificate','trade_certificate','bank_proof','other') then
  raise exception 'Unsupported document type';
 end if;
 if p_file_name is null or length(btrim(p_file_name)) not between 1 and 255
  or p_file_name ~ '[/\\\\]' then
  raise exception 'A valid file name is required';
 end if;
 if lower(coalesce(p_mime_type,'')) not in ('image/jpeg','image/png','application/pdf') then
  raise exception 'Only JPEG, PNG or PDF documents are accepted';
 end if;
 if p_file_size_bytes is null or p_file_size_bytes not between 1 and 20971520 then
  raise exception 'Document must be between 1 byte and 20 MB';
 end if;
 insert into public.srk_worker_documents(
  worker_id,application_id,document_type,storage_path,file_name,mime_type,file_size_bytes
 ) values(v_worker,p_application_id,p_document_type,p_storage_path,btrim(p_file_name),
  lower(p_mime_type),p_file_size_bytes)
 returning * into v_doc;
 return v_doc;
end
$function$;