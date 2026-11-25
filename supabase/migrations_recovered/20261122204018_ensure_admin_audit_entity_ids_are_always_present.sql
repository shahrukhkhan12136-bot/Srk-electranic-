
create or replace function public.srk_log_admin_entity_change()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_old jsonb; v_new jsonb; v_id uuid; v_booking uuid; v_changed text[];
  v_actor_role text; v_reason text; v_key text;
begin
  if auth.uid() is null then if tg_op='DELETE' then return old; else return new; end if; end if;
  if not exists(select 1 from public.srk_admin_users where user_id=auth.uid())
     and not exists(select 1 from public.srk_admin_staff_members where user_id=auth.uid() and is_active) then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  v_old:=case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else '{}'::jsonb end;
  v_new:=case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else '{}'::jsonb end;
  v_key:=coalesce(v_new->>'setting_key',v_old->>'setting_key',v_new->>'role_code',v_old->>'role_code','unknown');
  v_id:=coalesce(nullif(v_new->>'id','')::uuid,nullif(v_old->>'id','')::uuid,
    nullif(v_new->>'user_id','')::uuid,nullif(v_old->>'user_id','')::uuid,md5(v_key)::uuid);
  v_booking:=coalesce(nullif(v_new->>'booking_id','')::uuid,nullif(v_old->>'booking_id','')::uuid);
  v_actor_role:=case when exists(select 1 from public.srk_admin_users where user_id=auth.uid()) then 'super_admin' else 'staff' end;
  v_reason:=coalesce(v_new->>'admin_note',v_new->>'change_reason',v_new->>'admin_change_reason',
    v_new->>'moderation_note',v_new->>'reason','Admin panel change');
  select coalesce(array_agg(k),array[]::text[]) into v_changed
  from (select key k from jsonb_object_keys(v_new) key union select key k from jsonb_object_keys(v_old) key) keys
  where v_old->k is distinct from v_new->k;
  insert into public.srk_admin_audit_events(entity_type,entity_id,booking_id,action,actor_user_id,actor_role,changed_fields,before_data,after_data)
  values(tg_argv[0],v_id,v_booking,tg_op,auth.uid(),v_actor_role,v_changed,v_old,
    jsonb_set(v_new,'{admin_action_reason}',to_jsonb(v_reason),true));
  if v_booking is not null then
    insert into public.srk_booking_admin_changes(booking_id,admin_user_id,entity_type,entity_id,action,reason,old_values,new_values)
    values(v_booking,auth.uid(),tg_argv[0],v_id,tg_op,v_reason,v_old,v_new);
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end $$;
