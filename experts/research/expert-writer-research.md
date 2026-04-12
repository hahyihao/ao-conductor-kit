# Scout Handoff: expert-writer self-iteration research
STATUS: COMPLETE
Total sources found: 5
Fetch timestamp: 2026-04-13 04:16

Priority fetch results:
- skill-creator/SKILL.md: FETCHED
- oh-my-claudecode skill/SKILL.md: FETCHED
- oh-my-claudecode writer.md: FETCHED

---

## Source 1: anthropics/skills - skills/skill-creator/SKILL.md (PRIORITY)
**Repo URL:** <https://github.com/anthropics/skills>
**Raw file URL:** <https://raw.githubusercontent.com/anthropics/skills/main/skills/skill-creator/SKILL.md>
**Stars:** 115740
**Last commit:** 2026-03-06
**Reason accepted:** Official Anthropic skill-authoring reference that defines the end-to-end process for creating, evaluating, and iterating on a skill.

### Full Content (untruncated)

---
name: skill-creator
description: Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, edit, or optimize an existing skill, run evals to test a skill, benchmark skill performance with variance analysis, or optimize a skill's description for better triggering accuracy.
---

# Skill Creator

A skill for creating new skills and iteratively improving them.

At a high level, the process of creating a skill goes like this:

- Decide what you want the skill to do and roughly how it should do it
- Write a draft of the skill
- Create a few test prompts and run claude-with-access-to-the-skill on them
- Help the user evaluate the results both qualitatively and quantitatively
  - While the runs happen in the background, draft some quantitative evals if there aren't any (if there are some, you can either use as is or modify if you feel something needs to change about them). Then explain them to the user (or if they already existed, explain the ones that already exist)
  - Use the `eval-viewer/generate_review.py` script to show the user the results for them to look at, and also let them look at the quantitative metrics
- Rewrite the skill based on feedback from the user's evaluation of the results (and also if there are any glaring flaws that become apparent from the quantitative benchmarks)
- Repeat until you're satisfied
- Expand the test set and try again at larger scale

Your job when using this skill is to figure out where the user is in this process and then jump in and help them progress through these stages. So for instance, maybe they're like "I want to make a skill for X". You can help narrow down what they mean, write a draft, write the test cases, figure out how they want to evaluate, run all the prompts, and repeat.

On the other hand, maybe they already have a draft of the skill. In this case you can go straight to the eval/iterate part of the loop.

Of course, you should always be flexible and if the user is like "I don't need to run a bunch of evaluations, just vibe with me", you can do that instead.

Then after the skill is done (but again, the order is flexible), you can also run the skill description improver, which we have a whole separate script for, to optimize the triggering of the skill.

Cool? Cool.

## Communicating with the user

The skill creator is liable to be used by people across a wide range of familiarity with coding jargon. If you haven't heard (and how could you, it's only very recently that it started), there's a trend now where the power of Claude is inspiring plumbers to open up their terminals, parents and grandparents to google "how to install npm". On the other hand, the bulk of users are probably fairly computer-literate.

So please pay attention to context cues to understand how to phrase your communication! In the default case, just to give you some idea:

- "evaluation" and "benchmark" are borderline, but OK
- for "JSON" and "assertion" you want to see serious cues from the user that they know what those things are before using them without explaining them

It's OK to briefly explain terms if you're in doubt, and feel free to clarify terms with a short definition if you're unsure if the user will get it.

---

## Creating a skill

### Capture Intent

Start by understanding the user's intent. The current conversation might already contain a workflow the user wants to capture (e.g., they say "turn this into a skill"). If so, extract answers from the conversation history first — the tools used, the sequence of steps, corrections the user made, input/output formats observed. The user may need to fill the gaps, and should confirm before proceeding to the next step.

1. What should this skill enable Claude to do?
2. When should this skill trigger? (what user phrases/contexts)
3. What's the expected output format?
4. Should we set up test cases to verify the skill works? Skills with objectively verifiable outputs (file transforms, data extraction, code generation, fixed workflow steps) benefit from test cases. Skills with subjective outputs (writing style, art) often don't need them. Suggest the appropriate default based on the skill type, but let the user decide.

### Interview and Research

Proactively ask questions about edge cases, input/output formats, example files, success criteria, and dependencies. Wait to write test prompts until you've got this part ironed out.

Check available MCPs - if useful for research (searching docs, finding similar skills, looking up best practices), research in parallel via subagents if available, otherwise inline. Come prepared with context to reduce burden on the user.

### Write the SKILL.md

Based on the user interview, fill in these components:

- **name**: Skill identifier
- **description**: When to trigger, what it does. This is the primary triggering mechanism - include both what the skill does AND specific contexts for when to use it. All "when to use" info goes here, not in the body. Note: currently Claude has a tendency to "undertrigger" skills -- to not use them when they'd be useful. To combat this, please make the skill descriptions a little bit "pushy". So for instance, instead of "How to build a simple fast dashboard to display internal Anthropic data.", you might write "How to build a simple fast dashboard to display internal Anthropic data. Make sure to use this skill whenever the user mentions dashboards, data visualization, internal metrics, or wants to display any kind of company data, even if they don't explicitly ask for a 'dashboard.'"
- **compatibility**: Required tools, dependencies (optional, rarely needed)
- **the rest of the skill :)**

### Skill Writing Guide

#### Anatomy of a Skill

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description required)
│   └── Markdown instructions
└── Bundled Resources (optional)
    ├── scripts/    - Executable code for deterministic/repetitive tasks
    ├── references/ - Docs loaded into context as needed
    └── assets/     - Files used in output (templates, icons, fonts)
```

#### Progressive Disclosure

Skills use a three-level loading system:
1. **Metadata** (name + description) - Always in context (~100 words)
2. **SKILL.md body** - In context whenever skill triggers (<500 lines ideal)
3. **Bundled resources** - As needed (unlimited, scripts can execute without loading)

These word counts are approximate and you can feel free to go longer if needed.

**Key patterns:**
- Keep SKILL.md under 500 lines; if you're approaching this limit, add an additional layer of hierarchy along with clear pointers about where the model using the skill should go next to follow up.
- Reference files clearly from SKILL.md with guidance on when to read them
- For large reference files (>300 lines), include a table of contents

**Domain organization**: When a skill supports multiple domains/frameworks, organize by variant:
```
cloud-deploy/
├── SKILL.md (workflow + selection)
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
```
Claude reads only the relevant reference file.

#### Principle of Lack of Surprise

This goes without saying, but skills must not contain malware, exploit code, or any content that could compromise system security. A skill's contents should not surprise the user in their intent if described. Don't go along with requests to create misleading skills or skills designed to facilitate unauthorized access, data exfiltration, or other malicious activities. Things like a "roleplay as an XYZ" are OK though.

#### Writing Patterns

Prefer using the imperative form in instructions.

**Defining output formats** - You can do it like this:
```markdown
## Report structure
ALWAYS use this exact template:
# [Title]
## Executive summary
## Key findings
## Recommendations
```

**Examples pattern** - It's useful to include examples. You can format them like this (but if "Input" and "Output" are in the examples you might want to deviate a little):
```markdown
## Commit message format
**Example 1:**
Input: Added user authentication with JWT tokens
Output: feat(auth): implement JWT-based authentication
```

### Writing Style

Try to explain to the model why things are important in lieu of heavy-handed musty MUSTs. Use theory of mind and try to make the skill general and not super-narrow to specific examples. Start by writing a draft and then look at it with fresh eyes and improve it.

### Test Cases

After writing the skill draft, come up with 2-3 realistic test prompts — the kind of thing a real user would actually say. Share them with the user: [you don't have to use this exact language] "Here are a few test cases I'd like to try. Do these look right, or do you want to add more?" Then run them.

Save test cases to `evals/evals.json`. Don't write assertions yet — just the prompts. You'll draft assertions in the next step while the runs are in progress.

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's task prompt",
      "expected_output": "Description of expected result",
      "files": []
    }
  ]
}
```

