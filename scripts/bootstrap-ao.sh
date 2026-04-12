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
TMUX_MIN_VERSION=3.3
TMUX_SOURCE_VERSION=3.5a
TMUX_RELEASE_URL="https://github.com/tmux/tmux/releases/download/${TMUX_SOURCE_VERSION}/tmux-${TMUX_SOURCE_VERSION}.tar.gz"
TMUX_TARBALL="/tmp/tmux-${TMUX_SOURCE_VERSION}.tar.gz"
TMUX_SRC_DIR="/tmp/tmux-${TMUX_SOURCE_VERSION}"
TMUX_BACKUP_BIN=/usr/bin/tmux.3.2a.backup
GH_KEYRING=/etc/apt/keyrings/githubcli-archive-keyring.gpg
GH_SOURCE_LIST=/etc/apt/sources.list.d/github-cli.list

log_step() { printf '\033[1;36m==>\033[0m %s\n' "$1"; }
log_skip() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }
log_note() { printf '\033[0;37m   %s\033[0m\n' "$1"; }
die() {
	printf '\033[1;31merror:\033[0m %s\n' "$1" >&2
	exit 1
}

require_root() {
	[[ ${EUID:-$(id -u)} -eq 0 ]] || die "This script must run as root inside WSL."
}

have_command() {
	command -v "$1" >/dev/null 2>&1
}

is_package_installed() {
	dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q '^install ok installed$'
}

have_all_base_packages() {
	local package
	for package in "${BASE_PACKAGES[@]}"; do
		if ! is_package_installed "$package"; then
			return 1
		fi
	done
	return 0
}

node_major() {
	node --version 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/'
}

normalize_tmux_version() {
	printf '%s\n' "$1" | sed -E 's/^[^0-9]*//'
}

tmux_version_raw() {
	tmux -V 2>/dev/null | awk '{print $2}'
}

tmux_version_meets_min() {
	local version
	version="$(normalize_tmux_version "${1:-}")"
	[[ -n "$version" ]] || return 1
	dpkg --compare-versions "$version" ge "$TMUX_MIN_VERSION"
}

