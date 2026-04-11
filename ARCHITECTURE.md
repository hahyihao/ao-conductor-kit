# AO Conductor Kit — Architecture Doctrine

> 本文档是 2026-04-11 会话里讨论出的**最终角色架构与专家系统**。
> 所有 round 的派活、所有新专家的创建、所有流程优化，都必须以本文档为准。
> 本文档是**活的** — 每次用户纠正或新共识都必须回写进来。

---

## 1. 10 个角色

AO Conductor Kit 的运行时由 10 个角色组成。每个角色有严格边界，**不得跨越**。

| # | 角色 | 身份 | 物理形态 | 能做什么 | 绝不做什么 |
|---|---|---|---|---|---|
| 1 | **User** | 真人 | - | 给目标、审批、打断、纠正 | 写 brief、写代码 |
| 2 | **CEO** | 当前 Claude Code 窗口 | 你现在用的这个 Claude 对话 | 读意图、发目标、读 reviewer 报告、向 user 汇报 | 写代码/脚本/文档、运行 git、改 config、读 PR diff |
| 3 | **Task-Splitter** | 拆任务专家 | 常驻 orchestrator session（tmux 里的 codex/claude） | 拆任务、写 plan doc、写 briefs、建 issue、spawn worker、监控 | 自己写代码 |
| 4 | **Architect** | 架构决策专家 | 按需 spawn 的 codex session | 选架构模式、定模块边界、写 ADR | 写实现代码 |
| 5 | **Expert-Scout** | 抓新专家的专家 | 按需 spawn | 网上搜权威资料、提炼纪律、写新 expert 文件、admit 入库 | 干本职之外的事 |
| 6 | **Library-Maintainer** | 专家库管理员 | 按需 spawn + 定时触发 | 入库即时检查、定期扫重复/过期、写合并/归档 PR、维护 index.md | 删文件（只能归档） |
| 7 | **Env-Ops** | 环境/git/config 运维 | 按需 spawn | git commit/push/merge/rebase、文件重组、config 编辑、netsh/ao 命令 | 写业务代码 |
| 8 | **Worker** (10 种类型) | 干活员工 | spawn-per-task，一次性 | 按自己的专家身份写代码/文档/脚本、commit、push、PR | 超出 brief 的工作 |
| 9 | **Reviewer** | PR 审阅专家 | spawn-per-PR | 读 PR diff、按专家纪律审、输出结构化报告 | 直接改代码 |
| 10 | **Lifecycle Worker** | 看门人 | WSL 后台常驻 node 进程 | 轮询 GitHub CI/review、把反馈塞回对应 worker、cleanup merged session | - |

---

## 2. CEO 的 4 动作清单

CEO 在任何一次交互中**只做这 4 件事**：

1. **读 User 意图** → 翻译成一段自然语言高层目标
2. **发给 Task-Splitter**：`ao send <splitter-session> "<目标>"`
3. **读 Reviewer 结构化报告**（不读原始 diff）
4. **向 User 汇报结论 + 下一步建议**

**CEO 被禁止的动作**：
- 写任何代码文件（>10 行）
- 写任何脚本（>50 行）
- 写任何文档（>100 行）
- 运行任何 git 命令（除应急救援）
- 改任何 config 文件
- 读任何 PR 的原始 diff（只读 reviewer 摘要）

**CEO 的 Mode A 例外**：
- 1-2 行 typo 修复：允许
- 纯解释任务：允许
- 紧急救援 git 状态：允许但必须记录到 `docs/ceo-exceptions.md`

---

## 3. 专家库架构

### 3.1 目录结构

```
experts/
├── general/       # 通用领域专家
├── project/       # 项目特定专家
├── language/      # 语言特定专家
├── tool/          # 工具/库特定专家
├── index.md       # 自动维护的索引（library-maintainer 负责）
├── audit-log.md   # append-only 审计日志
├── discovery-queue.md  # expert-scout 的待抓取队列
└── README.md      # 库的教条与规则
```

### 3.2 4 个分类说明

| 分类 | 何时用 | 示例 |
|---|---|---|
| **general** | 跨项目、跨语言的通用角色 | code-writer, reviewer, debugger |
| **project** | 你的具体项目特有知识 | binance-trading, novel-reader, game-automation |
| **language** | 特定语言的最佳实践 | python-expert, lua-expert, bash-expert |
| **tool** | 特定库/框架/工具 | ccxt-expert, playwright-expert, ffmpeg-expert |

### 3.3 专家文件格式

```markdown
---
name: <kebab-case-id>
domain: general|project|language|tool
base-skill: <mature source reference>
external-sources:
  - <url>
project-extensions: []
discovered-on: YYYY-MM-DD
discovered-by: CEO|task-splitter|expert-scout|human
status: active|archived|draft
---

# <Name> Expert

This expert inherits from `<base-skill>`.

## 核心纪律（从 base 提炼的 5-15 条）
- ...

## 外部补充
- ...

## 不得跨越的边界
- ...
```

