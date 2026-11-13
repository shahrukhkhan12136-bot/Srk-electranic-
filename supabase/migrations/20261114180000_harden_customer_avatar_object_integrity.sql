-- Bind a customer's profile avatar reference to an actual private Storage
-- object with an allowed MIME type, size and matching UUID filename extension.

create or replace function public.srk_customer_update_my_profile(
  p_full_name text,
  p_preferred_language text default 'hi',
  p_avatar_path text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_name text := btrim(coalesce(p_full_name,''));
  v_lang text := coalesce(p_preferred_language,'hi');
  v_object_mime text;
  v_object_size bigint;
  v_extension text;
begin
  if v_user_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '28000';
  end if;
  if length(v_name) < 2 or length(v_name) > 120
     or v_lang not in ('hi','en') then
    raise exception 'INVALID_PROFILE_FIELDS' using errcode = '22023';
  end if;
  if p_avatar_path is not null then
    if length(p_avatar_path)>500
       or left(p_avatar_path,length(v_user_id::text || '/')) <> v_user_id::text || '/'
       or p_avatar_path !~ ('^' || v_user_id::text || '/[0-9a-fA-F-]{36}\.(jpg|png|webp)$') then
      raise exception 'INVALID_AVATAR_PATH' using errcode = '22023';
    end if;

    select o.metadata->>'mimetype',
           case when coalesce(o.metadata->>'size','') ~ '^[0-9]+$'
                then (o.metadata->>'size')::bigint else null end
      into v_object_mime,v_object_size
      from storage.objects o
     where o.bucket_id='srk-customer-avatars'
       and o.name=p_avatar_path
       and (storage.foldername(o.name))[1]=v_user_id::text;

    if not found or v_object_size not between 1 and 5242880 then
      raise exception 'AVATAR_OBJECT_INVALID' using errcode = '22023';
    end if;
    v_extension := case v_object_mime
      when 'image/jpeg' then 'jpg'
      when 'image/png' then 'png'
      when 'image/webp' then 'webp'
      else null end;
    if v_extension is null
       or split_part(p_avatar_path,'.',array_length(string_to_array(p_avatar_path,'.'),1)) <> v_extension then
      raise exception 'AVATAR_OBJECT_METADATA_MISMATCH' using errcode = '22023';
    end if;
  end if;

  insert into public.srk_customer_profiles(user_id,full_name,preferred_language,avatar_path,updated_at)
  values(v_user_id,v_name,v_lang,p_avatar_path,now())
  on conflict(user_id) do update
    set full_name=excluded.full_name,
        preferred_language=excluded.preferred_language,
        avatar_path=coalesce(excluded.avatar_path,public.srk_customer_profiles.avatar_path),
        updated_at=now();

  return jsonb_build_object('success',true);
end;
$function$;

revoke all on function public.srk_customer_update_my_profile(text,text,text) from public, anon;
grant execute on function public.srk_customer_update_my_profile(text,text,text) to authenticated;
