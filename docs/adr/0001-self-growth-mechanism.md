# ADR 0001: Round 4 Self-Growth Mechanism

- Date: 2026-04-12
- Status: Accepted
- Deciders: Architect / issue #128

## Context

`experts/` now exists as a real library with a stable directory layout,
an index, a discovery queue, and an append-only audit log. The Round 4+
goal in [ROADMAP.md](../../ROADMAP.md) and [ARCHITECTURE.md](../../ARCHITECTURE.md)
is to make that library self-growing at runtime:

- when dispatch needs an expert that does not exist yet, the system should
  discover and admit it
- when the library drifts, overlaps, or accumulates stale records, the
  system should clean it up without deleting history

Today that behavior exists only as doctrine. The repository has:

- a documented `expert-scout` role
- a documented `library-maintainer` role
- placeholder library records in
  [experts/index.md](../../experts/index.md),
  [experts/discovery-queue.md](../../experts/discovery-queue.md), and
  [experts/audit-log.md](../../experts/audit-log.md)

This ADR turns the existing role contracts in
[experts/general/expert-scout.md](../../experts/general/expert-scout.md)
and
[experts/general/library-maintainer.md](../../experts/general/library-maintainer.md)
into one runtime architecture.

But it does not yet have a formal architecture that answers:

- who is allowed to trigger discovery or cleanup
- what the canonical control records are
- when dispatch must block
- how scout admission and maintainer audit fit into one coherent flow
- how archive and cleanup happen without direct deletion

This ADR defines that architecture. It is the gate before implementation
issue splitting. It does not introduce runtime code in this PR.

## Decision Drivers

1. Self-growth must preserve the repository's core audit model: issue -> branch
   -> PR -> merge.
2. Dispatch quality must remain deterministic. A worker must not silently
   improvise because an expert was missing.
3. The library must remain append-only in spirit: archive, never delete.
4. The architecture must keep role boundaries explicit between CEO, PM
   (`task-splitter`), worker, scout, and maintainer.
5. Background automation may trigger work, but it must not bypass review
   or mutate `main` directly.
6. The first Round 4 design should stay boring and inspectable, so future
   implementation issues can be split cleanly.

## Decision

We will implement Round 4 self-growth as a **PR-mediated control loop**
with two separate but connected paths:

1. **Event-driven discovery path** for missing experts
2. **Externally triggered audit path** for cleanup, index refresh, and
   archive decisions

The design pattern is:

- `experts/discovery-queue.md` is the canonical request ledger for missing
  experts
- `experts/index.md` is the canonical active-library lookup surface used by
  dispatch
- `experts/audit-log.md` is the append-only record of every admission audit
  and periodic maintenance run
- all material library changes land through a focused PR to `main`
- no role writes directly to the default branch

### Discovery Path: Expert-Scout Admission

The chosen architecture for missing experts is a **blocking admission
pipeline**.

#### Trigger sources

A discovery request may originate from:

- `task-splitter` during pre-dispatch expert resolution
- a worker during execution when the brief proved insufficient because a
  required expert did not exist
- a human or CEO who identifies a missing expert as a follow-up task

Workers do not spawn `expert-scout` directly. A worker reports the miss
upstream; the PM owns normalization and routing.

#### Canonical flow

1. The PM determines that a specific expert is missing.
2. The PM records one canonical request in
   `experts/discovery-queue.md`.
3. The PM deduplicates equivalent requests against existing pending or
   blocked queue entries before spawning anything.
4. `expert-scout` claims one queue entry, researches authoritative
   upstreams, and prepares exactly one expert admission candidate.
5. The scout opens one focused PR that contains the admission unit. That
   unit must land atomically and include:
   - the new `experts/<domain>/<name>.md` file
   - the queue state transition for the request
   - the matching `experts/index.md` update
   - the matching `experts/audit-log.md` entry
6. `library-maintainer` performs the admission audit on that PR before it
   merges.
