#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

case "${1:-}" in
  "") sql_files=(prisma/seed-ai.sql prisma/check-ai.sql) ;;
  --check) sql_files=(prisma/check-ai.sql) ;;
  *) echo "Verwendung: npm run db:seed:ai | npm run db:check:ai" >&2; exit 1 ;;
esac

# Absichtlich keine DIRECT_URL/.env: Dieser Befehl arbeitet nur im lokalen Docker.
endpoint=$(docker context inspect --format '{{.Endpoints.docker.Host}}')
case "${DOCKER_HOST:-$endpoint}" in
  unix://*) ;;
  *) echo "Bitte einen lokalen Docker-Kontext mit Unix-Socket verwenden." >&2; exit 1 ;;
esac
container="${SUPABASE_DB_CONTAINER:-supabase_db_db}"
if [ "$(docker inspect --format '{{.State.Running}}' "$container" 2>/dev/null || true)" != true ]; then
  echo "Lokale Supabase-Datenbank läuft nicht. In db/: npx supabase start" >&2
  exit 1
fi

cat "${sql_files[@]}" | docker exec -i "$container" \
  psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 -f /dev/stdin
