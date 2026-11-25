
alter table public.srk_emergency_decision_appeals
 add column if not exists retention_until timestamptz,
 add column if not exists legal_hold boolean not null default false;
alter table public.srk_emergency_decision_appeal_events
 add column if not exists retention_until timestamptz,
 add column if not exists legal_hold boolean not null default false;

update public.srk_emergency_decision_appeals a
set retention_until=greatest(coalesce(a.retention_until,'-infinity'::timestamptz),
  coalesce(e.retention_until,clock_timestamp()+interval '3 years')),
 legal_hold=coalesce(e.legal_hold,false)
from public.srk_emergency_alerts e where e.id=a.alert_id
 and (a.retention_until is null or a.legal_hold is distinct from coalesce(e.legal_hold,false));
update public.srk_emergency_decision_appeal_events ev
set retention_until=coalesce(a.retention_until,clock_timestamp()+interval '3 years'),
 legal_hold=coalesce(a.legal_hold,false)
from public.srk_emergency_decision_appeals a where a.id=ev.appeal_id
 and (ev.retention_until is null or ev.legal_hold is distinct from a.legal_hold);

create or replace function public.srk_sync_emergency_appeal_retention()
returns trigger language plpgsql set search_path=''
as $$
declare v_alert public.srk_emergency_alerts%rowtype; v_parent public.srk_emergency_decision_appeals%rowtype;
begin
 if tg_table_name='srk_emergency_decision_appeals' then
  select * into v_alert from public.srk_emergency_alerts where id=new.alert_id;
  if not found then raise exception 'EMERGENCY_ALERT_NOT_FOUND'; end if;
  new.retention_until:=greatest(coalesce(new.retention_until,'-infinity'::timestamptz),
    coalesce(v_alert.retention_until,clock_timestamp()+interval '3 years'),
    clock_timestamp()+interval '3 years');
  new.legal_hold:=coalesce(new.legal_hold,false) or coalesce(v_alert.legal_hold,false);
 else
  select * into v_parent from public.srk_emergency_decision_appeals where id=new.appeal_id;
  if not found then raise exception 'EMERGENCY_APPEAL_NOT_FOUND'; end if;
  new.retention_until:=greatest(coalesce(new.retention_until,'-infinity'::timestamptz),
    coalesce(v_parent.retention_until,clock_timestamp()+interval '3 years'));
  new.legal_hold:=coalesce(new.legal_hold,false) or coalesce(v_parent.legal_hold,false);
 end if;
 return new;
end $$;
drop trigger if exists srk_emergency_appeal_retention_guard on public.srk_emergency_decision_appeals;
create trigger srk_emergency_appeal_retention_guard before insert or update on public.srk_emergency_decision_appeals
for each row execute function public.srk_sync_emergency_appeal_retention();
drop trigger if exists srk_emergency_appeal_event_retention_guard on public.srk_emergency_decision_appeal_events;
create trigger srk_emergency_appeal_event_retention_guard before insert or update on public.srk_emergency_decision_appeal_events
for each row execute function public.srk_sync_emergency_appeal_retention();

create or replace function public.srk_propagate_emergency_alert_retention_to_appeals()
returns trigger language plpgsql set search_path=''
as $$
begin
 update public.srk_emergency_decision_appeals
 set retention_until=greatest(coalesce(retention_until,'-infinity'::timestamptz),
      coalesce(new.retention_until,clock_timestamp()+interval '3 years')),
     legal_hold=coalesce(new.legal_hold,false)
 where alert_id=new.id;
 update public.srk_emergency_decision_appeal_events ev
 set retention_until=greatest(coalesce(ev.retention_until,'-infinity'::timestamptz),
      coalesce(a.retention_until,clock_timestamp()+interval '3 years')),
     legal_hold=coalesce(a.legal_hold,false)
 from public.srk_emergency_decision_appeals a
 where a.alert_id=new.id and ev.appeal_id=a.id;
 return new;
end $$;
drop trigger if exists srk_emergency_alert_appeal_retention_propagation on public.srk_emergency_alerts;
create trigger srk_emergency_alert_appeal_retention_propagation
after update of retention_until,legal_hold on public.srk_emergency_alerts
for each row when (new.retention_until is distinct from old.retention_until or new.legal_hold is distinct from old.legal_hold)
execute function public.srk_propagate_emergency_alert_retention_to_appeals();

create or replace function public.srk_block_emergency_appeal_early_delete()
returns trigger language plpgsql set search_path=''
as $$
begin
 if old.legal_hold or (old.retention_until is not null and old.retention_until>clock_timestamp()) then
  raise exception 'EMERGENCY_APPEAL_RETENTION_OR_LEGAL_HOLD_ACTIVE' using errcode='55000';
 end if;
 return old;
end $$;
drop trigger if exists srk_emergency_appeal_delete_guard on public.srk_emergency_decision_appeals;
create trigger srk_emergency_appeal_delete_guard before delete on public.srk_emergency_decision_appeals
for each row execute function public.srk_block_emergency_appeal_early_delete();
drop trigger if exists srk_emergency_appeal_event_delete_guard on public.srk_emergency_decision_appeal_events;
create trigger srk_emergency_appeal_event_delete_guard before delete on public.srk_emergency_decision_appeal_events
for each row execute function public.srk_block_emergency_appeal_early_delete();

revoke all on function public.srk_sync_emergency_appeal_retention() from public,anon,authenticated;
revoke all on function public.srk_propagate_emergency_alert_retention_to_appeals() from public,anon,authenticated;
revoke all on function public.srk_block_emergency_appeal_early_delete() from public,anon,authenticated;