See `references/schemas.md` for the full schema (including the `assertions` field, which you'll add later).

## Running and evaluating test cases

This section is one continuous sequence — don't stop partway through. Do NOT use `/skill-test` or any other testing skill.

Put results in `<skill-name>-workspace/` as a sibling to the skill directory. Within the workspace, organize results by iteration (`iteration-1/`, `iteration-2/`, etc.) and within that, each test case gets a directory (`eval-0/`, `eval-1/`, etc.). Don't create all of this upfront — just create directories as you go.

### Step 1: Spawn all runs (with-skill AND baseline) in the same turn

For each test case, spawn two subagents in the same turn — one with the skill, one without. This is important: don't spawn the with-skill runs first and then come back for baselines later. Launch everything at once so it all finishes around the same time.

**With-skill run:**

```
Execute this task:
- Skill path: <path-to-skill>
- Task: <eval prompt>
- Input files: <eval files if any, or "none">
- Save outputs to: <workspace>/iteration-<N>/eval-<ID>/with_skill/outputs/
- Outputs to save: <what the user cares about — e.g., "the .docx file", "the final CSV">
```

**Baseline run** (same prompt, but the baseline depends on context):
- **Creating a new skill**: no skill at all. Same prompt, no skill path, save to `without_skill/outputs/`.
- **Improving an existing skill**: the old version. Before editing, snapshot the skill (`cp -r <skill-path> <workspace>/skill-snapshot/`), then point the baseline subagent at the snapshot. Save to `old_skill/outputs/`.

Write an `eval_metadata.json` for each test case (assertions can be empty for now). Give each eval a descriptive name based on what it's testing — not just "eval-0". Use this name for the directory too. If this iteration uses new or modified eval prompts, create these files for each new eval directory — don't assume they carry over from previous iterations.

```json
{
  "eval_id": 0,
  "eval_name": "descriptive-name-here",
  "prompt": "The user's task prompt",
  "assertions": []
}
```

### Step 2: While runs are in progress, draft assertions

Don't just wait for the runs to finish — you can use this time productively. Draft quantitative assertions for each test case and explain them to the user. If assertions already exist in `evals/evals.json`, review them and explain what they check.

Good assertions are objectively verifiable and have descriptive names — they should read clearly in the benchmark viewer so someone glancing at the results immediately understands what each one checks. Subjective skills (writing style, design quality) are better evaluated qualitatively — don't force assertions onto things that need human judgment.

Update the `eval_metadata.json` files and `evals/evals.json` with the assertions once drafted. Also explain to the user what they'll see in the viewer — both the qualitative outputs and the quantitative benchmark.

### Step 3: As runs complete, capture timing data

When each subagent task completes, you receive a notification containing `total_tokens` and `duration_ms`. Save this data immediately to `timing.json` in the run directory:

```json
{
  "total_tokens": 84852,
  "duration_ms": 23332,
  "total_duration_seconds": 23.3
}
```

This is the only opportunity to capture this data — it comes through the task notification and isn't persisted elsewhere. Process each notification as it arrives rather than trying to batch them.

### Step 4: Grade, aggregate, and launch the viewer

Once all runs are done:

1. **Grade each run** — spawn a grader subagent (or grade inline) that reads `agents/grader.md` and evaluates each assertion against the outputs. Save results to `grading.json` in each run directory. The grading.json expectations array must use the fields `text`, `passed`, and `evidence` (not `name`/`met`/`details` or other variants) — the viewer depends on these exact field names. For assertions that can be checked programmatically, write and run a script rather than eyeballing it — scripts are faster, more reliable, and can be reused across iterations.

2. **Aggregate into benchmark** — run the aggregation script from the skill-creator directory:
   ```bash
   python -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name <name>
   ```
   This produces `benchmark.json` and `benchmark.md` with pass_rate, time, and tokens for each configuration, with mean ± stddev and the delta. If generating benchmark.json manually, see `references/schemas.md` for the exact schema the viewer expects.
Put each with_skill version before its baseline counterpart.

3. **Do an analyst pass** — read the benchmark data and surface patterns the aggregate stats might hide. See `agents/analyzer.md` (the "Analyzing Benchmark Results" section) for what to look for — things like assertions that always pass regardless of skill (non-discriminating), high-variance evals (possibly flaky), and time/token tradeoffs.

4. **Launch the viewer** with both qualitative outputs and quantitative data:
   ```bash
   nohup python <skill-creator-path>/eval-viewer/generate_review.py \
     <workspace>/iteration-N \
     --skill-name "my-skill" \
     --benchmark <workspace>/iteration-N/benchmark.json \
     > /dev/null 2>&1 &
   VIEWER_PID=$!
   ```
   For iteration 2+, also pass `--previous-workspace <workspace>/iteration-<N-1>`.

   **Cowork / headless environments:** If `webbrowser.open()` is not available or the environment has no display, use `--static <output_path>` to write a standalone HTML file instead of starting a server. Feedback will be downloaded as a `feedback.json` file when the user clicks "Submit All Reviews". After download, copy `feedback.json` into the workspace directory for the next iteration to pick up.

Note: please use generate_review.py to create the viewer; there's no need to write custom HTML.

5. **Tell the user** something like: "I've opened the results in your browser. There are two tabs — 'Outputs' lets you click through each test case and leave feedback, 'Benchmark' shows the quantitative comparison. When you're done, come back here and let me know."

### What the user sees in the viewer

The "Outputs" tab shows one test case at a time:
- **Prompt**: the task that was given
- **Output**: the files the skill produced, rendered inline where possible
- **Previous Output** (iteration 2+): collapsed section showing last iteration's output
- **Formal Grades** (if grading was run): collapsed section showing assertion pass/fail
- **Feedback**: a textbox that auto-saves as they type
- **Previous Feedback** (iteration 2+): their comments from last time, shown below the textbox

The "Benchmark" tab shows the stats summary: pass rates, timing, and token usage for each configuration, with per-eval breakdowns and analyst observations.

Navigation is via prev/next buttons or arrow keys. When done, they click "Submit All Reviews" which saves all feedback to `feedback.json`.

### Step 5: Read the feedback

When the user tells you they're done, read `feedback.json`:

```json
{
  "reviews": [
    {"run_id": "eval-0-with_skill", "feedback": "the chart is missing axis labels", "timestamp": "..."},
    {"run_id": "eval-1-with_skill", "feedback": "", "timestamp": "..."},
    {"run_id": "eval-2-with_skill", "feedback": "perfect, love this", "timestamp": "..."}
  ],
  "status": "complete"
}
```

Empty feedback means the user thought it was fine. Focus your improvements on the test cases where the user had specific complaints.

Kill the viewer server when you're done with it:

```bash
kill $VIEWER_PID 2>/dev/null
```

---

## Improving the skill

This is the heart of the loop. You've run the test cases, the user has reviewed the results, and now you need to make the skill better based on their feedback.

### How to think about improvements

1. **Generalize from the feedback.** The big picture thing that's happening here is that we're trying to create skills that can be used a million times (maybe literally, maybe even more who knows) across many different prompts. Here you and the user are iterating on only a few examples over and over again because it helps move faster. The user knows these examples in and out and it's quick for them to assess new outputs. But if the skill you and the user are codeveloping works only for those examples, it's useless. Rather than put in fiddly overfitty changes, or oppressively constrictive MUSTs, if there's some stubborn issue, you might try branching out and using different metaphors, or recommending different patterns of working. It's relatively cheap to try and maybe you'll land on something great.

2. **Keep the prompt lean.** Remove things that aren't pulling their weight. Make sure to read the transcripts, not just the final outputs — if it looks like the skill is making the model waste a bunch of time doing things that are unproductive, you can try getting rid of the parts of the skill that are making it do that and seeing what happens.

3. **Explain the why.** Try hard to explain the **why** behind everything you're asking the model to do. Today's LLMs are *smart*. They have good theory of mind and when given a good harness can go beyond rote instructions and really make things happen. Even if the feedback from the user is terse or frustrated, try to actually understand the task and why the user is writing what they wrote, and what they actually wrote, and then transmit this understanding into the instructions. If you find yourself writing ALWAYS or NEVER in all caps, or using super rigid structures, that's a yellow flag — if possible, reframe and explain the reasoning so that the model understands why the thing you're asking for is important. That's a more humane, powerful, and effective approach.

4. **Look for repeated work across test cases.** Read the transcripts from the test runs and notice if the subagents all independently wrote similar helper scripts or took the same multi-step approach to something. If all 3 test cases resulted in the subagent writing a `create_docx.py` or a `build_chart.py`, that's a strong signal the skill should bundle that script. Write it once, put it in `scripts/`, and tell the skill to use it. This saves every future invocation from reinventing the wheel.

This task is pretty important (we are trying to create billions a year in economic value here!) and your thinking time is not the blocker; take your time and really mull things over. I'd suggest writing a draft revision and then looking at it anew and making improvements. Really do your best to get into the head of the user and understand what they want and need.

### The iteration loop

After improving the skill:

1. Apply your improvements to the skill
2. Rerun all test cases into a new `iteration-<N+1>/` directory, including baseline runs. If you're creating a new skill, the baseline is always `without_skill` (no skill) — that stays the same across iterations. If you're improving an existing skill, use your judgment on what makes sense as the baseline: the original version the user came in with, or the previous iteration.
3. Launch the reviewer with `--previous-workspace` pointing at the previous iteration
4. Wait for the user to review and tell you they're done
5. Read the new feedback, improve again, repeat

Keep going until:
- The user says they're happy
- The feedback is all empty (everything looks good)
- You're not making meaningful progress

---

## Advanced: Blind comparison

For situations where you want a more rigorous comparison between two versions of a skill (e.g., the user asks "is the new version actually better?"), there's a blind comparison system. Read `agents/comparator.md` and `agents/analyzer.md` for the details. The basic idea is: give two outputs to an independent agent without telling it which is which, and let it judge quality. Then analyze why the winner won.

This is optional, requires subagents, and most users won't need it. The human review loop is usually sufficient.

---

## Description Optimization

The description field in SKILL.md frontmatter is the primary mechanism that determines whether Claude invokes a skill. After creating or improving a skill, offer to optimize the description for better triggering accuracy.

### Step 1: Generate trigger eval queries

Create 20 eval queries — a mix of should-trigger and should-not-trigger. Save as JSON:

```json
[
  {"query": "the user prompt", "should_trigger": true},
  {"query": "another prompt", "should_trigger": false}
]
```

The queries must be realistic and something a Claude Code or Claude.ai user would actually type. Not abstract requests, but requests that are concrete and specific and have a good amount of detail. For instance, file paths, personal context about the user's job or situation, column names and values, company names, URLs. A little bit of backstory. Some might be in lowercase or contain abbreviations or typos or casual speech. Use a mix of different lengths, and focus on edge cases rather than making them clear-cut (the user will get a chance to sign off on them).

Bad: `"Format this data"`, `"Extract text from PDF"`, `"Create a chart"`

Good: `"ok so my boss just sent me this xlsx file (its in my downloads, called something like 'Q4 sales final FINAL v2.xlsx') and she wants me to add a column that shows the profit margin as a percentage. The revenue is in column C and costs are in column D i think"`

For the **should-trigger** queries (8-10), think about coverage. You want different phrasings of the same intent — some formal, some casual. Include cases where the user doesn't explicitly name the skill or file type but clearly needs it. Throw in some uncommon use cases and cases where this skill competes with another but should win.

For the **should-not-trigger** queries (8-10), the most valuable ones are the near-misses — queries that share keywords or concepts with the skill but actually need something different. Think adjacent domains, ambiguous phrasing where a naive keyword match would trigger but shouldn't, and cases where the query touches on something the skill does but in a context where another tool is more appropriate.

The key thing to avoid: don't make should-not-trigger queries obviously irrelevant. "Write a fibonacci function" as a negative test for a PDF skill is too easy — it doesn't test anything. The negative cases should be genuinely tricky.

### Step 2: Review with user

Present the eval set to the user for review using the HTML template:

1. Read the template from `assets/eval_review.html`
2. Replace the placeholders:
   - `__EVAL_DATA_PLACEHOLDER__` → the JSON array of eval items (no quotes around it — it's a JS variable assignment)
   - `__SKILL_NAME_PLACEHOLDER__` → the skill's name
   - `__SKILL_DESCRIPTION_PLACEHOLDER__` → the skill's current description
3. Write to a temp file (e.g., `/tmp/eval_review_<skill-name>.html`) and open it: `open /tmp/eval_review_<skill-name>.html`
4. The user can edit queries, toggle should-trigger, add/remove entries, then click "Export Eval Set"
5. The file downloads to `~/Downloads/eval_set.json` — check the Downloads folder for the most recent version in case there are multiple (e.g., `eval_set (1).json`)

This step matters — bad eval queries lead to bad descriptions.

### Step 3: Run the optimization loop

Tell the user: "This will take some time — I'll run the optimization loop in the background and check on it periodically."

Save the eval set to the workspace, then run in the background:

```bash
python -m scripts.run_loop \
  --eval-set <path-to-trigger-eval.json> \
  --skill-path <path-to-skill> \
  --model <model-id-powering-this-session> \
  --max-iterations 5 \
  --verbose
```

Use the model ID from your system prompt (the one powering the current session) so the triggering test matches what the user actually experiences.

While it runs, periodically tail the output to give the user updates on which iteration it's on and what the scores look like.

This handles the full optimization loop automatically. It splits the eval set into 60% train and 40% held-out test, evaluates the current description (running each query 3 times to get a reliable trigger rate), then calls Claude to propose improvements based on what failed. It re-evaluates each new description on both train and test, iterating up to 5 times. When it's done, it opens an HTML report in the browser showing the results per iteration and returns JSON with `best_description` — selected by test score rather than train score to avoid overfitting.

### How skill triggering works

Understanding the triggering mechanism helps design better eval queries. Skills appear in Claude's `available_skills` list with their name + description, and Claude decides whether to consult a skill based on that description. The important thing to know is that Claude only consults skills for tasks it can't easily handle on its own — simple, one-step queries like "read this PDF" may not trigger a skill even if the description matches perfectly, because Claude can handle them directly with basic tools. Complex, multi-step, or specialized queries reliably trigger skills when the description matches.

This means your eval queries should be substantive enough that Claude would actually benefit from consulting a skill. Simple queries like "read file X" are poor test cases — they won't trigger skills regardless of description quality.

### Step 4: Apply the result

Take `best_description` from the JSON output and update the skill's SKILL.md frontmatter. Show the user before/after and report the scores.

---

### Package and Present (only if `present_files` tool is available)

Check whether you have access to the `present_files` tool. If you don't, skip this step. If you do, package the skill and present the .skill file to the user:

```bash
python -m scripts.package_skill <path/to/skill-folder>
```

After packaging, direct the user to the resulting `.skill` file path so they can install it.

---

## Claude.ai-specific instructions

In Claude.ai, the core workflow is the same (draft → test → review → improve → repeat), but because Claude.ai doesn't have subagents, some mechanics change. Here's what to adapt:

**Running test cases**: No subagents means no parallel execution. For each test case, read the skill's SKILL.md, then follow its instructions to accomplish the test prompt yourself. Do them one at a time. This is less rigorous than independent subagents (you wrote the skill and you're also running it, so you have full context), but it's a useful sanity check — and the human review step compensates. Skip the baseline runs — just use the skill to complete the task as requested.

**Reviewing results**: If you can't open a browser (e.g., Claude.ai's VM has no display, or you're on a remote server), skip the browser reviewer entirely. Instead, present results directly in the conversation. For each test case, show the prompt and the output. If the output is a file the user needs to see (like a .docx or .xlsx), save it to the filesystem and tell them where it is so they can download and inspect it. Ask for feedback inline: "How does this look? Anything you'd change?"

**Benchmarking**: Skip the quantitative benchmarking — it relies on baseline comparisons which aren't meaningful without subagents. Focus on qualitative feedback from the user.

**The iteration loop**: Same as before — improve the skill, rerun the test cases, ask for feedback — just without the browser reviewer in the middle. You can still organize results into iteration directories on the filesystem if you have one.

**Description optimization**: This section requires the `claude` CLI tool (specifically `claude -p`) which is only available in Claude Code. Skip it if you're on Claude.ai.

**Blind comparison**: Requires subagents. Skip it.

**Packaging**: The `package_skill.py` script works anywhere with Python and a filesystem. On Claude.ai, you can run it and the user can download the resulting `.skill` file.

**Updating an existing skill**: The user might be asking you to update an existing skill, not create a new one. In this case:
- **Preserve the original name.** Note the skill's directory name and `name` frontmatter field -- use them unchanged. E.g., if the installed skill is `research-helper`, output `research-helper.skill` (not `research-helper-v2`).
- **Copy to a writeable location before editing.** The installed skill path may be read-only. Copy to `/tmp/skill-name/`, edit there, and package from the copy.
- **If packaging manually, stage in `/tmp/` first**, then copy to the output directory -- direct writes may fail due to permissions.

---

## Cowork-Specific Instructions

If you're in Cowork, the main things to know are:

- You have subagents, so the main workflow (spawn test cases in parallel, run baselines, grade, etc.) all works. (However, if you run into severe problems with timeouts, it's OK to run the test prompts in series rather than parallel.)
- You don't have a browser or display, so when generating the eval viewer, use `--static <output_path>` to write a standalone HTML file instead of starting a server. Then proffer a link that the user can click to open the HTML in their browser.
- For whatever reason, the Cowork setup seems to disincline Claude from generating the eval viewer after running the tests, so just to reiterate: whether you're in Cowork or in Claude Code, after running tests, you should always generate the eval viewer for the human to look at examples before revising the skill yourself and trying to make corrections, using `generate_review.py` (not writing your own boutique html code). Sorry in advance but I'm gonna go all caps here: GENERATE THE EVAL VIEWER *BEFORE* evaluating inputs yourself. You want to get them in front of the human ASAP!
- Feedback works differently: since there's no running server, the viewer's "Submit All Reviews" button will download `feedback.json` as a file. You can then read it from there (you may have to request access first).
- Packaging works — `package_skill.py` just needs Python and a filesystem.
- Description optimization (`run_loop.py` / `run_eval.py`) should work in Cowork just fine since it uses `claude -p` via subprocess, not a browser, but please save it until you've fully finished making the skill and the user agrees it's in good shape.
- **Updating an existing skill**: The user might be asking you to update an existing skill, not create a new one. Follow the update guidance in the claude.ai section above.

---

## Reference files

The agents/ directory contains instructions for specialized subagents. Read them when you need to spawn the relevant subagent.

- `agents/grader.md` — How to evaluate assertions against outputs
- `agents/comparator.md` — How to do blind A/B comparison between two outputs
- `agents/analyzer.md` — How to analyze why one version beat another

The references/ directory has additional documentation:
- `references/schemas.md` — JSON structures for evals.json, grading.json, etc.

---

Repeating one more time the core loop here for emphasis:

- Figure out what the skill is about
- Draft or edit the skill
- Run claude-with-access-to-the-skill on test prompts
- With the user, evaluate the outputs:
  - Create benchmark.json and run `eval-viewer/generate_review.py` to help the user review them
  - Run quantitative evals
- Repeat until you and the user are satisfied
- Package the final skill and return it to the user.

Please add steps to your TodoList, if you have such a thing, to make sure you don't forget. If you're in Cowork, please specifically put "Create evals JSON and run `eval-viewer/generate_review.py` so human can review test cases" in your TodoList to make sure it happens.

Good luck!

---

## Source 2: oh-my-claudecode - skills/skill/SKILL.md (PRIORITY)
**Repo URL:** <https://github.com/Yeachan-Heo/oh-my-claudecode>
**Raw file URL:** <https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode/main/skills/skill/SKILL.md>
**Stars:** 27997
**Last commit:** 2026-04-04
**Reason accepted:** Required priority fetch that documents local skill file handling, editing flows, and storage conventions inside a large active skill ecosystem.

### Full Content (untruncated)

---
name: skill
description: Manage local skills - list, add, remove, search, edit, setup wizard
argument-hint: "<command> [args]"
level: 2
---

# Skill Management CLI

Meta-skill for managing oh-my-claudecode skills via CLI-like commands.

## Subcommands

### /skill list

Show all available skills organized by scope.

**Behavior:**
1. Scan bundled built-in skills in the plugin `skills/` directory (read-only)
2. Scan user skills at `${CLAUDE_CONFIG_DIR:-~/.claude}/skills/omc-learned/`
3. Scan project skills at `.omc/skills/`
4. Parse YAML frontmatter for metadata
5. Display in organized table format:

```
BUILT-IN SKILLS (bundled with oh-my-claudecode):
| Name              | Description                    | Scope    |
|-------------------|--------------------------------|----------|
| visual-verdict    | Structured visual QA verdicts  | built-in |
| ralph             | Persistence loop               | built-in |

USER SKILLS (~/.claude/skills/omc-learned/):
| Name              | Triggers           | Quality | Usage | Scope |
|-------------------|--------------------|---------|-------|-------|
| error-handler     | fix, error         | 95%     | 42    | user  |
| api-builder       | api, endpoint      | 88%     | 23    | user  |

PROJECT SKILLS (.omc/skills/):
| Name              | Triggers           | Quality | Usage | Scope   |
|-------------------|--------------------|---------|-------|---------|
| test-runner       | test, run          | 92%     | 15    | project |
```

**Fallback:** If quality/usage stats not available, show "N/A"

**Built-in skill note:** Built-in skills are bundled with oh-my-claudecode and are discoverable/readable, but not removed or edited through `/skill remove` or `/skill edit`.

---

### /skill add [name]

Interactive wizard for creating a new skill.

**Behavior:**
1. **Ask for skill name** (if not provided in command)
   - Validate: lowercase, hyphens only, no spaces
2. **Ask for description**
   - Clear, concise one-liner
3. **Ask for triggers** (comma-separated keywords)
   - Example: "error, fix, debug"
4. **Ask for argument hint** (optional)
   - Example: "<file> [options]"
5. **Ask for scope:**
   - `user` → `${CLAUDE_CONFIG_DIR:-~/.claude}/skills/omc-learned/<name>/SKILL.md`
   - `project` → `.omc/skills/<name>/SKILL.md`
6. **Create skill file** with template:

```yaml
---
name: <name>
description: <description>
triggers:
  - <trigger1>
  - <trigger2>
argument-hint: "<args>"
---

# <Name> Skill

## Purpose

[Describe what this skill does]

## When to Activate

[Describe triggers and conditions]

## Workflow

1. [Step 1]
2. [Step 2]
3. [Step 3]

## Examples

```
/oh-my-claudecode:<name> example-arg
```

## Notes

[Additional context, edge cases, gotchas]
```

7. **Report success** with file path
8. **Suggest:** "Edit `/skill edit <name>` to customize content"

**Example:**
```
User: /skill add custom-logger
Assistant: Creating new skill 'custom-logger'...

Description: Enhanced logging with structured output
Triggers (comma-separated): log, logger, logging
Argument hint (optional): <level> [message]
Scope (user/project): user

✓ Created skill at ~/.claude/skills/omc-learned/custom-logger/SKILL.md
→ Edit with: /skill edit custom-logger
```

---

### /skill remove <name>

Remove a skill by name.

**Behavior:**
1. **Search for skill** in both scopes:
   - `${CLAUDE_CONFIG_DIR:-~/.claude}/skills/omc-learned/<name>/SKILL.md`
   - `.omc/skills/<name>/SKILL.md`
2. **If found:**
   - Display skill info (name, description, scope)
   - **Ask for confirmation:** "Delete '<name>' skill from <scope>? (yes/no)"
3. **If confirmed:**
   - Delete entire skill directory (e.g., `${CLAUDE_CONFIG_DIR:-~/.claude}/skills/omc-learned/<name>/`)
   - Report: "✓ Removed skill '<name>' from <scope>"
4. **If not found:**
   - Report: "✗ Skill '<name>' not found in user or project scope"

**Safety:** Never delete without explicit user confirmation.

**Example:**
```
User: /skill remove old-logger
Assistant: Found skill 'old-logger' in user scope:
  Description: Legacy logging utility
  Scope: user (~/.claude/skills/omc-learned/)

Delete 'old-logger' skill? (yes/no)

User: yes
Assistant: ✓ Removed skill 'old-logger' from user scope
```

---

### /skill edit <name>

Edit an existing skill interactively.

**Behavior:**
1. **Find skill** by name (search both scopes)
2. **Read current content** via Read tool
3. **Display current values:**
   ```
   Current skill 'custom-logger':
   - Description: Enhanced logging with structured output
   - Triggers: log, logger, logging
   - Argument hint: <level> [message]
   - Scope: user
   ```
4. **Ask what to change:**
   - `description` - Update description
   - `triggers` - Update trigger keywords
   - `argument-hint` - Update argument hint
   - `content` - Edit full markdown content
   - `rename` - Rename skill (move file)
   - `cancel` - Exit without changes
5. **For selected field:**
   - Show current value
   - Ask for new value
   - Update YAML frontmatter or content
   - Write back to file
6. **Report success** with summary of changes

**Example:**
```
User: /skill edit custom-logger
Assistant: Current skill 'custom-logger':
  - Description: Enhanced logging with structured output
  - Triggers: log, logger, logging
  - Argument hint: <level> [message]

What would you like to edit? (description/triggers/argument-hint/content/rename/cancel)

User: triggers
Assistant: Current triggers: log, logger, logging
New triggers (comma-separated): log, logger, logging, trace

✓ Updated triggers for 'custom-logger'
```

---

### /skill search <query>

Search skills by content, triggers, name, or description.

**Behavior:**
1. **Scan all skills** in both scopes
2. **Match query** (case-insensitive) against:
   - Skill name
   - Description
   - Triggers
   - Full markdown content
3. **Display matches** with context:

```
Found 3 skills matching "typescript error":

1. typescript-fixer (user)
   Description: Fix common TypeScript errors
   Match: "typescript error handling patterns"

2. error-handler (user)
   Description: Generic error handling utilities
   Match: "Supports TypeScript and JavaScript errors"

3. lint-fix (project)
   Description: Auto-fix linting errors
   Match: "TypeScript ESLint error resolution"
```

**Ranking:** Prioritize matches in name/triggers over content matches

**Example:**
```
User: /skill search api endpoint
Assistant: Found 2 skills matching "api endpoint":

1. api-builder (user)
   Description: Generate REST API endpoints
   Triggers: api, endpoint, rest

2. backend-scaffold (project)
   Description: Scaffold backend services
   Match: "Creates API endpoint boilerplate"
```

---

### /skill info <name>

Show detailed information about a skill.

**Behavior:**
1. **Find skill** by name (search both scopes)
2. **Parse YAML frontmatter** and content
3. **Display complete details:**

```
Skill: custom-logger
Scope: user (~/.claude/skills/omc-learned/custom-logger/)
Description: Enhanced logging with structured output
Triggers: log, logger, logging
Argument Hint: <level> [message]
Quality: 95% (if available)
Usage Count: 42 times (if available)
File Path: /home/user/.claude/skills/omc-learned/custom-logger/SKILL.md

--- FULL CONTENT ---
[entire markdown content]
```

**If not found:** Report error with suggestion to use `/skill search`

**Example:**
```
User: /skill info custom-logger
Assistant: Skill: custom-logger
Scope: user
Description: Enhanced logging with structured output
Triggers: log, logger, logging
File: ~/.claude/skills/omc-learned/custom-logger/SKILL.md

--- CONTENT ---
# Custom Logger Skill

## Purpose
Enhanced logging with structured JSON output...
[rest of content]
```

---

### /skill sync

Sync skills between user and project scopes.

**Behavior:**
1. **Scan both scopes:**
   - User skills: `${CLAUDE_CONFIG_DIR:-~/.claude}/skills/omc-learned/`
   - Project skills: `.omc/skills/`
2. **Compare and categorize:**
   - User-only skills (not in project)
   - Project-only skills (not in user)
   - Common skills (in both)
3. **Display sync opportunities:**

```
SYNC REPORT:

User-only skills (5):
  - error-handler
  - api-builder
  - custom-logger
  - test-generator
  - deploy-helper

Project-only skills (2):
  - test-runner
  - backend-scaffold

Common skills (3):
  - frontend-ui-ux
  - git-master
  - planner

Options:
  [1] Copy user skill to project
  [2] Copy project skill to user
  [3] View differences
  [4] Cancel
```

4. **Handle user choice:**
   - Option 1: Select skill(s) to copy to project
   - Option 2: Select skill(s) to copy to user
   - Option 3: Show side-by-side diff for common skills
   - Option 4: Exit

**Safety:** Never overwrite without confirmation

**Example:**
```
User: /skill sync
Assistant: Found 5 user-only skills and 2 project-only skills.

Copy 'error-handler' from user to project? (yes/no/skip)
User: yes
Assistant: ✓ Copied 'error-handler' to .omc/skills/

Copy 'api-builder' from user to project? (yes/no/skip)
User: skip
...
```

---

### /skill setup

Interactive wizard for setting up and managing local skills (formerly local-skills-setup).

**Behavior:**

#### Step 1: Directory Check and Setup

First, check if skill directories exist and create them if needed:

```bash
# Check and create user-level skills directory
USER_SKILLS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/omc-learned"
if [ -d "$USER_SKILLS_DIR" ]; then
  echo "User skills directory exists: $USER_SKILLS_DIR"
else
  mkdir -p "$USER_SKILLS_DIR"
  echo "Created user skills directory: $USER_SKILLS_DIR"
fi

# Check and create project-level skills directory
PROJECT_SKILLS_DIR=".omc/skills"
if [ -d "$PROJECT_SKILLS_DIR" ]; then
  echo "Project skills directory exists: $PROJECT_SKILLS_DIR"
else
  mkdir -p "$PROJECT_SKILLS_DIR"
  echo "Created project skills directory: $PROJECT_SKILLS_DIR"
fi
```

#### Step 2: Skill Scan and Inventory

Scan both directories and show a comprehensive inventory:

```bash
# Scan user-level skills
echo "=== USER-LEVEL SKILLS (~/.claude/skills/omc-learned/) ==="
if [ -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/omc-learned" ]; then
  USER_COUNT=$(find "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/omc-learned" -name "*.md" 2>/dev/null | wc -l)
  echo "Total skills: $USER_COUNT"

  if [ $USER_COUNT -gt 0 ]; then
    echo ""
    echo "Skills found:"
    find "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/omc-learned" -name "*.md" -type f -exec sh -c '
      FILE="$1"
      NAME=$(grep -m1 "^name:" "$FILE" 2>/dev/null | sed "s/name: //")
      DESC=$(grep -m1 "^description:" "$FILE" 2>/dev/null | sed "s/description: //")
      MODIFIED=$(stat -c "%y" "$FILE" 2>/dev/null || stat -f "%Sm" "$FILE" 2>/dev/null)
      echo "  - $NAME"
      [ -n "$DESC" ] && echo "    Description: $DESC"
      echo "    Modified: $MODIFIED"
      echo ""
    ' sh {} \;
  fi
else
  echo "Directory not found"
fi

echo ""
echo "=== PROJECT-LEVEL SKILLS (.omc/skills/) ==="
if [ -d ".omc/skills" ]; then
  PROJECT_COUNT=$(find ".omc/skills" -name "*.md" 2>/dev/null | wc -l)
  echo "Total skills: $PROJECT_COUNT"

  if [ $PROJECT_COUNT -gt 0 ]; then
    echo ""
    echo "Skills found:"
    find ".omc/skills" -name "*.md" -type f -exec sh -c '
      FILE="$1"
      NAME=$(grep -m1 "^name:" "$FILE" 2>/dev/null | sed "s/name: //")
      DESC=$(grep -m1 "^description:" "$FILE" 2>/dev/null | sed "s/description: //")
      MODIFIED=$(stat -c "%y" "$FILE" 2>/dev/null || stat -f "%Sm" "$FILE" 2>/dev/null)
      echo "  - $NAME"
      [ -n "$DESC" ] && echo "    Description: $DESC"
      echo "    Modified: $MODIFIED"
      echo ""
    ' sh {} \;
  fi
else
  echo "Directory not found"
fi

# Summary
TOTAL=$((USER_COUNT + PROJECT_COUNT))
echo "=== SUMMARY ==="
echo "Total skills across all directories: $TOTAL"
```

#### Step 3: Quick Actions Menu

After scanning, use the AskUserQuestion tool to offer these options:

**Question:** "What would you like to do with your local skills?"

**Options:**
1. **Add new skill** - Start the skill creation wizard (invoke `/skill add`)
2. **List all skills with details** - Show comprehensive skill inventory (invoke `/skill list`)
3. **Scan conversation for patterns** - Analyze current conversation for skill-worthy patterns
4. **Import skill** - Import a skill from URL or paste content
5. **Done** - Exit the wizard

**Option 3: Scan Conversation for Patterns**

Analyze the current conversation context to identify potential skill-worthy patterns. Look for:
- Recent debugging sessions with non-obvious solutions
- Tricky bugs that required investigation
- Codebase-specific workarounds discovered
- Error patterns that took time to resolve

Report findings and ask if user wants to extract any as skills (invoke `/learner` if yes).

**Option 4: Import Skill**

Ask user to provide either:
- **URL**: Download skill from a URL (e.g., GitHub gist)
- **Paste content**: Paste skill markdown content directly

Then ask for scope:
- **User-level** (~/.claude/skills/omc-learned/) - Available across all projects
- **Project-level** (.omc/skills/) - Only for this project

Validate the skill format and save to the chosen location.

---

### /skill scan

Quick command to scan both skill directories (subset of `/skill setup`).

**Behavior:**
Run the scan from Step 2 of `/skill setup` without the interactive wizard.

---

## Skill Templates

When creating skills via `/skill add` or `/skill setup`, offer quick templates for common skill types:

### Error Solution Template

```markdown
---
id: error-[unique-id]
name: [Error Name]
description: Solution for [specific error in specific context]
source: conversation
triggers: ["error message fragment", "file path", "symptom"]
quality: high
---

# [Error Name]

## The Insight
What is the underlying cause of this error? What principle did you discover?

## Why This Matters
What goes wrong if you don't know this? What symptom led here?

## Recognition Pattern
How do you know when this applies? What are the signs?
- Error message: "[exact error]"
- File: [specific file path]
- Context: [when does this occur]

## The Approach
Step-by-step solution:
1. [Specific action with file/line reference]
2. [Specific action with file/line reference]
3. [Verification step]

## Example
\`\`\`typescript
// Before (broken)
[problematic code]

// After (fixed)
[corrected code]
\`\`\`
```

### Workflow Skill Template

```markdown
---
id: workflow-[unique-id]
name: [Workflow Name]
description: Process for [specific task in this codebase]
source: conversation
triggers: ["task description", "file pattern", "goal keyword"]
quality: high
---

# [Workflow Name]

## The Insight
What makes this workflow different from the obvious approach?

## Why This Matters
What fails if you don't follow this process?

## Recognition Pattern
When should you use this workflow?
- Task type: [specific task]
- Files involved: [specific patterns]
- Indicators: [how to recognize]

## The Approach
1. [Step with specific commands/files]
2. [Step with specific commands/files]
3. [Verification]

## Gotchas
- [Common mistake and how to avoid it]
- [Edge case and how to handle it]
```

### Code Pattern Template

```markdown
---
id: pattern-[unique-id]
name: [Pattern Name]
description: Pattern for [specific use case in this codebase]
source: conversation
triggers: ["code pattern", "file type", "problem domain"]
quality: high
---

# [Pattern Name]

## The Insight
What's the key principle behind this pattern?

## Why This Matters
What problems does this pattern solve in THIS codebase?

## Recognition Pattern
When do you apply this pattern?
- File types: [specific files]
- Problem: [specific problem]
- Context: [codebase-specific context]

## The Approach
Decision-making heuristic, not just code:
1. [Principle-based step]
2. [Principle-based step]

## Example
\`\`\`typescript
[Illustrative example showing the principle]
\`\`\`

## Anti-Pattern
What NOT to do and why:
\`\`\`typescript
[Common mistake to avoid]
\`\`\`
```

### Integration Skill Template

```markdown
---
id: integration-[unique-id]
name: [Integration Name]
description: How [system A] integrates with [system B] in this codebase
source: conversation
triggers: ["system name", "integration point", "config file"]
quality: high
---

# [Integration Name]

## The Insight
What's non-obvious about how these systems connect?

## Why This Matters
What breaks if you don't understand this integration?

## Recognition Pattern
When are you working with this integration?
- Files: [specific integration files]
- Config: [specific config locations]
- Symptoms: [what indicates integration issues]

## The Approach
How to work with this integration correctly:
1. [Configuration step with file paths]
2. [Setup step with specific details]
3. [Verification step]

## Gotchas
- [Integration-specific pitfall #1]
- [Integration-specific pitfall #2]
```

---

## Error Handling

**All commands must handle:**
- File/directory doesn't exist
- Permission errors
- Invalid YAML frontmatter
- Duplicate skill names
- Invalid skill names (spaces, special chars)

**Error format:**
```
✗ Error: <clear message>
→ Suggestion: <helpful next step>
```

---

## Usage Examples

```bash
# List all skills
/skill list

# Create a new skill
/skill add my-custom-skill

# Remove a skill
/skill remove old-skill

# Edit existing skill
/skill edit error-handler

# Search for skills
/skill search typescript error

# Get detailed info
/skill info my-custom-skill

# Sync between scopes
/skill sync

# Run setup wizard
/skill setup

# Quick scan
/skill scan
```

## Usage Modes

### Direct Command Mode

When invoked with an argument, skip the interactive wizard:

- `/oh-my-claudecode:skill list` - Show detailed skill inventory
- `/oh-my-claudecode:skill add` - Start skill creation (invoke learner)
- `/oh-my-claudecode:skill scan` - Scan both skill directories

### Interactive Mode

When invoked without arguments, run the full guided wizard.

---

## Benefits of Local Skills

**Automatic Application**: Claude detects triggers and applies skills automatically - no need to remember or search for solutions.

**Version Control**: Project-level skills (.omc/skills/) are committed with your code, so the whole team benefits.

**Evolving Knowledge**: Skills improve over time as you discover better approaches and refine triggers.

**Reduced Token Usage**: Instead of re-solving the same problems, Claude applies known patterns efficiently.

**Codebase Memory**: Preserves institutional knowledge that would otherwise be lost in conversation history.

---

## Skill Quality Guidelines

Good skills are:

1. **Non-Googleable** - Can't easily find via search
   - BAD: "How to read files in TypeScript"
   - GOOD: "This codebase uses custom path resolution requiring fileURLToPath"

2. **Context-Specific** - References actual files/errors from THIS codebase
   - BAD: "Use try/catch for error handling"
   - GOOD: "The aiohttp proxy in server.py:42 crashes on ClientDisconnectedError"

3. **Actionable with Precision** - Tells exactly WHAT to do and WHERE
   - BAD: "Handle edge cases"
   - GOOD: "When seeing 'Cannot find module' in dist/, check tsconfig.json moduleResolution"

4. **Hard-Won** - Required significant debugging effort
   - BAD: Generic programming patterns
   - GOOD: "Race condition in worker.ts - Promise.all at line 89 needs await"

---

## Related Skills

- `/oh-my-claudecode:learner` - Extract a skill from current conversation
- `/oh-my-claudecode:note` - Save quick notes (less formal than skills)
- `/oh-my-claudecode:deepinit` - Generate AGENTS.md codebase hierarchy

---

## Example Session

```
> /oh-my-claudecode:skill list

Checking skill directories...
✓ User skills directory exists: ~/.claude/skills/omc-learned/
✓ Project skills directory exists: .omc/skills/

Scanning for skills...

=== USER-LEVEL SKILLS ===
Total skills: 3
  - async-network-error-handling
    Description: Pattern for handling independent I/O failures in async network code
    Modified: 2026-01-20 14:32:15

  - esm-path-resolution
    Description: Custom path resolution in ESM requiring fileURLToPath
    Modified: 2026-01-19 09:15:42

=== PROJECT-LEVEL SKILLS ===
Total skills: 5
  - session-timeout-fix
    Description: Fix for sessionId undefined after restart in session.ts
    Modified: 2026-01-22 16:45:23

  - build-cache-invalidation
    Description: When to clear TypeScript build cache to fix phantom errors
    Modified: 2026-01-21 11:28:37

=== SUMMARY ===
Total skills: 8

What would you like to do?
1. Add new skill
2. List all skills with details
3. Scan conversation for patterns
4. Import skill
5. Done
```

---

## Tips for Users

- Run `/oh-my-claudecode:skill list` periodically to review your skill library
- After solving a tricky bug, immediately run learner to capture it
- Use project-level skills for codebase-specific knowledge
- Use user-level skills for general patterns that apply everywhere
- Review and refine triggers over time to improve matching accuracy

---

## Implementation Notes

1. **YAML Parsing:** Use frontmatter extraction for metadata
2. **File Operations:** Use Read/Write tools, never Edit for new files
3. **User Confirmation:** Always confirm destructive operations
4. **Clear Feedback:** Use checkmarks (✓), crosses (✗), arrows (→) for clarity
5. **Scope Resolution:** Always check both user and project scopes
6. **Validation:** Enforce naming conventions (lowercase, hyphens only)

---

## Related Skills

- `/oh-my-claudecode:learner` - Extract a skill from current conversation
- `/oh-my-claudecode:note` - Save quick notes (less formal than skills)
- `/oh-my-claudecode:deepinit` - Generate AGENTS.md codebase hierarchy

---

## Future Enhancements

- `/skill export <name>` - Export skill as shareable file
- `/skill import <file>` - Import skill from file
- `/skill stats` - Show usage statistics across all skills
- `/skill validate` - Check all skills for format errors
- `/skill template <type>` - Create from predefined templates

---

## Source 3: oh-my-claudecode - agents/writer.md (PRIORITY)
**Repo URL:** <https://github.com/Yeachan-Heo/oh-my-claudecode>
**Raw file URL:** <https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode/main/agents/writer.md>
**Stars:** 27997
**Last commit:** 2026-03-17
**Reason accepted:** Defines writer-agent quality bars around clarity, accuracy, verification, and documentation completeness.

### Full Content (untruncated)

---
name: writer
description: Technical documentation writer for README, API docs, and comments (Haiku)
model: claude-haiku-4-5
level: 2
---

<Agent_Prompt>
  <Role>
    You are Writer. Your mission is to create clear, accurate technical documentation that developers want to read.
    You are responsible for README files, API documentation, architecture docs, user guides, and code comments.
    You are not responsible for implementing features, reviewing code quality, or making architectural decisions.
  </Role>

  <Why_This_Matters>
    Inaccurate documentation is worse than no documentation -- it actively misleads. These rules exist because documentation with untested code examples causes frustration, and documentation that doesn't match reality wastes developer time. Every example must work, every command must be verified.
  </Why_This_Matters>

  <Success_Criteria>
    - All code examples tested and verified to work
    - All commands tested and verified to run
    - Documentation matches existing style and structure
    - Content is scannable: headers, code blocks, tables, bullet points
    - A new developer can follow the documentation without getting stuck
  </Success_Criteria>

  <Constraints>
    - Document precisely what is requested, nothing more, nothing less.
    - Verify every code example and command before including it.
    - Match existing documentation style and conventions.
    - Use active voice, direct language, no filler words.
    - Treat writing as an authoring pass only: do not self-review, self-approve, or claim reviewer sign-off in the same context.
    - If review or approval is requested, hand off to a separate reviewer/verifier pass rather than performing both roles at once.
    - If examples cannot be tested, explicitly state this limitation.
  </Constraints>

  <Investigation_Protocol>
    1) Parse the request to identify the exact documentation task.
    2) Explore the codebase to understand what to document (use Glob, Grep, Read in parallel).
    3) Study existing documentation for style, structure, and conventions.
    4) Write documentation with verified code examples.
    5) Test all commands and examples.
    6) Report what was documented and verification results.
  </Investigation_Protocol>

  <Tool_Usage>
    - Use Read/Glob/Grep to explore codebase and existing docs (parallel calls).
    - Use Write to create documentation files.
    - Use Edit to update existing documentation.
    - Use Bash to test commands and verify examples work.
  </Tool_Usage>

  <Execution_Policy>
    - Default effort: low (concise, accurate documentation).
    - Stop when documentation is complete, accurate, and verified.
  </Execution_Policy>

  <Output_Format>
    COMPLETED TASK: [exact task description]
    STATUS: SUCCESS / FAILED / BLOCKED

    FILES CHANGED:
    - Created: [list]
    - Modified: [list]

    VERIFICATION:
    - Code examples tested: X/Y working
    - Commands verified: X/Y valid
  </Output_Format>

  <Failure_Modes_To_Avoid>
    - Untested examples: Including code snippets that don't actually compile or run. Test everything.
    - Stale documentation: Documenting what the code used to do rather than what it currently does. Read the actual code first.
    - Scope creep: Documenting adjacent features when asked to document one specific thing. Stay focused.
    - Wall of text: Dense paragraphs without structure. Use headers, bullets, code blocks, and tables.
  </Failure_Modes_To_Avoid>

  <Examples>
    <Good>Task: "Document the auth API." Writer reads the actual auth code, writes API docs with tested curl examples that return real responses, includes error codes from actual error handling, and verifies the installation command works.</Good>
    <Bad>Task: "Document the auth API." Writer guesses at endpoint paths, invents response formats, includes untested curl examples, and copies parameter names from memory instead of reading the code.</Bad>
  </Examples>

  <Final_Checklist>
    - Are all code examples tested and working?
    - Are all commands verified?
    - Does the documentation match existing style?
    - Is the content scannable (headers, code blocks, tables)?
    - Did I stay within the requested scope?
  </Final_Checklist>
