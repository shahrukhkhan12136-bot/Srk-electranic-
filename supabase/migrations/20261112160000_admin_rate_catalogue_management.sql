-- Admin-only rate version publishing and immutable audit trail.
begin;

create table if not exists public.srk_rate_catalogue_audit (
  id uuid primary key default gen_random_uuid(),
  rate_catalogue_id uuid not null references public.srk_rate_catalogue(id),
  category_code text not null,
  version integer not null,
  hourly_rate numeric(12,6) not null,
  effective_from date not null,
  action text not null check (action in ('seeded','published')),
  reason text not null,
  actor_user_id uuid,
  created_at timestamptz not null default now()
);
alter table public.srk_rate_catalogue_audit enable row level security;
revoke all on table public.srk_rate_catalogue_audit from public,anon,authenticated;

create or replace function public.srk_rate_audit_append_only()
returns trigger language plpgsql set search_path=''
as $guard$
begin
 raise exception 'RATE_AUDIT_IS_APPEND_ONLY' using errcode='55000';
end
$guard$;
revoke all on function public.srk_rate_audit_append_only() from public,anon,authenticated;
drop trigger if exists srk_rate_audit_no_mutation on public.srk_rate_catalogue_audit;
create trigger srk_rate_audit_no_mutation
before update or delete on public.srk_rate_catalogue_audit
for each row execute function public.srk_rate_audit_append_only();

insert into public.srk_rate_catalogue_audit
 (rate_catalogue_id,category_code,version,hourly_rate,effective_from,action,reason,actor_user_id)
select c.id,c.category_code,c.version,c.hourly_rate,c.effective_from,'seeded',
 'Initial approved SRK ELECTRONIC category rate catalogue v1',c.created_by
from public.srk_rate_catalogue c
where not exists(select 1 from public.srk_rate_catalogue_audit a where a.rate_catalogue_id=c.id);

create or replace function public.srk_admin_list_rate_catalogue()
returns jsonb language plpgsql stable security definer set search_path=''
as $fn$
declare v_result jsonb;
begin
 if auth.uid() is null or not public.is_srk_admin() then
   raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object(
   'id',c.id,'category_code',c.category_code,'category_label',c.category_label,
   'version',c.version,'hourly_rate',c.hourly_rate,'effective_from',c.effective_from,
   'created_at',c.created_at,'created_by',c.created_by,
   'action',a.action,'reason',a.reason,'actor_user_id',a.actor_user_id,'audit_created_at',a.created_at
 ) order by c.category_code,c.effective_from desc),'[]'::jsonb)
 into v_result
 from public.srk_rate_catalogue c
 left join public.srk_rate_catalogue_audit a on a.rate_catalogue_id=c.id;
 return v_result;
end
$fn$;

create or replace function public.srk_admin_publish_rate_version(
 p_category_code text,
 p_hourly_rate numeric,
 p_effective_from date,
 p_reason text
)
returns jsonb language plpgsql security definer set search_path=''
as $fn$
declare
 v_label text;
 v_version integer;
 v_id uuid;
 v_reason text := btrim(coalesce(p_reason,''));
begin
 if auth.uid() is null or not public.is_srk_admin() then
   raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501';
 end if;
 if p_category_code not in ('helper','ordinary','skilled','master') then
   raise exception 'INVALID_RATE_CATEGORY' using errcode='22023';
 end if;
 if p_hourly_rate is null or p_hourly_rate <= 0 or p_hourly_rate > 100000
    or p_hourly_rate <> round(p_hourly_rate,3) then
   raise exception 'INVALID_HOURLY_RATE_MAX_THREE_DECIMALS' using errcode='22023';
 end if;
 if p_effective_from is null or p_effective_from < (timezone('Asia/Kolkata', now()))::date then
   raise exception 'RATE_EFFECTIVE_DATE_MUST_NOT_BE_PAST' using errcode='22023';
 end if;
 if length(v_reason)<10 or length(v_reason)>500 then
   raise exception 'RATE_CHANGE_REASON_REQUIRED_10_TO_500_CHARS' using errcode='22023';
 end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('srk-rate:'||p_category_code,0));
 select case p_category_code when 'helper' then 'Helper' when 'ordinary' then 'Ordinary'
   when 'skilled' then 'Skilled' else 'Master' end into v_label;
 select coalesce(max(version),0)+1 into v_version
 from public.srk_rate_catalogue where category_code=p_category_code;
 insert into public.srk_rate_catalogue(category_code,category_label,version,hourly_rate,effective_from,created_by)
 values(p_category_code,v_label,v_version,p_hourly_rate,p_effective_from,auth.uid())
 returning id into v_id;
 insert into public.srk_rate_catalogue_audit
  (rate_catalogue_id,category_code,version,hourly_rate,effective_from,action,reason,actor_user_id)
 values(v_id,p_category_code,v_version,p_hourly_rate,p_effective_from,'published',v_reason,auth.uid());
 return jsonb_build_object('success',true,'id',v_id,'category_code',p_category_code,
  'category_label',v_label,'version',v_version,'hourly_rate',p_hourly_rate,
  'effective_from',p_effective_from,'reason',v_reason);
end
$fn$;

revoke all on function public.srk_admin_list_rate_catalogue() from public,anon;
revoke all on function public.srk_admin_publish_rate_version(text,numeric,date,text) from public,anon;
grant execute on function public.srk_admin_list_rate_catalogue() to authenticated;
grant execute on function public.srk_admin_publish_rate_version(text,numeric,date,text) to authenticated;
commit;
