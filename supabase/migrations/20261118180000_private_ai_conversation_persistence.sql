-- Private, service-role-only persistence foundation for the AI assistant.
-- This migration creates storage only; it does not enable AI routes or invoke a provider.
-- SOURCE ONLY: review and replay the complete migration set before applying anywhere.

BEGIN;

CREATE TABLE IF NOT EXISTS public.srk_ai_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  module_key text NOT NULL CHECK (module_key IN (
    'customer_support','booking_assistant','electrician_assistant'
  )),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','handoff_requested','closed')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  closed_at timestamptz,
  CONSTRAINT srk_ai_conversation_closed_state_check
    CHECK ((status='closed') = (closed_at IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS srk_ai_conversations_owner_updated_idx
  ON public.srk_ai_conversations(owner_user_id,updated_at DESC,id DESC);
CREATE INDEX IF NOT EXISTS srk_ai_conversations_status_updated_idx
  ON public.srk_ai_conversations(status,updated_at DESC);

CREATE TABLE IF NOT EXISTS public.srk_ai_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL
    REFERENCES public.srk_ai_conversations(id) ON DELETE RESTRICT,
  sequence_no bigint GENERATED ALWAYS AS IDENTITY,
  sender_kind text NOT NULL CHECK (sender_kind IN ('user','assistant','human_agent')),
  sender_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  body text NOT NULL CHECK (length(btrim(body)) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT srk_ai_message_sender_identity_check CHECK (
    (sender_kind='assistant' AND sender_user_id IS NULL)
    OR (sender_kind IN ('user','human_agent') AND sender_user_id IS NOT NULL)
  ),
  CONSTRAINT srk_ai_message_conversation_sequence_key UNIQUE (conversation_id,sequence_no),
  CONSTRAINT srk_ai_message_id_conversation_key UNIQUE (id,conversation_id)
);

CREATE INDEX IF NOT EXISTS srk_ai_messages_thread_idx
  ON public.srk_ai_messages(conversation_id,sequence_no,id);

-- Store only a request digest and processing result reference, never the raw request body.
CREATE TABLE IF NOT EXISTS public.srk_ai_idempotency (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  idempotency_key uuid NOT NULL,
  request_sha256 bytea NOT NULL CHECK (octet_length(request_sha256)=32),
  status text NOT NULL DEFAULT 'processing'
    CHECK (status IN ('processing','completed','failed')),
  conversation_id uuid REFERENCES public.srk_ai_conversations(id) ON DELETE RESTRICT,
  response_message_id uuid,
  response_code integer CHECK (response_code BETWEEN 100 AND 599),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  completed_at timestamptz,
  failed_at timestamptz,
  processing_lease_expires_at timestamptz,
  retention_expires_at timestamptz,
  lease_version bigint NOT NULL DEFAULT 1 CHECK (lease_version > 0),
  CONSTRAINT srk_ai_idempotency_actor_key UNIQUE(actor_user_id,idempotency_key),
  CONSTRAINT srk_ai_idempotency_response_message_fk
    FOREIGN KEY (response_message_id,conversation_id)
    REFERENCES public.srk_ai_messages(id,conversation_id) ON DELETE RESTRICT,
  CONSTRAINT srk_ai_idempotency_state_check CHECK (
    (status='processing'
      AND completed_at IS NULL AND failed_at IS NULL
      AND response_message_id IS NULL AND response_code IS NULL
      AND processing_lease_expires_at IS NOT NULL
      AND retention_expires_at IS NULL)
    OR
    (status='completed'
      AND completed_at IS NOT NULL AND failed_at IS NULL
      AND response_message_id IS NOT NULL AND response_code IS NOT NULL
      AND processing_lease_expires_at IS NULL
      AND retention_expires_at IS NOT NULL
      AND conversation_id IS NOT NULL)
    OR
    (status='failed'
      AND completed_at IS NULL AND failed_at IS NOT NULL
      AND response_message_id IS NULL AND response_code IS NOT NULL
      AND processing_lease_expires_at IS NULL
      AND retention_expires_at IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS srk_ai_idempotency_processing_lease_idx
  ON public.srk_ai_idempotency(processing_lease_expires_at)
  WHERE status='processing';
CREATE INDEX IF NOT EXISTS srk_ai_idempotency_retention_idx
  ON public.srk_ai_idempotency(retention_expires_at)
  WHERE status IN ('completed','failed');

CREATE TABLE IF NOT EXISTS public.srk_ai_handoff_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL
    REFERENCES public.srk_ai_conversations(id) ON DELETE RESTRICT,
  requested_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  reason_code text NOT NULL CHECK (reason_code IN (
    'needs_human_support','safety_concern','account_issue','billing_question','other'
  )),
  urgency text NOT NULL DEFAULT 'normal' CHECK (urgency IN ('low','normal','high')),
  summary text NOT NULL CHECK (length(btrim(summary)) BETWEEN 1 AND 1000),
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued','assigned','resolved','cancelled')),
  assigned_to uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  resolved_at timestamptz,
  CONSTRAINT srk_ai_handoff_assignment_check CHECK (
    (status='assigned' AND assigned_to IS NOT NULL)
    OR status<>'assigned'
  ),
  CONSTRAINT srk_ai_handoff_resolution_check CHECK (
    (status='resolved') = (resolved_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS srk_ai_handoff_one_open_per_conversation_uidx
  ON public.srk_ai_handoff_queue(conversation_id)
  WHERE status IN ('queued','assigned');
CREATE INDEX IF NOT EXISTS srk_ai_handoff_queue_status_created_idx
  ON public.srk_ai_handoff_queue(status,created_at);

-- Metadata-only audit: deliberately no prompt, message body, token, or provider payload columns.
CREATE TABLE IF NOT EXISTS public.srk_ai_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid REFERENCES public.srk_ai_conversations(id) ON DELETE RESTRICT,
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  module_key text NOT NULL CHECK (module_key IN (
    'customer_support','booking_assistant','electrician_assistant'
  )),
  action_key text NOT NULL CHECK (action_key IN (
    'conversation_created','message_recorded','handoff_requested',
    'handoff_assigned','handoff_resolved','request_rejected'
  )),
  outcome text NOT NULL CHECK (outcome IN ('accepted','completed','rejected','failed')),
  request_id uuid,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX IF NOT EXISTS srk_ai_audit_conversation_created_idx
  ON public.srk_ai_audit_events(conversation_id,created_at DESC);
CREATE INDEX IF NOT EXISTS srk_ai_audit_actor_created_idx
  ON public.srk_ai_audit_events(actor_user_id,created_at DESC);

ALTER TABLE public.srk_ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_ai_idempotency ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_ai_handoff_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_ai_audit_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.srk_ai_conversations FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.srk_ai_messages FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.srk_ai_idempotency FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.srk_ai_handoff_queue FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.srk_ai_audit_events FROM PUBLIC,anon,authenticated;

GRANT ALL ON TABLE public.srk_ai_conversations TO service_role;
GRANT ALL ON TABLE public.srk_ai_messages TO service_role;
GRANT ALL ON TABLE public.srk_ai_idempotency TO service_role;
GRANT ALL ON TABLE public.srk_ai_handoff_queue TO service_role;
GRANT ALL ON TABLE public.srk_ai_audit_events TO service_role;

CREATE OR REPLACE FUNCTION public.srk_reject_ai_audit_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $function$
BEGIN
  RAISE EXCEPTION 'AI_AUDIT_EVENTS_ARE_APPEND_ONLY' USING ERRCODE='55000';
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_reject_ai_audit_mutation() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER srk_ai_audit_events_append_only
  BEFORE UPDATE OR DELETE ON public.srk_ai_audit_events
  FOR EACH ROW EXECUTE FUNCTION public.srk_reject_ai_audit_mutation();

COMMIT;
