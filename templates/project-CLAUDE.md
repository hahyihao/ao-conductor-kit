# CLAUDE.md — project-level context for this repo

<!--
  This file is automatically loaded by Claude Code when you enter this directory.
  Purpose: tell Claude (acting as CEO) the project-specific constraints so it can
  dispatch correctly to AO workers without re-learning them every session.
-->

## Project identity

- **Name:** <your project name>
- **Purpose:** <one-line description>
- **Language/stack:** <e.g. Python 3.11, Node 20, Go 1.22>
- **Sensitive areas:** <e.g. `strategies/`, `secrets/`, `migrations/`>

## AO is configured for this project

- `agent-orchestrator.yaml` lives at the repo root.
- GitHub repo: `<owner>/<repo>`
- Default branch: `main`
- Orchestrator session prefix: `<prefix>`
- Start AO with: `ao start` from the project root inside WSL.

## Dispatch policy for this project

When the user asks for work in this repo, Claude (CEO) should:

1. **Default to parallel dispatch** for any task that touches more than one file or module.
2. **Handle directly** only for: typo fixes, one-liner debug, interactive exploration.
3. **Never write code directly** to the files under `strategies/` or `<other sensitive dir>` — always dispatch to a worker for those paths.

## Mandatory brief content for workers in this repo

Every issue body must include:

- Target file path(s)
- Why this change is needed
- Any constraints specific to this codebase (style, API version, forbidden patterns)
- Test expectation (or "no tests" if pure docs)
- Output constraint: exactly which files the worker may create/modify

## Known traps (project-specific)

- <List any gotchas workers keep hitting in this repo>
- Example: "Always run `pnpm install` after adding a dependency; the lockfile is strict."
- Example: "Do NOT commit `.env` or anything in `secrets/`."

## Contact & escalation

- If a worker opens an unsafe or policy-violating PR, the CEO must flag it and request changes via `gh pr review --request-changes`.
- If 3 iterations fail, the CEO must stop automatic dispatch and report to the human user.
