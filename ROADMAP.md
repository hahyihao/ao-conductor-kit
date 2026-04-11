# AO Conductor Kit — Roadmap

> 按 `ARCHITECTURE.md` §8 的 4 轮计划推进。
> 本文档是**活的**，每完成一项立刻勾掉，每发现新坑立刻记录。

---

## 当前状态（2026-04-11 23:20）

### ✅ 已完成

- **v0.1.0** (2026-04-11 cb8b436 之前)：母盘 v0.1，用 AO 自派 6 个 worker 写成的 6 个文件
- **v0.2.0** (commit `81aaa2d`, tag `v0.2.0`)：母盘打磨批次（LICENSE / VERSION / CHANGELOG / SECURITY / verify / PR templates / tools）— **CEO 越界批次**，后续批次不再允许
- **v0.3.0-round-0** (commit `cb8b436`, tag `v0.3.0-round-0`)：Round 0 完成
  - `experts/` 目录结构建立
  - `experts/general/task-splitter.md` 手写完成（284 行）
  - `experts/index.md` / `audit-log.md` / `discovery-queue.md` / `README.md`
  - `AGENTS.md` 和 `agent-orchestrator.yaml` 添加到 kit 根，commit `b52f52f`
- **v0.3.1-doctrine** (commit `57b6a0a`, tag `v0.3.1-doctrine`)：ARCHITECTURE.md + ROADMAP.md（本文件的上一版）
- **Round 1 Part 1**（2026-04-11 23:17）：
  - **PR #9** `feat(experts): add architect expert (Round 1)` — worker `kit-14` 完成
  - 分支 `feat/4`，文件 `experts/general/architect.md`
  - **这是整条 CEO→PM→Worker→PR 闭环的第一次端到端验证**

### ⏳ 进行中 — Round 1 Part 2（正常推进，非阻塞）

**目标**：其余 4 个基础设施专家

**当前派发**（通过 CEO→PM 模式，由 `kit-orchestrator-9` 发起）：
```
kit-15  feat/issue-5  working  ← issue #5  expert-scout.md
kit-16  feat/issue-6  working  ← issue #6  library-maintainer.md
kit-17  feat/issue-7  working  ← issue #7  env-ops.md
kit-18  feat/issue-8  working  ← issue #8  code-reviewer.md
```

预计 3-8 分钟内陆续开 PR。CEO 只监控 `ao status`，不干预。

### ⏸ 待办

- **Round 2**：8 个通用专家（`code-writer` / `script-writer` / `writer` / `test-engineer` / `debugger` / `security-auditor` / `refactorer` / `planner`）
- **Round 3**：10 个项目专家（包装用户现有 OMC skill）
- **Round 4+**：运行时自增长机制验证（expert-scout 自抓、library-maintainer 定期清理）

---

## 🔥 根因已找到并修复：tmux 3.2a segfault

本轮会话前 5 次 `ao start` 全部在几秒到几分钟后 orchestrator/worker 进程消失，看起来像是随机 "killed" / "exited"。花了几个小时在错的方向（tmux screen size / codex alt screen / AGENTS.md parser / WSL EPIPE），最终在 `dmesg` 里找到真因：

```
[  120.327861] tmux: server[232]: segfault at 0 ip 000055b4552b2d80
[  209.926840] tmux: server[739]: segfault at 0 ip 0000556416bb0d80
```

**Ubuntu 22.04 的 apt tmux 3.2a (`3.2a-4ubuntu0.2`) 有 NULL 指针 segfault bug**，在 detached tmux + codex TUI + 文件操作负载下必然崩溃。

### 修复动作（已执行）

1. 从源码编译 `tmux 3.5a`（装了 libevent-dev / ncurses-dev / bison）
2. `mv /usr/bin/tmux /usr/bin/tmux.3.2a.backup`
3. `ln -sf /usr/local/bin/tmux /usr/bin/tmux`
4. 清理所有残留 worktree 和 AO 状态
5. `ao start` 重跑 → orchestrator 和 worker 全部稳定存活

**详细修复步骤和误诊链路见 `TROUBLESHOOTING.md` Issue 11 + 误诊链路章节**。

### 需要回写到 bootstrap 的事

