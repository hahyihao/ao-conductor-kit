# PM Lifecycle Protocol

本文件定义 CEO / PM / worker 模型里 PM 的生命周期、替换条件与交接协议。
目标只有一个：当某条 lane 需要更换 PM、跨电脑迁移、跨 session 接管时，系统仍然只沿着一条明确的执行线推进，不丢状态、不丢 ownership、不发生重复 dispatch。

## 1. 生命周期状态

每条 lane 的 PM 只允许处于以下五种状态之一：

- `active`：当前 PM 正在负责该 lane，拥有调度、跟进、审阅与汇报职责。
- `handoff-pending`：已经确认要交接，但旧 PM 还没有完成 freeze 和状态快照。
- `reconciling`：新 PM 已接手，正在核对 issue、branch、PR、worker、CI 与 dashboard 状态。
- `replaced`：旧 PM 已退出该 lane 的控制面，只保留只读历史，不再继续 dispatch。
- `closed`：该 lane 已交付、合并、取消，或被 CEO 明确归档，不再需要 live PM。

规则只有一条：一条 lane 在任一时刻只能有一个 `active` PM。
如果状态不清楚，就按“不能继续 dispatch”处理，先进入 `handoff-pending` 或 `reconciling`。

## 2. 角色边界与不变量

- CEO 负责 scope、优先级、lane 划分、PM 任命与 PM 替换裁决。
- PM 负责单条 lane 的执行推进：拆分、派工、验收、跟进、汇报、去重。
- worker 负责具体 issue / branch / PR 上的生产工作，不负责改写 lane ownership。
- 一条 lane 的 canonical state 必须落在可观察载体上：repo 文件、brief、GitHub issue / PR / comment、AO dashboard、`ao status`、CI 状态。
- 任何 PM 交接都不能依赖私人 memo、脑内待办、剪贴板、tmux 暂存画面或“我记得之前做到哪了”。
- 旧 PM 在未完成交接前不能把 lane 悄悄丢给新 PM；新 PM 在未完成 reconciliation 前不能假设自己已经理解全部上下文。

## 3. PM 交接 / 替换触发条件

以下情况触发 PM handoff 或 replacement：

- PM 所在 session 已死、失联、长期 idle，且该 lane 因此失去推进能力。
- PM 所在电脑、WSL、shell、认证环境或网络条件不可继续使用，需要换机器或换 session 才能推进。
- PM 已失去对 canonical state 的可靠观察能力，无法确认 issue、branch、PR、worker 的真实状态。
- 同一条 lane 出现 ownership 冲突，或已经发生“两个 PM 同时认为自己在负责”的风险。
- lane 被 CEO 重切边界，需要把它从旧 PM 的责任域迁到另一个 PM。
- 旧 PM 明确表示自己不能继续持有该 lane，且 CEO 接受替换。
- 用户或 CEO 明确下令“接管这个 lane / 接管这个 PR / 接管这个 session”。

以下情况通常不构成 PM replacement trigger：

- 只是某个 worker 卡住，但 PM 仍然在线、上下文完整、可以继续调度。
- 只是 CI 失败、PR 需要 review、或 brief 需要补充，但 lane ownership 仍清楚。
- 只是短时间无新输出，但 dashboard、`ao status`、GitHub 状态仍然连贯可追。

## 4. 什么时候替换 PM，什么时候保留 PM

应当保留当前 PM 的情况：

- 当前 PM 仍是该 lane 上下文最完整的人。
- 现有 issue、branch、PR、worker 映射关系清楚，没有 ownership 冲突。
- 问题属于 worker 执行层、CI 层或单次 dispatch 层，而不是 PM 控制面丢失。
- 当前 PM 还能基于可观察 state 继续推进，不需要跨环境迁移。

应当替换当前 PM 的情况：

- 继续保留旧 PM 会让 lane 停摆，或显著增加状态丢失风险。
- 旧 PM 已无法可靠访问当前环境、session 或凭据。
- 新 PM 更接近当前 canonical state，旧 PM 已经不再是最低摩擦的控制点。
- 不替换会造成重复派工、重复 PR、重复 issue、重复 review。
- lane 需要在另一台电脑、另一个 session、另一个运行中的 orchestrator 上继续执行。

判断标准不是“谁更忙”或“谁更想接”，而是：

- 谁能最稳定地观察 canonical state
- 谁能最少损耗地延续现有执行线
- 谁能在不制造重复工作的前提下继续推进

## 5. 六步 PM 替换流程

### Step 1. Freeze lane

先冻结 lane，禁止新旧 PM 并行 dispatch。
需要明确写出：

- 当前哪条 lane 进入 handoff
- 旧 PM 从这一刻起停止新增派工
- 现有 worker 先保持原状，不因为交接就盲目重启

如果 freeze 做不到，就不能进入下一步，因为这意味着 duplicate execution 风险仍在。

### Step 2. Snapshot canonical state

旧 PM 或接管方先收集最小运行快照：

