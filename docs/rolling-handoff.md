# Rolling Handoff Specification

`docs/rolling-handoff.md` is the canonical PM handoff snapshot for the
currently active round. The next PM should be able to read this file and
continue work without replaying full git history, issue history, or
session logs.

## What this file is for

- Capture the current operational state, not a narrative diary.
- Preserve only the context needed to continue the current round.
- Make ownership, blockers, and next actions explicit.
- Prefer exact issue numbers, PR numbers, branch names, and UTC
  timestamps over vague references such as "earlier" or "recently".

## Update rules

- Update the file when a PM takes over a round.
- Update it again after any merge, new PR, blocker change, or priority
  change that affects the next PM's decisions.
- Before handing off, make one final pass so stale items are removed or
  marked as resolved.
- If a fact cannot be verified from the repo, issue tracker, PR state,
  or CI, write `unknown` instead of guessing.
- Keep the file short. Link or reference canonical issues and PRs
  instead of copying long histories into the handoff.

## Required structure

The handoff file must use the exact section headings below:

- `## current-round`
- `## merged-this-session`
- `## open-PRs`
- `## known-blockers`
- `## next-priorities`

### `current-round`

This section defines the round the next PM is inheriting.

Include:

- Round name or identifier.
- Current status such as `active`, `blocked`, `parked`, or `closing`.
- The round goal in one or two sentences.
- The canonical issues, docs, or briefs that define scope.
- The last completed action.
- The single next action if the next PM does nothing else first.

### `merged-this-session`

This section records merges that landed during the current PM session or
the handoff window being summarized.

For each item include:

- Issue and PR number when available.
- Branch name.
- A short note on what merged.
- Merge timestamp in UTC if known.

If nothing merged in the current session, write `- none`.

### `open-PRs`

This section lists only PRs that still matter to the current round.

For each item include:

- PR number.
- Branch name.
- Current state such as `open`, `review`, `changes requested`, or `CI
  failing`.
- Why the PR matters to the round.
- The next owner action.

If there are no relevant open PRs, write `- none`.

### `known-blockers`

This section should contain only active blockers, not general risks.

For each blocker include:

- What is blocked.
- The concrete blocker.
- The owner or system that must unblock it.
- The condition that would clear the blocker.

If there are no active blockers, write `- none`.

### `next-priorities`

This section is an ordered queue for the next PM. It should be short and
actionable.

Rules:

- Use a numbered list in priority order.
- Each item must be an executable next step, not a theme.
- Reference the exact issue, PR, branch, or file involved.
- Put the default takeover action at priority `1`.

## Authoring guidance

- Prefer overwrite over accumulation. The handoff should show the latest
  truth, not every state transition that happened.
- If context is no longer actionable, delete it instead of archiving it
  here.
- Keep wording operational: who owns it, what is blocked, what happens
  next.
- Do not duplicate information across sections unless it changes the
  next action.

## Template

Use this template when creating or refreshing a rolling handoff
snapshot. In list sections, keep the real entries or `- none`, not
both.

```md
# Rolling Handoff

Last updated: YYYY-MM-DD HH:MM UTC

## current-round

- Round: <name or identifier>
- Status: <active|blocked|parked|closing>
- Goal: <one or two sentences>
- Canonical scope: <issues, briefs, docs>
- Last completed action: <latest completed step>
- Default next action: <the first thing the next PM should do>

## merged-this-session

- PR #<n> on `<branch>`: <what merged> (<YYYY-MM-DD HH:MM UTC>)
- none

## open-PRs

- PR #<n> on `<branch>`: <state>; <why it matters>; next: <owner action>
- none

## known-blockers

- <work item> is blocked by <blocker>; owner: <person/system>; clears
  when: <condition>
- none

## next-priorities

1. <highest-priority next action>
2. <next action>
3. <next action>
```
