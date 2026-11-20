#!/usr/bin/env bash
set -euo pipefail

DB_CONTAINER="${1:?Pass disposable Supabase database container name}"
ELECTRICIAN="00000000-0000-4000-8000-000000000811"
BOOKING_A="00000000-0000-4000-8000-000000000812"
BOOKING_B="00000000-0000-4000-8000-000000000813"
REFERENCE="CI-UTR-RACE-002"
TMP_DIR="$(mktemp -d)"
PID_A=""
PID_B=""

psql_db() {
  docker exec -i "$DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
}

cleanup() {
  rc=$?
  if [[ -n "$PID_B" ]]; then kill "$PID_B" 2>/dev/null || true; wait "$PID_B" 2>/dev/null || true; fi
  if [[ -n "$PID_A" ]]; then wait "$PID_A" 2>/dev/null || true; fi
  psql_db >/dev/null 2>&1 <<SQL || true
DELETE FROM public.srk_electrician_payouts WHERE booking_id IN ('$BOOKING_A','$BOOKING_B');
DELETE FROM public.service_bookings WHERE id IN ('$BOOKING_A','$BOOKING_B');
DELETE FROM public.electrician_profiles WHERE id='$ELECTRICIAN';
SQL
  if [[ $rc -ne 0 ]]; then
    for output in "$TMP_DIR"/*.out; do
      [[ -f "$output" ]] && { echo "--- $output"; cat "$output"; }
    done
  fi
  rm -rf "$TMP_DIR"
  exit "$rc"
}
trap cleanup EXIT

psql_db <<SQL
INSERT INTO public.electrician_profiles (
  id, display_name, phone, state, district, pincode, skills, active
) VALUES (
  '$ELECTRICIAN', 'CI Payout Race Test', '9000000011', 'Uttar Pradesh',
  'Kanpur', '208001', ARRAY['electrical'], false
);
INSERT INTO public.service_bookings (
  id, customer_name, phone, state, district, pincode, address, service_type
) VALUES
('$BOOKING_A','CI Race Customer A','9000000012','Uttar Pradesh','Kanpur','208001','Disposable race A','Electrical'),
('$BOOKING_B','CI Race Customer B','9000000013','Uttar Pradesh','Kanpur','208001','Disposable race B','Electrical');
SQL

# A inserts first and holds its transaction open. B must visibly wait on the
# uncommitted unique-index entry before A is allowed to commit.
(
  {
    echo "BEGIN;"
    echo "INSERT INTO public.srk_electrician_payouts (booking_id,electrician_profile_id,gross_service_amount,materials_amount,platform_commission,electrician_payable,payout_reference) VALUES ('$BOOKING_A','$ELECTRICIAN',100,0,15,85,'$REFERENCE');"
    echo "SELECT pg_sleep(10);"
    echo "COMMIT;"
  } | docker exec -e PGAPPNAME=srk_payout_race_a -i "$DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1
) >"$TMP_DIR/session-a.out" 2>&1 &
PID_A=$!

# Wait until A's INSERT has succeeded and its transaction is open before
# starting B. Without this handshake the scheduler can let B win the race,
# making the test nondeterministic and testing the wrong transaction.
A_INSERT_CONFIRMED=false
for attempt in $(seq 1 80); do
  if grep -q 'INSERT 0 1' "$TMP_DIR/session-a.out" 2>/dev/null; then
    A_INSERT_CONFIRMED=true
    break
  fi
  if ! kill -0 "$PID_A" 2>/dev/null; then
    echo "Session A exited before inserting its first payout row."
    exit 1
  fi
  sleep 0.1
done
if [[ "$A_INSERT_CONFIRMED" != true ]]; then
  echo "Session A did not confirm its insert before the concurrency check."
  exit 1
fi

docker exec -e PGAPPNAME=srk_payout_race_b -i "$DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 <<SQL >"$TMP_DIR/session-b.out" 2>&1 &
INSERT INTO public.srk_electrician_payouts (
  booking_id,electrician_profile_id,gross_service_amount,materials_amount,
  platform_commission,electrician_payable,payout_reference
) VALUES (
  '$BOOKING_B','$ELECTRICIAN',100,0,15,85,'  ci-utr-race-002  '
);
SQL
PID_B=$!

# Do not infer concurrency from a fixed sleep: prove PostgreSQL reports B
# blocked on A's uncommitted unique-key transaction before allowing A to finish.
WAIT_CONFIRMED=false
for attempt in $(seq 1 80); do
  WAIT_STATE="$(psql_db -At -c "SELECT coalesce(wait_event_type,'') || ':' || coalesce(wait_event,'') FROM pg_stat_activity WHERE application_name='srk_payout_race_b' AND state='active' LIMIT 1;")"
  if [[ "$WAIT_STATE" == "Lock:transactionid" ]]; then
    WAIT_CONFIRMED=true
    break
  fi
  if ! kill -0 "$PID_B" 2>/dev/null; then
    break
  fi
  sleep 0.1
done

if [[ "$WAIT_CONFIRMED" != true ]]; then
  echo "PostgreSQL did not confirm Session B waiting on Session A's unique-index transaction."
  exit 1
fi
echo "PASS: PostgreSQL confirmed Session B waiting on the uncommitted unique-key transaction."

wait "$PID_A"
PID_A=""

set +e
wait "$PID_B"
STATUS=$?
set -e
PID_B=""

if [[ "$STATUS" -eq 0 ]]; then
  echo "Concurrent duplicate payout reference unexpectedly succeeded."
  exit 1
fi
grep -q 'srk_electrician_payouts_unique_reference_normalized' "$TMP_DIR/session-b.out"

COUNT="$(psql_db -At -c "SELECT count(*) FROM public.srk_electrician_payouts WHERE lower(btrim(payout_reference))=lower('$REFERENCE');")"
[[ "$COUNT" == "1" ]]

echo "PASS: concurrent duplicate payout reference was rejected after unique-index conflict."
echo "PASS: exactly one concurrent payout row committed."
