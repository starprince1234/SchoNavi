#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="${APP_ROOT:-/opt/schonavi}"
AGENT_ROOT="${BACKEND_AGENT_PATH:-$APP_ROOT/backend_agent}"
BACKEND_ROOT="${BACKEND_ROOT:-$APP_ROOT/web/backend}"
mkdir -p "$AGENT_ROOT/data" "$AGENT_ROOT/raw_data" "$BACKEND_ROOT"

if [ -f "$APP_ROOT/backend_src.tar.gz" ]; then
  tmp_dir="$(mktemp -d)"
  tar -xzf "$APP_ROOT/backend_src.tar.gz" -C "$tmp_dir"
  rsync -a --delete \
    --exclude ".env*" \
    --exclude ".pytest_cache/" \
    --exclude "__pycache__/" \
    "$tmp_dir/backend/" "$BACKEND_ROOT/"
  rm -rf "$tmp_dir"
fi

if [ -f "$APP_ROOT/backend_agent_src.tar.gz" ]; then
  tmp_dir="$(mktemp -d)"
  tar -xzf "$APP_ROOT/backend_agent_src.tar.gz" -C "$tmp_dir"
  rsync -a --delete \
    --exclude ".env*" \
    --exclude ".venv/" \
    --exclude ".pytest_cache/" \
    --exclude ".pytest_tmp/" \
    --exclude ".omo/" \
    --exclude ".opencode/" \
    --exclude "__pycache__/" \
    --exclude "data/" \
    --exclude "logs/" \
    "$tmp_dir/backend_agent/" "$AGENT_ROOT/"
  rm -rf "$tmp_dir"
fi

if [ -n "${RAW_DATA_SYNC_COMMAND:-}" ]; then
  cd "$AGENT_ROOT"
  bash -lc "$RAW_DATA_SYNC_COMMAND"
fi
