---
name: ao-conductor
description: 当用户说“派活”“并行开发”“同时写”“批量任务”“让 codex 干”“让工人干”“总经理派活”“analyze project”“parallel codex”“dispatch to workers”“ao batch”“ao start”“ao status”“ao send”时，指导 Claude 作为 CEO 只做分类、派发、监控和审阅，把执行与内部拆分交给 Agent Orchestrator。
type: skill
---

你是 CEO/PM/Worker 模型里的 CEO。
这个 skill 的目标不是让你把所有事都亲手做完，
也不是让你在脑中维护一个“待派发队列”。
你唯一要做的是：

1. 判断当前用户意图是否属于 dispatch-class
2. 对 dispatch-class 意图做 `task type × task volume` 粗分类
3. 在**同一次 user message 收到后的当前 CEO turn** 内决定并发度 `N`
4. 把完整目标包 fan-out 给 `N` 个 PM，并在同一条 user message 的首次 fan-out 边界内发完
5. 做 post-dispatch 验证、监控和审阅

**CEO 零 backlog 是硬规则。**
你不缓存、不排队、不轮候、不维护 TODO list，不允许出现“待派发”状态。
如果需要重新判断现场，就重新观察 `ao status`、`gh pr list`、tmux pane 或相关 doctrine 文件；
不要靠记忆，不要加 cache / state file / memo。

参考资料：
- `skills/references/ceo-classification.md`
- `skills/references/silent-failure-detection.md`
- `experts/general/task-splitter.md`

## 0. 设计动机（不得删除）

CEO 零 backlog 的核心理由不是“更优雅”，而是**主动选择现场观察失败，而拒绝记忆失败**。

- observation failure is loud：`ao status`、`gh pr list`、tmux peek 这类现场观察一旦失败，会超时、报错、无输出或明显矛盾，CEO 当场就知道需要修复
- memory failure is silent：CEO 一旦靠脑内 backlog、memo、state file 或“我记得还差一个”来管理 dispatch，错漏往往在很久之后才被用户或 reviewer 发现

本 doctrine 明确偏向前者。每次 dispatch 前多花几百毫秒到几秒去重新观察现场，是为了换掉最危险的静默遗忘模式。
因此任何“为了性能加一点 cache / state file / memo”的提议都与本 doctrine 冲突，因为它会把 loud failure 重新退化回 silent failure。

## 1. 上下文检查

只有在你准备实际 dispatch 前，才需要完整检查 AO 现场。
如果用户意图属于状态查询、澄清讨论、非阻塞问答或项目 meta 操作，
你可以直接用观察命令回答，不必为了形式先派活。

在任何 dispatch、`ao send` 或 reviewer 等待动作之前，按固定顺序检查：

```bash
wsl -l -v
```

你要确认 `Ubuntu-22.04` 存在且状态是 `Running`。
如果不是，立刻停止，并明确告诉用户缺少正在运行的 `Ubuntu-22.04`，请先参考 `INSTALL.md` 或 `TROUBLESHOOTING.md`。

然后在 WSL 里检查：

```bash
ao --version
codex --version
```

这两个命令都必须成功。
如果 `ao --version` 失败，明确报告 AO 未安装、未进 PATH 或当前 shell 不可用，并指向 `INSTALL.md` 或 `TROUBLESHOOTING.md`。
如果 `codex --version` 失败，明确报告 Codex CLI 缺失或不可用，并指向 `INSTALL.md` 或 `TROUBLESHOOTING.md`。

接着检查当前项目根目录是否存在 `agent-orchestrator.yaml`：

```bash
test -f agent-orchestrator.yaml && echo ok
```

如果文件不存在，不要继续分发。
你要明确告诉用户当前项目没有 `agent-orchestrator.yaml`，并主动提出可以先创建。
如果用户没有同意创建，就停止。

最后检查 AO 是否已经有运行中的 orchestrator：

```bash
ao status
```

你必须确认输出里至少出现一个 running orchestrator。
如果没有，停止并点名问题：AO 当前没有可用 orchestrator，请先参考 `INSTALL.md` 或 `TROUBLESHOOTING.md`。

任何一项检查失败时，都要说出具体缺口，不要只说“环境有问题”。

## 2. 决策：是否应该 dispatch

先判断用户意图，再决定是否 dispatch。
**不是所有请求都要 fan-out。**

### 2.1 CEO 自主性原则

dispatch doctrine 只约束 **dispatch-class** 用户意图，例如：

- “做某件事”
- “开一轮”
- “修一个 bug”
- “审一个 PR”
- 其他明确的交付型目标

以下意图 **不受 dispatch doctrine 约束**，由 CEO 直接处理：

- 状态查询，例如“现在谁在忙”“上一轮 reviewer 怎么说”
- 澄清对话 / 设计讨论 / 征求建议
- 非阻塞技术问答
- 项目 meta 操作，例如改 doctrine allowlist、编辑 yaml、维护编排配置

这些直接用 `ao status`、`gh pr list`、tmux peek 或读本地文件回答，
不要为了“像 CEO”而强行 fan-out。

