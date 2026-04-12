#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel)
WORKTREE_ROOT=/root/.worktrees
LANE_ROOT=/root/lanes
DRY_RUN=0

declare -A ACTIVE_ORCHESTRATORS=()
SLOTS=(1 2 3 4)

log() {
  printf '[slot-lifecycle] %s\n' "$*"
}

warn() {
  printf '[slot-lifecycle] WARN: %s\n' "$*" >&2
}

usage() {
  cat <<'EOF'
Usage: tools/start-slot-lifecycle-workers.sh [--dry-run]

Clean stale slot orchestrator worktrees, prune the shared git worktree registry,
and then start any missing slot lifecycle/orchestrator sessions.

Options:
  --dry-run  Print planned cleanup/start actions without changing the system.
  -h, --help Show this help text.
EOF
}

run_cmd() {
  if (( DRY_RUN )); then
    log "DRY RUN: $*"
    return 0
  fi

  "$@"
}

load_active_orchestrators() {
  local status_json
  local -a status_cmd=(ao status --json)

  if ! command -v ao >/dev/null 2>&1; then
    warn "ao is not installed; falling back to tmux-only health checks"
    return 0
  fi

  if ! command -v node >/dev/null 2>&1; then
    warn "node is not installed; falling back to tmux-only health checks"
    return 0
  fi

  if command -v timeout >/dev/null 2>&1; then
    status_cmd=(timeout 15 ao status --json)
  fi

  if ! status_json=$("${status_cmd[@]}" 2>/dev/null); then
    warn "ao status is unavailable or timed out; falling back to tmux-only health checks"
    return 0
  fi

  while IFS='|' read -r project name; do
    [[ -n "$project" && -n "$name" ]] || continue
    ACTIVE_ORCHESTRATORS["$project/$name"]=1
  done < <(
    printf '%s' "$status_json" | node -e '
      const fs = require("fs");
      const raw = fs.readFileSync(0, "utf8").trim();
      if (!raw) process.exit(0);

      let items;
      try {
        items = JSON.parse(raw);
      } catch {
        process.exit(0);
      }

      for (const item of items) {
        if (!item || item.role !== "orchestrator") continue;
        if (item.activity !== "active") continue;
        if (!item.project || !item.name) continue;
        process.stdout.write(`${item.project}|${item.name}\n`);
      }
    '
  )
}

tmux_session_active() {
  local session_name="$1"

  if ! command -v tmux >/dev/null 2>&1; then
    return 1
  fi

  tmux has-session -t "$session_name" 2>/dev/null
}

slot_orchestrator_is_healthy() {
  local slot="$1"
  local session_name="$2"
  local project_id="ao-kit-slot-$slot"

  if [[ -n "${ACTIVE_ORCHESTRATORS["$project_id/$session_name"]+set}" ]]; then
    return 0
  fi

  tmux_session_active "$session_name"
}

cleanup_stale_slot_orchestrator_worktrees() {
  local slot slot_root prefix candidate session_name

  for slot in "${SLOTS[@]}"; do
    slot_root="$WORKTREE_ROOT/ao-kit-slot-$slot"
    prefix="kit${slot}-orchestrator-"

    if [[ ! -d "$slot_root" ]]; then
      log "slot $slot: no slot worktree root at $slot_root"
      continue
    fi

    shopt -s nullglob
    local candidates=("$slot_root"/${prefix}*)
    shopt -u nullglob

    if (( ${#candidates[@]} == 0 )); then
      log "slot $slot: no orchestrator worktrees to inspect"
      continue
    fi

    for candidate in "${candidates[@]}"; do
      [[ -d "$candidate" ]] || continue
      session_name=${candidate##*/}

      if slot_orchestrator_is_healthy "$slot" "$session_name"; then
        log "slot $slot: keeping healthy orchestrator worktree $candidate"
        continue
      fi

      log "slot $slot: removing stale orchestrator worktree $candidate"
      run_cmd rm -rf -- "$candidate"
    done
  done

  log "pruning shared git worktree registry"
  run_cmd git -C "$REPO_ROOT" worktree prune
}

slot_has_healthy_orchestrator() {
  local slot="$1"
  local slot_prefix="kit${slot}-orchestrator-"
  local active_key session_name

  for active_key in "${!ACTIVE_ORCHESTRATORS[@]}"; do
    [[ "$active_key" == "ao-kit-slot-$slot/$slot_prefix"* ]] && return 0
  done

  if ! command -v tmux >/dev/null 2>&1; then
    return 1
  fi

  while IFS= read -r session_name; do
    [[ "$session_name" == "$slot_prefix"* ]] && return 0
  done < <(tmux list-sessions -F '#S' 2>/dev/null || true)

  return 1
}

start_missing_slot_lifecycle_workers() {
  local slot lane_path
  local had_failures=0

  for slot in "${SLOTS[@]}"; do
    lane_path="$LANE_ROOT/kit-slot-$slot"

    if slot_has_healthy_orchestrator "$slot"; then
      log "slot $slot: skipped startup; orchestrator is already healthy"
      continue
    fi

    if [[ ! -d "$lane_path" ]]; then
      warn "slot $slot: cannot start lifecycle recovery; missing lane path $lane_path"
      had_failures=1
      continue
    fi

    log "slot $slot: starting lifecycle recovery via ao start --no-dashboard $lane_path"

    if (( DRY_RUN )); then
      continue
    fi

    if ao start --no-dashboard "$lane_path" >/dev/null; then
      log "slot $slot: startup command finished"
    else
      warn "slot $slot: ao start failed"
      had_failures=1
    fi
  done

  return $had_failures
}

main() {
  while (($# > 0)); do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        exit 1
        ;;
    esac
    shift
  done

  load_active_orchestrators
  cleanup_stale_slot_orchestrator_worktrees
  start_missing_slot_lifecycle_workers
}

main "$@"
