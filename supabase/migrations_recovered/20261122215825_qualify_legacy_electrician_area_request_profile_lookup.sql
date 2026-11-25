
do $fix$
declare v_def text;
begin
  v_def:=pg_get_functiondef('public.srk_electrician_list_my_area_requests()'::regprocedure);
  if position('SELECT id INTO v_profile_id FROM public.electrician_profiles WHERE user_id=v_uid AND auth_user_id=v_uid' in v_def)=0 then
    raise exception 'Expected legacy area request lookup not found; stop for manual review';
  end if;
  v_def:=replace(
    v_def,
    'SELECT id INTO v_profile_id FROM public.electrician_profiles WHERE user_id=v_uid AND auth_user_id=v_uid',
    'SELECT ep.id INTO v_profile_id FROM public.electrician_profiles ep WHERE ep.user_id=v_uid AND ep.auth_user_id=v_uid'
  );
  execute v_def;
end
$fix$;
