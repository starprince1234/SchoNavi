#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="${APP_ROOT:-/opt/schonavi}"
COMPOSE_FILE="${COMPOSE_FILE:-$APP_ROOT/docker-compose.prod.yml}"
AGENT_ROOT="${BACKEND_AGENT_HOST_PATH:-$APP_ROOT/backend_agent}"

cd "$APP_ROOT"

if ! ls "$AGENT_ROOT"/raw_data/*.db >/dev/null 2>&1; then
  echo "No raw SQLite DB files found in $AGENT_ROOT/raw_data" >&2
  exit 1
fi

mkdir -p "$AGENT_ROOT/data" "$APP_ROOT/cache/chroma"

if ! docker compose -f "$COMPOSE_FILE" ps --status running --services | grep -qx "backend"; then
  echo "The backend container is not running." >&2
  echo "Deploy/start the backend first so it has Doppler-injected production env vars." >&2
  exit 1
fi

docker compose -f "$COMPOSE_FILE" exec -T backend sh -lc \
  'cd "$BACKEND_AGENT_PATH" && python -m app.jobs.rebuild_all'

echo "Backend agent indexes rebuilt from $AGENT_ROOT/raw_data"
