begin;
revoke insert, update, delete, truncate, references, trigger
on public.srk_admin_permissions, public.srk_admin_roles,
   public.srk_admin_role_permissions, public.srk_admin_staff_members
from anon, authenticated;
commit;