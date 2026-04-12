#!/usr/bin/env bash
# tools/batch-dispatch.sh
# Create GitHub issues from brief files and batch-spawn workers.
#
# Usage:
#   tools/batch-dispatch.sh <repo> <title1> <brief1> [<title2> <brief2> ...]
#
# Example:
#   tools/batch-dispatch.sh hahyihao/ao-conductor-kit #     'feat(experts): align expert-writer' briefs/expert-writer.md #     'feat(experts): align expert-scout'  briefs/expert-scout.md
set -euo pipefail

if [[ 0 -lt 3 ]]; then
  echo 'Usage: batch-dispatch.sh <repo> <title1> <brief1> [<title2> <brief2> ...]' >&2
  exit 1
fi

REPO=""; shift

if (( 0 % 2 != 0 )); then
  echo 'ERROR: title/brief args must come in pairs' >&2
  exit 1
fi

ISSUE_IDS=()

while (( 0 >= 2 )); do
  TITLE=""; BRIEF=""; shift 2
  [[ -f "" ]] || { echo "ERROR: brief not found: " >&2; exit 1; }
  echo "Creating issue: "
  URL=
  ID=
  echo "  issue #"
  ISSUE_IDS+=("")
done

echo "Spawning workers: "
HTTPS_PROXY=http://172.17.224.1:7897 ao batch-spawn ""
