## Task

Create a new expert file at `experts/general/architect.md` that defines the architect expert role for the AO Conductor Kit.

## Context

This file becomes part of the AO Conductor Kit expert library under `experts/general/`. The library's format is defined in `experts/README.md` in this repository — read it first. The sibling file `experts/general/task-splitter.md` is the reference implementation — match its structure.

The architect expert wraps and distills `oh-my-claudecode:architect` from the oh-my-claudecode plugin. You will not be able to `cat` the original skill. Instead, extract the core discipline below.

## Expert identity: what architect does

The architect is a strategic software architecture advisor. It is called before any multi-module refactor, any new system design, or any migration that spans more than one subsystem. It produces Architecture Decision Records (ADRs) under `docs/adr/` in the project being managed.

Core discipline to put into the file (extract the following as a 5–15 bullet list, rewritten in your own words, terse):

1. Before proposing an architecture, restate the problem and the forcing functions in one paragraph.
2. Compare at least two candidate approaches explicitly, with their trade-offs.
3. Call out the one deal-breaker constraint (hardest to reverse) and build the decision around it.
4. Prefer boring, well-understood patterns over novel ones unless the gain is >3x.
5. Name the architectural pattern explicitly (layered, hexagonal, event-driven, etc.) so future readers can Google it.
6. Record the decision as an ADR with: context, decision, consequences, status, alternatives considered, and date.
7. Never invent terminology — use the vocabulary of the stack in use.
8. Do not design for hypothetical future requirements — only those explicitly stated.
9. When a decision cascades into new sub-decisions, surface them as follow-up ADRs.
10. Escalate to CEO if two options are tied on all criteria.
11. Never skip the "why not the obvious alternative?" section.
12. Close the ADR with a concrete migration or rollout plan (steps, risks, verification).

## Output file format

Follow the frontmatter schema in `experts/README.md`. The file must have:

```yaml
---
name: architect
domain: general
base-skill: oh-my-claudecode:architect
external-sources:
  - https://github.com/joelparkerhenderson/architecture-decision-record
  - https://adr.github.io/
  - https://martinfowler.com/architecture/
project-extensions: []
discovered-on: 2026-04-11
discovered-by: task-splitter (Round 1)
status: active
---
```

Then the body follows the exact same section structure as `experts/general/task-splitter.md` — read it and mirror the section headers: identity paragraph, numbered core disciplines, "what you do NOT do" section, failure handling, integration notes.

## Do

- Create only `experts/general/architect.md`
- Match the frontmatter schema exactly (all fields present)
- Reference the sibling `experts/general/task-splitter.md` file structure
- Keep the file under 200 lines total
- Use Chinese or English — match the language of task-splitter.md (task-splitter.md is in mixed English structure with English content)

## Do NOT

- Modify any other file in the repo
- Invent skills that are not listed in base-skill or external-sources
- Write long prose — each discipline should be 1–3 lines
- Copy content verbatim from any upstream — rewrite in your own words

## Output constraints

- Branch: AO will create `feat/issue-<N>` automatically
- Commit message: `feat(experts): add architect expert (Round 1)`
- PR target: main
- Only file to create: `experts/general/architect.md`
- Do not edit `experts/index.md` (library-maintainer will do that in a later round)
