# Round 3 Plan

Status snapshot: 2026-04-12

## Planning artifact status

- #48 requested a Round 3 planning artifact for dashboard visibility.
- PR #51 on branch `feat/48` is the existing artifact branch, and
  `docs/round-3-plan.md` is the concrete planning file under review.
- `main` does not currently contain a `docs/plans/` directory. Keep the
  Round 3 planning artifact here instead of creating a parallel plan
  location.
- This file is planning only. It does not authorize Round 3
  implementation, worker spawn, or worker preparation for parked issues
  #37 through #46.

## Current gate

- `ROADMAP.md` places Round 3 after the Round 2 general-expert wave.
- `ARCHITECTURE.md` keeps Round 3 blocked until Round 2 is complete,
  then packages 10 project experts.
- Round 1 is complete and delivered 5 infra experts.
- Round 3 remains parked until the remaining Round 2 blockers clear.

## Round 2 merge gate

- #22 `refactorer`: merged at `2026-04-12 08:54 UTC`.
- #23 `security-auditor`: open.
- #24 `script-writer`: open.
- #25 `debugger`: open.
- #26 `writer`: open.
- #27 `code-writer`: open.
- #28 `test-engineer`: open.
- #29 `planner`: open.
- Remaining Round 2 blockers are #23 through #29.
- Until those PRs merge, Round 3 stays planning-only and parked.

## Official Round 3 scope

- `experts/project/binance-trading.md`
  - Source skill: `binance-trading-ops`
  - Parked issue: #37
- `experts/project/xianyu-ops.md`
  - Source skill: `xianyu-ops`
  - Parked issue: #38
- `experts/project/tieba-operation.md`
  - Source skill: `tieba-operation-master`
  - Parked issue: #39
- `experts/project/novel-reader.md`
  - Source skill: `novel-reader-review`
  - Parked issue: #40
- `experts/project/game-automation.md`
  - Source skill: `game-automation`
  - Parked issue: #41
- `experts/project/ztc-optimizer.md`
  - Source skill family: `ztc-*`
  - Parked issue: #42
- `experts/project/chat-analysis.md`
  - Source skill: `chat-analysis`
  - Parked issue: #43
- `experts/project/qq-bot-audit.md`
  - Source skill: `qq-bot-audit`
  - Parked issue: #44
- `experts/project/douyin-content.md`
  - Source skill family: `douyin-*`
  - Parked issue: #45
- `experts/project/swarm-commander.md`
  - Source skill set: `swarm-commander + pc-init`
  - Parked issue: #46

## Candidate pool scanned from the installed skill ecosystem

This scan is planning rationale only. It is not an execution queue and
does not permit worker prep while Round 3 is parked.

- `swarm-commander`
  - Purpose: PC fleet controller for precheck, dispatch, stage-gates,
    and result routing.
  - Packaging call: Keep host-side swarm routing distinct from device
    ops.
  - Effort: medium
- `pc-init`
  - Purpose: New machine bootstrap and readiness setup for the PC fleet.
  - Packaging call: Fold it into the host controller expert rather than
    giving it a separate slot.
  - Effort: small
- `binance-trading-ops`
  - Purpose: Binance trading operations, diagnostics, reporting,
    backtest, and phone-order chain analysis.
  - Packaging call: Preserve a risk-sensitive project boundary with
    specialized references.
  - Effort: medium
- `xianyu-ops`
  - Purpose: Android device operations for monitoring, screenshot
    verification, fixes, and analysis.
  - Packaging call: Keep screenshot-first and device-only routing
    explicit.
  - Effort: medium
- `tieba-operation-master`
  - Purpose: Tieba plus Douyin mobile operations for growth, content,
    traffic, safety, and monitoring.
  - Packaging call: Keep a distinct mobile content-ops expert boundary.
  - Effort: medium
- `chat-analysis`
  - Purpose: Batch conversation analysis with prep, analyze, review,
    modify, and report stages.
  - Packaging call: Preserve the full workflow rather than collapsing it
    into a one-off report helper.
  - Effort: medium