- lane 目标与当前 scope
- 已存在的 brief、issue、branch、PR、review、CI 状态
- 已知 active worker、idle worker、失败 worker
- 当前 blocker、最后一个已完成动作、下一个明确动作

快照必须来自可核对来源，而不是记忆。
如果某条信息不能被 repo / GitHub / dashboard / `ao status` 证实，就标成 unknown，不要脑补。

### Step 3. Assign the new PM and cut ownership

CEO 明确指定新 PM，并切清 ownership：

- 新 PM 从哪一刻开始拥有该 lane
- 旧 PM 从哪一刻起只读
- 哪些 issue / branch / PR 继续沿用，不重建
- 哪些事项不在这次接管范围内

这一刀必须切干净。
旧 PM 不能在交接后继续“顺手补发几条”，新 PM 也不能顺手接走相邻 lane。

### Step 4. Reconcile execution state

新 PM 先做 reconciliation，再决定是否需要补动作：

- 看 dashboard 是否仍有 live session / live worker
- 看 `ao status`、issue、PR、CI 是否与快照一致
- 确认哪些 dispatch 已被真正吃到，哪些只是看起来发出去了
- 确认是否已经存在进行中的 branch / PR，避免重复创建

只要 reconciliation 还没完成，就不要新开第二条执行线。

### Step 5. Reissue only the missing control actions

新 PM 只补“控制面缺失动作”，不重做已有产物。
允许补发的内容通常只有：

- 原本没被 worker 吃到的 dispatch
- 缺失的 review / merge / CI 跟进
- 因 session 死亡而中断的明确下一步

不允许为了“保险”再建一套 issue、再开一条 branch、再起一个平行 PR。
如果是否重复无法判断，继续停在 reconciliation，而不是冒险重发。

### Step 6. Resume and announce the new operating line

新 PM 恢复 lane 推进时，必须明确对外宣布：

- 现在谁是这条 lane 的 active PM
- 当前保留了哪些 issue / branch / PR / worker
- 当前取消、归档或忽略了哪些旧状态
- 接下来唯一有效的下一步是什么

只有做到这一步，replacement 才算完成，lane 才从 `reconciling` 回到 `active`。

## 6. 跨电脑 / 跨 session 迁移规则

跨电脑、跨 WSL、跨 shell、跨 session 的 PM 迁移，一律按 replacement 处理，不按“无缝继续”处理。

- 新环境必须重新验证 AO、Git、GitHub、orchestrator、dashboard、repo 路径都可用。
- 不得假设旧机器上的 tmux pane、shell 历史、环境变量、代理、未提交终端状态还能继承。
- 迁移的单位是 lane，不是“把所有正在做的事一起端过去”。
- 优先复用已有 issue、branch、PR、brief；不要因为换机器就重建工单体系。
- 如果是在已有 PR 上继续工作，新 PM 应直接延续该 PR 的执行线，而不是另开替代 PR。
- 如果旧 session 仍活着但控制权要切换，必须先 freeze，再接管；不能两个 session 同时向同一 lane 发指令。

跨 session 接管时，最低限度要重新确认：

- 当前主 issue 是哪个
- 当前主 branch / PR 是哪个
- 当前 active worker 是否还在跑
- 当前 CI / review / merge 卡在哪一步
- 下一步是否已经明确，还是需要 CEO 重新裁决

## 7. 交接时必须保留的状态、ownership 与反重复边界

### 7.1 必须保留的执行状态

交接不能丢以下信息：

- lane 的目标、范围、验收口径
- 当前 canonical brief / issue / PR
- 最新 branch 名称与代码落点
- review 结论、CI 结果、已知 blocker
- 最后一个已完成动作与下一个明确动作

如果这些信息缺失，新的 PM 不能靠猜测恢复；要么补观察，要么向 CEO 升级。

### 7.2 必须切清的 ownership

- 每条 lane 只有一个 active PM。
- 每个 issue / PR 必须能说清现在由哪个 PM 跟进。
- 每个 worker 必须能说清自己服务的是哪条 lane、哪个 issue、哪条 branch。
- 旧 PM 在被替换后不再拥有该 lane 的调度权，除非 CEO 再次明确指派。

### 7.3 反重复边界

交接期间必须显式守住以下边界：

- 不为同一目标重复创建 issue。
- 不为同一实现线重复创建 branch。
- 不为同一交付物重复创建 PR。
- 不在未确认旧 worker 已失效前，给同一 brief 再派一个平行 worker。
- 不把“我不确定旧状态还活不活”当成重复派工的理由。

原则很简单：先确认现有执行线是否还能延续，再决定是否补新的控制动作。
只要旧线还能延续，就不重建。

## 8. 最小交接包

任何 PM handoff 至少要交出下面这份最小包，缺一项就说明交接还没完成：

- lane 名称与目标
- 当前 active / parked / blocked 状态
- canonical brief、issue、branch、PR 链接或编号
- 当前 worker 映射
- 当前 blocker
- 下一步唯一有效动作
- 明确的 `do not duplicate` 边界

如果这份最小交接包写不出来，说明系统还没有准备好替换 PM。
先补状态，再谈接管。
