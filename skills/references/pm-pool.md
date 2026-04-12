# PM Pool and Idle-Slot Dispatch Protocol

本文件是 `ao-conductor` 的 PM idle-pool / dispatch 权威参考。
它定义 CEO 如何面向一组可复用的 PM slot 做 bring-up、派发、释放、扩缩容和冲突阻断。

这里的 PM 指项目经理层，也就是可持续接收 CEO 指令、再把任务翻译成 issue / brief / worker 执行流的 orchestrator session。
如果一个项目只有一个 PM，也仍然适用本协议，只是 pool 容量为 1。

## 1. 定义与边界

### 1.1 PM pool 是什么

PM pool 是当前项目中全部可被观察、可被命名、可被复用的 PM slot 集合。
每个 slot 都必须有稳定身份，至少能稳定映射到下面这些实体：

- 一个 PM / orchestrator session
- 一个专属 worktree
- 一个稳定 branch 基线
- 一个 dashboard 可见槽位或等价的可观察状态
- 一条明确的 ownership 链

PM pool 管的是 PM 层 dispatch，不是 worker 实现细节。
本协议回答的是“把哪个任务交给哪个 PM slot，以及何时该停”，
不是“worker 具体怎么写代码”。

### 1.2 Slot 状态

每个 PM slot 只允许处于以下状态之一：

- `idle`
  可观察、健康、当前没有未释放的 assignment，可以接新任务。
- `assigned`
  已被某个 canonical item 占用，正在做 task translation / issue routing / worker orchestration。
- `blocked`
  当前链路遇到明确阻塞，尚未释放 ownership，不能接新任务。
- `draining`
  不再接收新任务，但正在把现有链路收尾到可释放状态。
- `offline`
  session 不健康、身份不明、dashboard 不可验证、或基础设施未就绪。

`unknown` 不是合法长期状态。
如果观察结果只有 `(unknown)`、空白 dashboard、或 session 身份对不上，
该 slot 只能按 `offline` 或 `blocked` 处理，不能继续 dispatch。

### 1.3 Canonical item

PM pool 只接受显式存在的 canonical item：

- 已写明边界的用户请求
- 已存在的 issue / PR / review thread
- 当前运行明确承认的 queue item
- 已落盘并被当前会话认可的 parked item

PM pool 不接受私人 memo、脑内 backlog、隐藏 state file 或“我记得还有一项”。
pool 可以拉取下一个显式 item，但不能凭记忆制造下一项。

## 2. Activation / Bring-Up Flow

每次启用 PM pool，都按固定顺序 bring up。
顺序错了，后面的 slot 判断和容量判断都会失真。

### 2.1 先判断是否值得进入 PM pool

只有 `Mode B` 或 `Mode C` 才进入 PM pool。

- `Mode A` 是单文件、单点、短平快修改，直接处理，不占 PM 容量。
- `Mode B` 是一个 PM 足够承接的中等任务。
- `Mode C` 是可以拆成多个自包含子任务的并行 dispatch。

如果任务根本不值得调度，就不要为了“保持层级结构”硬占一个 PM slot。

### 2.2 环境 bring-up

在看 pool 之前，先确认 dispatch 基础是健康的：

- WSL / shell 环境可用
- `ao` 可运行
- 需要时 `codex` 可运行
- `agent-orchestrator.yaml` 存在且当前项目指向正确
- runtime 仍是 `tmux`

最小检查通常至少包括：

```bash
ao status
test -f agent-orchestrator.yaml && echo ok
```

如果仓库采用 slot-based 运行形态，还要先确认 slot lifecycle 是健康的。
在 AO Conductor Kit 自己的多 slot 形态下，可用仓库 helper 恢复 slot lifecycle：

```bash
./tools/start-slot-lifecycle-workers.sh
```

这一步的目标不是“顺手修掉一切”，
而是确保你要观察的 PM slot 真的是同一组稳定实体。

### 2.3 建立 pool snapshot

pool snapshot 的权威顺序与 state-check 一致：

1. dashboard 可见状态
2. `ao status`
3. tmux / worktree / 进程等诊断通道

bring-up 时，必须把每个 slot 明确归类为 `idle`、`assigned`、`blocked`、`draining` 或 `offline`。
如果某个 slot 没法归类，不要乐观处理，直接按不可派发处理。

### 2.4 Canonical queue 检查