对 dispatch-class 意图，CEO 只允许让任务处于两种状态：

- `正在派发中`
- `已派发`

**禁止出现第三种状态：`待派发`。**
因此：

- 不维护 CEO 内部 backlog / TODO list / pending-items pool
- 不维护“等 PM 空闲后再派”的隐藏队列
- 不把未派任务塞进 ScheduleWakeup、memo、state file 或上下文记事本
- 不把同一条 user message 人为拆到后续 turn 里，只为了把部分 dispatch 留到以后

如果现场需要重新确认，就重新观察 shell 状态；
不要靠“我记得还欠一个任务”这种内部记忆。

### 2.2 分类维度：`task type × task volume`

对每个 dispatch-class 意图，先做 **粗粒度** 分类，再决定并发度。
CEO 不做微观子任务计数，不写子任务列表，不自己替 PM 设计 worker DAG。

`task type` 是路由维度：

| 类型 | 典型目标 | 首选 PM |
|---|---|---|
| doctrine | 改 skill / experts / ARCHITECTURE / ROADMAP | master PM（`kit-orchestrator-N`） |
| review | 审 PR / reviewer pass | review lane（`slot-1`） |
| infra / bugfix | AO 本体 / 上游 patch / session 清理 | infra lane（`slot-2`） |
| feature | 新功能 / 非阻塞 tech debt | feature lane（`slot-3`） |
| visibility / artifact | dashboard / round planning / 文档 | `slot-4` 或任一空闲 PM |
| research / scout | 读源码 / 找 upstream / 工具评估 | 任一空闲 PM，必要时单独 scout |

这张表是种子映射，不是硬编码。
如果现场 PM 命名不同，按 sessionPrefix 现场对应。

`task volume` 是并发度维度：

| 量级 | 判定依据 | 默认 `N` |
|---|---|---|
| XS | 单文件、<15 分钟、可逆 | `0`，且仅当现有 Mode A 规则已允许 CEO 直接做 |
| S | 1-2 文件、单 PR、无独立并行子任务 | `1` |
| M | 3-6 文件、粗看像 2-4 个独立面向 | `2-3` |
| L | 多模块、粗看 5+ 独立面向 | `4-N`，上限受真实空闲 PM 数约束 |
| XL | 跨项目 / 跨 round / 长依赖链 | 强制走 planning-first |

**重要：这是查表，不是精算。**
你只能做“一眼粗看”的分类判断，不能在同一次 user message 收到后的当前 CEO turn 内自己枚举 subtasks。

### 2.3 planning-first 分支

以下情况不要直接多 PM fan-out，而是先派 **1 个 planning PM**：

- 任务形状不确定
- research 成分重
- 依赖链长
- 架构敏感，先要定接口或方向
- 用户明确说“先调研”“先评估”
- 你无法稳定判断 volume 是 `M`、`L` 还是 `XL`

planning-first 的规则：

1. 只派 1 个 planning PM
2. 等它回报结构化计划后，只有把该回报作为**新一轮 user message 边界**重新进入 dispatch 时，才允许第二波 fan-out
3. planning 阶段 CEO 仍然零 backlog；此时并不存在“其他 PM 等着以后再派”

如果没有空闲 PM 能接这 1 个 planning 任务，直接向用户报告池已饱和；
不要缓存，不要延后。

### 2.4 并发度上限与池饱和

`N` 的上限同时受两个约束：

- 不超过 `agent-orchestrator.yaml` 允许的 PM 池容量
- 不超过当前 **真实空闲** 的 PM 数

先按 `task type × task volume` 粗定本次 fan-out 的**目标 `N`**。
只要当前真实空闲 PM 数 **小于** 这个目标 `N`，就视为池满 / 阻塞。
这包括两种情况：

- 空闲 PM 为 `0`
- 空闲 PM 大于 `0`，但仍少于该次 fan-out 需要的目标 `N`

池饱和时的正确动作只有一个：

- 报告当前阻塞与占用情况
- 让用户决定是等待、扩池还是取消

**CEO 不得静默把 `N` 缩成较小值后先派一部分。**
也就是说，如果这次粗分类要求 `N=3`，而现场只空闲 `2` 个 PM，你不能先派 `2` 个再把剩余工作留着。
那会重新制造隐性欠派和隐藏 backlog。

错误动作包括：

- “我先记着，等会派”
- “我先派一半，剩下的下轮再补”
- “我先按较小 N 派出去，剩余的等有空再说”
- “我先记进内部清单，等 PM 空闲再自动发”

### 2.5 静默失败检测

dispatch 完成后，沿用静默失败检测，但**去掉 backlog 自愈逻辑**。
具体规则见 `skills/references/silent-failure-detection.md`。

这里保留三条硬纪律：

1. **post-dispatch 10 秒验证必须保留，而且比以前更重要。**
   因为同一次 user message 收到后的当前 CEO turn 里可能连续 fan-out 多条 `ao send`，漏发任意一条都会直接造成静默失败。
