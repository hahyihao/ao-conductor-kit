## Task: Write `TROUBLESHOOTING.md`

Create a troubleshooting guide in Chinese that documents real issues encountered during the initial AO install on Windows 10 21H1 on 2026-04-11. Every issue listed below actually happened and was fixed. For each issue, write a section with four parts: Symptom, Root Cause, Fix, Prevention.

## Real issues to document

### Issue 1 — wsl --install not recognized on Win10 21H1
Symptom: In admin PowerShell, `wsl --install` fails with "wsl : 无法将wsl项识别为 cmdlet ...". The file C:\Windows\System32\wsl.exe does not exist.
Root cause: The modern one-liner is a Win11 feature that Microsoft partially backported to Win10 22H2, but Win10 21H1 does not have it. The wsl.exe stub is only created after enabling the "Microsoft-Windows-Subsystem-Linux" feature and rebooting.
Fix: Use DISM to enable both `Microsoft-Windows-Subsystem-Linux` and `VirtualMachinePlatform`, then reboot. After reboot, wsl.exe exists.
Prevention: Use bootstrap-wsl2.ps1 which handles this path automatically.

### Issue 2 — Ubuntu rootfs download returns 404
Symptom: curl or Invoke-WebRequest to https://cloud-images.ubuntu.com/wsl/jammy/current/ubuntu-jammy-wsl-amd64-wsl.rootfs.tar.gz returns 404 Not Found.
Root cause: Canonical renamed the file in early 2026. The old name "wsl.rootfs" is retired. New name is "ubuntu22.04lts.rootfs".
Fix: Use https://cloud-images.ubuntu.com/wsl/jammy/current/ubuntu-jammy-wsl-amd64-ubuntu22.04lts.rootfs.tar.gz
Prevention: Always list the /current/ directory first to see available filenames, or use the script that is kept up to date.

### Issue 3 — WSL bash script fails with "not a valid identifier" on export PATH
Symptom: Running `wsl -d Ubuntu-22.04 bash -c 'export PATH=/foo:$PATH; do_stuff'` fails with errors like "bash: export: `Files/Git/usr/bin/core_perl:...': not a valid identifier".
Root cause: WSL bash inherits the Windows PATH. The Windows PATH contains unquoted paths like "C:\Program Files\...", which bash sees as space-separated multiple arguments. Any attempt to re-export PATH or iterate over it explodes on the spaces.
Fix: At the very top of every WSL bash one-liner or script, reset PATH to a clean Linux PATH:

    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    export PATH

Prevention: Every script in this repo that runs through "wsl bash -c" resets PATH on the first line. If you write new bash scripts, do the same.

### Issue 4 — pnpm build fails because bun was installed
Symptom: User tries to install AO with "bun install" and gets errors about package.json fields or ends up with a broken node_modules.
Root cause: AO's package.json specifies `"packageManager": "pnpm@9.15.4"` and uses pnpm workspaces (pnpm-workspace.yaml). bun does not understand pnpm workspaces.
Fix: Uninstall bun's attempt (delete node_modules). Install pnpm globally and re-run: `npm i -g pnpm@9.15.4 && pnpm install && pnpm build`.
Prevention: Read package.json packageManager field before picking a package manager for any project.

### Issue 5 — AO orchestrator session dies immediately under runtime:process
Symptom: `ao start` reports "Orchestrator session created" but a moment later `ao session ls -a` shows the orchestrator as [killed]. Subsequent `ao send demo-orchestrator-1 "..."` returns "Session does not exist".
Root cause: With runtime:process in agent-orchestrator.yaml, AO spawns the orchestrator as a plain subprocess. Codex CLI in non-interactive mode exits after one response, so the subprocess terminates and AO marks it killed.
Fix: Set `runtime: tmux` in agent-orchestrator.yaml. Tmux keeps the session alive across turns.
Prevention: The templates/agent-orchestrator.yaml in this repo defaults to runtime:tmux.

### Issue 6 — git push to github.com hangs via Clash fake-ip even though curl works
Symptom: `curl https://api.github.com` from WSL returns 200 OK in under 1 second. But `git push origin main` hangs indefinitely. The git process is alive at 0% CPU, waiting on a socket that never responds.
Root cause: Clash Verge on Windows uses fake-ip mode (the CIDR 198.18.0.0/15). GitHub domains get resolved to fake IPs inside Clash's scope. curl's short GET sneaks through Clash's TUN, but git push's long-lived HTTP/2 upload stream is not captured by Clash's TUN when initiated from WSL. Result: WSL sends packets to a fake IP that no one routes.
Fix: Two parts.
1. On Windows admin PowerShell, expose Clash to the WSL gateway:

    netsh interface portproxy add v4tov4 listenport=7897 listenaddress=172.17.224.1 connectport=7897 connectaddress=127.0.0.1
    New-NetFirewallRule -DisplayName "WSL Clash Proxy 7897" -Direction Inbound -LocalPort 7897 -Protocol TCP -Action Allow

