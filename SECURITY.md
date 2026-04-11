# Security Policy

This document describes how secrets are handled in the AO Conductor Kit and what to do if you find a vulnerability.

## Scope

The AO Conductor Kit manages install scripts and task briefs. It does NOT itself store or transmit production secrets. However, using it requires configuring several credentials (OpenAI API key, GitHub Personal Access Token, proxy passwords), so the handling rules below apply to both this kit's own files and the downstream machines where you install it.

## Credentials this kit touches

| Credential | Where it lives | How this kit handles it |
|---|---|---|
| OpenAI API key for Codex | `/root/.codex/auth.json` inside WSL, chmod 600 | Must be set by the operator; never baked into the kit |
| GitHub Personal Access Token | `~/.config/gh/hosts.yml` inside WSL, managed by `gh auth login` | Set interactively by operator; never committed |
| Clash Verge proxy port | `netsh portproxy` on Windows + `git config --global http.proxy` inside WSL | Port number configurable; no credentials stored |
| Codex proxy endpoint | `/root/.codex/config.toml` inside WSL | URL is configurable; authentication handled by the proxy itself |

## What this kit will NOT do

- Commit any file containing a real API key, token, or password.
- Execute any command that exposes secrets to stdout, logs, or git history.
- Source secrets from the public Internet at install time.

## What you MUST do on any machine where you install this kit

1. **Never paste real tokens into documentation**. The kit's docs use placeholders like `ghp_your_token_here` and `sk-your-key-here`. Gitleaks allowlists these specific strings; do not weaken the allowlist.
2. **Rotate the Personal Access Token** used for the first install if it was pasted into a shared chat session, terminal history file, or chat log.
3. **Set `chmod 600` on `/root/.codex/auth.json`** after creating it. `scripts/bootstrap-ao.sh` does not set this for you because it does not create the file.
4. **Change any SSH password that was visible in a config file**. The kit's development session exposed a weak password (`123456`) in a backup `ssh-config.toml`. If you have copied such a file, change that SSH password immediately and regenerate keys where possible.
5. **Keep Clash Verge and any proxy configs out of this repository**. The kit only needs the proxy's listening port; it does not need the proxy's config file, rules, or subscription URL.
6. **Run `gitleaks` locally before every `git push`** on any repository where you have edited config templates. `scripts/verify-install.sh` includes an optional `gitleaks detect` step.

## Automated protections in this kit

- `.gitleaks.toml` allowlists only the documentation placeholder strings. Any real secret-looking string in a tracked file will still be caught.
- `.github/workflows/gitleaks.yml` runs on every push and pull request to `main`.
- `.github/workflows/codeql.yml` runs semantic analysis for Python sources.
- `.github/workflows/super-linter.yml` runs all supported linters.
- `.github/workflows/dependency-review.yml` reviews dependency diffs for known vulnerabilities.
- `.github/dependabot.yml` opens weekly PRs to upgrade GitHub Actions to their latest versions.

## Reporting a vulnerability

If you find a security issue in the scripts, CI configs, or generated project templates:

1. **Do NOT open a public issue on GitHub**.
2. Email the maintainer directly. See the `AUTHOR` metadata in `scripts/bootstrap-wsl2.ps1` or the repository owner on GitHub for contact details.
3. Include: affected file, reproduction steps, impact assessment, and (if known) a suggested fix.
4. You will receive an acknowledgement within 7 days. Fixes are scheduled based on severity: critical within 72 hours, high within 7 days, medium within 30 days, low on the next release.

## Out of scope

- Vulnerabilities in `agent-orchestrator` itself (report to its upstream repository).
- Vulnerabilities in Codex, Claude Code, or `gh` CLI (report to their respective vendors).
- Vulnerabilities in Clash Verge, WSL2, or other infrastructure this kit relies on but does not ship.
- Misconfiguration by operators who ignore the rules above.