在分配 PM 之前，先确认“下一项工作”来自当前运行承认的 canonical source。
如果没有显式 item，就如实报告 pool idle。
不要因为 pool 空着，就发明一个 backlog 给它吃。

### 2.5 Post-dispatch 10 秒验证

每次把新任务送入 PM slot 后，
都必须按 `skills/references/silent-failure-detection.md` 做一次 10 秒验证：

1. 先看 dashboard
2. 再看 `ao status`
3. 确认目标 slot 至少出现一个可见产物
4. 如果没有，立刻 self-heal 或阻断

“message sent” 不是 assignment 成功。
只有可观察产物出现后，该 slot 才算真正进入 `assigned`。

## 3. Pool Parameters and Capacity Model

PM pool 的容量不是“有几个 tmux 窗口”，
而是“有几个健康、空闲、可安全接单的 PM slot”。

### 3.1 核心参数

| 参数                  | 含义                                        | 默认纪律                                         |
| --------------------- | ------------------------------------------- | ------------------------------------------------ |
| `slot_count`          | 已配置的 PM slot 总数                       | 只统计有稳定身份的 slot                          |
| `healthy_slots`       | 当前可观察且健康的 slot 数量                | `idle` + `assigned` + `draining`，不含 `offline` |
| `idle_slots`          | 当前能立刻接任务的 slot 数量                | 必须可观察且未持有 active ownership              |
| `assigned_slots`      | 已被 canonical item 占用的 slot 数量        | 一个 active dispatch chain 算 1                  |
| `blocked_slots`       | 有明确阻塞、尚未释放 ownership 的 slot 数量 | 不可继续派发                                     |
| `warm_spares`         | 预留出来的空闲余量                          | 多 slot 项目建议至少保留 1                       |
| `independent_batches` | 当前真的可以独立并发的批次数                | 只统计 brief 可自包含的批次                      |

### 3.2 有效容量

有效派发容量可以按下面的思路判断：

`effective_capacity = min(idle_slots - warm_spares, independent_batches)`

如果结果小于等于 0，当前就不该再扩派。

这里有三个硬原则：

- 一个 PM slot 可以管理多个 worker，但它仍然只算一个 `assigned` PM
- 不要把 worker 数量误当成 PM 容量
- 不要因为“还有 CPU / tmux 空位”就无视 brief 自包含和 ownership 边界

### 3.3 一次 assignment 的粒度

默认粒度是：

- 一个 PM slot 同一时刻只拥有一个 active dispatch chain
- 一个 dispatch chain 可以包含一个中等任务，或一组事先写清 independence 的批处理子任务
- 没有书面 independence proof 时，不允许把同一个 issue 在 PM 层拆成多条并行链

PM pool 的默认目标是稳，不是把每个 slot 都塞满。

## 4. Physical Implementation / Runtime Shape

一个健康的 PM slot，在物理上通常至少对应下面这些对象：

- `agent-orchestrator.yaml` 中一个稳定的 project entry，或等价配置实体
- 一个稳定 session name，例如 `<sessionPrefix>-orchestrator-<N>`
- 一个独立 worktree
- 一个不污染 `main` 的 branch 基线
- 一个可回看、可交叉核对的 dashboard / status presence

如果仓库采用 slot lane 结构，
每个 slot 还应有自己的 lane 或等价隔离基线。
PM slot 之间不能共享同一个可写 worktree，
也不能通过匿名临时 session 轮流冒充同一个 slot。

健康运行形态必须满足四条：

- 身份稳定：同一个 slot 的 session / worktree / branch 能对上
- 观察稳定：dashboard 和 `ao status` 能交叉核对
- 反馈稳定：CI / review / wake-up 能回到原链路
- 隔离稳定：一个 slot 出问题时，不会污染其它 slot 的 branch 或 ownership

如果以上任一条不成立，pool 先降级，再谈 dispatch。

## 5. Assign / Release Lifecycle

### 5.1 Assign

分配 PM slot 时按下面的顺序执行：

1. 先选健康，再选空闲，再选最匹配当前任务的 slot
2. 为该 slot 绑定一个明确的 canonical item 或一个事先写明边界的 batch
3. 给 PM 发送自包含指令，不允许依赖 CEO 私聊上下文、隐式 plan、或“看上文”
4. 执行 10 秒 state-check
5. 只有出现可观察 activity 后，才把 slot 标成 `assigned`

一个 assignment 成立后，该 PM slot 就拥有当前链路的调度 ownership。
后续 worker 生成、issue 映射、PR 追踪和异常回派，都应优先沿原链路返回。

