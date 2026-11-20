#!/usr/bin/env bash
set -euo pipefail

DB_CONTAINER="${1:?Pass disposable Supabase database container name}"
ELECTRICIAN="00000000-0000-4000-8000-000000000811"
BOOKING_A="00000000-0000-4000-8000-000000000812"
BOOKING_B="00000000-0000-4000-8000-000000000813"
REFERENCE="CI-UTR-RACE-002"
TMP_DIR="$(mktemp -d)"
PID_A=""

psql_db() {
  docker exec -i "$DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
}

cleanup() {
  rc=$?
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

# Session A holds the unique-index key until it commits. Session B attempts the
# same normalized reference while A is uncommitted and must fail after waiting.
(
  {
    echo "BEGIN;"
    echo "INSERT INTO public.srk_electrician_payouts (booking_id,electrician_profile_id,gross_service_amount,materials_amount,platform_commission,electrician_payable,payout_reference) VALUES ('$BOOKING_A','$ELECTRICIAN',100,0,15,85,'$REFERENCE');"
    echo "SELECT pg_sleep(2);"
    echo "COMMIT;"
  } | timeout 20s docker exec -i "$DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1
) >"$TMP_DIR/session-a.out" 2>&1 &
PID_A=$!
sleep 0.3

set +e
timeout 20s docker exec -i "$DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 <<SQL >"$TMP_DIR/session-b.out" 2>&1
INSERT INTO public.srk_electrician_payouts (
  booking_id,electrician_profile_id,gross_service_amount,materials_amount,
  platform_commission,electrician_payable,payout_reference
) VALUES (
  '$BOOKING_B','$ELECTRICIAN',100,0,15,85,'  ci-utr-race-002  '
);
SQL
STATUS=$?
set -e

wait "$PID_A"
PID_A=""

if [[ "$STATUS" -eq 0 ]]; then
  echo "Concurrent duplicate payout reference unexpectedly succeeded."
  exit 1
fi
grep -q 'srk_electrician_payouts_unique_reference_normalized' "$TMP_DIR/session-b.out"

COUNT="$(psql_db -At -c "SELECT count(*) FROM public.srk_electrician_payouts WHERE lower(btrim(payout_reference))=lower('$REFERENCE');")"
[[ "$COUNT" == "1" ]]

echo "PASS: concurrent duplicate payout reference was rejected after unique-index conflict."
echo "PASS: exactly one concurrent payout row committed."
