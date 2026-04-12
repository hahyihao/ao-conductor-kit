# Expert File Architecture

This document is the normative structure for expert files under `experts/`.
Future expert files must follow this 10-section contract so `task-splitter`,
workers, and reviewers can rely on a consistent layout.

Use `experts/general/expert-scout.md` as the golden template for density,
self-containment, and operational tone. If an existing file diverges from this
document, this architecture document is the standard to converge toward.

## Mandatory Sections

| # | Section | What it must contain | Why it exists |
| --- | --- | --- | --- |
| 1 | **Frontmatter** | Required fields: `name`, `agent`, `model`, `domain`, `description`, `base-skill`, `status`. Optional: `external-sources`, `project-extensions`, `discovered-on`, `discovered-by`. The `description` must be a rich multi-sentence identity statement that explains what the expert does and when to use it. | Dispatch, discovery, and auditing depend on stable metadata and reliable activation text. |
| 2 | **When to Apply** | Three tiers only: **Must Use**, **Recommended**, **Skip**. Each tier must include a decision criterion, not just examples. | Workers need a fast routing rule before they read the rest of the file. |
| 3 | **Rule Categories by Priority** | A table with exactly these columns: `Priority`, `Category`, `Impact`, `Key Checks`, `Antipatterns`. Order rows from highest to lowest priority. | This exposes the expert's decision stack and shows what matters most under pressure. |
| 4 | **Tools Available** | The tools the expert may use, plus each tool's purpose and usage constraints. Name prohibitions or approval requirements explicitly. | Tool misuse is a common failure mode; the expert must define safe tool boundaries. |
| 5 | **Core Rules** | A numbered list of the expert's main behavioral rules. These are the primary discipline the worker follows. | This is the executable doctrine of the expert. |
| 6 | **Antipatterns** | Refused behaviors, bad habits, or common mistakes. Every item must include a `because` clause. | Antipatterns prevent predictable failure and explain the reasoning behind the refusal. |
| 7 | **Failure Handling** | Concrete failure scenario followed by handling steps or escalation path. | Experts must stay useful when the ideal path breaks. |
| 8 | **Integration Notes** | Collaboration boundaries, handoffs, and ownership splits with other experts or roles. | Experts operate in a multi-role system and need explicit coordination rules. |
| 9 | **First Action** | The first thing the expert does at session start, before broad execution begins. | This creates a consistent startup routine and reduces thrashing. |
| 10 | **Quality Gate** | A self-check checklist. Every item must pass before the expert declares work done. | Completion must be observable and repeatable, not based on intuition. |

## Section Guidance

### 1. Frontmatter

Use YAML frontmatter at the top of the file. Keep field names stable and avoid
inventing extra required keys. `description` is not a slogan; it should read as
the expert's identity and activation contract.

### 2. When to Apply

Tell the router when the expert is mandatory, when it is helpful but optional,
and when it should be skipped. Write criteria that can be applied to a new
task, not vague role marketing.

### 3. Rule Categories by Priority

Group the expert's doctrine into a small number of categories and rank them.
This section is a map of the rule system, while `Core Rules` contains the full
behavioral detail.

### 4. Tools Available

List only tools the expert can actually use in this environment or workflow.
For each tool, state what it is for and what limits apply so the worker knows
when a tool is valid, risky, or forbidden.

### 5. Core Rules

Write the main operating rules as numbered imperatives. Keep them concrete,
testable, and specific enough that a worker can execute without guessing.

### 6. Antipatterns

Document the behaviors the expert refuses. Every item must explain its reason
with a `because` clause so the worker can generalize correctly in edge cases.

### 7. Failure Handling

Name the failure modes that matter for this expert and define what to do next.
Use scenario-to-response formatting so recovery steps are easy to scan.

### 8. Integration Notes

Clarify boundaries with adjacent experts, who owns what, and when handoff is
required. If overlap exists, explain the boundary instead of leaving it implied.

### 9. First Action

Define the startup move that orients the expert before it starts making changes.
This is usually a classification, scope check, file read, or state capture step.

### 10. Quality Gate

End with a checklist the expert can run against its own output. The checklist
must verify the expert's actual finish line, not just that some work happened.

## Skeleton Template

```md
---
name: <kebab-case-name>
agent: <codex|claude-code|other supported agent>
model: <model identifier>
domain: <general|project|language|tool>
description: >
  This expert is used when <task shape / decision boundary>.
  It owns <specific responsibility>, protects <main risk>, and is the default
  choice when <activation criteria>. It should not be used when <clear skip
  boundary>.
base-skill: <upstream source or provenance reference>
status: <active|draft|archived>
external-sources:
  - <url>
project-extensions: []
discovered-on: YYYY-MM-DD
discovered-by: <role or human>
---

# <Expert Name> Expert

Brief identity paragraph. State what the expert does, who invokes it, and the
boundary it enforces.

## 1. When to Apply

- **Must Use:** <decision criterion>
- **Recommended:** <decision criterion>
- **Skip:** <decision criterion>

## 2. Rule Categories by Priority

| Priority | Category | Impact | Key Checks | Antipatterns |
| --- | --- | --- | --- | --- |
| P0 | <highest-priority category> | <why it matters> | <what to verify> | <what to avoid> |
| P1 | <next category> | <why it matters> | <what to verify> | <what to avoid> |

## 3. Tools Available

| Tool | Purpose | Usage Constraints |
| --- | --- | --- |
| `<tool>` | <what it is for> | <limits / approval / forbidden cases> |

## 4. Core Rules

1. <primary rule>
2. <next rule>
3. <next rule>

## 5. Antipatterns

- <refused behavior>, because <reason>.
- <refused behavior>, because <reason>.

## 6. Failure Handling

- **<failure scenario>:** <handling steps or escalation path>.
- **<failure scenario>:** <handling steps or escalation path>.

## 7. Integration Notes

- `<role or expert>`: <boundary / handoff rule>.
- `<role or expert>`: <boundary / handoff rule>.

## 8. First Action

1. <startup step>
2. <startup step>

## 9. Quality Gate

- [ ] <must-pass self-check>
- [ ] <must-pass self-check>
- [ ] <must-pass self-check>
```

## Enforcement Notes

- All 10 sections above are mandatory for new expert files.
- Frontmatter is mandatory section 1 of the architecture, but it sits above the
  Markdown body. Number the body headings from `1` as shown in the skeleton.
- Keep expert files practical and concise. Under 200 lines is the default target
  unless the domain is unusually complex.
- Prefer one expert per file, one role per file, and one clear activation
  boundary per file.
