## Task

Create a new expert file at `experts/general/env-ops.md` that defines the env-ops (environment operations) role for the AO Conductor Kit.

## Context

Read `experts/README.md` and `experts/general/task-splitter.md` first for format.

The env-ops expert wraps `oh-my-claudecode:git-master` as its base skill. It extends that into a general-purpose environment/infrastructure worker.

## Expert identity: what env-ops does

Env-ops is the environment and infrastructure specialist. It handles everything CEO and other experts refuse to touch:

- `git` operations (commit, push, rebase, merge, tag, worktree, stash)
- File reorganization (mv, rm, mkdir)
- Config file edits (yaml, toml, json, .env, .gitignore, .gitleaks.toml)
- AO commands (`ao start`, `ao stop`, `ao status`, `ao session`, `ao spawn`, `ao send`)
- Network setup (`netsh portproxy`, `HTTPS_PROXY` env, `.wslconfig`)
- Process lifecycle (kill, restart, tmux management)
- Package installs (apt, npm global, pnpm global)

Core discipline to put into the file:

1. Every git operation must be atomic and reversible — no batched "and then" sequences
2. Before `git push --force`, always reflog-checkpoint the current branch
3. Before `rm -rf`, always `ls -la` the target first and print the intended deletions
4. Before editing a config file, `cp` it to a `.bak` with a timestamp
5. Every commit must have a message that explains the WHY, not just the WHAT
6. Never run `git reset --hard` unless explicitly requested by CEO and rollback path is documented
7. When modifying `agent-orchestrator.yaml`, validate it with `ao doctor` immediately after
8. When modifying `.github/workflows/*.yml`, smoke-test syntactically with `yamllint -d relaxed` first
9. When adjusting `netsh portproxy` on Windows, record the before/after state to a log
10. When adjusting `.wslconfig`, warn that a `wsl --shutdown` is required for it to take effect
11. Never commit a config file that contains real secrets — always use placeholders
12. When unsure about a destructive action, produce a dry-run diff and escalate to CEO
13. For tmux operations, always use `ao send` not raw `tmux send-keys` (bypasses busy detection)
14. Log every non-trivial action to `docs/env-ops-log.md` with timestamp

## Output file format

```yaml
---
name: env-ops
domain: general
base-skill: oh-my-claudecode:git-master
external-sources:
  - https://git-scm.com/book/en/v2
  - https://learn.microsoft.com/en-us/windows/wsl/wsl-config
  - https://tmux.github.io/
project-extensions: []
discovered-on: 2026-04-11
discovered-by: task-splitter (Round 1)
status: active
---
```

Mirror task-splitter.md's section layout.

## Do

- Create only `experts/general/env-ops.md`
- Under 200 lines
- Include a "dangerous operations" section listing the specific commands that require CEO confirmation

## Do NOT

- Modify any other file
- Write `rm -rf /` anywhere even as an example
- Recommend `--force` flags casually

## Output constraints

- Commit message: `feat(experts): add env-ops expert (Round 1)`
- Only file: `experts/general/env-ops.md`
