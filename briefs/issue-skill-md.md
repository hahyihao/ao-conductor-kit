## Task: Write `skills/ao-conductor.md`

Create the source file for a Claude Code Skill. When a user installs this skill at ~/.claude/skills/ao-conductor/SKILL.md, Claude Code will auto-load it whenever the user says certain trigger phrases. The skill teaches Claude to act as the CEO in the CEO/PM/Worker model: dispatch work to Agent Orchestrator instead of doing it directly.

## Skill format reference

A Claude Code skill is a single markdown file with YAML frontmatter. Frontmatter fields:

    ---
    name: ao-conductor
    description: <one-line description with trigger keywords baked in; used by skill matcher>
    ---

    <body: instructions that Claude reads when the skill activates>

The description line should list concrete trigger phrases (in Chinese and English) that activate the skill. Examples of good trigger phrases:
- "派活", "并行开发", "同时写", "批量任务"
- "analyze project", "parallel codex", "dispatch to workers"
- "ao batch", "ao start", "ao status", "ao send"
- "让 codex 干", "让工人干", "总经理派活"

## Body content requirements

The body must instruct Claude on the following, in this order:

### 1. Context check (first thing Claude does when skill activates)
Instruct Claude to first verify the environment before dispatching:
- `wsl -l -v` shows Ubuntu-22.04 is running
- `ao --version` inside WSL works
- `codex --version` inside WSL works
- The current project has an agent-orchestrator.yaml (or offer to create one)
- AO has a running orchestrator: `ao status` shows at least one orchestrator
If any check fails, instruct Claude to stop and report the specific missing piece, with a pointer to INSTALL.md or TROUBLESHOOTING.md.

### 2. Decision: should we dispatch?
Claude decides between three modes:
- Mode A — direct: one file, one change, under 15 minutes estimated. Handle with Bash + Edit directly.
- Mode B — single worker: medium task, one Codex process is enough. Use `ao send <orchestrator-session> "..."` to send one big instruction.
- Mode C — parallel dispatch: task splits into 3 or more independent subtasks. Use `ao batch-spawn` with multiple issues.

Claude must state which mode it chose and why before acting.

### 3. Brief writing protocol (for Mode C)
Each worker only receives the issue body as context. Claude must write each brief self-contained, containing:
- Target file path
- Purpose of this subtask
- Outline of sections or functions expected
- Specific facts the worker needs (URLs, versions, commands, config content)
- Do and Don't list
- Format requirements (length, style, language)
- Output constraint: which files to create, which files NOT to modify, commit message format

Briefs are written to `briefs/<slug>.md` in the current repo before issue creation.

### 4. Issue creation protocol
For each brief:
    gh issue create --repo <owner/repo> --title "..." --body-file briefs/<slug>.md
Collect the returned issue numbers.

### 5. Spawn protocol
    cd <project path in WSL>
    HTTPS_PROXY=http://172.17.224.1:7897 ao batch-spawn <id1> <id2> <id3> ...
Tell the user the orchestrator URL and the per-session URLs so they can watch the dashboard.

### 6. Monitoring protocol
Every few minutes, run `ao status`. Look for: session name, branch, PR number, CI status, activity. Report to the user a tight summary — do not dump the raw output.

### 7. Review protocol
Once workers are done (ao status shows them as idle/done and PRs appear):
    gh pr list --repo <owner/repo>
    gh pr diff <pr-number>
For each PR, summarize: files changed, lines added/removed, whether the brief was followed, any obvious problems.
Tell the user which PRs look good to merge and which need iteration.

### 8. Iteration protocol
If a PR has problems, either:
- Open a new review comment on the PR (lifecycle worker will pick it up and re-dispatch to the same worker)
- Or write a new brief and create a new follow-up issue

### 9. Anti-patterns — when NOT to use the skill
List concrete anti-patterns Claude should refuse to dispatch:
- User asks "fix this one typo" — just fix it
- User asks "explain what this function does" — just explain
- User is in an interactive debugging session — AO breaks the flow
- No git repo exists — AO needs a git repo to operate
- No GitHub remote configured — batch-spawn requires gh

### 10. Common pitfalls the skill must remind Claude about
- Workers see only the issue body — put every relevant fact IN the body
- `runtime: tmux` must be set in agent-orchestrator.yaml, not `runtime: process`
- Always export HTTPS_PROXY when calling `ao start` or `ao send` from WSL
- After `gh auth login`, always run `gh auth setup-git`
- After creating the repo, `git push` requires the proxy workaround (see TROUBLESHOOTING.md)

## Writing requirements

1. Frontmatter with name, description, and optional type: feedback (skip type or use "skill" if unsure).
2. Body in Chinese prose. Shell commands and file paths in English.
3. Body length: 200 to 500 lines.
4. Use H2 sections for each of the 10 body requirements above.
5. Include at least two concrete example dialogues: user says X, skill instructs Claude to do Y.
6. Do not include real API keys or tokens.

## Output constraints

- Create only this file: skills/ao-conductor.md
- Do NOT modify any other file.
- Commit message: "feat: add ao-conductor skill source"
- Open a pull request to main.
