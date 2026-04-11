#!/usr/bin/env bash
# Purpose: Install the complete Agent Orchestrator toolchain inside WSL2 Ubuntu 22.04.
# Date: 2026-04-11
# Target environment: Ubuntu 22.04 running in WSL2 as root.
# Usage: bash scripts/bootstrap-ao.sh

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -euo pipefail

BASE_PACKAGES=(git tmux build-essential curl ca-certificates gnupg xz-utils unzip)
AO_ROOT=/root/agent-orchestrator
AO_BIN="$AO_ROOT/packages/ao/bin/ao.js"

log_step() { printf '\033[1;36m==>\033[0m %s\n' "$1"; }
log_skip() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }
log_note() { printf '\033[0;37m   %s\033[0m\n' "$1"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "This script must run as root inside WSL."
}

is_package_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q '^install ok installed$'
}

have_all_base_packages() {
  local pkg
  for pkg in "${BASE_PACKAGES[@]}"; do
    if ! is_package_installed "$pkg"; then
      return 1
    fi
  done
}

node_major() {
  node --version 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/'
}

ao_is_ready() {
  [[ -d "$AO_ROOT/.git" ]] &&
    [[ -f "$AO_BIN" ]] &&
    (cd "$AO_ROOT" && node "$AO_BIN" --version >/dev/null 2>&1)
}

install_base_packages() {
  if have_all_base_packages; then
    log_skip "Apt base packages already installed"
    return
  fi

  log_step "Installing apt base packages"
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${BASE_PACKAGES[@]}"
}

install_nodejs() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    local major
    major="$(node_major || true)"
    if [[ "$major" =~ ^[0-9]+$ ]] && (( major >= 20 )); then
      log_skip "Node.js $(node --version) already installed"
      return
    fi
  fi

  log_step "Installing Node.js 20"
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nodejs
}

install_pnpm() {
  if command -v pnpm >/dev/null 2>&1 && [[ "$(pnpm --version 2>/dev/null)" == "9.15.4" ]]; then
    log_skip "pnpm 9.15.4 already installed"
    return
  fi

  log_step "Installing pnpm 9.15.4"
  npm install -g pnpm@9.15.4
}

install_ai_clis() {
  if command -v codex >/dev/null 2>&1 && command -v claude >/dev/null 2>&1; then
    log_skip "Codex and Claude Code CLIs already installed"
    return
  fi

  log_step "Installing Codex and Claude Code CLIs"
  npm install -g @openai/codex @anthropic-ai/claude-code
}

install_github_cli() {
  if command -v gh >/dev/null 2>&1; then
    log_skip "GitHub CLI already installed"
    return
  fi

  log_step "Installing GitHub CLI"
  mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
  chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gh
}

clone_and_build_ao() {
  if ao_is_ready; then
    log_skip "Agent Orchestrator already built"
    return
  fi

  log_step "Cloning and building Agent Orchestrator"
  if [[ ! -d "$AO_ROOT/.git" ]]; then
    git clone https://github.com/ComposioHQ/agent-orchestrator "$AO_ROOT"
  else
    log_note "Using existing checkout at $AO_ROOT"
  fi

  cd "$AO_ROOT"
  pnpm install
  pnpm build
}

install_ao_symlink() {
  if [[ -L /usr/local/bin/ao ]] &&
    [[ "$(readlink -f /usr/local/bin/ao)" == "$AO_BIN" ]] &&
    ao_is_ready; then
    log_skip "ao already linked into /usr/local/bin"
    return
  fi

  if [[ ! -f "$AO_BIN" ]]; then
    die "AO binary not found at $AO_BIN; build step did not complete."
  fi

  log_step "Linking ao into /usr/local/bin"
  chmod +x "$AO_BIN"
  ln -sf "$AO_BIN" /usr/local/bin/ao
}

verify_toolchain() {
  if command -v git >/dev/null 2>&1 &&
    command -v tmux >/dev/null 2>&1 &&
    command -v node >/dev/null 2>&1 &&
    command -v npm >/dev/null 2>&1 &&
    command -v pnpm >/dev/null 2>&1 &&
    command -v codex >/dev/null 2>&1 &&
    command -v claude >/dev/null 2>&1 &&
    command -v gh >/dev/null 2>&1 &&
    command -v ao >/dev/null 2>&1; then
    log_step "Verifying installed toolchain"
  else
    die "One or more required commands are missing from PATH."
  fi

  git --version
  tmux -V
  node --version
  npm --version
  pnpm --version
  codex --version
  claude --version
  gh --version | sed -n '1p'
  ao --version
}

main() {
  require_root
  install_base_packages
  install_nodejs
  install_pnpm
  install_ai_clis
  install_github_cli
  clone_and_build_ao
  install_ao_symlink
  verify_toolchain
}

main "$@"
