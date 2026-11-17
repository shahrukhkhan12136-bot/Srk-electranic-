begin;
select plan(11);

select ok(
  exists (
    select 1
      from pg_proc p
     where p.oid='public.srk_admin_staff_can_read_customer_attachment(text)'::regprocedure
       and p.prosecdef
       and p.provolatile='v'
       and coalesce(p.proconfig::text,'') like '%search_path=""%'
  ),
  'Staff attachment Storage guard is VOLATILE SECURITY DEFINER with an empty search_path'
);

select ok(
  has_function_privilege('authenticated','public.srk_admin_staff_can_read_customer_attachment(text)','EXECUTE')
  and not has_function_privilege('anon','public.srk_admin_staff_can_read_customer_attachment(text)','EXECUTE')
  and not exists (
    select 1
      from pg_proc p,
           lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
     where p.oid='public.srk_admin_staff_can_read_customer_attachment(text)'::regprocedure
       and acl.grantee=0
       and acl.privilege_type='EXECUTE'
  ),
  'Storage guard is executable by authenticated users only, not anon or PUBLIC'
);

select ok(
  position('srk_has_admin_permission(''support.customer.read'')' in lower(pg_get_functiondef('public.srk_admin_staff_can_read_customer_attachment(text)'::regprocedure)))>0
  and position('auth.uid()' in lower(pg_get_functiondef('public.srk_admin_staff_can_read_customer_attachment(text)'::regprocedure)))>0,
  'Staff attachment access requires the active session-bound customer support read permission'
);

select ok(
  position('storage.foldername(p_object_name)' in lower(pg_get_functiondef('public.srk_admin_staff_can_read_customer_attachment(text)'::regprocedure)))>0
  and position('v_parts[2]::uuid' in lower(pg_get_functiondef('public.srk_admin_staff_can_read_customer_attachment(text)'::regprocedure)))>0
  and position('customer_user_id::text=v_parts[1]' in lower(pg_get_functiondef('public.srk_admin_staff_can_read_customer_attachment(text)'::regprocedure)))>0,
  'Storage path must map to the exact Customer-owned complaint'
);

select ok(
  position('case_type=''customer_complaint''' in lower(pg_get_functiondef('public.srk_admin_staff_can_read_customer_attachment(text)'::regprocedure)))>0
  and position('assigned_staff_user_id=v_uid' in lower(pg_get_functiondef('public.srk_admin_staff_can_read_customer_attachment(text)'::regprocedure)))>0
  and position('from public.srk_booking_complaints c' in lower(pg_get_functiondef('public.srk_admin_staff_can_read_customer_attachment(text)'::regprocedure)))
      < position('from public.srk_admin_support_assignments a' in lower(pg_get_functiondef('public.srk_admin_staff_can_read_customer_attachment(text)'::regprocedure)))
  and length(lower(pg_get_functiondef('public.srk_admin_staff_can_read_customer_attachment(text)'::regprocedure)))
      - length(replace(lower(pg_get_functiondef('public.srk_admin_staff_can_read_customer_attachment(text)'::regprocedure)),'for share','')) >= 16,
  'Staff must hold the current complaint assignment, with case then assignment row locks'
);

select ok(
  position('srk_booking_complaint_message_attachments' in lower(pg_get_functiondef('public.srk_admin_staff_can_read_customer_attachment(text)'::regprocedure)))>0
  and position('a.storage_path=p_object_name' in lower(pg_get_functiondef('public.srk_admin_staff_can_read_customer_attachment(text)'::regprocedure)))>0,
  'Staff can read only objects already linked in the complaint attachment metadata'
);

