# Round 3 Plan

Status snapshot: 2026-04-12

## Planning artifact status

- [Issue #48](https://github.com/hahyihao/ao-conductor-kit/issues/48) requested a Round 3 planning artifact for dashboard visibility.
- [PR #51](https://github.com/hahyihao/ao-conductor-kit/pull/51) on branch `feat/48` is the existing artifact branch, and `docs/round-3-plan.md` is the concrete planning file under review.
- `main` does not currently contain a `docs/plans/` directory. Keep the Round 3 planning artifact here instead of creating a parallel plan location.
- This file is planning only. It does not authorize Round 3 implementation, worker spawn, or worker preparation for parked issues [#37](https://github.com/hahyihao/ao-conductor-kit/issues/37) through [#46](https://github.com/hahyihao/ao-conductor-kit/issues/46).

## Current gate

- `ROADMAP.md` places Round 3 after the Round 2 general-expert wave.
- `ARCHITECTURE.md` keeps Round 3 blocked until Round 2 is complete, then packages 10 project experts.
- Round 1 is complete and delivered 5 infra experts.
- Round 3 remains parked until the remaining Round 2 blockers clear.

## Round 2 merge gate

| PR | Expert | State on 2026-04-12 |
|---|---|---|
| [#22](https://github.com/hahyihao/ao-conductor-kit/pull/22) | `refactorer` | merged at `2026-04-12 08:54 UTC` |
| [#23](https://github.com/hahyihao/ao-conductor-kit/pull/23) | `security-auditor` | open |
| [#24](https://github.com/hahyihao/ao-conductor-kit/pull/24) | `script-writer` | open |
| [#25](https://github.com/hahyihao/ao-conductor-kit/pull/25) | `debugger` | open |
| [#26](https://github.com/hahyihao/ao-conductor-kit/pull/26) | `writer` | open |
| [#27](https://github.com/hahyihao/ao-conductor-kit/pull/27) | `code-writer` | open |
| [#28](https://github.com/hahyihao/ao-conductor-kit/pull/28) | `test-engineer` | open |
| [#29](https://github.com/hahyihao/ao-conductor-kit/pull/29) | `planner` | open |

- Remaining Round 2 blockers: [#23](https://github.com/hahyihao/ao-conductor-kit/pull/23), [#24](https://github.com/hahyihao/ao-conductor-kit/pull/24), [#25](https://github.com/hahyihao/ao-conductor-kit/pull/25), [#26](https://github.com/hahyihao/ao-conductor-kit/pull/26), [#27](https://github.com/hahyihao/ao-conductor-kit/pull/27), [#28](https://github.com/hahyihao/ao-conductor-kit/pull/28), and [#29](https://github.com/hahyihao/ao-conductor-kit/pull/29).
- Until those PRs merge, Round 3 stays planning-only and parked.

## Official Round 3 scope

| Target expert | Source skill(s) | Parked issue |
|---|---|---|
| `experts/project/binance-trading.md` | `binance-trading-ops` | [#37](https://github.com/hahyihao/ao-conductor-kit/issues/37) |
| `experts/project/xianyu-ops.md` | `xianyu-ops` | [#38](https://github.com/hahyihao/ao-conductor-kit/issues/38) |
| `experts/project/tieba-operation.md` | `tieba-operation-master` | [#39](https://github.com/hahyihao/ao-conductor-kit/issues/39) |
| `experts/project/novel-reader.md` | `novel-reader-review` | [#40](https://github.com/hahyihao/ao-conductor-kit/issues/40) |
| `experts/project/game-automation.md` | `game-automation` | [#41](https://github.com/hahyihao/ao-conductor-kit/issues/41) |
| `experts/project/ztc-optimizer.md` | `ztc-*` family | [#42](https://github.com/hahyihao/ao-conductor-kit/issues/42) |
| `experts/project/chat-analysis.md` | `chat-analysis` | [#43](https://github.com/hahyihao/ao-conductor-kit/issues/43) |
| `experts/project/qq-bot-audit.md` | `qq-bot-audit` | [#44](https://github.com/hahyihao/ao-conductor-kit/issues/44) |
| `experts/project/douyin-content.md` | `douyin-*` family | [#45](https://github.com/hahyihao/ao-conductor-kit/issues/45) |
| `experts/project/swarm-commander.md` | `swarm-commander + pc-init` | [#46](https://github.com/hahyihao/ao-conductor-kit/issues/46) |

## Candidate pool scanned from the installed skill ecosystem

This scan is planning rationale only. It is not an execution queue and does not permit worker prep while Round 3 is parked.

| Candidate | Purpose summary | Why package into an expert | Effort |
|---|---|---|---|
| `swarm-commander` | PC fleet controller for precheck, dispatch, stage-gates, and result routing. | High routing value for host-side swarm work that should stay distinct from device ops. | medium |
| `pc-init` | New machine bootstrap and readiness setup for the PC fleet. | Worth preserving, but best folded into the host controller expert instead of taking a separate slot. | small |
| `binance-trading-ops` | Binance trading operations, diagnostics, reporting, backtest, and phone-order chain analysis. | Strong project boundary with specialized operational references and risk-sensitive workflows. | medium |
| `xianyu-ops` | Android device operations hub for Xianyu monitoring, screenshot verification, fixes, and analysis. | Clear screenshot-first discipline and device-only routing value. | medium |
| `tieba-operation-master` | Tieba plus Douyin mobile operations for account growth, content, traffic, safety, and monitoring. | Distinct mobile content-ops discipline with reusable routing rules. | medium |
| `chat-analysis` | Batch conversation-analysis pipeline with prep, analyze, review, modify, and report stages. | Valuable because it exposes a full analysis workflow instead of a one-off report skill. | medium |
| `novel-reader-review` | Reader-side fiction chapter review with scoring, immersion checks, and AI-style detection. | Unique reader-only stance that should not be confused with generic writing help. | small |
| `game-automation` | Game scripting workflow from screenshots and page maps to YAML state machines and regression loops. | Good expert candidate because it is a specialized automation domain, not ordinary scripting. | medium |
| `qq-bot-audit` | QQ bot vector-base audit, false-positive review, fission testing, and regression verification. | Strong audit/repair discipline with a clear quality bar and bounded project scope. | small |
| `ztc-optimizer` | Single-shop Taobao ads operations hub for diagnosis and optimization. | Natural hub skill for the larger `ztc-*` family and a good top-level router. | medium |
| `ztc-patrol` | Store patrol and diagnostics for the ZTC operating loop. | Worth scanning, but it overlaps heavily with the planned ZTC hub expert. | small |
| `ztc-keyword` | Keyword execution and tuning inside the ZTC operating loop. | Important subdomain, but better represented as a routed capability under one expert. | small |
| `ztc-product` | Product lifecycle operations inside the ZTC operating loop. | Useful domain coverage, but too overlapping to justify a separate Round 3 expert. | small |
| `ztc-store` | Store setup and infrastructure operations inside the ZTC operating loop. | Important as part of the shop-level hub, not as a standalone packaging target. | small |
| `douyin-shared-rules` | Global hard-gates and workflow rules for the Douyin content toolchain. | Critical family-level discipline that should be preserved in one merged content expert. | medium |
| `douyin-content-creation` | Topic selection and draft generation for the Douyin pipeline. | Valuable production stage, but too narrow to ship as its own project expert. | small |
| `douyin-content-review` | Review and gating of drafts before later production stages. | Important quality-control stage that belongs inside a merged pipeline expert. | small |
| `douyin-content-layout` | Layout and packaging stage for Douyin content assets. | Useful stage skill, but better consumed through one pipeline-facing expert. | small |
| `douyin-video-review` | Final video review and release gating for Douyin outputs. | High-value downstream gate, but still a sub-step of the full content system. | small |
| `desktop-control` | Desktop interaction and control support for local operator workflows. | Useful helper capability, but not as differentiated as the final top-10 project domains. | medium |

## Selection rationale

- The selected 10 cover the highest-value project routing surfaces without fragmenting Round 3 into too many narrow experts.
- `swarm-commander + pc-init` was merged so PC fleet control and machine admission live behind one host-side expert.
- The `ztc-*` family was merged into `ztc-optimizer` so shop routing, patrol, keyword, product, and store work stay under one single-shop hub.
- The `douyin-*` family was merged into `douyin-content` so creation, review, layout, and final video gates stay in one content-pipeline expert.
- Lower-ranked scanned candidates such as standalone `pc-init`, the individual `ztc-*` subskills, the individual `douyin-*` stages, and `desktop-control` are still useful inputs, but they package better as merged capabilities than as separate Round 3 expert slots.

## Execution guardrails

- Do not spawn or prepare implementation workers for parked issues [#37](https://github.com/hahyihao/ao-conductor-kit/issues/37) through [#46](https://github.com/hahyihao/ao-conductor-kit/issues/46) while Round 2 blockers [#23](https://github.com/hahyihao/ao-conductor-kit/pull/23) through [#29](https://github.com/hahyihao/ao-conductor-kit/pull/29) are still open.
- The parked issues already define the implementation entry points; no extra Round 3 pre-work queue should be created before the Round 2 gate clears.
- When the gate clears, resume from this file plus parked issues [#37](https://github.com/hahyihao/ao-conductor-kit/issues/37) through [#46](https://github.com/hahyihao/ao-conductor-kit/issues/46) instead of creating a separate `docs/plans/` artifact.
