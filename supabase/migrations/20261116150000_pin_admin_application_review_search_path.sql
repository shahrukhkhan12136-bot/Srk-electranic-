-- The application-review SECURITY DEFINER function schema-qualifies all
-- application/auth relations and project helpers; built-ins resolve via pg_catalog.
alter function public.srk_admin_review_application(uuid, text)
  set search_path = '';
