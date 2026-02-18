#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="OpenSnapper"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
BUNDLE_ID="${BUNDLE_ID:-com.opensnapper.app}"
RESET_SCREEN_CAPTURE="${RESET_SCREEN_CAPTURE:-0}"

if [[ "${1:-}" == "--reset-screen-capture" ]]; then
  RESET_SCREEN_CAPTURE=1
  shift
fi

if [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--reset-screen-capture]" >&2
  exit 1
fi

if [[ ! -d "$APP_DIR" ]]; then
  "$ROOT_DIR/scripts/build-app.sh"
fi

if [[ "$RESET_SCREEN_CAPTURE" == "1" ]]; then
  tccutil reset ScreenCapture "$BUNDLE_ID" >/dev/null 2>&1 || true
fi
open "$APP_DIR"

echo "Launched: $APP_DIR"
if [[ "$RESET_SCREEN_CAPTURE" == "1" ]]; then
  echo "Reset ScreenCapture permission for: $BUNDLE_ID"
else
  echo "ScreenCapture permission unchanged (use --reset-screen-capture or RESET_SCREEN_CAPTURE=1 to reset)"
fi