pick_ncurses_dev_package() {
	if apt-cache show libncurses5-dev >/dev/null 2>&1; then
		printf '%s\n' libncurses5-dev
		return
	fi

	if apt-cache show libncurses-dev >/dev/null 2>&1; then
		printf '%s\n' libncurses-dev
		return
	fi

	die "Could not find an ncurses development package required to build tmux."
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

install_tmux_build_dependencies() {
	local ncurses_pkg
	apt-get update -qq
	ncurses_pkg="$(pick_ncurses_dev_package)"

	log_step "Installing tmux build dependencies"
	DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
		libevent-dev \
		"$ncurses_pkg" \
		pkg-config \
		automake \
		autoconf \
		bison
}

build_tmux_from_source() {
	log_step "Building tmux ${TMUX_SOURCE_VERSION} from source"
	rm -rf "$TMUX_SRC_DIR"
	curl -fsSL -o "$TMUX_TARBALL" "$TMUX_RELEASE_URL"
	tar -xf "$TMUX_TARBALL" -C /tmp

	cd "$TMUX_SRC_DIR"
	./configure --prefix=/usr/local
	make -j"$(nproc)"
	make install
}

ensure_usr_bin_tmux_target() {
	if [[ ! -x /usr/local/bin/tmux ]]; then
		die "Expected /usr/local/bin/tmux after source build, but it was not found."
	fi

	if [[ -L /usr/bin/tmux ]] && [[ "$(readlink -f /usr/bin/tmux)" == "/usr/local/bin/tmux" ]]; then
		log_skip "/usr/bin/tmux already points to /usr/local/bin/tmux"
		return
	fi

	if [[ -e /usr/bin/tmux && ! -L /usr/bin/tmux ]]; then
		if [[ ! -e "$TMUX_BACKUP_BIN" ]]; then
			mv /usr/bin/tmux "$TMUX_BACKUP_BIN"
			log_note "Preserved previous /usr/bin/tmux as $TMUX_BACKUP_BIN"
		else
			log_note "Backup already exists at $TMUX_BACKUP_BIN"
			rm -f /usr/bin/tmux
		fi
	fi

	ln -sfn /usr/local/bin/tmux /usr/bin/tmux
	log_note "/usr/bin/tmux now points to /usr/local/bin/tmux"
}

ensure_safe_tmux() {
	local current_version current_path
	current_version=
	current_path=

	if command -v tmux >/dev/null 2>&1; then
		current_path="$(command -v tmux)"
		current_version="$(tmux_version_raw || true)"
		if tmux_version_meets_min "$current_version"; then
			log_skip "tmux ${current_version} at ${current_path} already meets minimum >= ${TMUX_MIN_VERSION}"
			if [[ -x /usr/local/bin/tmux ]]; then
				ensure_usr_bin_tmux_target
			fi
			return
		fi

		log_step "Upgrading tmux from source because ${current_version:-unknown} at ${current_path} is below ${TMUX_MIN_VERSION}"
	else
		log_step "Installing tmux ${TMUX_SOURCE_VERSION} from source because tmux is missing"
	fi

	install_tmux_build_dependencies
	build_tmux_from_source
	ensure_usr_bin_tmux_target

	current_version="$(tmux_version_raw || true)"
	tmux_version_meets_min "$current_version" || die "tmux upgrade failed; expected >= ${TMUX_MIN_VERSION}, got ${current_version:-missing}"
	log_note "tmux ${current_version} is ready for detached AO/Codex sessions"
}

install_nodejs() {
	if have_command node && have_command npm; then
		local major
		major="$(node_major || true)"
		if [[ "$major" =~ ^[0-9]+$ ]] && ((major >= 20)); then
			log_skip "Keeping existing Node.js $(node --version)"
			return
		fi
	fi

	log_step "Installing Node.js 20"
	curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
	DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nodejs
}

install_pnpm() {
	if have_command pnpm && [[ "$(pnpm --version 2>/dev/null)" == "9.15.4" ]]; then
		log_skip "pnpm 9.15.4 already installed"
		return
	fi

	log_step "Installing pnpm 9.15.4"
	npm install -g pnpm@9.15.4
}

install_ai_clis() {
	if have_command codex && have_command claude; then
		log_skip "Codex and Claude Code CLIs already installed"
		return
	fi

	log_step "Installing Codex and Claude Code CLIs"
	npm install -g @openai/codex @anthropic-ai/claude-code
}

install_github_cli() {
	if have_command gh; then
		log_skip "GitHub CLI already installed"
		return
	fi

	log_step "Installing GitHub CLI"
	install -d -m 755 /etc/apt/keyrings
	curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o "$GH_KEYRING"
	chmod go+r "$GH_KEYRING"
	echo "deb [arch=$(dpkg --print-architecture) signed-by=$GH_KEYRING] https://cli.github.com/packages stable main" \
		>"$GH_SOURCE_LIST"
	apt-get update -qq
	DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gh
}

clone_and_build_ao() {
	if ao_is_ready; then
		log_skip "Agent Orchestrator already built"
		return
	fi

	log_step "Cloning and building Agent Orchestrator"
	if [[ -e "$AO_ROOT" && ! -d "$AO_ROOT/.git" ]]; then
		die "Expected $AO_ROOT to be a git checkout, but it already exists as something else."
	fi

	if [[ ! -d "$AO_ROOT/.git" ]]; then
		git clone https://github.com/ComposioHQ/agent-orchestrator "$AO_ROOT"
	else
		log_note "Using existing checkout at $AO_ROOT"
	fi

	cd "$AO_ROOT"
	pnpm install
	pnpm build
}

install_ao_wrapper() {
	if [[ ! -f "$AO_BIN" ]]; then
		die "AO binary not found at $AO_BIN; build step did not complete."
	fi

	log_step "Installing ao wrapper into /usr/local/bin"
	chmod +x "$AO_BIN"
	rm -f /usr/local/bin/ao
	cat >/usr/local/bin/ao <<EOF
#!/usr/bin/env bash
set -euo pipefail

AO_BIN="$AO_BIN"

find_config_path() {
	if [[ -n "\${AO_CONFIG_PATH:-}" && -f "\$AO_CONFIG_PATH" ]]; then
		printf '%s\n' "\$AO_CONFIG_PATH"
		return 0
	fi

	local dir="\${PWD:-.}"
	while :; do
		if [[ -f "\$dir/agent-orchestrator.yaml" ]]; then
			printf '%s\n' "\$dir/agent-orchestrator.yaml"
			return 0
		fi
		if [[ "\$dir" == "/" ]]; then
			return 1
		fi
		dir="\$(dirname "\$dir")"
	done
}

has_explicit_start_project() {
	local arg
	for arg in "\${@:2}"; do
		if [[ "\$arg" != -* ]]; then
			return 0
		fi
	done
	return 1
}

get_start_positional_arg() {
	local arg
	for arg in "\${@:2}"; do
		if [[ "\$arg" != -* ]]; then
			printf '%s\n' "\$arg"
			return 0
		fi
	done
	return 1
}

resolve_native_start_project() {
	local config_path="\$1"
	[[ -n "\$config_path" ]] || return 0

	AO_CONFIG_PATH="\$config_path" node --input-type=module - <<'NODE'
try {
  const { loadConfig } = await import("/root/agent-orchestrator/packages/core/dist/index.js");
  const { findProjectForDirectory } = await import(
    "/root/agent-orchestrator/packages/cli/dist/lib/project-resolution.js"
  );
  const config = loadConfig();
  const projectIds = Object.keys(config.projects);
  const currentDir = process.cwd();

  if (projectIds.length === 1) {
    console.log(projectIds[0]);
    process.exit(0);
  }

  const worktreeMatch = currentDir.match(/^\/root\/\.worktrees\/([^/]+)(?:\/|$)/);
  if (worktreeMatch?.[1] && config.projects[worktreeMatch[1]]) {
    console.log(worktreeMatch[1]);
    process.exit(0);
  }

  const matched = findProjectForDirectory(config.projects, currentDir);
  if (matched) {
    console.log(matched);
  }
} catch {
  // Fall back to AO's own CLI error if config discovery fails.
}
NODE
}

resolve_fallback_start_project() {
	local config_path="\$1"
	[[ -n "\$config_path" ]] || return 0

	AO_CONFIG_PATH="\$config_path" node --input-type=module - <<'NODE'
try {
  const { loadConfig } = await import("/root/agent-orchestrator/packages/core/dist/index.js");
  const { findProjectForDirectory } = await import(
    "/root/agent-orchestrator/packages/cli/dist/lib/project-resolution.js"
  );
  const config = loadConfig();
  const projectIds = Object.keys(config.projects);
  if (projectIds.length <= 1) {
    process.exit(0);
  }

  const matched = findProjectForDirectory(config.projects, process.cwd());
  if (!matched && config.projects["ao-kit"]) {
    console.log("ao-kit");
  }
} catch {
  // Fall back to AO's own CLI error if config discovery fails.
}
NODE
}

should_start_lifecycle() {
	local dashboard_enabled=1
	local orchestrator_enabled=1
	local arg

	for arg in "\${@:2}"; do
		case "\$arg" in
			--no-dashboard)
				dashboard_enabled=0
				;;
			--no-orchestrator)
				orchestrator_enabled=0
				;;
		esac
	done

	(( dashboard_enabled || orchestrator_enabled ))
}

