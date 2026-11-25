
revoke all privileges on all tables in schema public from anon;
revoke all privileges on all sequences in schema public from anon;

grant select on table
  public.services,
  public.states,
  public.srk_service_categories,
  public.srk_service_types,
  public.srk_service_skills,
  public.srk_skill_levels,
  public.srk_service_rates
to anon;
