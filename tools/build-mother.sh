#!/usr/bin/env bash
set -e

MOTHER="/mnt/d/脚本程序/agent-orchestrator"
REPO="/root/projects/ao-demo"

cd "$REPO"

echo "=== fetch origin ==="
HTTPS_PROXY=http://172.17.224.1:7897 git fetch origin --prune 2>&1 | tail -3

mkdir -p "$MOTHER/scripts" "$MOTHER/skills/references" "$MOTHER/.github/workflows"

echo "=== extract worker files ==="
git show "origin/feat/9:scripts/bootstrap-wsl2.ps1"  > "$MOTHER/scripts/bootstrap-wsl2.ps1"
git show "origin/feat/10:scripts/bootstrap-ao.sh"    > "$MOTHER/scripts/bootstrap-ao.sh"
git show "origin/feat/11:INSTALL.md"                  > "$MOTHER/INSTALL.md"
git show "origin/feat/12:FLOW.md"                     > "$MOTHER/FLOW.md"
git show "origin/feat/13:TROUBLESHOOTING.md"          > "$MOTHER/TROUBLESHOOTING.md"
git show "HEAD:skills/ao-conductor.md"                > "$MOTHER/skills/ao-conductor.md"
git show "HEAD:skills/references/silent-failure-detection.md" \
                                                      > "$MOTHER/skills/references/silent-failure-detection.md"

echo "=== copy CI files ==="
cp "$MOTHER/ci-staging/super-linter.yml"      "$MOTHER/.github/workflows/super-linter.yml"
cp "$MOTHER/ci-staging/codeql.yml"             "$MOTHER/.github/workflows/codeql.yml"
cp "$MOTHER/ci-staging/gitleaks.yml"           "$MOTHER/.github/workflows/gitleaks.yml"
cp "$MOTHER/ci-staging/dependency-review.yml"  "$MOTHER/.github/workflows/dependency-review.yml"
cp "$MOTHER/ci-staging/dependabot.yml"         "$MOTHER/.github/dependabot.yml"
cp "$MOTHER/ci-staging/.gitleaks.toml"         "$MOTHER/.gitleaks.toml"

echo "=== final tree ==="
cd "$MOTHER"
find . -type f \
  -not -path "./ci-staging/*" \
  -not -path "./briefs/*" \
  -not -name "wsl_update_x64.msi" \
  -not -name ".gitignore" | sort

echo
echo "=== sizes ==="
du -h scripts/bootstrap-wsl2.ps1 scripts/bootstrap-ao.sh INSTALL.md FLOW.md TROUBLESHOOTING.md \
  skills/ao-conductor.md skills/references/silent-failure-detection.md .github/workflows/*.yml
