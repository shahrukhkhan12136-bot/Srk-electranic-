#!/usr/bin/env bash
set -euo pipefail

DB_CONTAINER="${1:?Pass the disposable Supabase database container name}"
ACTOR="00000000-0000-4000-8000-000000000301"
CONVERSATION="00000000-0000-4000-8000-000000000302"
SAME_KEY="00000000-0000-4000-8000-000000000303"
KEY_A="00000000-0000-4000-8000-000000000304"
KEY_B="00000000-0000-4000-8000-000000000305"
DIGEST="$(printf 'f%.0s' {1..64})"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

psql_setup() {
  docker exec -i "$DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
}

psql_setup <<SQL
INSERT INTO auth.users (id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
VALUES ('$ACTOR','authenticated','authenticated','ai-concurrency@example.test','',
        transaction_timestamp(),transaction_timestamp(),transaction_timestamp());
INSERT INTO public.srk_ai_conversations(id,owner_user_id,module_key)
VALUES ('$CONVERSATION','$ACTOR','customer_support');
SET request.jwt.claim.role='service_role';
SELECT public.srk_ai_reserve_idempotency('$ACTOR','$SAME_KEY',decode(repeat('f',64),'hex'));
SELECT public.srk_ai_reserve_idempotency('$ACTOR','$KEY_A',decode(repeat('f',64),'hex'));
SELECT public.srk_ai_reserve_idempotency('$ACTOR','$KEY_B',decode(repeat('f',64),'hex'));
SQL

# Session A completes and deliberately holds the transaction open. Session B
# starts while the idempotency row is locked and must replay the exact result.
(
  {
    echo "BEGIN;";
    echo "SET LOCAL request.jwt.claim.role='service_role';";
    echo "SELECT public.srk_ai_complete_idempotency('$ACTOR','$SAME_KEY',decode(repeat('f',64),'hex'),1,'$CONVERSATION','same-key answer',200)->>'state';";
    echo "SELECT pg_sleep(2);";
    echo "COMMIT;";
  } | timeout 25s docker exec -i "$DB_CONTAINER" psql -X -At -U postgres -d postgres -v ON_ERROR_STOP=1
) >"$TMP_DIR/same-a.out" 2>&1 &
PID_A=$!
sleep 0.3
timeout 25s docker exec -i "$DB_CONTAINER" psql -X -At -U postgres -d postgres -v ON_ERROR_STOP=1 <<SQL >"$TMP_DIR/same-b.out" 2>&1
SET request.jwt.claim.role='service_role';
WITH result AS (
 SELECT public.srk_ai_complete_idempotency('$ACTOR','$SAME_KEY',decode(repeat('f',64),'hex'),1,'$CONVERSATION','same-key answer',200) AS payload
)
SELECT CASE WHEN payload->>'state'='replay'
 AND payload->>'response_message_id'=(SELECT response_message_id::text FROM public.srk_ai_idempotency
   WHERE actor_user_id='$ACTOR' AND idempotency_key='$SAME_KEY')
 THEN 'SAME_KEY_REPLAY_OK' ELSE 'SAME_KEY_REPLAY_FAILED:'||payload::text END
FROM result;
SQL
wait "$PID_A"
grep -q 'completed' "$TMP_DIR/same-a.out"
grep -q 'SAME_KEY_REPLAY_OK' "$TMP_DIR/same-b.out"

# Distinct idempotency keys for one conversation serialize on the conversation
# row after each worker has locked its own idempotency row.
(
  {
    echo "BEGIN;";
    echo "SET LOCAL request.jwt.claim.role='service_role';";
    echo "SELECT public.srk_ai_complete_idempotency('$ACTOR','$KEY_A',decode(repeat('f',64),'hex'),1,'$CONVERSATION','different-key A',200)->>'state';";
    echo "SELECT pg_sleep(2);";
    echo "COMMIT;";
  } | timeout 25s docker exec -i "$DB_CONTAINER" psql -X -At -U postgres -d postgres -v ON_ERROR_STOP=1
) >"$TMP_DIR/different-a.out" 2>&1 &
PID_A=$!
sleep 0.3
timeout 25s docker exec -i "$DB_CONTAINER" psql -X -At -U postgres -d postgres -v ON_ERROR_STOP=1 <<SQL >"$TMP_DIR/different-b.out" 2>&1
SET request.jwt.claim.role='service_role';
SELECT public.srk_ai_complete_idempotency('$ACTOR','$KEY_B',decode(repeat('f',64),'hex'),1,'$CONVERSATION','different-key B',200)->>'state';
SQL
wait "$PID_A"
grep -q 'completed' "$TMP_DIR/different-a.out"
grep -q 'completed' "$TMP_DIR/different-b.out"

COUNT="$(psql_setup -At -c "SELECT count(*) FROM public.srk_ai_messages WHERE conversation_id='$CONVERSATION' AND sender_kind='assistant';")"
if [[ "$COUNT" != "3" ]]; then
  echo "Expected exactly 3 assistant messages after same-key and different-key races; got $COUNT"
  cat "$TMP_DIR"/*.out
  exit 1
fi

echo "PASS: concurrent same-key completion produced one exact replay and one message."
echo "PASS: concurrent different-key completions serialized on the conversation and both completed."
echo "PASS: total assistant message count is exactly 3."