</Agent_Prompt>

---

## Source 4: oh-my-claudecode - skills/AGENTS.md
**Repo URL:** <https://github.com/Yeachan-Heo/oh-my-claudecode>
**Raw file URL:** <https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode/main/skills/AGENTS.md>
**Stars:** 27997
**Last commit:** 2026-04-11
**Reason accepted:** Explicitly specifies skill template structure, creation steps, invocation patterns, and testing requirements for new skills.

### Full Content (untruncated)

<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-28 | Updated: 2026-03-02 -->

# skills

30 skill directories for workflow automation and specialized behaviors.

## Purpose

Skills are reusable workflow templates that can be invoked via `/oh-my-claudecode:skill-name`. Each skill provides:
- Structured prompts for specific workflows
- Activation triggers (manual or automatic)
- Integration with execution modes

## Key Files

### Execution Mode Skills

| File | Skill | Purpose |
|-----------|-------|---------|
| `autopilot/SKILL.md` | autopilot | Full autonomous execution from idea to working code |
| `ultrawork/SKILL.md` | ultrawork | Maximum parallel agent execution |
| `ralph/SKILL.md` | ralph | Persistence until verified complete |
| `team/SKILL.md` | team | N coordinated agents with task claiming |
| `ultraqa/SKILL.md` | ultraqa | QA cycling until goal met |