### 3.4 核心规则

1. **绝不原创内容**。所有专家必须引用一个成熟上游（OMC skill、官方文档、权威博客、RFC）。
2. **专家文件短**。frontmatter + 5-15 条核心纪律 + 链接。不写长文。
3. **append-only 精神**。淘汰走 `library-maintainer` 流程标记为 `archived`，不直接删。
4. **一个专家一个领域**。重叠走 maintainer 的合并流程。
5. **允许自动发现**。缺失专家由 `expert-scout` 自动抓取入库。maintainer 在入库时和定期时审计。

---

## 4. 自动发现机制（Expert-Scout 流程）

```
Task-Splitter 拆任务
    ↓
扫 experts/index.md 找匹配专家
    ↓
 有 ─────→ 读 expert 内容 → 注入 brief → 派活
    ↓
 缺
    ↓
在 experts/discovery-queue.md 记一行
    ↓
spawn expert-scout worker
    ↓
scout 网上搜权威资料
    ↓
scout 提炼 → 写 experts/<domain>/<name>.md → commit → PR
    ↓
library-maintainer 即时检查（frontmatter、重复、链接）
    ↓
merge 入库 → 更新 index.md
    ↓
task-splitter 重试原任务 → 这次能找到专家 → 正常派活
```

**user 确认**：新专家 auto-merge 入库，**由 maintainer 定期清理**，不需要人工逐一审核。

---

## 5. 10 种 Worker 类型与专家映射

| # | Worker 类型 | 注入专家 | OMC base skill |
|---|---|---|---|
| 1 | `write-code` | code-writer + 语言专家 | `executor` + 语言最佳实践 |
| 2 | `review-code` | code-reviewer + security-auditor | `code-reviewer` + `security-reviewer` |
| 3 | `refactor` | refactorer | `code-simplifier` + `ai-slop-cleaner` |
| 4 | `write-docs` | writer | `writer` + Divio 四分法 |
| 5 | `write-script` | script-writer + 语言专家 | `executor`(脚本模式) + shellcheck/PSScriptAnalyzer |
| 6 | `write-tests` | test-engineer | `test-engineer` + AAA/property-based |
| 7 | `debug` | debugger | `debugger` + `tracer` |
| 8 | `analysis-report` | scientist | `scientist` + `rigorous-reasoning` |
| 9 | `security-audit` | security-auditor | `security-reviewer` + OWASP |
| 10 | `plan` | planner + architect | `planner` + `architect` |

---

## 6. 专家注入机制

**不是**动态加载另一个 skill 文件（AO 不支持）。
**而是**：Task-Splitter 在生成 brief 时**把专家文件的内容直接拷进 brief body**。

```
brief body = 
    任务描述
  + 目标文件路径
  + 【注入：专家 X 的核心纪律】
  + 【注入：专家 Y 的核心纪律】（如有多个专家叠加）
  + Do / Don't 清单
  + Output constraint
  + commit message 格式
```

Worker 读 brief 就等于读了多个专家的"精神"，虽然它不知道这些来自 experts/ 目录。

---

## 7. 标准派发流程（11 阶段）

### CEO 侧只需要做 4 阶段（极简）

```
CEO.1  读 User 意图
CEO.2  翻译成自然语言目标 + ao send <splitter>
CEO.3  读 reviewer 结构化报告
CEO.4  向 User 汇报 + 建议下一步
```

### Splitter 侧内部完成 7 阶段

```
S.1  读 AGENTS.md + experts/general/task-splitter.md 刷新纪律
S.2  pre-dispatch checklist（环境/AO/gh/代理/git 状态）
S.3  判断 Mode A/B/C
S.4  必要时调用 architect 产出 ADR
S.5  扫 experts/ 找匹配，缺的派 scout
S.6  写 plan doc → briefs → issues
S.7  ao batch-spawn 并监控
```

---

## 8. 4 轮 Bootstrap 计划

### Round 0 — CEO 手写 task-splitter（一次性越界，仅此一次）
- **产出**：`experts/general/task-splitter.md`
- **状态**：✅ 已完成（commit `cb8b436`, tag `v0.3.0-round-0`）

### Round 1 — 建 5 个基础设施专家
- **方式**：通过 task-splitter 派 5 个并行 worker
- **产出**：
  1. `experts/general/architect.md` ← `oh-my-claudecode:architect`
  2. `experts/general/expert-scout.md` ← `document-specialist` + `external-context` + `tech-scout`
  3. `experts/general/library-maintainer.md` ← `verifier` + `simplify`
  4. `experts/general/env-ops.md` ← `git-master`
  5. `experts/general/code-reviewer.md` ← `code-reviewer` + `security-reviewer`