select ok(
  position('srk_customer_support_object_access(name,true)' in lower(pg_get_expr(
    (select polqual from pg_policy
      where polname='srk_customer_support_read_own_or_admin'
        and polrelid='storage.objects'::regclass),
    'storage.objects'::regclass
  )))>0
  and position('srk_admin_staff_can_read_customer_attachment(name)' in lower(pg_get_expr(
    (select polqual from pg_policy
      where polname='srk_customer_support_read_own_or_admin'
        and polrelid='storage.objects'::regclass),
    'storage.objects'::regclass
  )))>0,
  'Storage SELECT policy preserves Customer/Main Admin access and adds assigned Staff read access'
);

select ok(
  position('support.customer.read' in lower(pg_get_functiondef('public.srk_admin_staff_list_customer_attachments(uuid)'::regprocedure)))>0
  and position('support_case_not_assigned_to_you' in lower(pg_get_functiondef('public.srk_admin_staff_list_customer_attachments(uuid)'::regprocedure)))>0
  and position('limit 100' in lower(pg_get_functiondef('public.srk_admin_staff_list_customer_attachments(uuid)'::regprocedure)))>0,
  'Attachment metadata RPC requires support read permission, current assignment, and bounded results'
);

select ok(
  position('from public.srk_booking_complaints c' in lower(pg_get_functiondef('public.srk_admin_staff_list_customer_attachments(uuid)'::regprocedure)))
      < position('from public.srk_admin_support_assignments a' in lower(pg_get_functiondef('public.srk_admin_staff_list_customer_attachments(uuid)'::regprocedure)))
  and position('for share' in lower(pg_get_functiondef('public.srk_admin_staff_list_customer_attachments(uuid)'::regprocedure)))>0
  and position('storage_path' in lower(pg_get_function_result('public.srk_admin_staff_list_customer_attachments(uuid)'::regprocedure)))>0
  and position('customer_phone' in lower(pg_get_function_result('public.srk_admin_staff_list_customer_attachments(uuid)'::regprocedure)))=0,
  'Metadata RPC locks complaint before assignment and returns only attachment metadata, not private Customer contact fields'
);

select ok(
  has_function_privilege('authenticated','public.srk_admin_staff_list_customer_attachments(uuid)','EXECUTE')
  and not has_function_privilege('anon','public.srk_admin_staff_list_customer_attachments(uuid)','EXECUTE')
  and position('srk_customer_support_object_delete_access(name)' in lower(coalesce(pg_get_expr(
    (select polqual from pg_policy
      where polname='srk_customer_support_delete_own'
        and polrelid='storage.objects'::regclass),
    'storage.objects'::regclass
  ),'')))>0
  and not exists (
    select 1
      from pg_policy p
     where p.polrelid='storage.objects'::regclass
       and p.polname in ('srk_customer_support_delete_own','srk_customer_support_upload_own')
       and position('srk_admin_staff_can_read_customer_attachment' in lower(
         coalesce(pg_get_expr(p.polqual,p.polrelid),'') || ' ' ||
         coalesce(pg_get_expr(p.polwithcheck,p.polrelid),'')
       ))>0
  ),
  'Metadata RPC is authenticated-only and Staff attachment read does not grant Storage upload or delete access'
);

select ok(
  exists (
    select 1
      from pg_proc p
     where p.oid='public.srk_admin_staff_list_customer_attachments(uuid)'::regprocedure
       and p.prosecdef
       and p.provolatile='v'
       and coalesce(p.proconfig::text,'') like '%search_path=""%'
  )
  and has_function_privilege('authenticated','public.srk_admin_staff_list_customer_attachments(uuid)','EXECUTE')
  and not has_function_privilege('anon','public.srk_admin_staff_list_customer_attachments(uuid)','EXECUTE')
  and not exists (
    select 1
      from pg_proc p,
           lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
     where p.oid='public.srk_admin_staff_list_customer_attachments(uuid)'::regprocedure
       and acl.grantee=0
       and acl.privilege_type='EXECUTE'
  ),
  'attachment metadata RPC is VOLATILE SECURITY DEFINER with empty search_path and authenticated-only EXECUTE'
);

select * from finish();
rollback;