- `scripts/bootstrap-ao.sh` **必须**添加 tmux 源码编译步骤，不要依赖 apt 版本
- `scripts/verify-install.sh` **必须**检查 `tmux -V >= 3.3`
- `README.md` 明写"Ubuntu 22.04 的 apt tmux 不可用"

这些是 Round 1 完成后要派 worker 处理的第一个改动（写进 Round 2 开始前的待办）。

---

## 未解决的技术债（更新后）

| # | 问题 | 影响 | 优先级 | 状态 |
|---|---|---|---|---|
| 1 | tmux 3.2a segfault | ~~阻塞所有 codex TUI session~~ | 🔴 | ✅ **已修复**（源码 3.5a） |
| 2 | orchestrator prompt 里 PATH 有 Windows 路径污染 | 警告但不影响功能 | 🟡 | 未修，低优先 |
| 3 | WSL2 localhost forwarding 偶尔失效 | 代理/推送链路偶发断开 | ✅ | 已修复：`repair-wsl2-localhost-forwarding.ps1` 自愈修复 `portproxy` 漂移 |
| 4 | 旧 orchestrator session `[killed]` 残留在 ao status | 界面乱，不影响功能 | 🟢 | 未清，等 library-maintainer 类似机制处理 |
| 5 | `ao session kill` 不清 worktree (Issue 12) | 后续 spawn 冲突 | 🟠 | 已文档化，workaround 是手动 rm + git worktree prune |
| 6 | `bootstrap-ao.sh` 用 apt tmux | 新机器按 v0.2 脚本装会重复踩 Issue 11 | 🔴 | Round 1 完成后第一件要改的事 |

---

## 已记录的 CEO 例外（越界清单）

按规矩 CEO 不写代码。以下是已记录的例外，每条都有明确原因和清账计划：

1. **v0.2 打磨批次** (2026-04-11)：CEO 手写 LICENSE/VERSION/CHANGELOG/SECURITY/verify-install.sh/tools/*。**原因**：当时还没有 task-splitter 可用。**教训**：后续批次必须派 worker。
2. **Round 0 task-splitter.md** (2026-04-11)：CEO 手写 splitter 自己。**原因**：自举起点。**唯一性**：明确声明为"唯一一次"。
3. **v0.3.1 doctrine 文档**（ARCHITECTURE.md + ROADMAP.md）(2026-04-11)：CEO 手写。**原因**：元层级的 doctrine 必须由 CEO 维护。**规则**：这类文档本来就属于"CEO 允许直接写"的灰色地带。
4. **Round 1 Part 1 的 5 份 brief** (2026-04-11)：CEO 手写，作为 tmux segfault 绕行方案。**原因**：当时认为 PM 链路坏了，决定直派。**清账**：tmux 修好后，Round 1 Part 2 改走 PM 模式成功，证明只要修好基础设施就不需要再 CEO 越界。
5. **TROUBLESHOOTING.md 的 Issue 11 / 12 / 误诊链路追加** (2026-04-11)：CEO 手写。**原因**：刚调出的根因必须立刻记录防止遗忘，派 worker 去写反而丢细节。**规则**：troubleshooting 类"刚踩完的坑立即写"属于 CEO 允许范围。

---

## 下一次会话启动检查清单

如果会话重开或换 CEO：

1. 读 `ARCHITECTURE.md` 全文
2. 读 `ROADMAP.md` 看当前状态（就是本文件）
3. 读 `experts/general/task-splitter.md` 理解派发纪律
4. 读 `TROUBLESHOOTING.md` Issue 11 / 12 / 误诊链路（**极其重要**，否则会重复掉同一个坑）
5. `cd /root/projects/ao-conductor-kit && ao status` 看 orchestrator 状态
6. 验证 `tmux -V` 是 3.3+（如果是 3.2a 立刻按 Issue 11 修复）
7. 恢复到上次的 round 继续

---

## 变更记录

- **2026-04-11 22:10** — 初版，记录 Round 0 完成和 Round 1 阻塞状态
- **2026-04-11 23:20** — 定位 tmux 3.2a segfault 为根因并修复；Round 1 Part 1 首个 PR（#9 architect）完成；Round 1 Part 2 通过 CEO→PM 流程成功派发 4 个 worker，正在等待 PR；追加 TROUBLESHOOTING.md Issue 11 / 12 / 误诊链路