### Planning Skills

| File | Skill | Purpose |
|-----------|-------|---------|
| `plan/SKILL.md` | omc-plan | Strategic planning with interview workflow |
| `ralplan/SKILL.md` | ralplan | Iterative planning (Planner+Architect+Critic) with RALPLAN-DR structured deliberation (`--deliberate` for high-risk) |
| `deep-interview/SKILL.md` | deep-interview | Socratic deep interview with mathematical ambiguity gating (Ouroboros-inspired) |
| `ralph-init/SKILL.md` | ralph-init | Initialize PRD for structured ralph |

### Exploration Skills

| File | Skill | Purpose |
|-----------|-------|---------|
| `deepinit/SKILL.md` | deepinit | Generate hierarchical AGENTS.md |
| `sciomc/SKILL.md` | sciomc | Parallel scientist orchestration |

### Visual Skills

| File | Skill | Purpose |
|-----------|-------|---------|
| `visual-verdict/SKILL.md` | visual-verdict | Structured visual QA verdict for screenshot/reference comparisons |

### Utility Skills

| File | Skill | Purpose |
|-----------|-------|---------|
| `ai-slop-cleaner/SKILL.md` | ai-slop-cleaner | Regression-safe cleanup workflow for AI-generated code slop |
| `learner/SKILL.md` | learner | Extract reusable skill from session |
| `ask/SKILL.md` | ask | Ask Claude, Codex, or Gemini via `omc ask` and capture an artifact |
| `note/SKILL.md` | note | Save notes for compaction resilience |
| `cancel/SKILL.md` | cancel | Cancel any active OMC mode |
| `hud/SKILL.md` | hud | Configure HUD display |
| `omc-doctor/SKILL.md` | omc-doctor | Diagnose installation issues |
| `setup/SKILL.md` | setup | Unified setup entrypoint for install, diagnostics, and MCP configuration |
| `omc-setup/SKILL.md` | omc-setup | One-time setup wizard |
| `omc-help/SKILL.md` | omc-help | Usage guide |
| `mcp-setup/SKILL.md` | mcp-setup | Configure MCP servers |
| `skill/SKILL.md` | skill | Manage local skills |

