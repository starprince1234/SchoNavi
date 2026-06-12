#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="${APP_ROOT:-/opt/schonavi}"
AGENT_ROOT="${BACKEND_AGENT_HOST_PATH:-$APP_ROOT/backend_agent}"
LOG_DIR="${LOG_DIR:-$APP_ROOT/logs}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/rebuild_backend_agent_indexes.log}"
PID_FILE="${PID_FILE:-$APP_ROOT/rebuild_backend_agent_indexes.pid}"
LOCK_FILE="${LOCK_FILE:-$APP_ROOT/rebuild_backend_agent_indexes.lock}"
MODE="${1:-}"

cd "$APP_ROOT"

if ! ls "$AGENT_ROOT"/raw_data/*.db >/dev/null 2>&1; then
  echo "No raw SQLite DB files found in $AGENT_ROOT/raw_data" >&2
  exit 1
fi

mkdir -p "$AGENT_ROOT/data" "$APP_ROOT/cache/chroma"
mkdir -p "$LOG_DIR"

find_backend_container() {
  local container_id
  container_id="$(
    docker ps \
      --filter "label=com.docker.compose.project=schonavi" \
      --filter "label=com.docker.compose.service=backend" \
      --format "{{.ID}}" \
      | head -n 1
  )"

  if [ -z "$container_id" ]; then
    container_id="$(
      docker ps \
        --filter "name=schonavi-backend" \
        --format "{{.ID}}" \
        | head -n 1
    )"
  fi

  echo "$container_id"
}

run_rebuild() {
  flock -n 9 || {
    echo "Another backend agent index rebuild is already running." >&2
    exit 1
  }

  local container_id
  container_id="$(find_backend_container)"

  if [ -z "$container_id" ]; then
    echo "The backend container is not running." >&2
    echo "Deploy/start the backend first so it has Doppler-injected production env vars." >&2
    exit 1
  fi

  echo "[$(date -Is)] Starting backend agent index rebuild in container $container_id"
  docker exec "$container_id" sh -lc \
    'cd "$BACKEND_AGENT_PATH" && python -m app.jobs.rebuild_all'
  echo "[$(date -Is)] Backend agent indexes rebuilt from '"$AGENT_ROOT"'/raw_data"
}

if [ "$MODE" = "--foreground" ]; then
  run_rebuild 9>"$LOCK_FILE"
  exit 0
fi

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" >/dev/null 2>&1; then
  echo "Backend agent index rebuild is already running with PID $(cat "$PID_FILE")."
  echo "Log: $LOG_FILE"
  exit 0
fi

(
  run_rebuild 9>"$LOCK_FILE"
) >>"$LOG_FILE" 2>&1 &

echo "$!" > "$PID_FILE"
echo "Backend agent index rebuild started in background with PID $(cat "$PID_FILE")."
echo "Log: $LOG_FILE"
echo "Watch with: tail -f $LOG_FILE"
