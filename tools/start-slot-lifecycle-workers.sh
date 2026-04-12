#!/usr/bin/env bash
# Purpose: Clear stale slot orchestrator worktrees safely, then ensure the four
# AO Kit slot lifecycle workers are running without duplicating healthy ones.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel)
AO_CONFIG_FILE="$REPO_ROOT/agent-orchestrator.yaml"
CORE_DIST="/root/agent-orchestrator/packages/core/dist/index.js"
LIFECYCLE_SERVICE_DIST="/root/agent-orchestrator/packages/cli/dist/lib/lifecycle-service.js"
WORKTREE_ROOT=/root/.worktrees
DRY_RUN=0

declare -A ACTIVE_ORCHESTRATORS=()
SLOTS=(1 2 3 4)
SLOT_PROJECTS=(
	"ao-kit-slot-1"
	"ao-kit-slot-2"
	"ao-kit-slot-3"
	"ao-kit-slot-4"
)

log() {
	printf '[slot-lifecycle] %s\n' "$*"
}

die() {
	printf '[slot-lifecycle] ERROR: %s\n' "$*" >&2
	exit 1
}

warn() {
	printf '[slot-lifecycle] WARN: %s\n' "$*" >&2
}

usage() {
	cat <<'EOF'
Usage: tools/start-slot-lifecycle-workers.sh [--dry-run]

Clean stale slot orchestrator worktrees, prune the shared git worktree registry,
and then ensure the four slot lifecycle workers are healthy.

Options:
  --dry-run  Print planned cleanup/start actions without changing the system.
  -h, --help Show this help text.
EOF
}

run_cmd() {
	if ((DRY_RUN)); then
		log "DRY RUN: $*"
		return 0
	fi

	"$@"
}

run_ao() {
	(
		cd "$REPO_ROOT"
		AO_CONFIG_PATH="$AO_CONFIG_FILE" "$@"
	)
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

	if ! status_json=$(run_ao "${status_cmd[@]}" 2>/dev/null); then
		warn "ao status is unavailable or timed out; falling back to tmux-only health checks"
		return 0
	fi

	while IFS='|' read -r project name; do
		[[ -n "$project" && -n "$name" ]] || continue
		ACTIVE_ORCHESTRATORS["$project/$name"]=1
	done < <(
		STATUS_JSON="$status_json" node <<'EOF'
const raw = (process.env.STATUS_JSON ?? "").trim();
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
EOF
	)
}

tmux_session_active() {
	local expected_name="$1"
	local session_name

	if ! command -v tmux >/dev/null 2>&1; then
		return 1
	fi

	while IFS= read -r session_name; do
		[[ "$session_name" == "$expected_name" || "$session_name" == *-"$expected_name" ]] && return 0
	done < <(tmux list-sessions -F '#S' 2>/dev/null || true)

	return 1
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
	local -a candidates=()

	for slot in "${SLOTS[@]}"; do
		slot_root="$WORKTREE_ROOT/ao-kit-slot-$slot"
		prefix="kit${slot}-orchestrator-"

		if [[ ! -d "$slot_root" ]]; then
			log "slot $slot: no slot worktree root at $slot_root"
			continue
		fi

		mapfile -d '' -t candidates < <(
			find "$slot_root" -mindepth 1 -maxdepth 1 -type d -name "${prefix}*" -print0
		)

		if ((${#candidates[@]} == 0)); then
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

ensure_slot_lifecycle_workers() {
	AO_CONFIG_PATH="$AO_CONFIG_FILE" DRY_RUN="$DRY_RUN" node --input-type=module - "${SLOT_PROJECTS[@]}" <<'NODE'
const projectIds = process.argv.slice(2);
const dryRun = process.env["DRY_RUN"] === "1";

const { loadConfig } = await import("/root/agent-orchestrator/packages/core/dist/index.js");
const { ensureLifecycleWorker, getLifecycleWorkerStatus } = await import(
  "/root/agent-orchestrator/packages/cli/dist/lib/lifecycle-service.js"
);

const configPath = process.env["AO_CONFIG_PATH"] ?? "";
const config = loadConfig();
let failed = false;

for (const projectId of projectIds) {
  if (!config.projects[projectId]) {
    console.error(`[slot-lifecycle] ERROR: ${projectId} is missing from ${configPath}`);
    failed = true;
    continue;
  }

  try {
    if (dryRun) {
      const status = getLifecycleWorkerStatus(config, projectId);
      const pid = status.pid ?? "unknown";
      const action = status.running ? "would skip" : "would start";
      const reason = status.running ? `already running (PID ${pid})` : "worker not running";
      console.log(`[slot-lifecycle] ${action} ${projectId} ${reason} log=${status.logFile}`);
      continue;
    }

    const status = await ensureLifecycleWorker(config, projectId);
    const pid = status.pid ?? "unknown";
    const action = status.started ? "started" : "skipped";
    const reason = status.started ? `PID ${pid}` : `already running (PID ${pid})`;
    console.log(`[slot-lifecycle] ${action} ${projectId} ${reason} log=${status.logFile}`);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[slot-lifecycle] ERROR: ${projectId} ${message}`);
    failed = true;
  }
}

if (failed) {
  process.exit(1);
}
NODE
}

main() {
	while (($# > 0)); do
		case "$1" in
		--dry-run)
			DRY_RUN=1
			;;
		-h | --help)
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

	[[ -f "$AO_CONFIG_FILE" ]] || die "agent-orchestrator config not found at $AO_CONFIG_FILE"
	[[ -f "$CORE_DIST" ]] || die "AO core build not found at $CORE_DIST"
	[[ -f "$LIFECYCLE_SERVICE_DIST" ]] || die "AO CLI lifecycle service not found at $LIFECYCLE_SERVICE_DIST"

	load_active_orchestrators
	cleanup_stale_slot_orchestrator_worktrees
	ensure_slot_lifecycle_workers
}

main "$@"
