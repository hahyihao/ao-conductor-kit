# Changelog

All notable changes to the AO Conductor Kit are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `patches/ao-main-2ebe111a-pr-feedback-context.patch` — upstream AO patch
  that adds concrete CI/review feedback context to lifecycle auto-reroutes and
  caps review auto-feedback retries at 2 by default

### Changed

- `experts/general/task-splitter.md` — now makes `ci_failed` / review
  auto-routing explicit and escalates after 2 auto-feedback loops on the same
  PR
- `templates/agent-orchestrator.yaml` and `templates/project-CLAUDE.md` —
  document the 2-retry PR feedback loop expectation for project configs

## [0.2.0] — 2026-04-11

### Added

- `LICENSE` — MIT license
- `VERSION` — SemVer source of truth
- `CHANGELOG.md` — this file
- `SECURITY.md` — secrets handling policy and responsible disclosure
- `scripts/verify-install.sh` — smoke test that verifies all 9 components are installed and reachable
- `tools/` — promoted from `ci-staging/`, now contains named utilities:
  - `tools/build-mother.sh` — extract worker PRs into the mother disc
  - `tools/review-prs.sh` — batch summary of PR diffs and CI status
  - `tools/merge-prs.sh` — squash-merge a list of PRs
  - `tools/git-init-push.sh` — initialize and push the mother disc to GitHub
- `.github/pull_request_template.md` — enforce brief/checklist in PRs
- `.github/ISSUE_TEMPLATE/bug_report.md` — structured bug reports
- `.github/ISSUE_TEMPLATE/feature_request.md` — structured feature requests

### Fixed

- `scripts/bootstrap-wsl2.ps1` — replaced the `.AUTHOR: TODO` placeholder with an actual author identifier

### Changed

- `ci-staging/` removed; all helper scripts moved to `tools/`
- `.gitignore` — no longer hides tools (now versioned), still hides `wsl_update_x64.msi` and `.omc/`

## [0.1.0] — 2026-04-11

### Added — initial release (mother disc)

- `README.md` — master entry point with 3 usage scenarios
- `CLAUDE.md` — project-level Claude Code context for the mother disc directory
- `INSTALL.md` (669 lines) — 8-phase install guide, written by Codex worker `demo-6` from AO issue #11
- `FLOW.md` (581 lines) — CEO→PM→Worker doctrine, written by `demo-7` from issue #12
- `TROUBLESHOOTING.md` (564 lines) — 10 real issues from initial install, by `demo-8` from issue #13
- `scripts/bootstrap-wsl2.ps1` (237 lines) — Windows WSL2 installer, by `demo-4` from issue #9
- `scripts/bootstrap-ao.sh` (183 lines) — WSL toolchain installer, by `demo-5` from issue #10
- `skills/ao-conductor.md` (309 lines) — Claude CEO skill source, by `demo-9` from issue #14
- `templates/agent-orchestrator.yaml` — new-project AO config template
- `templates/project-CLAUDE.md` — per-project Claude context template
- `.github/workflows/super-linter.yml` — 50+ language linting (super-linter v7)
- `.github/workflows/codeql.yml` — semantic security analysis (CodeQL v3)
- `.github/workflows/gitleaks.yml` — secret scanning (gitleaks v2)
- `.github/workflows/dependency-review.yml` — PR-scoped dependency review (v4)
- `.github/dependabot.yml` — weekly GitHub Actions upgrade
- `.gitleaks.toml` — documentation placeholder allowlist
- `briefs/` — 6 task briefs used to dispatch the Codex workers that wrote v0.1
- `ci-staging/` — intermediate artifacts (superseded by `tools/` in v0.2)

### Generation method

v0.1 was produced via AO self-dispatch in about 8 minutes:

- CEO (Claude Opus) wrote 6 detailed briefs to `briefs/`
- Created 6 GitHub issues (`#9`–`#14`) in `hahyihao/ao-test`
- `ao batch-spawn 9 10 11 12 13 14` launched 6 parallel Codex workers
- Each worker wrote one file, committed, pushed, and opened a PR
- Total worker output: ~2,543 lines across 6 files
