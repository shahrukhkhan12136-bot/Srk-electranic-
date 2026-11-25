
alter table public.srk_push_delivery_recipients
  alter column subscription_id drop not null;

alter table public.srk_push_delivery_recipients
  drop constraint srk_push_delivery_recipients_subscription_id_fkey;

alter table public.srk_push_delivery_recipients
  add constraint srk_push_delivery_recipients_subscription_id_fkey
  foreign key (subscription_id)
  references public.srk_push_subscriptions(id)
  on delete set null;

comment on column public.srk_push_delivery_recipients.subscription_id is
'Nullable after a subscription is removed; preserves recipient delivery and attempt audit history.';
