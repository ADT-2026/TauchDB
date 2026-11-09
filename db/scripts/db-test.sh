#!/usr/bin/env bash
set -euo pipefail

set -a; [ -f .env ] && . ./.env; set +a

OUT=$(psql "$DIRECT_URL" -v ON_ERROR_STOP=1 \
  -f prisma/seed.sql -f prisma/tests.sql 2>&1)

echo "$OUT" | grep -E "OK|FEHLT|FEHLER" || true

if echo "$OUT" | grep -qE "FEHLT|FEHLER"; then
  echo "Tests fehlgeschlagen"
  exit 1
fi
echo "Alle Tests bestanden"