- **状态**：⏳ 当前卡在 tmux+codex 稳定性问题（见 §10）

### Round 2 — 建 8 个通用领域专家
- **方式**：task-splitter 派 8 个并行 worker
- **产出**：
  1. `code-writer.md` ← `executor`
  2. `script-writer.md` ← `executor` + shellcheck
  3. `writer.md` ← `writer`
  4. `test-engineer.md` ← `test-engineer`
  5. `debugger.md` ← `debugger` + `tracer`
  6. `security-auditor.md` ← `security-reviewer`
  7. `refactorer.md` ← `code-simplifier`
  8. `planner.md` ← `planner`
- **状态**：⏸ 等 Round 1 完成

### Round 3 — 建 10 个项目特定专家（包装现有 OMC skill）
- **方式**：task-splitter 派 10 个并行 worker
- **产出**（按用户的 OMC skill 清单）：
  1. `project/binance-trading.md`
  2. `project/xianyu-ops.md`
  3. `project/tieba-operation.md`
  4. `project/novel-reader.md`
  5. `project/game-automation.md`
  6. `project/ztc-optimizer.md`（合并 ztc-* 系列）
  7. `project/chat-analysis.md`
  8. `project/qq-bot-audit.md`
  9. `project/douyin-content.md`（合并 douyin-* 系列）
  10. `project/swarm-commander.md`（合并 `pc-init`）
- **状态**：⏸ 等 Round 2 完成
- **备注**：缺的项目专家按需在 Round 4 动态添加，不阻塞

### Round 4+ — 运行时自增长
- expert-scout 自动抓缺失专家
- library-maintainer 定期审计
- 用户说"清理"触发深度审计
- **状态**：⏸ 等 Round 1-3 完成

---

## 9. Phase 1-6 加速决策

用户确认的加速方案：

| 方案 | 状态 | 说明 |
|---|---|---|
| **方案 1 — 跳 Phase 5**（不做 ao status 预检查） | ✅ 采纳 | CEO 直接 dispatch，失败再处理 |
| **方案 2 — Phase 3+4 合并内联** | ✅ 采纳 | 一次性任务用 `gh issue create --body "..."` 内联 |
| **方案 3 — Brief 模板库** | ⏸ 待建 | Round 2 时建 `briefs/templates/*.template.md` |
| **方案 4 — PM 委托** | ✅ 采纳为默认 | CEO 只发自然语言给 splitter |

---

## 10. 已知阻塞与绕行

### 10.1 阻塞：tmux+codex 在 kit-orchestrator 里频繁死亡

**现象**（2026-04-11 会话中出现 5 次）：
- `ao start` 成功，orchestrator session 创建
- tmux session 短暂存活（可观察到 codex PID）
- 几秒到几分钟后，tmux 和 codex 进程消失
- `ao session ls -a` 显示 orchestrator 为 `[killed]`
- ao start 的 parent、dashboard、lifecycle-worker 都还活着

**已排除**：
- ❌ 不是 CEO 手误杀进程（第 5 次明确没运行 kill）
- ❌ 不是 yaml 配置错误（`runtime: tmux` 正确）
- ❌ 不是 AGENTS.md 缺失（第 5 次 AGENTS.md 在 worktree 里）
- ❌ 不是网络问题
- ❌ 不是 gh/codex 认证问题

**可能原因**（未验证）：
- tmux 的 terminal size 异常（每次出现 "131072x1 screen size is bogus"）
- WSL2 tmux 的 TTY 分配问题
- codex TUI 需要特定 terminal 能力
- 某个定时任务或 watchdog 误杀

**绕行方案**：**CEO 暂时直接 batch-spawn worker**，跳过 orchestrator 层。
- 这是 CEO 的一次例外（记录到 `docs/ceo-exceptions.md`）
- 等 Round 2+ 有 env-ops 和 reviewer 专家后，重新排查这个问题
- 或者换 orchestrator agent 从 codex 到 claude-code（yaml 修改）

---

## 11. 活文档规则

本文档是活的：
- 每次 Round 完成 → 更新 §8 的状态
- 每次发现新坑 → 加到 §10
- 每次 CEO 纠正 / user 新要求 → 更新对应章节
- 每次 expert 库结构调整 → 更新 §3
- 不删除，只追加或标记过时

**更新签名格式**：
```
## 变更记录
- 2026-04-11 初版（会话共识）
- 2026-04-12 ...
```

---

## 变更记录

- **2026-04-11** — 初版，基于当日会话的完整共识。作者：CEO（本次 Claude 会话）。参考了用户的多轮纠正和 OMC 现有 skill 清单。