2. Inside WSL, set git to use the proxy AND export the environment variable for the push command itself (git config alone is not reliable for large pushes):

    git config --global http.proxy http://172.17.224.1:7897
    git config --global https.proxy http://172.17.224.1:7897
    HTTPS_PROXY=http://172.17.224.1:7897 git push -u origin main

Prevention: Use scripts/setup-clash-proxy.ps1 and scripts/setup-git-proxy.sh (if they exist).

### Issue 7 — git push returns 401 Unauthorized even with working proxy
Symptom: After fixing the proxy, git push reaches GitHub but immediately returns "HTTP/2 401" with "www-authenticate: Basic realm=\"GitHub\"".
Root cause: `gh auth login --with-token` only configures gh CLI. It does NOT automatically configure git to use gh as a credential helper. git has no credentials and sends an anonymous request.
Fix: Run `gh auth setup-git` once. This edits ~/.gitconfig to register gh as a credential helper. Subsequent git push uses the gh token.
Prevention: Bootstrap scripts must always run `gh auth setup-git` after `gh auth login`.

### Issue 8 — ao spawn refuses to start because gh is not installed
Symptom: `ao spawn 1` prints: "✗ GitHub CLI (gh) is not installed. Install it: https://cli.github.com/".
Root cause: AO's spawn and batch-spawn commands require gh to fetch issue metadata from GitHub. Without gh, AO cannot read the issue body which it uses as the initial prompt for the worker Codex session.
Fix: Install gh via apt (see INSTALL.md Phase 3). Then authenticate with `gh auth login`.
Prevention: bootstrap-ao.sh installs gh as a required dependency.

### Issue 9 — Codex curl POST /responses returns 200 but output is empty
Symptom: Testing the Codex proxy directly with `curl -X POST http://proxy:port/responses -d '{"model":"gpt-5.4","input":"hi"}'` returns HTTP 200 with `{"status":"completed","output":[],"usage":{"output_tokens":7}}`. usage claims 7 output tokens but the output array is empty.
Root cause: The proxy's non-streaming mode returns the initial response shell BEFORE the model has produced content. The content arrives via Server-Sent Events on a stream only, not in the non-stream JSON body.
Fix: Use `stream: true` in the request body, or use `curl -N -H "Accept: text/event-stream"` to stay connected. Codex CLI uses streaming mode by default so normal `codex exec` works fine. This issue only appears when hand-testing with curl.
Prevention: If you are hand-testing the Codex proxy, always pass `"stream": true`.

### Issue 10 — Codex prints "bubblewrap on PATH not found" warning
Symptom: Every `codex exec` run prints: "warning: Codex could not find bubblewrap on PATH. Install bubblewrap with your OS package manager. ... Codex will use the vendored bubblewrap in the meantime."
Root cause: Codex uses bubblewrap for its sandbox feature. It ships a vendored copy for Linux, so it works without the system bubblewrap. The warning is cosmetic.
Fix: Either ignore the warning, or install system bubblewrap: `apt-get install -y bubblewrap`.
Prevention: bootstrap-ao.sh can optionally install bubblewrap to silence the warning.

## Writing requirements

1. Chinese prose. Commands and code stay English.
2. Each issue is its own H2 section. Use the exact four-part structure: "现象", "根因", "修复", "预防".
3. At the top, add a table of contents with issue number and title.
4. Include a "调试技巧" section at the end with general tips: how to read codex logs, how to check tmux sessions, how to inspect ao status, how to look at /root/.config/gh/hosts.yml.
5. Add a "已知无害警告" section listing harmless warnings like the bubblewrap one and the "xdg-open is not installed" warning from ao dashboard.
6. Target length: 400 to 700 lines.
7. Use the date 2026-04-11 in the header.

## Output constraints

- Create only this file: TROUBLESHOOTING.md (at repo root)
- Do NOT modify any other file.
- Commit message: "docs: add TROUBLESHOOTING.md with 10 real issues from initial install"
- Open a pull request to main.
