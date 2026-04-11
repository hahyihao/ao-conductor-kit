## Task: Write `FLOW.md`

Create the doctrine document for the AO Conductor Kit, in Chinese. This explains the "CEO → Project Manager → Worker" three-layer model and the standard operating procedure for dispatching work. No code — this is pure doctrine and flow.

## Core idea to convey

The user's current Claude Code interactive window is the CEO. Its job is to think, read intent, write briefs, and review. It does NOT touch code directly. Claude's 1M context window is a limited cognitive bandwidth resource. Every token spent on reading files, writing code, or running tests is a token NOT spent on thinking. Offloading execution to Codex workers lets Claude keep the full context window for strategy.

## Three layers

### Layer 1: CEO (总经理) — the current Claude Code window
- Role: read user intent, decide strategy, write briefs for each subtask, dispatch, review PRs, report progress.
- Never: write code directly, read files for execution purposes, run tests or builds.
- Tools: TaskCreate for tracking, Bash only for AO orchestration commands (ao status, ao send, gh issue create, ao batch-spawn).
- Key metric: keep token usage per session low (under 80k) by routing execution away.
- Output to user: concise status reports, proposed next actions, summaries of worker output.

### Layer 2: Project Manager (项目经理) — the AO orchestrator session
- Physical form: a Codex or Claude Code CLI running inside a tmux window in WSL, managed by AO.
- Role: receive high-level intent from CEO via `ao send`, break it into subtasks, spawn workers, monitor them.
- Lives in: /root/.worktrees/ao-demo/demo-orchestrator-N in WSL, bound to a dedicated git branch (orchestrator/...) so it doesn't pollute main.
- Configured by: agent-orchestrator.yaml under defaults.orchestrator.
- Stays running between tasks. Same session receives multiple messages over time.
- One orchestrator per project, named like "<sessionPrefix>-orchestrator-<N>".

### Layer 3: Workers (员工) — Codex CLI sessions spawned per issue
- Physical form: a Codex CLI process running inside its own tmux window, with its own git worktree, bound to its own feature branch.
- Role: handle exactly ONE GitHub issue. Read the issue body, generate the code, commit, push, open a PR.
- Isolation: each worker has its own .worktrees/<prefix>-<N> directory, so multiple workers cannot step on each other's files.
- Spawn command: `ao batch-spawn 1 2 3 4 5` creates 5 workers in parallel, one per issue number.
- Each worker exits after its first PR is opened. The lifecycle worker takes over from there.

## The reaction engine

AO runs a lifecycle worker in the background that polls GitHub for:
- CI status on each open PR
- New review comments on each open PR
- Whether the issue has been closed manually

When a failure or new comment appears, the lifecycle worker sends the failure details back to the original worker session via `ao send`, which re-wakes Codex and asks it to fix the problem. This loop continues until CI is green or max retries is exceeded.

## Standard dispatch procedure (CEO playbook)

1. User gives a goal in natural language.
2. CEO (you) decides: is this one task or multiple parallelizable tasks?
   - One small task → handle directly with one Codex invocation or Claude's own tools.
   - Multiple parallelizable tasks → dispatch to AO.
3. CEO writes ONE detailed brief per subtask, stored as a markdown file under briefs/.
4. CEO creates N GitHub issues using `gh issue create --body-file`, one per brief.
5. CEO confirms AO is running: `ao status`. If not, `cd <project> && ao start`.
6. CEO spawns N workers in parallel: `ao batch-spawn <id1> <id2> <id3> ...`.
7. CEO monitors: `ao status` every few minutes, or watches the dashboard at http://localhost:3000.
8. When workers finish, CEO reviews each PR for quality. Writes a summary for the user: which PRs are good, which need rework.
9. User decides to merge, request changes, or reject.
10. If CI fails on any PR, the reaction engine automatically re-dispatches to the same worker. CEO only intervenes when max retries is hit.

## ASCII diagram

Include an ASCII art flow diagram that shows:
- User on the left
- CEO (Claude) in the middle upper
- AO Orchestrator below the CEO
- Three Worker sessions in parallel below the orchestrator
- Each worker connected to its own git worktree
- Arrow from workers up to GitHub (push/PR)
- Arrow from GitHub back down to the Lifecycle Worker (polling)
- Arrow from Lifecycle Worker back to Workers (reaction engine)

## When to use AO vs when to skip

### Use AO when
- Task is multi-file and parts are independent (can parallelize)
- Task involves long deep work where Claude's context would fill up (big refactors, research)
- Task benefits from multi-angle analysis (security audit + perf audit + style audit in parallel)
- You need reproducible, auditable output (each worker commits and PRs its own slice)

### Skip AO when
- Task is a one-line edit or bug fix
- Task requires live UI feedback (front-end debugging)
- Task needs tight iteration with the user (conversational exploration)
- The overhead of creating issues exceeds the value of parallelism (typically any task under 15 minutes single-worker)

## Writing requirements

1. Full Chinese prose.
2. Use H2 for the three layers and H2 for each major section.
3. Include the ASCII diagram verbatim in a code fence.
4. At least one concrete example walkthrough: "假设用户说'帮我审计交易策略的三个风险点'" — trace it through all three layers.
5. End with a one-page cheat sheet of the 10 dispatch-procedure steps.
6. Target length: 300 to 600 lines.
7. No code samples beyond shell commands. This is doctrine, not implementation.

## Output constraints

- Create only this file: FLOW.md (at repo root)
- Do NOT modify any other file.
- Commit message: "docs: add FLOW.md CEO-PM-Worker doctrine"
- Open a pull request to main.
