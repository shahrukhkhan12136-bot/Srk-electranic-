
do $fix$
declare v_def text;
begin
  v_def:=pg_get_functiondef('public.srk_admin_review_worker_application(uuid,text,text)'::regprocedure);
  if position('if not found then raise exception ''Application not found''; end if;' in v_def)=0 then
    raise exception 'Expected application lookup not found; stop';
  end if;
  v_def:=replace(
    v_def,
    'if not found then raise exception ''Application not found''; end if;',
    'if not found then raise exception ''Application not found''; end if;'||E'\n'||
    '  select * into v_profile from public.srk_worker_profiles where user_id=v_app.user_id for update;'||E'\n'||
    '  if found and v_profile.worker_code is not null and ('||
    'v_profile.category_id is distinct from v_app.category_id or '||
    'v_profile.worker_type is distinct from v_app.worker_type) then '||
    'raise exception ''Approved worker category/type cannot be changed because the permanent Worker ID is category-bound''; end if;'
  );
  execute v_def;
end
$fix$;