7. Only after the PR lands on `main` may the PM retry the blocked dispatch.

The critical choice here is that **admission is blocking for dependent
dispatch**. If a plan depends on the missing expert, the plan waits. We do
not let a worker proceed with an implied expert or a partially admitted
library state.

#### Queue state model

Architecturally, a discovery request has three states:

- `pending`: requested and not yet claimed or resolved
- `blocked`: scout could not safely admit it and escalation is required
- `resolved`: the admission PR merged and the expert is visible in the
  index

The exact Markdown syntax for representing these states is deferred to
implementation. The architectural requirement is the state machine, not the
file formatting.

### Audit Path: Library-Maintainer Cleanup

The chosen architecture for cleanup is an **externally triggered periodic
audit pipeline**.

`library-maintainer` has two operating modes that share the same output
rules:

- **Immediate mode**: admission audit for each scout PR
- **Periodic mode**: full-library maintenance sweep

#### Trigger model

Immediate mode is triggered by every scout admission PR.

Periodic mode is triggered only by an explicit external actor:

- a user asks for cleanup or deep audit
- CEO or PM requests a maintenance run because drift is suspected
- lifecycle automation invokes a scheduled audit

The maintainer does not invent its own hidden scheduler. If recurring
cadence is needed, the cadence is owned by the external trigger owner
(likely lifecycle automation), not by the expert file itself.

When the library grows past 50 experts, the external trigger owner should
add a weekly full-audit cadence. That cadence is still external; it is not
embedded as self-scheduling logic inside `library-maintainer`.

#### Periodic audit scope

A periodic audit checks at minimum:

- index drift versus actual expert files
- unresolved or stale discovery requests
- duplicate or near-duplicate experts in the same domain
- broken or unreachable `external-sources`
- stale experts that need review
- upstream drift that should be surfaced but not auto-applied
- archive candidates

Each periodic run produces one focused PR or one blocked report. Cleanup
does not happen by silent background mutation.

#### Archive architecture

Archive is defined as an **in-place status transition**, not file deletion
and not relocation into a separate archive tree.

When an expert leaves active use:

- the expert file remains in its current domain directory
- frontmatter `status` changes to `archived`
- `experts/index.md` reflects the status and refreshed counts
- `experts/audit-log.md` records why the archive happened

This preserves file history, path stability, and auditability. Round 4 does
not introduce a physical `archive/` directory.

### Atomic Merge Unit

The library's visible state must not drift across files. Therefore the
merge unit for a discovery admission or maintenance change is atomic at the
PR level.

That means a successful change lands with all of its record updates
together:

- expert content
- queue state
- index update
- audit-log entry

We explicitly reject a design where the expert file merges first and the
index or audit trail is updated later in a separate reconciliation step.

### Ownership Boundaries

The self-growth loop uses these role boundaries:

| Role                 | Owns                                                                                                           | Must not do                                                                                   |
| -------------------- | -------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| CEO                  | sets goal, approves escalations, decides whether to accept broad maintenance outcomes                          | write expert files or perform library audits directly                                         |
| PM / `task-splitter` | resolves expert needs, records discovery requests, blocks or retries dispatch, routes escalations              | invent expert content, bypass missing-expert gates                                            |
| Worker               | reports missing expertise discovered during execution, then waits or continues only if PM explicitly re-briefs | spawn scout directly or patch the library ad hoc                                              |
| `expert-scout`       | researches one missing expert and prepares one admission candidate                                             | update unrelated library records or redesign taxonomy                                         |
| `library-maintainer` | audits admissions, refreshes index, records audit results, proposes consolidation or archive PRs               | delete experts, rewrite audit history, auto-update upstream drift into content without review |
| Lifecycle automation | triggers recurring audit runs and routes feedback                                                              | make library content decisions by itself                                                      |

The important boundary is that **only PM decides whether a missing expert
blocks active work**, and **only maintainer decides whether an admission or
cleanup patch is library-safe**.

### Failure Handling and Safety Rails