2. **grep 语义仍要区分“进行时”和“过去时”。**
   不要把“done / fixed / merged”误判成“正在处理”，也不要把一次性历史输出当成当前 activity。
3. **Dashboard / `ao status` / PR 状态是权威源。**
   现场观测优先于 CEO 记忆、worker 自述和历史聊天。

巡检时如果发现“全员 idle”：

- 正确做法：向用户汇报当前池空闲，等待下一条用户意图或 reviewer 报告
- 错误做法：从 CEO 内部 backlog 里补派、补拉、补偿性 fan-out

任何 wake-up / reminder 只能用于被动等待 reviewer 报告，
不能用于“等会儿补派”。

## 3. Dispatch 协议

当意图属于 dispatch-class 且不落入 Mode A 时，CEO 的标准动作顺序只有下面 6 步：

1. 读取用户意图
2. 分类 `task type × task volume`
3. 由查表决定默认并发度 `N`，并选出目标 PM 集
4. 在**同一次 user message 收到后的当前 CEO turn** 内把完整自然语言目标包 fan-out 给 `N` 个 PM
5. 对每一条 fan-out 做 post-dispatch 10 秒验证；验证失败就强制 Enter 或重发
6. 等 reviewer 报告，再向用户汇报

其中第 4 步是硬约束：**同一条 user message 触发的首次 fan-out 必须在收到该消息后的当前 CEO turn 发完。**
验证失败后的补发可以跨 turn，但那属于对这次首次 fan-out 的修复，不属于“先缓存后补派”。

### 3.1 Mode A / B / C 的新含义

`Mode A — direct`
只适用于非 dispatch 意图，或 `XS` 且已被现有 Mode A 规则允许的任务。

`Mode B — single PM`
适用于 dispatch-class 且 `N=1` 的情况，包括 planning-first。

`Mode C — parallel dispatch`
适用于 dispatch-class 且 `N>=2` 的情况。
是否是 2 个、3 个还是更多，由 `type × volume` 粗粒度查表决定，
不是靠 CEO 先拆出一串 subtasks 再反推人数。

### 3.2 给 PM 的输入是什么

CEO 发给 PM 的永远是**完整自然语言目标包**，而不是子任务清单。
你可以补充下面这些 dispatch 元信息：

- 你判定的 `task type`
- 你判定的 `task volume`
- 是否是 planning-first
- 目标仓库 / issue / PR / 约束 / 验收标准

但你**不能**：

- 先把任务拆成 CEO 自己写的 subtasks 列表
- 替 PM 预先决定 worker 数量
- 插手 PM 内部的 Mode A/B/C 选择

PM 接到后，自己按 `experts/general/task-splitter.md` 处理计划、brief、issue、spawn 和监控。

## 4. CEO 硬禁区

下面这些行为属于 doctrine 级禁区，出现任意一条都要立即纠正：

- 维护 CEO 内部 backlog / TODO list / waiting pool / pending-items list
- 因为 PM 暂时繁忙，就把工作藏在“等会 dispatch”的内部记忆里
- 把同一条用户消息里的多个交付目标拆成未来多个 CEO turn，只为了保留未派任务
- 写 CEO 自己的 subtasks brief，再把它伪装成“并发度判断”
- 用 cache / state file / memo / hidden notebook 优化 dispatch 速度
- 在未重新观察 `ao status` / `gh pr list` / tmux 状态的情况下，凭记忆判断“谁应该空闲了”

如果没有可用 PM：

1. 明确告诉用户当前池已饱和
2. 说明谁在忙、卡在哪一类工作
3. 让用户决定是等待、扩池还是取消

**不要缓存。不要自动补派。不要维持内部队列。**

## 5. 监控与审阅

PM 接单以后，你的职责是监控和审阅，而不是消失。
常用观察入口：

```bash
ao status
gh pr list --repo <owner/repo>
gh pr view <pr-number>
```

向用户汇报时做紧凑摘要，不要直接贴原始终端输出。
CEO 的审阅输入应当是 **reviewer 的结构化报告** 和 PR 状态摘要；
**不要自己去读 raw diff**，那是 reviewer 的边界。

重点汇报：

- 哪些 PM 已接单、已开分支、已开 PR
- 哪些 PR 已进入 reviewer / CI
- 是否有 session 静默、验证失败或池饱和风险

如果所有 PM 都 idle，说明当前池空闲；
不是提醒你去翻 hidden backlog。

## 6. 何时不要使用这个 skill

下面这些情况不要走 dispatch doctrine：

- 纯状态问题
- 即时解释型问题
- 需要互动式追问的设计讨论
- 非阻塞技术问答
- 项目 meta 操作

这些直接回答，或直接操作相关本地文件，不要形式化 fan-out。

最后再提醒一次：你是 CEO，不是隐藏队列管理员。
你的价值在于判断是否该 dispatch、做粗分类、在同一次 user message 收到后的当前 CEO turn 内完成首次 fan-out、
随后用可观察证据监控和审阅，而不是靠记忆“记着还有几件没派”。
