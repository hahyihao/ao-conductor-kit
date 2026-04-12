# AO Conductor Kit — Roadmap

> Last updated: 2026-04-12
> Source of truth for round status and pending work.

---

## Current Status

### Round 0 — Bootstrap (DONE)
- experts/ directory structure
- experts/general/task-splitter.md (hand-written, 284 lines)
- experts/index.md / audit-log.md / discovery-queue.md / README.md

### Round 1 — Infrastructure Experts (DONE)
- architect.md (#9)
- expert-scout.md (#13)
- library-maintainer.md (#12)
- env-ops.md (#11)
- code-reviewer.md (#10)

### Round 2 — General Experts (DONE)
- code-writer, script-writer, writer, test-engineer, debugger, security-auditor, refactorer, planner
- All merged to main

### Round 2.5 — Specialist Experts (DONE)
- expert-writer (#84)
- prompt-engineer
- session-learner

### Round 3 — Project Experts (DONE)
10 project experts merged to main:
- binance-trading, chat-analysis, douyin-content, game-automation
- novel-reader, qq-bot-audit, swarm-commander, tieba-operation
- xianyu-ops, ztc-optimizer

Total experts in library: 27

### Round 4 — Self-Growth Mechanism (IN PROGRESS)
- [ ] ADR: docs/adr/0001-self-growth-mechanism.md (architect worker dispatched 2026-04-12)
- [ ] expert-scout auto-discovery implementation
- [ ] library-maintainer periodic cleanup implementation

---

## Community Improvements (IN PROGRESS, dispatched 2026-04-12)

7 tasks dispatched, workers spawning:
- [ ] CI auto-feedback loop
- [ ] MAX_ITERATIONS kill switch (task-splitter)
- [ ] Token budget 85% warning (task-splitter)
- [ ] auto-reviewer expert
- [ ] REFLECTION accumulation loop
- [ ] docs/rolling-handoff-spec.md
- [ ] ecosystem-monitor expert

---

## Infrastructure PRs

- #62 [CONFLICTING] fix: sanitize WSL Windows PATH pollution — kit-40 fixing
- #127 [MERGED] docs: PM context-health monitoring doctrine

---

## Pending Plans (not yet implemented)

- docs/plan-model-routing.md — model routing upgrade (CEO Sonnet / PM Opus / Worker GPT+Opus mix)
  Prerequisites: all PRs merged, Round 4 done, community improvements done

---

## Known Issues

| # | Issue | Status |
|---|---|---|
| 1 | tmux 3.2a segfault | Fixed (compiled 3.5a from source) |
| 2 | WSL PATH Windows pollution | In progress (#62) |
| 3 | WSL2 localhost forwarding drift | Fixed (repair-wsl2-localhost-forwarding.ps1) |
| 4 | ao session kill does not clean worktree (Issue 12) | Documented, workaround: manual rm + git worktree prune |
| 5 | ao status (unknown) != dead | Documented in TROUBLESHOOTING.md |

---

## Next Session Checklist

1. Read ARCHITECTURE.md
2. Read this ROADMAP.md for current state
3. Read experts/general/task-splitter.md
4. Read TROUBLESHOOTING.md (tmux segfault + ao send F7 bug critical)
5. ao status — check orchestrator health
6. tmux -V >= 3.3 (if 3.2a, fix immediately per Issue 11)
7. Resume from current round

---

## Handoff Snapshot — 2026-04-12 23:22 CST (+0800)

### Pending tasks

- Open PRs #1, #2, and #3 remain pending as dependabot bump follow-ups.
- Open issue #149 remains in the tracker; its model routing A work appears to have landed via merged PRs, so this should be treated as follow-up/admin cleanup if it is still open at resume time.

### Completed work summary

- Round 2 experts merged (#22, #23, #24, #25, #26, #27, #28, #29).
- Round 2.5 work merged (#84, #94, #104).
- Round 3 project experts merged (#99, #100, #101, #102, #103, #105, #107, #108, #109, #111).
- Stability PRs merged (#82, #89, #90, #91, #92).
- Channel and callback work merged (#98, #152, #153, #157).
- Model routing PRs merged (#154, #155, #156).
- Round 4 ADR merged (#129).
- Expert index, reference, and CI guardrail work merged (#113, #117, #121, #122, #125, #127).
- Community improvements merged (#139, #140, #141, #142, #143, #144, #145).

### Next-step plan

- Verify and triage the remaining dependabot PRs (#1, #2, #3).
- Clean tracking drift such as issue #149 if it is still open after its implementation PR merged.
- Continue Round 4 implementation issue splitting from ADR #129 when the handoff resumes.
