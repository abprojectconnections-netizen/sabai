#!/usr/bin/env bash
# End-to-end smoke test against a running LOCAL backend (see docs/run-local.md): register -> browse -> book -> pay (mock) -> refund.
# Needs: curl, jq. Usage: API=http://localhost:8088/api/v1 ./scripts/e2e-smoke.sh
set -euo pipefail
API=${API:-http://localhost:8088/api/v1}
email="smoke-$(date +%s)-$RANDOM@example.test"
say() { printf '\n== %s\n' "$*"; }
req() { curl -sS -w '\n%{http_code}' "$@"; }
body() { sed '$d'; }
code() { tail -n1; }

say "register"
r=$(req -X POST "$API/auth/register" -H 'Content-Type: application/json' -d "{\"email\":\"$email\",\"password\":\"password123\",\"display_name\":\"Smoke Test\"}")
[ "$(echo "$r" | code)" = 201 ] || { echo "$r"; exit 1; }
tok=$(echo "$r" | body | jq -r '.data.access_token')
auth=(-H "Authorization: Bearer $tok")

say "catalogue"
item=$(curl -sS "$API/catalog/items?limit=50" | jq -r '[.data[] | select(.category=="TOUR")][0]')
id=$(echo "$item" | jq -r .id)
date=$(date -u -d "+5 days" +%F) # more than the 48h free-cancellation window, so the refund below is due
echo "$item" | jq -c '{title,from_price,next_available_date}'

say "book (client sends no price)"
b=$(curl -sS -X POST "$API/bookings" "${auth[@]}" -H 'Content-Type: application/json' -H "Idempotency-Key: smoke-b-$email" -d "{\"items\":[{\"inventory_item_id\":\"$id\",\"service_date\":\"$date\",\"quantity\":2}]}")
echo "$b" | jq -c '.data | {id,status,payable_total}'
bid=$(echo "$b" | jq -r .data.id)

say "payment intent"
i=$(curl -sS -X POST "$API/payments/intents" "${auth[@]}" -H 'Content-Type: application/json' -H "Idempotency-Key: smoke-i-$email" -d "{\"booking_id\":\"$bid\",\"method\":\"PROMPTPAY_QR\"}")
ref=$(echo "$i" | jq -r .data.payment_reference); echo "$i" | jq -c '.data | {payment_reference,amount}'

say "simulate provider event (dev only)"
curl -sS -X POST "$API/dev/payments/simulate" "${auth[@]}" -H 'Content-Type: application/json' -d "{\"payment_reference\":\"$ref\"}" | jq -c .data

say "my booking"
curl -sS "$API/bookings/$bid" "${auth[@]}" | jq -c '.data | {status,payment_status,payable_total,refunds}'

say "refund request"
curl -sS -X POST "$API/refunds" "${auth[@]}" -H 'Content-Type: application/json' -H "Idempotency-Key: smoke-r-$email" -d "{\"booking_id\":\"$bid\",\"method\":\"ORIGINAL_METHOD\"}" | jq -c '.data // .error'

say "wallet (refund credit only)"
curl -sS "$API/wallet" "${auth[@]}" | jq -c .data
echo; echo "smoke test finished"
