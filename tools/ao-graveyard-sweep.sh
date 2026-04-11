#!/usr/bin/env bash
set -euo pipefail

SESSIONS_ROOT="/root/.agent-orchestrator"

if ! command -v ao >/dev/null 2>&1; then
  echo "error: ao CLI not found" >&2
  exit 1
fi

tmux_available=0
if command -v tmux >/dev/null 2>&1; then
  tmux_available=1
fi

get_active_sessions() {
  ao session ls -a | awk '
    match($0, /^[[:space:]]*([^[:space:]]+).*\[([^][]+)\][[:space:]]*$/, m) {
      status = m[2]
      if (status != "killed" && status != "exited") {
        print m[1]
      }
    }
  '
}

declare -A active_sessions=()

refresh_active_sessions() {
  active_sessions=()
  while IFS= read -r session_name; do
    if [[ -n "${session_name}" ]]; then
      active_sessions["${session_name}"]=1
    fi
  done < <(get_active_sessions)
}

session_is_active_cached() {
  local session_name="$1"
  [[ -n "${active_sessions[$session_name]+x}" ]]
}

session_is_active_live() {
  local session_name="$1"
  get_active_sessions | grep -Fxq -- "${session_name}"
}

read_tmux_name() {
  local session_file="$1"
  awk -F= '
    /^tmuxName=/ {
      print substr($0, index($0, "=") + 1)
      found = 1
      exit
    }
    END {
      if (!found) {
        print ""
      }
    }
  ' "${session_file}" || true
}

has_tmux_session() {
  local tmux_name="$1"
  if [[ "${tmux_available}" -ne 1 || -z "${tmux_name}" ]]; then
    return 1
  fi

  tmux has-session -t "${tmux_name}" 2>/dev/null
}

session_files_scanned=0
active_sessions_skipped=0
kill_attempts=0
metadata_removed_by_ao=0
metadata_deleted=0
metadata_kept=0
tmux_checks_skipped=0

refresh_active_sessions

while IFS= read -r -d '' session_file; do
  session_name="$(basename "${session_file}")"
  ((session_files_scanned += 1))

  if session_is_active_cached "${session_name}"; then
    ((active_sessions_skipped += 1))
    continue
  fi

  ((kill_attempts += 1))
  echo "sweeping ${session_name}"
  ao session kill "${session_name}" >/dev/null 2>&1 || true

  if [[ ! -e "${session_file}" ]]; then
    ((metadata_removed_by_ao += 1))
    continue
  fi

  if session_is_active_live "${session_name}"; then
    ((metadata_kept += 1))
    echo "  kept: session is active"
    continue
  fi

  tmux_name="$(read_tmux_name "${session_file}")"
  if [[ "${tmux_available}" -ne 1 || -z "${tmux_name}" ]]; then
    ((tmux_checks_skipped += 1))
    ((metadata_kept += 1))
    echo "  kept: tmux verification unavailable for this metadata file"
    continue
  fi

  if has_tmux_session "${tmux_name}"; then
    ((metadata_kept += 1))
    echo "  kept: tmux session still exists (${tmux_name})"
    continue
  fi

  rm -f -- "${session_file}"
  ((metadata_deleted += 1))
  echo "  deleted metadata file"
done < <(
  find "${SESSIONS_ROOT}" \
    -path '*/sessions/archive' -prune -o \
    -path '*/sessions/*' -type f -print0
)

echo
echo "Sweep summary:"
echo "  session files scanned: ${session_files_scanned}"
echo "  active sessions skipped: ${active_sessions_skipped}"
echo "  kill attempts: ${kill_attempts}"
echo "  metadata removed by ao: ${metadata_removed_by_ao}"
echo "  metadata deleted directly: ${metadata_deleted}"
echo "  metadata kept: ${metadata_kept}"
echo "  tmux checks skipped: ${tmux_checks_skipped}"
