#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)
CONFIG_FILE="${REPO_ROOT}/agent-orchestrator.yaml"
WORKTREE_ROOT="${AO_WORKTREE_ROOT:-/root/.worktrees}"

usage() {
  cat <<'EOF'
Usage: tools/ao-session-purge.sh <session-name>

Kill an AO session if it still exists, remove its stale worktree directory,
and prune Git's worktree registry.

Optional environment variables:
  AO_PROJECT_SLUG   Override the project slug from agent-orchestrator.yaml
  AO_WORKTREE_ROOT  Override the worktree root (default: /root/.worktrees)
EOF
}

log() {
  printf '[ao-session-purge] %s\n' "$*"
}

die() {
  log "ERROR: $*"
  exit 1
}

resolve_project_slug() {
  if [[ -n "${AO_PROJECT_SLUG:-}" ]]; then
    printf '%s\n' "${AO_PROJECT_SLUG}"
    return 0
  fi

  [[ -f "${CONFIG_FILE}" ]] || die "missing ${CONFIG_FILE}; set AO_PROJECT_SLUG to continue"

  awk '
    /^projects:[[:space:]]*$/ { in_projects = 1; next }
    in_projects && /^[^[:space:]]/ { exit }
    in_projects && match($0, /^  ([^:#[:space:]]+):[[:space:]]*$/, m) {
      print m[1]
      exit
    }
  ' "${CONFIG_FILE}"
}

session_exists() {
  local session_name=$1
  ao session ls 2>/dev/null | grep -Eq "^[[:space:]]+${session_name}([[:space:]]|$)"
}

[[ $# -eq 1 ]] || {
  usage >&2
  exit 1
}

command -v ao >/dev/null 2>&1 || die "ao CLI not found in PATH"
command -v git >/dev/null 2>&1 || die "git not found in PATH"

SESSION_NAME=$1
PROJECT_SLUG=$(resolve_project_slug)
[[ -n "${PROJECT_SLUG}" ]] || die "could not determine project slug from ${CONFIG_FILE}"

CURRENT_WORKTREE_NAME=$(basename -- "${REPO_ROOT}")
if [[ "${SESSION_NAME}" == "${CURRENT_WORKTREE_NAME}" ]]; then
  die "refusing to purge the current worktree (${SESSION_NAME}) from inside itself"
fi

WORKTREE_DIR="${WORKTREE_ROOT}/${PROJECT_SLUG}/${SESSION_NAME}"

log "repo root: ${REPO_ROOT}"
log "project slug: ${PROJECT_SLUG}"
log "target session: ${SESSION_NAME}"
log "target worktree: ${WORKTREE_DIR}"

if session_exists "${SESSION_NAME}"; then
  log "session exists in AO; running: ao session kill ${SESSION_NAME}"
  ao session kill "${SESSION_NAME}"
else
  log "session not present in AO; skipping ao session kill"
fi

if [[ -e "${WORKTREE_DIR}" ]]; then
  log "removing stale worktree directory"
  rm -rf -- "${WORKTREE_DIR}"
else
  log "worktree directory already absent; nothing to remove"
fi

log "pruning git worktree metadata"
git -C "${REPO_ROOT}" worktree prune

log "done"
