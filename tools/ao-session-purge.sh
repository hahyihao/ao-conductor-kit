#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <session-name>" >&2
}

log() {
  printf '[ao-session-purge] %s\n' "$*"
}

add_candidate() {
  local candidate="$1"
  local existing

  for existing in "${CANDIDATE_PATHS[@]:-}"; do
    if [[ "$existing" == "$candidate" ]]; then
      return
    fi
  done

  CANDIDATE_PATHS+=("$candidate")
}

if [[ $# -ne 1 || -z "${1:-}" ]]; then
  usage
  exit 1
fi

if ! command -v ao >/dev/null 2>&1; then
  log "Required command not found: ao"
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  log "Required command not found: git"
  exit 1
fi

SESSION_NAME="$1"
REPO_ROOT="$(git rev-parse --show-toplevel)"
COMMON_DIR="$(git rev-parse --git-common-dir)"
declare -a CANDIDATE_PATHS=()

AO_SESSION_LIST_OUTPUT=""
if ! AO_SESSION_LIST_OUTPUT="$(ao session ls 2>&1)"; then
  log "Failed to list AO sessions."
  printf '%s\n' "$AO_SESSION_LIST_OUTPUT" >&2
  exit 1
fi

if awk -v session="$SESSION_NAME" '$1 == session { found=1 } END { exit found ? 0 : 1 }' <<<"$AO_SESSION_LIST_OUTPUT"; then
  log "Session \"$SESSION_NAME\" is active in AO; running ao session kill."

  AO_KILL_OUTPUT=""
  if ! AO_KILL_OUTPUT="$(ao session kill "$SESSION_NAME" 2>&1)"; then
    if grep -Fq "SessionNotFoundError" <<<"$AO_KILL_OUTPUT" || grep -Fq "Session not found" <<<"$AO_KILL_OUTPUT"; then
      log "Session \"$SESSION_NAME\" disappeared before kill completed; continuing with worktree cleanup."
      AO_KILL_OUTPUT=""
    else
      log "ao session kill failed for \"$SESSION_NAME\"."
      printf '%s\n' "$AO_KILL_OUTPUT" >&2
      exit 1
    fi
  fi

  if [[ -n "$AO_KILL_OUTPUT" ]]; then
    printf '%s\n' "$AO_KILL_OUTPUT"
  fi
else
  log "Session \"$SESSION_NAME\" is already absent from AO; skipping ao session kill."
fi

while IFS= read -r line; do
  worktree_path="${line#worktree }"
  if [[ "$worktree_path" == /root/.worktrees/*/"$SESSION_NAME" ]]; then
    add_candidate "$worktree_path"
  fi
done < <(git worktree list --porcelain | awk '/^worktree / { print }')

shopt -s nullglob
for candidate in /root/.worktrees/*/"$SESSION_NAME"; do
  if [[ ! -d "$candidate" ]]; then
    continue
  fi

  candidate_common_dir=""
  if candidate_common_dir="$(git -C "$candidate" rev-parse --git-common-dir 2>/dev/null)" && [[ "$candidate_common_dir" == "$COMMON_DIR" ]]; then
    add_candidate "$candidate"
  fi
done
shopt -u nullglob

if [[ ${#CANDIDATE_PATHS[@]} -eq 0 ]]; then
  log "No matching worktree directory found under /root/.worktrees for \"$SESSION_NAME\"."
else
  for candidate in "${CANDIDATE_PATHS[@]}"; do
    if [[ "$candidate" == "$REPO_ROOT" ]]; then
      log "Refusing to remove the current worktree: $candidate"
      continue
    fi

    if [[ -d "$candidate" ]]; then
      log "Removing worktree directory: $candidate"
      rm -rf -- "$candidate"
    else
      log "Worktree directory already absent: $candidate"
    fi
  done
fi

log "Running git worktree prune."
git worktree prune

log "Purge complete for \"$SESSION_NAME\"."
