# Expert Library Audit Log

Append-only log. Each entry is a single audit run by `library-maintainer`.
Format: `## YYYY-MM-DD HH:MM [trigger] — summary`

## 2026-04-11 21:00 [bootstrap] — Round 0 initial state

- Created experts/ directory structure
- Added first expert: general/task-splitter.md (hand-written by CEO)
- No duplicates, no stale entries
- All required placeholders present (index.md, audit-log.md, discovery-queue.md)

## 2026-04-12 05:45 [issue-75] — Superpowers merger gate roles

- Added `experts/general/verifier.md` for independent Gate Function runs
- Updated `experts/index.md` so task-splitter can discover the verifier role
- Preserved existing `task-splitter` entry and zero-backlog doctrine coverage

## 2026-04-12 06:05 [pr-78-rework] — reviewer pass contract

- Added `experts/general/code-reviewer.md`
- Defined concrete `--pass=spec` and `--pass=quality` invocation contracts and structured output schemas
- Updated `experts/index.md` so review workers can discover the two-pass reviewer identity
