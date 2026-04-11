## Task: Write `INSTALL.md`

Create the master installation guide, in Chinese, for Windows 10 users installing the AO Conductor Kit from scratch. This is the first file a new user reads.

## Tested install path from the 2026-04-11 session

The install happens in 8 sequential phases. Each phase must be a section with: prerequisite checks, exact commands to run, expected output, how to verify, troubleshooting pointer.

## Phase outline

### Phase 0 — 前置检查 (Prerequisites)
- Windows 10 build 19041 or higher (21H1/21H2/22H2 all fine, Win11 better)
- Administrator rights on the machine
- BIOS virtualization (Intel VT-x or AMD-V) enabled — check via Task Manager → Performance → CPU → right bottom "Virtualization: Enabled"
- At least 15 GB free disk space
- Internet access (Clash Verge or similar proxy recommended for git push to GitHub)

### Phase 1 — Run scripts/bootstrap-wsl2.ps1 (Windows side, admin PowerShell)
- Purpose: enable WSL2 features via DISM, download and install WSL2 kernel MSI, download Ubuntu 22.04 rootfs and import it.
- Command: `powershell -ExecutionPolicy Bypass -File scripts\bootstrap-wsl2.ps1`
- Expected output: wsl -l -v shows Ubuntu-22.04 Stopped 2
- Reboot required between DISM step and MSI install. Script detects this and exits cleanly. Rerun after reboot.

### Phase 2 — Reboot the computer
- After DISM completes, wsl.exe stub does not yet exist in C:\Windows\System32. Reboot required.
- After reboot, rerun bootstrap-wsl2.ps1 to complete stages 2-7.

### Phase 3 — Run scripts/bootstrap-ao.sh (WSL side, as root)
- From WSL: `wsl -d Ubuntu-22.04 -- bash /mnt/d/your/path/to/scripts/bootstrap-ao.sh`
- Or from Windows cmd: `wsl -d Ubuntu-22.04 bash /mnt/d/your/path/to/scripts/bootstrap-ao.sh`
- Installs: git, tmux, build-essential, Node 20, pnpm 9.15.4, codex CLI, claude CLI, gh CLI, clones and builds agent-orchestrator, creates /usr/local/bin/ao symlink.
- Takes 5 to 10 minutes.
- Expected final output: version block with 9 items.

### Phase 4 — Configure Codex to use your LLM proxy
- File: /root/.codex/config.toml (inside WSL)
- Minimal template:

    model_provider = "my-proxy"
    model = "gpt-5.4"
    model_reasoning_effort = "xhigh"
    model_context_window = 1000000

    [model_providers.my-proxy]
    name = "my-proxy"
    base_url = "http://your-proxy-host:port"
    wire_api = "responses"
    requires_openai_auth = true

- File: /root/.codex/auth.json — chmod 600 — contents:

    {
      "OPENAI_API_KEY": "sk-your-key-here"
    }

- Verify: run a smoke test inside WSL:
    cd /tmp && codex exec --sandbox read-only --skip-git-repo-check "say hi in 3 words"
- Expected: the model responds with three words within 10 to 30 seconds.

### Phase 5 — Configure Windows proxy port forward so WSL can reach Clash Verge for git push
- Run in admin PowerShell:
    netsh interface portproxy add v4tov4 listenport=7897 listenaddress=172.17.224.1 connectport=7897 connectaddress=127.0.0.1
    New-NetFirewallRule -DisplayName "WSL Clash Proxy 7897" -Direction Inbound -LocalPort 7897 -Protocol TCP -Action Allow
- Note: the listen address 172.17.224.1 is the default Windows vEthernet (WSL) gateway. Confirm by running `ipconfig` and looking for the "vEthernet (WSL)" interface.
- If your Clash Verge proxy port is not 7897, adjust both the netsh rule and the git proxy step.

### Phase 6 — Set git proxy inside WSL
- Inside WSL:
    git config --global http.proxy http://172.17.224.1:7897
    git config --global https.proxy http://172.17.224.1:7897
- Important: git push must still be invoked with HTTPS_PROXY environment variable as a belt-and-suspenders measure. The global config alone is sometimes flaky during large pushes:
    HTTPS_PROXY=http://172.17.224.1:7897 git push origin main

### Phase 7 — GitHub authentication
- Inside WSL, you need a GitHub Personal Access Token with scopes: repo, workflow, read:org.
- Generate at https://github.com/settings/tokens/new
- Authenticate gh:
    echo "ghp_your_token_here" | gh auth login --with-token
- Wire git to use gh credentials:
    gh auth setup-git
- This step is CRITICAL. Without it, `git push` returns 401 Unauthorized even when the proxy is working.

### Phase 8 — First AO smoke test
- In WSL, create a toy git repo:
    mkdir -p /root/projects/ao-hello && cd /root/projects/ao-hello
    git init -b main && echo "# AO Hello" > README.md
    git add . && git commit -m init
- Create a GitHub repo and push:
    gh repo create ao-hello --public --source=. --remote=origin --push
- Copy templates/agent-orchestrator.yaml into the repo and adjust the repo/path fields.
- Start AO:
    cd /root/projects/ao-hello && ao start
- Expected output includes: "Dashboard: http://localhost:3000", "Orchestrator: http://localhost:3000/sessions/hello-orchestrator-1"
- Open browser to http://localhost:3000 — WSL2 forwards localhost automatically from Windows.

## Writing requirements

1. Full Chinese prose. Code blocks and commands stay in English.
2. Use H2 for each phase and H3 for sub-steps.
3. Every command block must be labelled as Windows PowerShell or WSL bash.
4. Add a summary table at the top listing the 8 phases and which side (Win/WSL) they run on.
5. At the end include a "常见问题" section that points to TROUBLESHOOTING.md for specific symptoms.
6. Do not copy any real API keys or Personal Access Tokens into the document — use placeholders only.
7. Target length: 400 to 700 lines.
8. Use the date 2026-04-11 in the header.

## Output constraints

- Create only this file: INSTALL.md (at the repo root)
- Do NOT modify README.md or any other existing file.
- Commit message: "docs: add INSTALL.md master install guide"
- Open a pull request to main.
