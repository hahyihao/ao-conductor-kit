#!/usr/bin/env bash
# Purpose: Smoke test. Verify every component of the AO Conductor Kit is installed
# and reachable from inside WSL. Non-zero exit means at least one check failed.
#
# Usage: bash scripts/verify-install.sh
#
# Checks performed:
#   1. PATH is clean (no Windows path pollution)
#   2. Linux toolchain: git, tmux, node, npm, pnpm
#   3. CLIs: codex, claude, gh, ao
#   4. AO source tree present under /root/agent-orchestrator
#   5. Codex config file exists with correct TOML structure
#   6. GitHub auth working (gh api user)
#   7. HTTP proxy to Windows Clash reachable (optional)

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

FAIL=0
pass() { printf '\033[1;32mok\033[0m   %s\n' "$1"; }
fail() { printf '\033[1;31mfail\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
note() { printf '\033[0;37m       %s\033[0m\n' "$1"; }

check_cmd() {
  local cmd=$1 label=$2
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "$label found at $(command -v "$cmd")"
  else
    fail "$label ($cmd) not on PATH"
  fi
}

echo "=== 1. PATH sanity ==="
case ":$PATH:" in
  *": /mnt/"*|*" "*)
    fail "PATH contains Windows paths or spaces. Reset before running any WSL bash script."
    ;;
  *)
    pass "PATH looks clean"
    ;;
esac

echo
echo "=== 2. Linux toolchain ==="
check_cmd git         "git"
check_cmd tmux        "tmux"
check_cmd node        "Node.js"
check_cmd npm         "npm"
check_cmd pnpm        "pnpm"

echo
echo "=== 3. Agent CLIs ==="
check_cmd codex       "Codex CLI"
check_cmd claude      "Claude Code CLI"
check_cmd gh          "GitHub CLI"
check_cmd ao          "Agent Orchestrator CLI"

echo
echo "=== 4. AO source tree ==="
if [ -d /root/agent-orchestrator/.git ]; then
  pass "/root/agent-orchestrator is a git checkout"
else
  fail "/root/agent-orchestrator missing or not a git checkout"
fi
if [ -x /root/agent-orchestrator/packages/ao/bin/ao.js ]; then
  pass "ao.js entry point is executable"
else
  fail "ao.js entry point missing or not executable"
fi

echo
echo "=== 5. Codex config ==="
if [ -f /root/.codex/config.toml ]; then
  pass "/root/.codex/config.toml exists"
  if grep -q '^model_provider' /root/.codex/config.toml; then
    pass "config.toml defines a model_provider"
  else
    fail "config.toml has no model_provider line"
  fi
else
  fail "/root/.codex/config.toml missing — create per INSTALL.md Phase 4"
fi
if [ -f /root/.codex/auth.json ]; then
  local_perm=$(stat -c '%a' /root/.codex/auth.json 2>/dev/null || echo unknown)
  if [ "$local_perm" = "600" ]; then
    pass "auth.json permissions are 600"
  else
    fail "auth.json permissions are $local_perm (should be 600)"
  fi
else
  fail "/root/.codex/auth.json missing — create with your API key"
fi

echo
echo "=== 6. GitHub auth ==="
if gh api user --jq .login >/dev/null 2>&1; then
  pass "gh auth works as $(gh api user --jq .login)"
  if git config --global --get-all credential.helper 2>/dev/null | grep -q gh \
     || git config --global --get credential.https://github.com.helper 2>/dev/null | grep -q gh; then
    pass "git credential helper uses gh"
  else
    fail "git credential helper is not wired to gh — run 'gh auth setup-git'"
  fi
else
  fail "gh is not authenticated — run 'gh auth login'"
fi

echo
echo "=== 7. Proxy reachability (optional) ==="
PROXY_HOST=$(ip route show default 2>/dev/null | awk '/default/ {print $3}')
if [ -n "${PROXY_HOST:-}" ]; then
  if timeout 3 bash -c "</dev/tcp/${PROXY_HOST}/7897" 2>/dev/null; then
    pass "Clash proxy reachable at ${PROXY_HOST}:7897"
  else
    note "Clash proxy at ${PROXY_HOST}:7897 not reachable (skip if you don't use Clash)"
  fi
else
  note "Could not determine Windows host IP (skip if you don't need a proxy)"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  printf '\033[1;32mAll checks passed.\033[0m\n'
  exit 0
else
  printf '\033[1;31m%s check(s) failed.\033[0m See failures above and consult TROUBLESHOOTING.md.\n' "$FAIL"
  exit 1
fi
