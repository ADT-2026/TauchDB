#!/usr/bin/env bash
set -euo pipefail

set -a; [ -f .env ] && . ./.env; set +a

psql "$DIRECT_URL" -v ON_ERROR_STOP=1 -f prisma/seed.sql 2>&1