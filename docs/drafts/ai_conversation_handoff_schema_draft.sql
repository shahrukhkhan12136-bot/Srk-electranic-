-- DRAFT ONLY. Review and rename into supabase/migrations only after approval.
-- Do not apply to any database from this draft.
BEGIN;
CREATE TABLE public.srk_ai_conversations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 owner_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 actor_type text NOT NULL CHECK(actor_type IN ('customer','electrician')),
 module_key text NOT NULL CHECK((actor_type='customer' AND module_key IN ('customer_support','booking_assistant')) OR (actor_type='electrician' AND module_key='electrician_assistant')),
 status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','handoff_pending','closed')),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 closed_at timestamptz, CHECK((status='closed')=(closed_at IS NOT NULL)), UNIQUE(id,owner_user_id)
);
CREATE INDEX srk_ai_conversations_owner_recent_idx ON public.srk_ai_conversations(owner_user_id,updated_at DESC,id);
CREATE TABLE public.srk_ai_messages (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 conversation_id uuid NOT NULL REFERENCES public.srk_ai_conversations(id) ON DELETE CASCADE,
 sequence_no bigint NOT NULL CHECK(sequence_no>0),
 sender_type text NOT NULL CHECK(sender_type IN ('user','assistant','system')),
 body text NOT NULL CHECK(length(btrim(body)) BETWEEN 1 AND 8000),
 provider_request_id text CHECK(provider_request_id IS NULL OR length(provider_request_id)<=200),
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(conversation_id,sequence_no)
);
CREATE INDEX srk_ai_messages_conversation_order_idx ON public.srk_ai_messages(conversation_id,sequence_no);
CREATE TABLE public.srk_ai_idempotency (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 owner_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 endpoint_key text NOT NULL CHECK(endpoint_key IN ('assistant','handoff','action')),
 idempotency_key text NOT NULL CHECK(length(idempotency_key) BETWEEN 16 AND 128),
 request_hash text NOT NULL CHECK(request_hash ~ '^[0-9a-f]{64}$'),
 state text NOT NULL CHECK(state IN ('processing','completed','failed_retryable')),
 response_status integer CHECK(response_status BETWEEN 100 AND 599),
 response_body jsonb CHECK(response_body IS NULL OR pg_column_size(response_body)<=65536),
 lease_expires_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL,
 UNIQUE(owner_user_id,endpoint_key,idempotency_key),
 CHECK(expires_at>created_at),
 CHECK ((state='completed' AND response_status IS NOT NULL AND response_body IS NOT NULL) OR (state<>'completed' AND response_status IS NULL AND response_body IS NULL)),
 CHECK ((state='processing')=(lease_expires_at IS NOT NULL))
);
CREATE INDEX srk_ai_idempotency_expiry_idx ON public.srk_ai_idempotency(expires_at);
CREATE TABLE public.srk_ai_handoffs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 conversation_id uuid NOT NULL,
 owner_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 queue_key text NOT NULL CHECK(queue_key IN ('main_admin')),
 reason_code text NOT NULL CHECK(reason_code IN ('user_requested','ai_uncertain','safety','service_issue','other')),
 urgency text NOT NULL DEFAULT 'normal' CHECK(urgency IN ('low','normal','high')),
 summary text NOT NULL CHECK(length(btrim(summary)) BETWEEN 1 AND 2000),
 status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','assigned','in_progress','resolved','cancelled')),
 assigned_staff_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 FOREIGN KEY(conversation_id,owner_user_id) REFERENCES public.srk_ai_conversations(id,owner_user_id) ON DELETE CASCADE,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), resolved_at timestamptz
);
CREATE UNIQUE INDEX srk_ai_handoffs_one_open_per_conversation_uidx ON public.srk_ai_handoffs(conversation_id) WHERE status IN ('queued','assigned','in_progress');
CREATE INDEX srk_ai_handoffs_queue_recent_idx ON public.srk_ai_handoffs(queue_key,status,created_at,id);
CREATE TABLE public.srk_ai_audit_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 actor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 actor_type text NOT NULL CHECK(actor_type IN ('customer','electrician','staff','main_admin','system')),
 module_key text NOT NULL CHECK(module_key IN ('customer_support','booking_assistant','electrician_assistant','system')),
 event_type text NOT NULL CHECK(event_type IN ('conversation_created','message_persisted','provider_requested','provider_failed','handoff_created','handoff_status_changed','access_denied','rate_limited','safety_block')),
 outcome text NOT NULL CHECK(outcome IN ('allowed','denied','success','failure')),
 conversation_id uuid REFERENCES public.srk_ai_conversations(id) ON DELETE SET NULL,
 handoff_id uuid REFERENCES public.srk_ai_handoffs(id) ON DELETE SET NULL,
 correlation_id uuid, idempotency_key text CHECK(idempotency_key IS NULL OR length(idempotency_key)<=128),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK(pg_column_size(metadata)<=8192),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX srk_ai_audit_events_recent_idx ON public.srk_ai_audit_events(created_at DESC,id);
CREATE INDEX srk_ai_audit_events_correlation_idx ON public.srk_ai_audit_events(correlation_id) WHERE correlation_id IS NOT NULL;
ALTER TABLE public.srk_ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_ai_idempotency ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_ai_handoffs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_ai_audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_ai_conversations,public.srk_ai_messages,public.srk_ai_idempotency,public.srk_ai_handoffs,public.srk_ai_audit_events FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.srk_ai_conversations,public.srk_ai_messages,public.srk_ai_idempotency,public.srk_ai_handoffs TO service_role;
GRANT SELECT,INSERT ON public.srk_ai_audit_events TO service_role;
COMMIT;
