begin;
select plan(4);
select ok(
 position('metadata->>''mimetype''' in lower(pg_get_functiondef('public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint)'::regprocedure)))>0
 and position('metadata->>''size''' in lower(pg_get_functiondef('public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint)'::regprocedure)))>0,
 'attachment metadata must match actual Storage object MIME type and byte size'
);
select ok(
 position('attachment_object_metadata_mismatch' in lower(pg_get_functiondef('public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint)'::regprocedure)))>0,
 'mismatched object metadata is rejected'
);
select ok(
 exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='customer deletes only unlinked support attachments'),
 'customer cleanup policy is limited to unlinked objects'
);
select ok(
 position('not exists' in lower((select qual from pg_policies where schemaname='storage' and tablename='objects' and policyname='customer deletes only unlinked support attachments')))>0,
 'customer cannot delete attachment objects already linked to support history'
);
select * from finish();
rollback;