The chosen architecture includes these mandatory rails:

1. No authoritative source: scout marks the request `blocked`, records the
   reason, and escalates. No expert is admitted from intuition.
2. Existing expert conflict: scout does not overwrite; maintainer handles
   consolidation or rejection through PR review.
3. Duplicate queue requests: PM deduplicates before spawn and links later
   requests to the canonical queue entry.
4. Partial admission is invalid: if the PR does not update queue, index,
   and audit record together, the admission is not complete.
5. Broad cleanup is bounded: if a periodic run would rewrite more than 3
   experts, maintainer stops and converts the outcome into follow-up issues
   instead of shipping a giant PR.
6. Broken external links during periodic audit do not cause deletion.
   Default action is to mark the expert `draft` or flag it for review,
   then log the evidence.
7. User-triggered "clean up" means deep audit, not auto-merge of sweeping
   structural changes without review.

## Consequences

### Positive

- Missing experts become a visible, auditable control flow instead of an
  implicit failure mode.
- Dispatch remains deterministic because dependency on a missing expert is
  resolved before work resumes.
- Cleanup and archive stay reviewable and reversible at the PR level.
- The library keeps one coherent source of truth across expert files,
  queue, index, and audit log.

### Negative

- Discovery can slow dispatch because dependent work blocks until
  admission merges.
- The system needs external trigger plumbing for periodic audits.
- Maintainer becomes a real gate, which adds process overhead but prevents
  silent library drift.

### Operational implication

Round 4 implementation should be activated only after the Round 3 expert
set is fully integrated into `main`, because the self-growth loop depends
on `experts/index.md` being the stable runtime lookup surface.

## Alternatives Considered

### 1. Manual-only library curation

Have CEO or a human add missing experts and run cleanup by hand.

Rejected because it breaks the stated Round 4 goal of runtime self-growth,
keeps missing experts as an interrupt-driven human bottleneck, and weakens
the role boundaries already defined in the repository doctrine.

### 2. Fully automatic background mutation

Let automation discover experts, rewrite indices, and archive experts in
the background without a normal PR boundary.

Rejected because it breaks the repository's audit model, hides failures, and
makes library state changes harder to review and roll back.

### 3. Non-blocking discovery

Let workers continue with a best-effort interpretation while scout admits
the missing expert asynchronously.

Rejected because it directly conflicts with the requirement that expert
injection is part of brief quality and dispatch determinism. If the expert
matters enough to request, the work should not silently proceed as though
it already exists.

## Deferred to Follow-On Implementation Issues

This ADR intentionally does not decide:

- the exact Markdown schema for queue metadata and blocked-state fields
- the exact command surface (`ao send`, `ao spawn`, lifecycle hooks, or
  wrapper scripts) for each trigger
- whether maintainer amends scout branches directly or only through review
  comments, as long as the final merge unit stays atomic
- the exact stale-age thresholds and duplicate-detection heuristics
- CI policy details for link checking, schema validation, or auto-merge
- dashboards, metrics, and notification formatting

Those are implementation issues downstream of this ADR.

## Rollout Plan

1. Define the concrete queue state schema and the admission/audit record
   format.
2. Implement PM-side missing-expert detection, deduplication, and blocking
   retry behavior.
3. Implement scout-side admission preparation for one queue entry at a
   time.
4. Implement maintainer-side immediate admission audit so one PR can land
   atomically with expert, queue, index, and audit-log updates.
5. Implement periodic audit triggering via lifecycle automation or explicit
   user/PM commands.
6. Add validation and observability so blocked requests, archive actions,
   and index drift are easy to inspect.

## Verification

This ADR is successful when later Round 4 implementation can be split into
clear issues that answer these questions without reopening architecture:

- how a missing expert becomes one canonical discovery request
- when dispatch must wait
- how scout and maintainer divide the admission path
- how cleanup and archive land without deletion or direct-branch mutation
- which details remain implementation choices instead of architectural
  ambiguity
