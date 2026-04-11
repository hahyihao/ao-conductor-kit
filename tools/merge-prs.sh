#!/usr/bin/env bash
# Merge the 6 AO-generated PRs in hahyihao/ao-test in sequence.
# Uses --squash for a clean main history.
set -e
export HTTPS_PROXY=http://172.17.224.1:7897
export HTTP_PROXY=http://172.17.224.1:7897

REPO=hahyihao/ao-test

for pr in 15 16 17 18 19 20; do
  echo "========== Merging PR #${pr} =========="
  gh pr merge "${pr}" --repo "${REPO}" --squash --delete-branch 2>&1 | tail -5 || \
    echo "  (merge failed for #${pr}, continuing)"
  echo
done

echo "=== remaining open PRs ==="
gh pr list --repo "${REPO}" --state open
