#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="OpenSnapper"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"

build_and_launch() {
  pkill -f "${APP_NAME}.app/Contents/MacOS/${APP_NAME}" >/dev/null 2>&1 || true
  "$ROOT_DIR/scripts/build-app.sh" >/dev/null
  sleep 0.15
  open -n "$APP_DIR" >/dev/null 2>&1 || open "$APP_DIR"
  echo "[$(date +%H:%M:%S)] Rebuilt and relaunched"
}

snapshot_hash() {
  {
    find "$ROOT_DIR/Sources" -type f -name '*.swift' -print
    find "$ROOT_DIR/Resources" -type f -print 2>/dev/null || true
    echo "$ROOT_DIR/Package.swift"
  } | sort | xargs stat -f '%N %m' 2>/dev/null | shasum | awk '{print $1}'
}

echo "Starting OpenSnapper dev watch..."
build_and_launch

if command -v fswatch >/dev/null 2>&1; then
  echo "Watching with fswatch (Ctrl+C to stop)"
  fswatch -o "$ROOT_DIR/Sources" "$ROOT_DIR/Resources" "$ROOT_DIR/Package.swift" | while read -r _; do
    sleep 0.15
    build_and_launch || echo "Build failed, watching for next change..."
  done
else
  echo "fswatch not found; using polling every 1s (Ctrl+C to stop)"
  last_hash="$(snapshot_hash)"
  while true; do
    sleep 1
    current_hash="$(snapshot_hash)"
    if [[ "$current_hash" != "$last_hash" ]]; then
      last_hash="$current_hash"
      build_and_launch || echo "Build failed, watching for next change..."
    fi
  done
fi
