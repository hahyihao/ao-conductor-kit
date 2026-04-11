## Task

Create a new expert file at `experts/general/library-maintainer.md` defining the library-maintainer role for the AO Conductor Kit.

## Context

Read `experts/README.md` for the library's rules. Read `experts/general/task-splitter.md` for the reference section structure.

The library-maintainer wraps two oh-my-claudecode skills as base:
- `oh-my-claudecode:verifier` — verification strategy and evidence-based completion checks
- `oh-my-claudecode:simplify` — consolidation and cleanup

## Expert identity: what library-maintainer does

The library-maintainer is the librarian of `experts/`. It has two modes:

**Immediate mode** (runs on every new expert admission):
1. Validate the frontmatter schema (all required fields present, correct types)
2. Detect duplicates against existing experts in the same domain
3. Verify every URL in `external-sources` is reachable (HEAD request)
4. Verify `base-skill` references a real OMC skill or upstream that exists
5. Update `experts/index.md` with a new row for the new expert
6. Append an entry to `experts/audit-log.md`

**Scheduled mode** (runs periodically, triggered by user or cron):
1. Scan all experts for stale `discovered-on` dates (> 180 days without review)
2. Detect near-duplicate experts in the same domain (same base-skill, similar name)
3. Re-verify all external-sources URLs (flag 404s as `status: draft`)
4. Detect content drift: compare against upstream OMC skill if available
5. Propose consolidations via PR (never delete — always archive)
6. Update `experts/index.md` stats

Core discipline to put into the file:

1. The library-maintainer never deletes experts — only moves them to `status: archived`
2. All structural changes to the library go through PR — never direct writes
3. When two experts overlap, propose a merge PR (new consolidated expert + archive the two originals)
4. Frontmatter validation is strict: missing fields → admission blocked
5. External sources are verified via HEAD request with 5s timeout
6. Audit-log entries are append-only — never rewrite history
7. When a base-skill upstream version changes, add a note but do not auto-update the expert (human or scout decides)
8. When the library grows past 50 experts, auto-schedule a weekly full audit
9. Never run destructive git operations — only `git add`, `commit`, `push` of new PRs
10. When a URL goes 404, mark the expert as `status: draft` and log it — do not archive yet
11. When audit finds nothing to fix, write a single-line audit entry "no drift detected"
12. Stop and escalate to CEO if detected drift would require rewriting more than 3 experts in one run

## Output file format

```yaml
---
name: library-maintainer
domain: general
base-skill: oh-my-claudecode:verifier + oh-my-claudecode:simplify
external-sources:
  - https://keepachangelog.com/en/1.1.0/
  - https://semver.org/
  - https://12factor.net/config
project-extensions: []
discovered-on: 2026-04-11
discovered-by: task-splitter (Round 1)
status: active
---
```

Mirror task-splitter.md's section layout.

## Do

- Create only `experts/general/library-maintainer.md`
- Include both immediate mode and scheduled mode sections
- Under 220 lines
- Explicitly state that library-maintainer writes PRs, never direct edits

## Do NOT

- Modify any other file
- Propose deletion semantics anywhere — archival only
- Invent a cron scheduler — the doctrine only says "periodic" which is externally triggered

## Output constraints

- Commit message: `feat(experts): add library-maintainer expert (Round 1)`
- Only file: `experts/general/library-maintainer.md`
