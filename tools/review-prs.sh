#!/usr/bin/env bash
set -e
for pr in 15 16 17 18 19 20; do
  echo "========== PR #${pr} =========="
  gh pr view "${pr}" --repo hahyihao/ao-test --json title,additions,deletions,changedFiles \
    --jq '.title + " | +" + (.additions|tostring) + " -" + (.deletions|tostring) + " / " + (.changedFiles|tostring) + " files"'
  echo "Files:"
  gh pr diff "${pr}" --repo hahyihao/ao-test --name-only | sed 's/^/  /'
  echo "CI:"
  gh pr checks "${pr}" --repo hahyihao/ao-test 2>&1 | head -6 | sed 's/^/  /' || echo "  (no checks yet)"
  echo
done
