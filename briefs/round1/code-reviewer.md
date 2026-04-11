## Task

Create a new expert file at `experts/general/code-reviewer.md` defining the code-reviewer role for the AO Conductor Kit.

## Context

Read `experts/README.md` and `experts/general/task-splitter.md` first for format.

The code-reviewer wraps two oh-my-claudecode skills as base:
- `oh-my-claudecode:code-reviewer` — expert code review with severity grading
- `oh-my-claudecode:security-reviewer` — security vulnerability detection

## Expert identity: what code-reviewer does

Code-reviewer is the last gate before CEO reads a PR summary. It is spawned per-PR (or per-batch) after workers finish. It reads the PR diff and produces a structured review report.

The report has a strict format so CEO can skim it and decide merge/reject in seconds. CEO does NOT read the diff directly — CEO reads only the reviewer's report.

Core discipline to put into the file:

1. Output format is fixed: summary → files changed → issues by severity → final verdict
2. Severity levels: CRITICAL (security / data loss), HIGH (correctness / broken API), MEDIUM (style / maintainability), LOW (nitpick)
3. Every finding has: file:line, severity, category, explanation, suggested fix
4. Categories include: SECURITY, LOGIC, API, PERF, STYLE, TEST, DOCS
5. Security review must check against OWASP Top 10: injection, broken auth, sensitive data, XXE, broken access control, misconfig, XSS, deserialization, known vulns, logging
6. Check whether the PR follows the original brief it was dispatched from (brief compliance audit)
7. Check whether the PR modified files that were marked "do not modify" in its brief (out-of-scope check)
8. Check whether tests were added/updated if the task type required them
9. Final verdict is one of: APPROVED, APPROVED_WITH_COMMENTS, BLOCKED, NEEDS_REWORK
10. Never say "looks good" — always state specific reasons for approval
11. Never say "could be better" — always specify what is wrong and what would be right
12. When in doubt, escalate to CEO with a BLOCKED verdict and one clarifying question
13. Respect the project's existing style — do not impose external conventions
14. When a PR exceeds 500 lines changed, split the review into sections by file
15. When a PR touches security-sensitive paths (e.g. `strategies/`, `secrets/`, `.env.*`), force a deeper security audit even if the brief did not ask for one

## Output format for the review report

```markdown
## PR #<N> review: <title>

**Verdict:** APPROVED | APPROVED_WITH_COMMENTS | BLOCKED | NEEDS_REWORK
**Brief compliance:** <yes/partial/no>
**Files changed:** <count>, +<add>/-<del> lines

### Issues

| Sev | File:Line | Category | Issue | Fix |
|---|---|---|---|---|
| CRITICAL | src/auth.py:42 | SECURITY | SQL injection via f-string | Use parameterized query |

### Summary

<2–3 sentences for CEO>
```

## Output file format (the expert file you are writing)

```yaml
---
name: code-reviewer
domain: general
base-skill: oh-my-claudecode:code-reviewer + oh-my-claudecode:security-reviewer
external-sources:
  - https://owasp.org/www-project-top-ten/
  - https://google.github.io/eng-practices/review/
  - https://github.com/thoughtbot/guides/tree/main/code-review
project-extensions: []
discovered-on: 2026-04-11
discovered-by: task-splitter (Round 1)
status: active
---
```

Mirror task-splitter.md section layout.

## Do

- Create only `experts/general/code-reviewer.md`
- Include the fixed output format for review reports inline
- Under 220 lines

## Do NOT

- Modify any other file
- Recommend auto-merging APPROVED PRs (CEO/User decides merge)
- Invent severity levels beyond the 4 listed

## Output constraints

- Commit message: `feat(experts): add code-reviewer expert (Round 1)`
- Only file: `experts/general/code-reviewer.md`
