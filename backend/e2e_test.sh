#!/usr/bin/env bash
set -euo pipefail

if [ -z "${1-}" ]; then
  echo "Usage: $0 <base-url>"
  echo "Example: $0 https://etherworld-otp.up.railway.app"
  exit 1
fi

BASE="$1"
EMAIL="test+$(date +%s)@example.com"

echo "Sending OTP to $EMAIL..."
curl -s -X POST "$BASE/auth/send-otp" -H "Content-Type: application/json" -d "{\"email\":\"$EMAIL\"}" | jq || true

echo "NOTE: If running in TEST MODE, check your deployment logs for the printed OTP code."