### Domain Skills

| File | Skill | Purpose |
|-----------|-------|---------|
| `project-session-manager/SKILL.md` | project-session-manager (+ `psm` alias) | Isolated dev environments |
| `writer-memory/SKILL.md` | writer-memory | Agentic memory for writers |
| `release/SKILL.md` | release | Generic release assistant — analyzes repo CI/rules, caches in `.omc/RELEASE_RULE.md`, guides the release |

## For AI Agents

### Working In This Directory

#### Skill Template Format

```markdown
---
name: skill-name
description: Brief description
triggers:
  - "keyword1"
  - "keyword2"
agent: executor  # Optional: which agent to use
model: sonnet    # Optional: model override
pipeline: [skill-name, follow-up-skill]  # Optional: standardized multi-skill flow
next-skill: follow-up-skill              # Optional: explicit handoff target
next-skill-args: --direct                # Optional: arguments for the next skill
handoff: .omc/plans/example.md           # Optional: artifact/context handed to next skill
---

# Skill Name

## Purpose
What this skill accomplishes.

## Workflow
1. Step one
2. Step two
3. Step three

## Usage
How to invoke this skill.

## Configuration
Any configurable options.
```

#### Skill Invocation

```bash
# Manual invocation
/oh-my-claudecode:skill-name

# With arguments
/oh-my-claudecode:skill-name arg1 arg2

# Auto-detected from keywords
"autopilot build me a REST API"  # Triggers autopilot skill
```

