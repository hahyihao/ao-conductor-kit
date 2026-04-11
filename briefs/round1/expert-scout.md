## Task

Create a new expert file at `experts/general/expert-scout.md` that defines the expert-scout role for the AO Conductor Kit.

## Context

Read `experts/README.md` for the library's frontmatter schema. Read `experts/general/task-splitter.md` for the reference structure. Mirror task-splitter.md's section layout.

The expert-scout wraps three oh-my-claudecode skills as base:
- `oh-my-claudecode:document-specialist` — external documentation and reference lookups
- `oh-my-claudecode:external-context` — parallel web search for context
- `oh-my-claudecode:tech-scout` — technology scouting and evaluation

## Expert identity: what expert-scout does

Expert-scout is the self-extension mechanism of the expert library. When task-splitter looks up a domain in `experts/index.md` and finds nothing, it appends a line to `experts/discovery-queue.md` and spawns expert-scout. Expert-scout is responsible for:

1. Read the requested domain from discovery-queue.md
2. Search authoritative sources online for that domain
3. Extract 5–15 core discipline rules from the sources
4. Write a new expert file under the correct subdir (general/, project/, language/, tool/)
5. Update discovery-queue.md to mark the entry as resolved
6. Commit and open a PR

Core discipline to put into the file:

1. Never invent a domain — the domain name must come from discovery-queue.md
2. Prioritize sources in this order: official docs → RFC/PEP/spec → top 3 GitHub awesome-* lists → high-reputation individual blogs → top Stack Overflow answers
3. Extract only discipline that is stable (>2 years old) unless the domain is younger
4. Deduplicate content across sources — never paraphrase the same rule twice
5. Attribute every bullet to its source in a link, do not fabricate URLs
6. Keep the new expert file under 200 lines — density over length
7. The frontmatter must include every source URL under `external-sources`
8. Mark status: active immediately if the sources are authoritative; status: draft if only blog-level sources were found
9. Never overwrite an existing expert — if one is found, log the conflict in audit-log.md and stop
10. After writing the file, update discovery-queue.md's status column
11. Use the kit's commit message convention: `feat(experts): admit <domain>/<name> from Round <N> discovery`
12. Escalate to CEO if no authoritative source exists for the domain

## Output file format

```yaml
---
name: expert-scout
domain: general
base-skill: oh-my-claudecode:document-specialist + external-context + tech-scout
external-sources:
  - https://github.com/sindresorhus/awesome
  - https://www.rfc-editor.org/
  - https://peps.python.org/
project-extensions: []
discovered-on: 2026-04-11
discovered-by: task-splitter (Round 1)
status: active
---
```

Mirror task-splitter.md's section layout: role paragraph, numbered disciplines, "what you do NOT do", failure handling, integration notes.

## Do

- Create only `experts/general/expert-scout.md`
- Match frontmatter exactly
- Under 200 lines
- Integration section must explain how expert-scout is invoked (by task-splitter via discovery-queue.md + ao spawn)

## Do NOT

- Modify any other file
- Add "fetch the internet at runtime" behavior — expert-scout searches, reads, writes a file, commits, done
- Invent sources

## Output constraints

- Commit message: `feat(experts): add expert-scout expert (Round 1)`
- Only file: `experts/general/expert-scout.md`
- Do not touch `experts/index.md` or `discovery-queue.md` (library-maintainer territory)
