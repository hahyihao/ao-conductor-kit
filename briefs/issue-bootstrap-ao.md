## Task: Write `scripts/bootstrap-ao.sh`

Create a bash script that runs INSIDE WSL2 Ubuntu 22.04 as root to install the complete AO toolchain. This script is stage 2 of the AO Conductor Kit install, run after scripts/bootstrap-wsl2.ps1 has finished on the Windows side.

## Tested facts from the 2026-04-11 install session

### Critical: WSL bash inherits Windows PATH with spaces
When bash runs inside WSL via "wsl -d Ubuntu-22.04 bash -c ..." it inherits the Windows PATH which contains spaces such as "/mnt/c/Program Files/Git/usr/bin". Any plain "export PATH=..." in the script will explode because bash splits on spaces. Solution: the very first executable line of the script must reset PATH to a clean Linux PATH:

    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    export PATH

### Install order that actually worked

1. apt base packages
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git tmux build-essential curl ca-certificates gnupg xz-utils unzip

2. Node.js 20 from NodeSource
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nodejs
   Expected: node v20.20.2 (or newer 20.x), npm 10.x

3. pnpm 9.15.4 — REQUIRED by AO
   AO's package.json specifies: "packageManager": "pnpm@9.15.4"
   Do NOT use bun for AO. bun will not build AO's monorepo correctly. Install pnpm globally:
    npm i -g pnpm@9.15.4

4. Codex and Claude Code CLIs
    npm i -g @openai/codex @anthropic-ai/claude-code
   Expected: codex-cli 0.120.0+, claude 2.1.101+

5. GitHub CLI — needed by AO batch-spawn to read issues and create PRs
    mkdir -p -m 755 /etc/apt/keyrings
    wget -nv -O /etc/apt/keyrings/githubcli-archive-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
    apt-get update -qq
    apt-get install -y -qq gh
   Expected: gh 2.89.0+

6. Clone and build AO
    cd /root
    git clone https://github.com/ComposioHQ/agent-orchestrator
    cd agent-orchestrator
    pnpm install
    pnpm build
   Notes:
   - pnpm install runs a postinstall step that rebuilds node-pty native module (about 20 seconds)
   - pnpm build compiles multiple packages: core, cli, ao, web (Next.js), plugins. Takes 1 to 2 minutes.

7. Create symlink so "ao" is on PATH
    chmod +x /root/agent-orchestrator/packages/ao/bin/ao.js
    ln -sf /root/agent-orchestrator/packages/ao/bin/ao.js /usr/local/bin/ao

## Verification block at end of script
The script must print a version block and exit non-zero if anything is missing:

    git --version
    tmux -V
    node --version
    npm --version
    pnpm --version
    codex --version
    claude --version
    gh --version
    ao --version

Expected final output:
    git version 2.34.1
    tmux 3.2a
    v20.20.2
    10.x or 11.x
    9.15.4
    codex-cli 0.120.0
    2.1.101 (Claude Code)
    gh version 2.89.0
    0.2.2

## Script requirements

1. Shebang: #!/usr/bin/env bash
2. set -euo pipefail immediately after the PATH reset
3. Each stage is a named function. Each function first checks "is it already installed" and early-returns if so.
4. Log each stage with a colored prefix (use plain ANSI escape sequences, not tput). Example: printf '\033[1;36m==>\033[0m %s\n' "Installing Node.js 20"
5. Must run unattended from a fresh Ubuntu 22.04 WSL image. No interactive prompts.
6. Header comment: purpose, date 2026-04-11, target env Ubuntu 22.04 in WSL2, usage "bash scripts/bootstrap-ao.sh".
7. Target length: 120 to 200 lines.

## Known gotchas to handle gracefully

- If node already installed at a version other than 20.x, prefer the existing one. Only replace if less than 20.
- If AO already cloned, skip git clone and just cd into it.
- pnpm may print a "New major version available" notice. Ignore it.

## Output constraints

- Create only this file: scripts/bootstrap-ao.sh
- chmod +x is not needed in git, but the shebang is.
- Do NOT modify any other file.
- Commit message: "feat: add bootstrap-ao.sh WSL toolchain installer"
- Open a pull request to main.
