# AO Conductor Kit — Roadmap

> 按 `ARCHITECTURE.md` §8 的 4 轮计划推进。
> 本文档是**活的**，每完成一项立刻勾掉，每发现新坑立刻记录。

---

## 当前状态（2026-04-11 22:10）

### ✅ 已完成

- **v0.1.0** (2026-04-11 cb8b436 之前)：母盘 v0.1，用 AO 自派 6 个 worker 写成的 6 个文件
- **v0.2.0** (commit `81aaa2d`, tag `v0.2.0`)：母盘打磨批次（LICENSE / VERSION / CHANGELOG / SECURITY / verify / PR templates / tools）— **CEO 越界批次**，后续批次不再允许
- **v0.3.0-round-0** (commit `cb8b436`, tag `v0.3.0-round-0`)：Round 0 完成
  - `experts/` 目录结构建立
  - `experts/general/task-splitter.md` 手写完成（284 行）
  - `experts/index.md` / `audit-log.md` / `discovery-queue.md` / `README.md`
  - `AGENTS.md` 和 `agent-orchestrator.yaml` 添加到 kit 根，commit `b52f52f`

### ⏳ 进行中 — Round 1（阻塞）

**目标**：建 5 个基础设施专家：`architect` / `expert-scout` / `library-maintainer` / `env-ops` / `code-reviewer`

**阻塞**：
- Orchestrator tmux+codex 在 kit 项目里频繁死亡（详见 `ARCHITECTURE.md` §10.1）
- 5 次 `ao start` 全部在几秒到几分钟后 codex 进程消失
- 无法通过 task-splitter 完成派发

**绕行**：
- CEO 暂时**直接 `ao batch-spawn`**（跳过 splitter），把 task-splitter.md 的四件套规则当作 brief 编写的模板
- CEO 直接写 5 份 brief 到 `briefs/`
- 直接 `gh issue create` 建 5 个 issue
- 直接 `ao batch-spawn` 起 5 个 worker（worker 类型还能跑，因为上次 6 路成功过）
- 这是**记录在案的 CEO 例外**，不作为常态

**下一步（即将执行）**：
1. 关掉当前所有 orchestrator 相关进程（确认全死）
2. CEO 直接写 5 份 brief 到 `/root/projects/ao-conductor-kit/briefs/`
3. `gh issue create` 建 5 个 issue
4. `ao batch-spawn` 起 5 个 worker
5. 监控 + 审 PR

### ⏸ 待办

- **Round 2**：8 个通用专家（`code-writer` / `script-writer` / `writer` / `test-engineer` / `debugger` / `security-auditor` / `refactorer` / `planner`）
- **Round 3**：10 个项目专家（包装用户现有 OMC skill）
- **Round 4+**：运行时自增长机制验证（expert-scout 自抓、library-maintainer 定期清理）

---

## 未解决的技术债

| # | 问题 | 影响 | 优先级 |
|---|---|---|---|
| 1 | tmux+codex 在 ao-kit 项目里频繁死亡 | 阻塞 task-splitter 自动派发，只能 CEO 直派 | 🔴 高 |
| 2 | orchestrator prompt 里 PATH 有 Windows 路径污染 | 可能触发 codex 死亡 | 🟠 中 |
| 3 | WSL2 localhost forwarding 卡住 | 需要 netsh portproxy workaround | 🟡 低（已绕行） |
| 4 | 旧 orchestrator session `[killed]` 残留在 ao status | 界面乱，不影响功能 | 🟢 低 |

---

## 已记录的 CEO 例外（越界清单）

按规矩 CEO 不写代码。以下是已记录的例外：

1. **v0.2 打磨批次** (2026-04-11)：CEO 手写 LICENSE/VERSION/CHANGELOG/SECURITY/verify-install.sh/tools/*。 **原因**：当时还没有 task-splitter 可用。**教训**：后续批次必须派 worker。
2. **Round 0 task-splitter.md** (2026-04-11)：CEO 手写 splitter 自己。**原因**：自举起点，没有 splitter 就没法建 splitter。**唯一性**：明确声明为"唯一一次"。
3. **Round 1 临时直派**（进行中）：因 §1 的 tmux 阻塞，CEO 暂代 splitter 写 5 份 brief + 直接 batch-spawn。**原因**：基础设施问题绕行。**清账计划**：Round 2 开始前必须解决 §1 问题或改走 claude-code orchestrator。

---

## 下一次会话启动检查清单

如果会话重开或换 CEO：

1. 读 `ARCHITECTURE.md` 全文
2. 读 `ROADMAP.md` 看当前状态
3. 读 `experts/general/task-splitter.md` 理解派发纪律
4. `cd /root/projects/ao-conductor-kit && ao status` 看 orchestrator 状态
5. 查 §"未解决的技术债" §10.1 是否已修
6. 恢复到上次的 round 继续

---

## 变更记录

- **2026-04-11 22:10** — 初版，记录 Round 0 完成和 Round 1 阻塞状态。作者：CEO（本次 Claude 会话）。
