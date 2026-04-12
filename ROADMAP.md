# AO Conductor Kit — Roadmap

> 按 `ARCHITECTURE.md` §8 的 4 轮计划推进。
> 本文档是**活的**，每完成一项立刻勾掉，每发现新坑立刻记录。

---

## 当前状态（2026-04-12 18:16:22 UTC+08:00 / 2026-04-12 10:16:22 UTC）

> 本快照由 session `kit-78` 刷新，用来替换 2026-04-11 的旧状态叙述。

| Round | 状态 | 当前快照 |
|---|---|---|
| Round 0 | ✅ 已完成 | `experts/` 基础库、`task-splitter.md`、索引与审计文件已落地，tag `v0.3.0-round-0` 仍是自举基线。 |
| Round 1 | ✅ 已完成 | 5 个基础设施专家已进入 `main`：`architect`、`expert-scout`、`library-maintainer`、`env-ops`、`code-reviewer`。 |
| Round 2 | ✅ 已完成 | 8 个通用专家已进入 `main`：`code-writer`、`script-writer`、`writer`、`test-engineer`、`debugger`、`security-auditor`、`refactorer`、`planner`。 |
| Round 2.5 | ✅ 已完成 | 专家库增强波次已进入 `main`：`expert-writer`、`prompt-engineer`，以及 `experts/index.md` 刷新与库整理。 |
| Round 3 | ✅ 已完成 | 按本次用户指令记为完成：10 个项目专家包装任务已在 `feat/37`-`feat/46` 产出实现分支与 PR，规划基线见 `docs/round-3-plan.md`。这表示本轮交付已完成；合并回 `main` 仍由后续整合任务跟进。 |
| Round 4+ | ⏸ 待启动 | 运行时自增长、自动发现、周期性库维护仍未闭环，等 Round 3 主线整合后继续。 |

### 本次会话主要产出

- **Round 2 收口完成**：8 个通用专家全部落到 `main`，Round 2 不再是“等待中”。
- **Round 2.5 收口完成**：`experts/general/expert-writer.md`、`experts/general/prompt-engineer.md` 与专家索引刷新已落到 `main`。
- **Round 3 交付完成**：以下 10 个项目专家已在对应 issue 分支完成包装实现：
  - `experts/project/binance-trading.md`
  - `experts/project/xianyu-ops.md`
  - `experts/project/tieba-operation.md`
  - `experts/project/novel-reader.md`
  - `experts/project/game-automation.md`
  - `experts/project/ztc-optimizer.md`
  - `experts/project/chat-analysis.md`
  - `experts/project/qq-bot-audit.md`
  - `experts/project/douyin-content.md`
  - `experts/project/swarm-commander.md`
- **配套交付已落地**：`docs/round-3-plan.md`、`tools/ao-event-sink.mjs`、tmux/bootstrap 加固、stale slot/worktree 恢复修复、专家库索引刷新，已经把第 2 轮到第 3 轮之间的运维断点补齐。

### 当前仍在跟进的事

- 把 Round 3 的 10 个项目专家从当前实现分支/PR 整合回 `main`。
- 在 Round 3 主线整合后，再启动 Round 4 的自动发现与定期维护闭环。
- 继续把历史 incident 处理沉淀回 `TROUBLESHOOTING.md`，但不再把 ROADMAP 当 incident 日志使用。

### 历史基线

- `tmux 3.2a` segfault 已确认修复，详细根因与误诊链路保留在 `TROUBLESHOOTING.md` Issue 11。
- `ao session kill` 残留 worktree 的恢复路径已文档化并已有部分自动化修复，详情见 `TROUBLESHOOTING.md` Issue 12。
- 本文档从这一版开始以“轮次状态 + 当前交付 + 后续整合项”为主，不再保留旧的逐小时 incident 播报风格。

---

## 变更记录

- **2026-04-12 18:16** — 刷新当前状态快照：按用户指令将 Round 2、Round 2.5、Round 3 记为完成；补记本次 session 时间戳与主要交付；明确区分“已完成交付”和“尚待合并回 `main` 的 Round 3 整合项”
- **2026-04-11 22:10** — 初版，记录 Round 0 完成和 Round 1 阻塞状态
- **2026-04-11 23:20** — 定位 tmux 3.2a segfault 为根因并修复；Round 1 Part 1 首个 PR（#9 architect）完成；Round 1 Part 2 通过 CEO→PM 流程成功派发 4 个 worker，正在等待 PR；追加 TROUBLESHOOTING.md Issue 11 / 12 / 误诊链路