### 5.2 In-flight 纪律

slot 处于 `assigned` 时，CEO 不应再把无关新任务塞进同一个 PM，
除非已经有书面化的 multiplexing 设计并证明不会混淆 ownership。

默认纪律仍然是：

- 一个 PM slot 一次只吃一条 active dispatch chain
- 同一 issue 不跨两个 PM slot 并发推进
- review / CI / follow-up 优先回到原 PM / 原 worker 链

### 5.3 Release

slot 只有在下面条件都成立时，才可以释放回 `idle`：

- 当前 dispatch chain 已达到可观察终态
- 不再存在未验证的 send / wake-up / self-heal 动作
- 还需要继续推进的工作已经变成显式 issue / comment / parked item，而不是 PM 脑内待办
- dashboard 和 `ao status` 不再显示该 slot 仍持有 active ownership

常见可释放场景包括：

- 当前批次已稳定生成 issue / PR / review 产物，且后续由原链路被动承接
- 当前项已明确阻塞，并已向 CEO / 用户升级，等待新决策
- 当前 queue 在权威来源里已经空了

如果只是“看起来暂时没消息”，但 ownership 还没收敛，就不能算 `idle`。

## 6. Scale-Up / Scale-Down

### 6.1 何时 scale up

只有在下面条件同时满足时，才应扩大 PM pool 使用量：

- 当前 canonical queue 里存在多个彼此独立的 item
- 这些 item 的 brief 可以写成 self-contained 文档
- 当前 `effective_capacity` 明确不足
- 扩派不会打破已有 ownership 或反馈链

scale up 的正确动作是启用额外的已配置 slot，
或按明确方案新增 slot 配置并先 bring up 到可观察状态。

错误动作包括：

- 用两个 PM slot 吃同一个 issue
- 让一个 PM 在未释放前兼做第二个不相关批次
- 让 implementer 自己再并发拆出隐藏子池

### 6.2 何时 scale down

当 queue 明显缩小、slot 长时间空闲、或基础设施需要收缩时，
应采用 drain-first 的 scale down：

1. 先把目标 slot 标成 `draining`
2. 停止向它分配新任务
3. 等现有链路到达可观察终态
4. 再把 slot 释放为 `idle` 或转为 `offline`

不要通过抢占、切断、或“反正暂时没动静就关掉”来做粗暴缩容。

### 6.3 故障恢复不等于 scale up

恢复挂掉的 slot，是 bring-up / repair，不是新增容量。
如果只是把 `offline` slot 恢复到原本应有状态，
不要把它误记成“多出一个新 PM”。

## 7. Hard Conflict Rules

下面任何一条命中，都必须阻断 dispatch：

- 没有健康且可观察的 `idle` slot
- 目标 slot 的 dashboard / `ao status` 状态对不上，或身份映射不清
- 当前任务不是 canonical item，只存在于记忆、memo 或隐藏 state 中
- brief 不能自包含，仍然依赖主对话、plan file 或“看上文”
- 同一个 issue / batch 已被另一个 PM slot 持有 ownership
- dispatch 会把一个单 issue implementer 工作强拆成未授权并行
- 目标 slot 仍有未释放的 active chain，却被要求中途切换到不相关任务
- reaction / feedback 链不完整，导致 CI、review 或 wake-up 无法回原链路
- slot worktree、branch 基线或 project 配置明显脏乱，无法证明隔离边界仍成立

这些不是“谨慎建议”，而是硬阻断条件。
命中后要么先修 bring-up / ownership / brief，
要么明确升级给 CEO / 用户做新决策。

## 8. Minimal Operating Checklist

每次使用 PM pool 前，至少快速过一遍下面这张清单：

- 当前任务确实属于 `Mode B` 或 `Mode C`
- canonical item 已写明，不靠脑补
- pool snapshot 已完成，slot 状态明确
- 目标 slot 当前是健康且可观察的 `idle`
- dispatch 指令是 self-contained 的
- 10 秒 state-check 已执行
- ownership、release 条件和反馈回路都清楚

PM pool 的目的不是“多开几个窗口”，
而是让 PM 层 dispatch 变成一个可观察、可扩缩、可阻断、可审计的系统。
只要 ownership 不清、状态不可见、或下一项并不显式存在，
宁可让 pool 保持 idle，也不要假装它还能安全吞下更多任务。