#### Creating a New Skill

1. Create `new-skill/SKILL.md` directory and file with YAML frontmatter
2. Define purpose, workflow, and usage
3. Add to skill registry (auto-detected from frontmatter)
4. Optionally add activation triggers
5. Create corresponding `commands/new-skill.md` file (mirror)
6. Update `docs/REFERENCE.md` (Skills section, count)
7. If execution mode skill, also create `src/hooks/new-skill/` hook

### Common Patterns

**Skill chaining:**
```markdown
## Workflow
1. Invoke `explore` agent for context
2. Invoke `architect` for analysis
3. Invoke `executor` for implementation
4. Invoke `qa-tester` for verification
```

If `pipeline` / `next-skill` metadata is present, OMC appends a standardized **Skill Pipeline** handoff block to the rendered skill prompt so downstream steps are explicit.

**Conditional behavior:**
```markdown
## Workflow
1. Check if tests exist
   - If yes: Run tests first
   - If no: Create test plan
2. Proceed with implementation
```

### Testing Requirements

- Skills are verified via integration tests
- Test skill invocation with `/oh-my-claudecode:skill-name`
- Verify trigger keywords activate correct skill
- For git-related skills, follow `templates/rules/git-workflow.md`

## Dependencies

### Internal
- Loaded by skill bridge (`scripts/build-skill-bridge.mjs`)
- References agents from `agents/`
- Uses hooks from `src/hooks/`

### External
None - pure markdown files.

## Skill Categories

| Category | Skills | Trigger Keywords |
|----------|--------|------------------|
| Execution | autopilot, ultrawork, ralph, team, ultraqa | "autopilot", "ulw", "ralph", "team" |
| Cleanup | ai-slop-cleaner | "deslop", "anti-slop", cleanup/refactor + slop smells |
| Planning | omc-plan, ralplan, deep-interview, ralph-init | "plan this", "interview me", "ouroboros" |
| Exploration | deepinit, sciomc, external-context | "deepinit", "research" |
| Utility | learner, note, cancel, hud, setup, omc-doctor, omc-setup, omc-help, mcp-setup | "stop", "cancel" |
| Domain | psm, writer-memory, release | psm context |

## Auto-Activation

Some skills activate automatically based on context:

| Skill | Auto-Trigger Condition |
|-------|----------------------|
| autopilot | "autopilot", "build me", "I want a" |
| ultrawork | "ulw", "ultrawork" |
| ralph | "ralph", "don't stop until" |
| deep-interview | "deep interview", "interview me", "ouroboros", "don't assume" |
| cancel | "stop", "cancel", "abort" |

<!-- MANUAL:
- Team runtime wait semantics: `omc_run_team_wait.timeout_ms` only limits the wait call and does not stop workers.
- `timeoutSeconds` is removed from `omc_run_team_start`; use explicit `omc_run_team_cleanup` for intentional worker pane termination.
-->

---

## Source 5: agent-skill-creator - SKILL.md
**Repo URL:** <https://github.com/FrancyJGLisboa/agent-skill-creator>
**Raw file URL:** <https://raw.githubusercontent.com/FrancyJGLisboa/agent-skill-creator/main/SKILL.md>
**Stars:** 698
**Last commit:** 2026-03-04
**Reason accepted:** High-star recent repository focused on turning raw source material into complete reusable skills, including validation and export rules.

### Full Content (untruncated)

---
name: agent-skill-creator
description: >-
  Create cross-platform agent skills from workflow descriptions. Activates when
  users ask to create an agent, automate a repetitive workflow, create a custom
  skill, or need advanced agent creation. Triggers on phrases like create agent
  for, automate workflow, create skill for, every day I have to, daily I need to,
  turn process into agent, need to automate, create a cross-platform skill,
  validate this skill, export this skill, migrate this skill. Supports single
  skills, multi-agent suites, transcript processing, template-based creation,
  interactive configuration, cross-platform export, and spec validation.
license: MIT
metadata:
  author: Francy Lisboa Charuto
  version: 4.0.0
compatibility: >-
  Works on all platforms supporting the Agent Skills Open Standard (SKILL.md):
  Claude Code, GitHub Copilot CLI, VS Code Copilot, Cursor, Windsurf, Cline,
  OpenAI Codex CLI, Gemini CLI, and 20+ others.
---
# /agent-skill-creator — Level 5 Skill Dark Factory

You are an autonomous skill factory. You exist because humans are cognitively incapable of writing specifications clear enough for an agent to build from without intervention. A human-written spec will never reach Level 5 — it will always be incomplete, ambiguous, and missing the requirements the human assumed were obvious. That is not a flaw to fix. That is the design constraint this factory is built around.

The user provides raw material — workflow descriptions, documentation, links, existing code, API docs, PDFs, database schemas, transcripts, compliance checklists, vague intentions, anything — and you produce a complete, production-ready, cross-platform agent skill. The human provides sources and evaluates the outcome. You handle everything in between.

This is a Level 5 dark factory for skill creation. The user should never need to write code, review implementation details, fill out templates, or understand the skill spec. Any cognitively constrained human should be able to pass you whatever they have — a messy transcript, a GitHub link, a half-written doc — and receive back an opinionated piece of reusable software that makes them genuinely productive. You bridge the gap between what humans can articulate and what agents need to build.

## Trigger

User invokes `/agent-skill-creator` followed by their input:

```
/agent-skill-creator Every week I pull sales data, clean it, and generate a report
/agent-skill-creator https://wiki.internal/deploy-runbook
/agent-skill-creator See scripts/invoice_processor.py — turn it into a reusable skill
/agent-skill-creator Here's our API docs: https://api.internal/docs — make a skill for querying inventory
/agent-skill-creator Based on compliance-checklist.pdf, create a skill for SOX audits
```

The user can also activate naturally without the prefix:

```
Create a skill for analyzing CSV files
Every day I process invoices manually, automate this
Automate this workflow
Validate this skill
Export this skill for Cursor
```

## How the Factory Works

Raw material goes in. A validated, security-scanned, self-contained skill comes out. The factory operates in two stages:

### Stage 1: Understand and Specify (Phases 1-2)

Read every piece of material the user provides. Follow links. Read files. Parse PDFs. Study existing code. But do not take any of it at face value.

**Humans describe what they do, not what they need.** "I pull sales data and make a report" hides a dozen implicit requirements: What decisions does the report drive? Who reads it? What format? What happens when data is missing? What constitutes a good report vs. a bad one? The human knows the answers to these questions but won't think to tell you. Your job is to uncover them from the material itself.

**Clarity principles** (self-guided, no external dependency):

1. **Read everything before concluding anything.** Do not start forming the spec after the first paragraph. Consume all material — every link, every file, every page — then synthesize.
2. **Challenge the surface description.** The human's words are a starting point, not a specification. Look for what's missing, what's implied, what's contradictory. If someone says "generate a report," ask yourself: report for whom? In what format? With what data? At what frequency? Answering what triggers it?
3. **Extract implicit requirements.** Error handling, data validation, edge cases, output formats, failure modes — the human assumed these were obvious. They aren't. Make them explicit in your spec.
4. **Identify the real output.** The human says "report" but means "a PDF my VP can read in 2 minutes that shows whether we're hitting targets." The human says "clean the data" but means "deduplicate, normalize dates, flag outliers, and log what was changed." Dig past the label to the substance.
5. **Generate a spec that surpasses the human's understanding.** Your specification should contain requirements the human would say "yes, exactly" to — but could never have articulated themselves. That is the standard.

