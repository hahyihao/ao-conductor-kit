#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

nohup node "$SCRIPT_DIR/ao-event-sink.mjs" >/dev/null 2>&1 &
echo "$!"