run_post_start_helper() {
	local config_path="\${1:-}"
	if [[ -z "\$config_path" ]]; then
		config_path="\$(find_config_path || true)"
	fi

	if [[ -z "\$config_path" ]]; then
		return 0
	fi

	local repo_root helper
	repo_root="\$(cd "\$(dirname "\$config_path")" && pwd)"
	helper="\$repo_root/tools/start-slot-lifecycle-workers.sh"

	if [[ -x "\$helper" ]]; then
		AO_CONFIG_PATH="\$config_path" "\$helper"
	fi
}

if [[ "\${1:-}" == "start" ]]; then
	for arg in "\$@"; do
		if [[ "\$arg" == "-h" || "\$arg" == "--help" ]]; then
			exec "\$AO_BIN" "\$@"
		fi
	done

	config_path="\$(find_config_path || true)"
	start_args=("\$@")
	resolved_project=""

	if [[ -n "\$config_path" ]] && ! has_explicit_start_project "\$@"; then
		resolved_project="\$(resolve_native_start_project "\$config_path" || true)"
		fallback_project="\$(resolve_fallback_start_project "\$config_path" || true)"
		if [[ -n "\$fallback_project" ]]; then
			start_args+=("\$fallback_project")
			resolved_project="\$fallback_project"
		fi
	elif has_explicit_start_project "\$@"; then
		resolved_project="\$(get_start_positional_arg "\$@" || true)"
	fi

	set +e
	"\$AO_BIN" "\${start_args[@]}"
	status=\$?
	set -e

	if [[ \$status -ne 0 ]]; then
		exit \$status
	fi

	if should_start_lifecycle "\$@" && [[ "\$resolved_project" == "ao-kit" ]]; then
		run_post_start_helper "\$config_path"
	fi
	exit 0
fi

exec "\$AO_BIN" "\$@"
EOF
	chmod +x /usr/local/bin/ao
}

verify_required_commands() {
	local command_name
	for command_name in git tmux node npm pnpm codex claude gh ao; do
		have_command "$command_name" || die "Required command '$command_name' is missing from PATH."
	done
}

verify_toolchain() {
	local node_major_version node_version pnpm_version

	log_step "Verifying installed toolchain"
	verify_required_commands

	node_version="$(node --version)"
	node_major_version="$(node_major)"
	if [[ ! "$node_major_version" =~ ^[0-9]+$ ]] || ((node_major_version < 20)); then
		die "Node.js 20 or newer is required, found $node_version."
	fi

	pnpm_version="$(pnpm --version)"
	[[ "$pnpm_version" == "9.15.4" ]] || die "pnpm 9.15.4 is required, found $pnpm_version."

	git --version
	tmux -V
	printf '%s\n' "$node_version"
	npm --version
	printf '%s\n' "$pnpm_version"
	codex --version
	claude --version
	gh --version | sed -n '1p'
	ao --version
}

main() {
	require_root
	install_base_packages
	ensure_safe_tmux
	install_nodejs
	install_pnpm
	install_ai_clis
	install_github_cli
	clone_and_build_ao
	install_ao_wrapper
	verify_toolchain
}

main "$@"