- `novel-reader-review`
  - Purpose: Reader-side fiction chapter review with scoring,
    immersion checks, and AI-style detection.
  - Packaging call: Preserve the reader-only stance instead of merging
    it into generic writing help.
  - Effort: small
- `game-automation`
  - Purpose: Game scripting from screenshots and page maps to YAML
    state machines and regression loops.
  - Packaging call: Treat it as a specialized automation domain, not
    ordinary scripting.
  - Effort: medium
- `qq-bot-audit`
  - Purpose: QQ bot vector-base audit, false-positive review, fission
    testing, and regression verification.
  - Packaging call: Preserve the audit and repair discipline as a
    bounded project expert.
  - Effort: small
- `ztc-optimizer`
  - Purpose: Single-shop Taobao ads operations for diagnosis and
    optimization.
  - Packaging call: Use it as the top-level router for the broader
    `ztc-*` family.
  - Effort: medium
- `ztc-patrol`
  - Purpose: Store patrol and diagnostics inside the ZTC operating loop.
  - Packaging call: Keep as a supporting input under one ZTC hub.
  - Effort: small
- `ztc-keyword`
  - Purpose: Keyword execution and tuning inside the ZTC operating loop.
  - Packaging call: Represent it as routed capability under one expert.
  - Effort: small
- `ztc-product`
  - Purpose: Product lifecycle operations inside the ZTC operating loop.
  - Packaging call: Keep the coverage, but avoid a separate Round 3
    expert slot.
  - Effort: small
- `ztc-store`
  - Purpose: Store setup and infrastructure operations inside the ZTC
    operating loop.
  - Packaging call: Keep it under the shop-level hub.
  - Effort: small
- `douyin-shared-rules`
  - Purpose: Global hard gates and workflow rules for the Douyin
    content toolchain.
  - Packaging call: Preserve these as family-level rules inside one
    merged content expert.
  - Effort: medium
- `douyin-content-creation`
  - Purpose: Topic selection and draft generation for the Douyin
    pipeline.
  - Packaging call: Keep as a stage inside one pipeline expert.
  - Effort: small
- `douyin-content-review`
  - Purpose: Review and gating of drafts before later production
    stages.
  - Packaging call: Keep as a quality-control stage inside one pipeline
    expert.
  - Effort: small
- `douyin-content-layout`
  - Purpose: Layout and packaging for Douyin content assets.
  - Packaging call: Keep as a routed stage under one pipeline-facing
    expert.
  - Effort: small
- `douyin-video-review`
  - Purpose: Final video review and release gating for Douyin outputs.
  - Packaging call: Keep as a downstream gate under the same merged
    content expert.
  - Effort: small
- `desktop-control`
  - Purpose: Desktop interaction support for local operator workflows.
  - Packaging call: Useful helper capability, but weaker than the final
    top-10 project domains.
  - Effort: medium

## Selection rationale

- The selected 10 cover the highest-value project routing surfaces
  without fragmenting Round 3 into too many narrow experts.
- `swarm-commander + pc-init` was merged so PC fleet control and
  machine admission live behind one host-side expert.
- The `ztc-*` family was merged into `ztc-optimizer` so shop routing,
  patrol, keyword, product, and store work stay under one hub.
- The `douyin-*` family was merged into `douyin-content` so creation,
  review, layout, and final video gates stay in one pipeline expert.
- Lower-ranked scanned candidates such as standalone `pc-init`, the
  individual `ztc-*` subskills, the individual `douyin-*` stages, and
  `desktop-control` still matter, but they package better as merged
  capabilities than as separate Round 3 expert slots.

## Execution guardrails

- Do not spawn or prepare implementation workers for parked issues #37
  through #46 while Round 2 blockers #23 through #29 are still open.
- The parked issues already define the implementation entry points. Do
  not create an extra Round 3 pre-work queue before the Round 2 gate
  clears.
- When the gate clears, resume from this file plus parked issues #37
  through #46 instead of creating a separate `docs/plans/` artifact.
