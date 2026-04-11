#!/usr/bin/env bash
set -euo pipefail
export HTTPS_PROXY=http://172.17.224.1:7897
export HTTP_PROXY=http://172.17.224.1:7897

KIT_DIR="/mnt/d/脚本程序/agent-orchestrator"
cd "$KIT_DIR"

if [ ! -d .git ]; then
  echo "=== git init ==="
  git init -q -b main
fi

echo "=== git add ==="
git add .

echo "=== git status ==="
git status -s | head -20

echo "=== git commit ==="
if git diff --staged --quiet; then
  echo "nothing to commit"
else
  git -c user.email="ceo@local" -c user.name="CEO" \
      commit -q -m "init: AO Conductor Kit mother disc v0.1

Generated 2026-04-11 via AO self-dispatch:
- 6 parallel Codex workers wrote INSTALL.md, FLOW.md, TROUBLESHOOTING.md,
  scripts/bootstrap-wsl2.ps1, scripts/bootstrap-ao.sh, skills/ao-conductor.md
- CEO (Claude Opus) wrote README.md, CLAUDE.md, templates/, .github/workflows/
- Total ~2800 lines across 15 core files" 2>&1 | tail -5
fi

echo "=== gh repo create + push ==="
if gh repo view hahyihao/ao-conductor-kit >/dev/null 2>&1; then
  echo "repo already exists, just pushing"
  git remote get-url origin >/dev/null 2>&1 || \
    git remote add origin https://github.com/hahyihao/ao-conductor-kit.git
  git push -u origin main 2>&1 | tail -5
else
  gh repo create hahyihao/ao-conductor-kit \
    --public \
    --description "AO Conductor Kit — portable init kit for Claude CEO + Codex workers on Windows/WSL2" \
    --source=. \
    --remote=origin \
    --push 2>&1 | tail -5
fi

echo
echo "=== final ==="
gh repo view hahyihao/ao-conductor-kit --json url,stargazerCount,diskUsage --jq '.url + " | size=" + (.diskUsage|tostring) + " KB"'
