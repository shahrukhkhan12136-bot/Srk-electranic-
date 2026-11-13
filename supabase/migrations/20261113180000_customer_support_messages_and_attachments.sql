-- Customer support message thread and private attachment storage.
-- Source-only migration: do not apply to the live project until reviewed and approved.

create table if not exists public.srk_booking_complaint_messages (
  id uuid primary key default gen_random_uuid(),
  complaint_id uuid not null references public.srk_booking_complaints(id) on delete cascade,
  sender_user_id uuid not null references auth.users(id),
  sender_role text not null check (sender_role in ('customer','admin')),
  body text not null check (length(btrim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);

create index if not exists srk_booking_complaint_messages_thread_idx
  on public.srk_booking_complaint_messages (complaint_id, created_at, id);

alter table public.srk_booking_complaint_messages enable row level security;
revoke all on public.srk_booking_complaint_messages from anon, authenticated;

-- Customer-facing reads are constrained through complaint ownership.
create policy "customer reads own complaint messages"
on public.srk_booking_complaint_messages
for select to authenticated
using (
  sender_role in ('customer','admin')
  and exists (
    select 1 from public.srk_booking_complaints c
    where c.id = complaint_id and c.customer_user_id = (select auth.uid())
  )
);

create or replace function public.srk_customer_send_booking_complaint_message(
  p_complaint_id uuid,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_message_id uuid;
begin
  if v_user_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '28000';
  end if;

  if p_complaint_id is null
     or p_body is null
     or length(btrim(p_body)) < 1
     or length(btrim(p_body)) > 4000 then
    raise exception 'INVALID_MESSAGE' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.srk_booking_complaints c
    where c.id = p_complaint_id
      and c.customer_user_id = v_user_id
      and c.status <> 'closed'
  ) then
    raise exception 'COMPLAINT_NOT_AVAILABLE' using errcode = '42501';
  end if;

  insert into public.srk_booking_complaint_messages
    (complaint_id, sender_user_id, sender_role, body)
  values
    (p_complaint_id, v_user_id, 'customer', btrim(p_body))
  returning id into v_message_id;

  return v_message_id;
end;
$function$;

create or replace function public.srk_customer_list_booking_complaint_messages(
  p_complaint_id uuid
)
returns table (
  id uuid,
  sender_role text,
  body text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '28000';
  end if;

  if not exists (
    select 1 from public.srk_booking_complaints c
    where c.id = p_complaint_id and c.customer_user_id = v_user_id
  ) then
    raise exception 'COMPLAINT_NOT_AVAILABLE' using errcode = '42501';
  end if;

  return query
    select m.id, m.sender_role, m.body, m.created_at
    from public.srk_booking_complaint_messages m
    where m.complaint_id = p_complaint_id
    order by m.created_at asc, m.id asc
    limit 200;
end;
$function$;

revoke all on function public.srk_customer_send_booking_complaint_message(uuid,text) from public, anon;
grant execute on function public.srk_customer_send_booking_complaint_message(uuid,text) to authenticated;
revoke all on function public.srk_customer_list_booking_complaint_messages(uuid) from public, anon;
grant execute on function public.srk_customer_list_booking_complaint_messages(uuid) to authenticated;

-- Private, narrowly scoped support attachments. Object path:
-- <customer-auth-uid>/<complaint-id>/<random-object-name>
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'srk-customer-support',
  'srk-customer-support',
  false,
  10485760,
  array['image/jpeg','image/png','image/webp','application/pdf']::text[]
)
on conflict (id) do update
set public = false,
    file_size_limit = 10485760,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "customer uploads support attachments to own complaint"
on storage.objects
for insert to authenticated
with check (
  bucket_id = 'srk-customer-support'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (
    select 1 from public.srk_booking_complaints c
    where c.id::text = (storage.foldername(name))[2]
      and c.customer_user_id = (select auth.uid())
      and c.status <> 'closed'
  )
);

create policy "customer reads support attachments for own complaint"
on storage.objects
for select to authenticated
using (
  bucket_id = 'srk-customer-support'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (
    select 1 from public.srk_booking_complaints c
    where c.id::text = (storage.foldername(name))[2]
      and c.customer_user_id = (select auth.uid())
  )
);

create policy "customer deletes support attachments for own complaint"
on storage.objects
for delete to authenticated
using (
  bucket_id = 'srk-customer-support'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (
    select 1 from public.srk_booking_complaints c
    where c.id::text = (storage.foldername(name))[2]
      and c.customer_user_id = (select auth.uid())
  )
);