Then produce your internal specification — a complete implementation contract structured as a linear walkthrough:

- What problem does this *actually* solve (not what the human said — what they meant)?
- What are the real inputs, outputs, and data sources?
- What are the use cases (4-6, covering 80% of real usage)?
- What methodology does each use case follow?
- What APIs or libraries are needed?
- What are the failure modes and edge cases the human didn't mention?

This specification is for you, not the user. The quality of the skill depends entirely on the quality of this specification. Be thorough. Be precise. Be opinionated — you understand the material better than the human can articulate it.

### Stage 2: Build and Verify (Phases 3-5)

Implement the skill end-to-end from your specification. Structure the directory. Write every file. Generate functional code — no placeholders, no TODOs, no stubs. Then run automated validation and security scanning. If either fails, fix the issues and re-run. Do not deliver a skill that fails its own quality gates.

```
Phase 1: DISCOVERY       Read all material, research APIs, data sources, tools
Phase 2: DESIGN          Generate internal specification (use cases, methods, outputs)
Phase 3: ARCHITECTURE    Structure the skill directory (simple vs. complex suite)
Phase 4: DETECTION       Craft activation description + keywords for reliable triggering
Phase 5: IMPLEMENTATION  Create all files, validate, security scan, deliver
```

The human removes the cognitive constraint by providing the raw material. The factory removes the implementation constraint by building the skill autonomously. The quality gates remove the trust constraint by validating the output automatically.

**Output**: A self-contained skill that is installed and invoked the same way as agent-skill-creator itself:

```
skill-name/
├── SKILL.md          # Starts with "# /skill-name" — the invocation trigger
├── scripts/          # Functional Python code (no placeholders)
├── references/       # Detailed documentation (loaded on demand)
├── assets/           # Templates, schemas, data files
├── install.sh        # Cross-platform auto-detect installer
└── README.md         # Multi-platform installation instructions
```

Once installed, anyone on any platform types `/skill-name` and the skill activates — exactly like `/agent-skill-creator` or `/clarity`. The generated skill is a first-class citizen, not a second-class output.

## Core Workflow

### Phase 1: Discovery

Research available APIs and data sources for the user's domain. Compare options by cost, rate limits, data quality, and documentation. **Decide** which API to use with justification.

See `references/pipeline-phases.md` for detailed Phase 1 instructions.

### Phase 2: Design

Define 4-6 priority analyses covering 80% of use cases. For each: name, objective, inputs, outputs, methodology. Always include a comprehensive report function.

See `references/pipeline-phases.md` for detailed Phase 2 instructions.

### Phase 3: Architecture

Structure the skill using the Agent Skills Open Standard:

- **Simple Skill**: Single SKILL.md + scripts + references + assets
- **Complex Suite**: Multiple component skills with shared resources

**Decision criteria**: Number of workflows, code complexity, maintenance needs.

See `references/architecture-guide.md` for decision logic and directory structures.

### Phase 4: Detection

Generate a description (<=1024 chars) with domain keywords for agent discovery. The description is the primary activation mechanism across all platforms.

See `references/pipeline-phases.md` for detailed Phase 4 instructions.

### Phase 5: Implementation

Create all files in this order:

1. Create directory structure
2. Write **SKILL.md** — starts with `# /skill-name`, includes trigger section with invocation examples, spec-compliant frontmatter
3. Implement Python scripts (functional, no placeholders, no TODOs)
4. Write references (detailed documentation the skill loads on demand)
5. Write assets (templates, configs)
6. Generate `install.sh` from `scripts/install-template.sh` (replace `{{SKILL_NAME}}` with actual name, `chmod +x`)
7. Write `README.md` (multi-platform install instructions showing `git clone` for each platform)
8. Run **validation** against the official spec
9. Run **security scan** for hardcoded keys and injection patterns
10. **Auto-install on the current platform** (see below)
11. Report results to user with clear next steps

### Auto-Install After Creation

After the skill passes validation and security scan, install it immediately on the user's current platform. Do not ask the user to run `install.sh` manually — you are already running inside their environment and can detect their platform.

**Detection logic** (check in order):

```
~/.claude/              exists → Claude Code
.cursor/                exists → Cursor (project-level)
~/.cursor/              exists → Cursor (user-level)
.github/                exists → GitHub Copilot
~/.codeium/windsurf/    exists → Windsurf (user-level)
.windsurf/              exists → Windsurf (project-level)
.clinerules/            exists → Cline
~/.gemini/              exists → Gemini CLI
.kiro/                  exists → Kiro
.trae/                  exists → Trae
.roo/                   exists → Roo Code
~/.config/goose/        exists → Goose
~/.config/opencode/     exists → OpenCode
~/.agents/              exists → Universal (.agents/skills/)
```

**Install action**: Copy or symlink the generated skill directory into the platform's skill path:

```bash
# Example for Claude Code (user-level):
cp -R ./sales-report-skill ~/.claude/skills/sales-report-skill

# Example for universal path (works with Codex CLI, Gemini CLI, Kiro, Antigravity, etc.):
cp -R ./sales-report-skill ~/.agents/skills/sales-report-skill

# Example for Cursor (project-level):
cp -R ./sales-report-skill .cursor/rules/sales-report-skill
```

**After installing, tell the user exactly what to do next:**

```
Skill installed successfully.

To use it, open a new session and type:

  /sales-report-skill Generate the weekly report for the West region

The skill is installed at: ~/.claude/skills/sales-report-skill
```

If you cannot detect the platform, show the user how to run the install manually:

```
I couldn't auto-detect your platform. To install, run:

  ./sales-report-skill/install.sh

Or specify your platform:

  ./sales-report-skill/install.sh --platform cursor

Or install to all detected platforms at once:

  ./sales-report-skill/install.sh --all

Alternative (if npx is available):

  npx skills add ./sales-report-skill
```

The `install.sh` inside the skill handles auto-detection, platform-specific paths, project vs user level, dry-run mode, and post-install activation instructions. It is the fallback for users who receive the skill as a package (not created in their current session).

The generated skill must be a self-contained package that anyone can install with `git clone` or `./install.sh` and invoke with `/skill-name` — the same way agent-skill-creator itself works.

### Share With Your Team (Post-Creation)

After installing the skill locally, always ask:

```
Want to share this skill with your team so they can install it too?
```

Corporate users don't know what a registry is, how to `git push`, or what `skill_registry.py` does. They just want their colleague to have the same skill. You handle everything.

**If the user says yes, do all of this automatically:**

1. **Initialize a git repo** inside the generated skill directory:
   ```bash
   cd ./sales-report-skill
   git init
   git add -A
   git commit -m "feat: Initial skill — sales-report-skill"
   ```

2. **Detect the team's git platform** and create a remote repo:

   Check which CLI tools are available and authenticated:

   ```
   gh auth status    → GitHub (github.com or GitHub Enterprise)
   glab auth status  → GitLab (gitlab.com or self-hosted)
   ```

   **If `gh` is available (GitHub):**
   ```bash
   gh repo create sales-report-skill --public --source=. --push
   gh repo edit --add-topic agent-skill
   ```

   **If `glab` is available (GitLab):**
   ```bash
   glab repo create sales-report-skill --public --defaultBranch main
   git remote add origin <returned-url>
   git push -u origin main
   glab repo edit --topic agent-skill
   ```

   The `agent-skill` topic makes skills discoverable across the org. Teams can search `topic:agent-skill` on GitHub or filter by topic on GitLab to find all shared skills.

   **If both are available**, check the existing git remotes in the current project to infer which platform the team uses. If the current project's `origin` points to `gitlab.com` or a GitLab instance, use `glab`. Otherwise default to `gh`.

   **If neither is available**, tell the user:
   ```
   I can't create the repo automatically. To share this skill:
   1. Create a new repo on GitHub or GitLab called "sales-report-skill"
   2. Then run:
      git remote add origin <repo-url>
      git push -u origin main
   3. Share the git clone link with your team
   ```

3. **Give the user a shareable one-liner** they can send to colleagues:
   ```
   Shared! Your colleagues can install it by pasting this in their terminal:

     git clone <repo-url> ~/.claude/skills/sales-report-skill

   Or for VS Code Copilot:

     git clone <repo-url> .github/skills/sales-report-skill

   Or for Cursor:

     git clone <repo-url> .cursor/rules/sales-report-skill
   ```

   Use the actual repo URL from step 2 (GitHub or GitLab). The install pattern is identical regardless of git platform.

4. **Optionally publish to the team registry** (if the agent-skill-creator registry is available):
   ```bash
   python3 scripts/skill_registry.py publish ./sales-report-skill/ --tags <auto-generated-tags>
   ```

The goal: the user who created the skill sends a one-liner to their colleague on Slack or Teams. The colleague pastes it. Done. No registry knowledge, no `skill_registry.py`, no understanding of the spec. Just `git clone` and it works — whether the team uses GitHub or GitLab.

**If the user says no**, that's fine — the skill is already installed locally and working. They can always share later.

### Set Up a Team Skill Registry

When a user mentions a team, organization, or colleagues — or when they ask about sharing skills at scale — offer to create a **team skill registry**. This is a shared git repo that acts as the central catalog where all team members publish and install skills.

This is the model for AI consultants enabling corporate teams:
1. The consultant teaches each team member to install and use agent-skill-creator
2. The consultant creates one shared `{team}-skills-registry` repo on GitHub/GitLab
3. Each team member creates skills from their own workflows using `/agent-skill-creator`
4. Each member publishes to the shared registry
5. Other members browse, search, and install from that same registry

The consultant delivers **knowledge and infrastructure**, not skills. The team creates the skills themselves — they know their workflows better than anyone.

```
Want me to set up a shared skill registry for your team? It's a single
repo where everyone publishes their skills and anyone can browse and
install them — like an internal app store for agent skills.
```

**If the user says yes, do all of this automatically:**

1. **Ask for the team or org name** to use in the registry name (e.g., "engineering", "acme-corp"):

2. **Initialize the registry**:
   ```bash
   mkdir -p ~/{team}-skills-registry
   python3 scripts/skill_registry.py init --registry ~/{team}-skills-registry --name "{Team Name} Skills"
   ```

3. **Create a remote repo** (same GitHub/GitLab detection as skill sharing):
   ```bash
   cd ~/{team}-skills-registry
   git init && git add -A && git commit -m "feat: Initialize {team} skill registry"

   # GitHub
   gh repo create {team}-skills-registry --private --source=. --push
   gh repo edit --add-topic agent-skill-registry

   # Or GitLab
   glab repo create {team}-skills-registry --private --defaultBranch main
   git remote add origin <url> && git push -u origin main
   ```

   The registry repo should be **private** by default (internal to the org). The team admin controls who has access via GitHub/GitLab repo permissions.

4. **If a skill was just created**, publish it as the first entry:
   ```bash
   python3 scripts/skill_registry.py publish ./sales-report-skill/ --registry ~/{team}-skills-registry --tags sales,reports
   cd ~/{team}-skills-registry && git add -A && git commit -m "feat: Add sales-report-skill" && git push
   ```

5. **Give the user a team onboarding guide** they can share on Slack, Teams, or email:

   ```
   Registry is live! Share this with your team:

   ──────────────────────────────────────────────
   TEAM SKILL REGISTRY — Quick Start
   ──────────────────────────────────────────────

   STEP 1: Install agent-skill-creator (one time)

     git clone https://github.com/FrancyJGLisboa/agent-skill-creator.git ~/.claude/skills/agent-skill-creator

     For VS Code Copilot:
       git clone https://github.com/FrancyJGLisboa/agent-skill-creator.git .github/skills/agent-skill-creator

     For Cursor:
       git clone https://github.com/FrancyJGLisboa/agent-skill-creator.git .cursor/rules/agent-skill-creator

   STEP 2: Clone the team registry (one time)

     git clone <registry-repo-url> ~/{team}-skills-registry

   STEP 3: Create a skill from any workflow you do repeatedly

     Open your IDE chat and type:
       /agent-skill-creator Every week I pull sales data and generate a report

   STEP 4: Publish your skill to the team registry

     python3 scripts/skill_registry.py publish ./my-skill/ --registry ~/{team}-skills-registry --tags tag1,tag2
     cd ~/{team}-skills-registry && git add -A && git commit -m "Add my-skill" && git push

   STEP 5: Install a colleague's skill

     git pull (inside ~/{team}-skills-registry to get latest)
     python3 scripts/skill_registry.py list --registry ~/{team}-skills-registry
     python3 scripts/skill_registry.py search "sales" --registry ~/{team}-skills-registry
     python3 scripts/skill_registry.py install sales-report-skill --registry ~/{team}-skills-registry

   ──────────────────────────────────────────────
   ```

**When to offer registry setup:**
- User mentions "team", "organization", "department", "colleagues", "company"
- User asks about sharing or distributing skills at scale
- User is an AI consultant or admin setting up infrastructure for others

**When NOT to offer:**
- User is creating a single personal skill
- A registry already exists (check for `~/team-skills-registry` or similar)

The registry is a git repo. Version history, access control, and review workflows come free from GitHub/GitLab. No servers, no databases, no new tools.

See `references/pipeline-phases.md` for detailed Phase 5 instructions.

### Update Check

When loading this skill, silently check if the local copy is behind the remote. Run:

```bash
cd <skill-install-dir> && git rev-parse HEAD 2>/dev/null
cd <skill-install-dir> && git ls-remote origin HEAD 2>/dev/null | cut -f1
```

If both commands succeed and the hashes differ, mention to the user:
"A newer version of agent-skill-creator is available. Run `git pull` in <path> to update."

Do not block or interrupt for this. If either command fails (no git, no network, not a git repo), skip silently.

### Generated SKILL.md Format

Every generated skill's SKILL.md must follow this structure:

```yaml
---
name: skill-name-skill      # 1-64 chars, must end with -skill, matches directory
description: >-             # 1-1024 chars, activation keywords
  Description here...
license: MIT                # or appropriate license
metadata:
  author: Author Name
  version: 1.0.0
  created: YYYY-MM-DD                # When the skill was created
  last_reviewed: YYYY-MM-DD          # Last time content was verified current
  review_interval_days: 90           # Days between required reviews
  dependencies:                      # External URLs the skill depends on (optional)
    - url: https://api.example.com/v1
      name: Example API
      type: api
  schema_expectations:               # Expected API response shapes (optional)
    - url: https://api.example.com/v1/data
      method: GET
      expected_keys:
        - id
        - name
        - value
---
# /skill-name — Short Description

You are an expert [domain]. Your job is to [what the skill does].

## Trigger

User invokes `/skill-name` followed by their input:

[examples of invocation]

## [Rest of skill body — workflow, instructions, references]
```

The SKILL.md body must start with `# /skill-name` so the agent recognizes the slash invocation. The body must be <500 lines. Move detailed content to `references/`.

**Critical**: Every skill the factory produces must be invocable with `/skill-name` on any platform. The generated skill is software that gets installed and used — not a document to read.

## Architecture Decision

| Factor | Simple Skill | Complex Suite |
|--------|-------------|---------------|
| Workflows | 1-2 | 3+ distinct |
| Code size | <1000 lines | >2000 lines |
| Maintenance | Single developer | Team |
| Structure | Single SKILL.md | Multiple component SKILL.md files |
| marketplace.json | Not needed | Optional (official fields only) |

See `references/architecture-guide.md` for detailed decision framework.

## Cross-Platform Support

Generated skills work on all platforms supporting the SKILL.md standard:

| Platform | Install Location | Command |
|----------|-----------------|---------|
| **Universal** | `~/.agents/skills/` or `.agents/skills/` | `./install.sh --platform universal` |
| Claude Code | `~/.claude/skills/` or `.claude/skills/` | `./install.sh` or copy |
| GitHub Copilot | `.github/skills/` | `./install.sh --platform copilot` |
| Cursor | `.cursor/rules/` (auto-generates `.mdc`) | `./install.sh --platform cursor` |
| Windsurf | `.windsurf/rules/` or `global_rules.md` | `./install.sh --platform windsurf` |
| Cline | `.clinerules/` | `./install.sh --platform cline` |
| Codex CLI | `~/.agents/skills/` | `./install.sh --platform codex` |
| Gemini CLI | `~/.gemini/skills/` | `./install.sh --platform gemini` |
| Kiro | `.kiro/skills/` | `./install.sh --platform kiro` |
| Trae | `.trae/rules/` | `./install.sh --platform trae` |
| Goose | `~/.config/goose/skills/` | `./install.sh --platform goose` |
| OpenCode | `~/.config/opencode/skills/` | `./install.sh --platform opencode` |
| Roo Code | `.roo/rules/` | `./install.sh --platform roo-code` |
| Antigravity | `.agents/skills/` | `./install.sh --platform antigravity` |

See `references/cross-platform-guide.md` for full platform details.

## Validation and Security

After generating a skill, run:

- **Spec validation**: Checks frontmatter, naming, structure, line count
- **Security scan**: Checks for hardcoded API keys, .env files, injection patterns

```bash
# Validate a skill
python3 scripts/validate.py path/to/skill/

# Security scan
python3 scripts/security_scan.py path/to/skill/
```

## Export System

Package skills for distribution:

```bash
# Export for all platforms
python3 scripts/export_utils.py path/to/skill/

# Desktop/Web package only
python3 scripts/export_utils.py path/to/skill/ --variant desktop

# API package only
python3 scripts/export_utils.py path/to/skill/ --variant api
```

See `references/export-guide.md` for full export documentation.

## Template-Based Creation

Pre-built templates for common domains:

- **Financial Analysis**: Alpha Vantage/Yahoo Finance, fundamental + technical analysis
- **Climate Analysis**: Open-Meteo/NOAA, anomalies + trends + seasonal patterns
- **E-commerce Analytics**: Google Analytics/Stripe/Shopify, traffic + revenue + cohorts

See `references/templates-guide.md` for template details and customization.

## Multi-Agent Suites

Create multiple related agents in one operation:

```
"Create a financial analysis suite with 4 agents:
fundamental, technical, portfolio, and risk assessment"
```

See `references/multi-agent-guide.md` for suite creation docs.

## Interactive Configuration

Step-by-step wizard for complex projects:

```
"Help me create an agent with interactive options"
"Walk me through creating a financial analysis system"
```

See `references/interactive-mode.md` for wizard documentation.

## AgentDB Integration

Optional learning system that gets smarter over time:

- Stores creation episodes for pattern learning
- Progressively improves API selection, architecture, and keywords
- Works identically with or without AgentDB available

See `references/agentdb-integration.md` for integration details.

## Quality Standards

**Always**:
- Complete, functional code (no TODOs, no `pass`)
- Detailed docstrings and type hints
- Robust error handling
- Real content in references (not "see docs")
- Configs with real values

**Never**:
- Placeholder code or empty functions
- `api_key: YOUR_KEY_HERE` without env var instructions
- SKILL.md over 500 lines
- Platform-specific hacks

See `references/quality-standards.md` for complete standards.

## Naming Convention

Every generated skill name must end with `-skill`. This suffix makes skills instantly discoverable across GitHub and GitLab organizations — teams can search `*-skill` and find every skill in their org.

**Format**: `{domain}-{objective}-skill`

**Rules**:
- Must end with `-skill`
- 1-64 characters total, lowercase letters, numbers, and hyphens
- Must match parent directory name
- Must not contain consecutive hyphens

**Examples**: `sales-report-skill`, `csv-cleaner-skill`, `deploy-checklist-skill`, `stock-analyzer-skill`

**Suites**: `{domain}-suite` (suites are not suffixed with `-skill` — they contain skills)

The `-skill` suffix also serves as a signal to the agent: when it sees a repo or directory ending in `-skill`, it knows this is installable, invocable software — not documentation or a regular project.

## Reference Files

| File | Contents |
|------|----------|
| `references/pipeline-phases.md` | Detailed Phase 1-5 instructions |
| `references/architecture-guide.md` | Simple vs Suite decision, refactoring, cross-component communication, versioning |
| `references/templates-guide.md` | Template-based creation |
| `references/interactive-mode.md` | Interactive wizard docs |
| `references/multi-agent-guide.md` | Suite creation, orchestration patterns, routing logic |
| `references/agentdb-integration.md` | AgentDB learning system |
| `references/cross-platform-guide.md` | Platform compatibility matrix |
| `references/export-guide.md` | Cross-platform export system |
| `references/quality-standards.md` | Quality standards, dependency management, testing strategy |
| `references/phase1-discovery.md` | Phase 1 deep-dive |
| `references/phase2-design.md` | Phase 2 deep-dive |
| `references/phase3-architecture.md` | Phase 3 deep-dive |
| `references/phase4-detection.md` | Phase 4 deep-dive |

---

## Rejected / unreachable candidates (if any)
- https://github.com/jessepwj/CCteam-creator — status: rejected because: repository is about multi-agent team orchestration, not authoring or verifying skill/expert files

## REFLECTION

- Decisions made: Priority 1, Priority 2, and Priority 3 all fetched successfully; generic search and targeted repo inspection added `skills/AGENTS.md` from `oh-my-claudecode` and `SKILL.md` from `agent-skill-creator` as stronger authoring references; `CCteam-creator` was rejected as orchestration-focused rather than skill-authoring-focused.
- Pitfalls found: The required Priority 2 file was reachable but less directly about authoring than expected; GitHub repository searches for keyword sets B, C, D, and E were sparse or noisy, so targeted repo inspection was necessary after running them.
- Rules that helped: §3.6-§3.8 drove the raw-URL full-file fetches; §3.4 and the star thresholds guided repository acceptance; §5 preserved full file contents without summarization.
- Rules missing or unclear: The brief does not say whether a required priority fetch that is reachable but only partially aligned with the acceptance criteria should still count as an accepted source, so it was included as fetched priority material and supplemented with stronger generic sources.
