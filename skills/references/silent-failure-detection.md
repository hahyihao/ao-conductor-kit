# Silent Failure Detection and State-Check Protocol

本文件是 `ao-conductor` 的权威 state-check protocol。
它定义 CEO / PM 在 zero-backlog doctrine 下如何识别静默失败、如何区分进行时与过去时、以及何时允许自愈。

## 1. 目标与边界

本协议要解决的是四类静默失败：

- dispatch 发出后实际上没有被目标 session 吃到
- dashboard 没有可见产物，但操作者误把 tmux / API / 进程存在当成成功
- 把过去时输出误判成正在工作
- 池已经空闲、且下一项工作已经在权威来源里明示存在，但系统没有继续推进

本协议的目标是 self-heal 这些失败，而不是重新引入隐藏 backlog。
禁止把调度状态放进私人 memo、cache、state file、脑内 todo 或“稍后再派”的暗账。

self-heal 只允许基于可观察、可核对、已授权的来源行动：

- 当前这次 dispatch 的目标 session / slot
- dashboard 可见的 session、summary、issue、branch、PR
- `ao status` 与 GitHub issue / PR 状态
- 当前运行明确指定的 canonical queue 或已存在的显式待办来源

如果下一步需要新的 scope 判断、优先级重排或产品决策，就停止自愈并向用户汇报，不要擅自脑补。

## 2. 权威观察通道

state-check 的权威顺序如下：

1. dashboard 可见状态
2. `ao status` 与 GitHub issue / PR 状态
3. tmux pane、pstree、raw API、进程树、底层日志

规则只有一条：dashboard 是“是否真的可观察地在跑 / 已交付”的裁决通道。
tmux、pstree、API 和 PID 只能用于诊断“为什么 dashboard 还没显示”，不能用来证明“其实已经成功”。

因此：

- 如果 dashboard 上 slot 为空、summary 为 null、没有 issue / PR 绑定，就不能对外宣称“已经在跑”
- 如果 dashboard 与 tmux / API 矛盾，先按 dashboard 记状态，再用诊断通道查原因
- 交付证明优先是 dashboard 可见产物与 GitHub 产物，不是后台还有进程活着

## 3. 信号语义：进行时 vs 过去时

所有巡检都必须把 present signal 和 past signal 分开匹配。
不要用一个混合 grep 把两者当成同一种“活跃”。

### 3.1 Present signals

以下信号表示当前 turn 仍在推进，可视为进行时：

- `Working (\\d+[smh])`
- `• Updated Plan`
- 以 `• Ran` 开头的进行时输出
- `• Exploring`
- `• Explored`
- dashboard activity 持续变化
- branch / PR / summary 在当前观察窗口内继续前进

### 3.2 Past signals

以下信号只表示前一个 turn 已完成，不表示当前仍在工作：

- `Worked for \\d+[smh]`
- `─ Worked for ─`
- 已完成的 reviewer 报告或静态总结，且没有新的进行时信号

### 3.3 判定规则

- 只看到 past signal，没有新的 present signal，就按 idle 处理
- `Worked for ...` 绝不能被解释成 “still in progress”
- dispatch 后既没有 present signal，也没有 dashboard 可见产物，优先怀疑 silent failure

## 4. Post-dispatch 10 秒验证

每一次 `ao send`、`ao batch-spawn`、以及同一 turn 内的连续 fan-out，都必须做一次 dispatch 后验证。

最小流程：

1. 发送后等待约 10 秒
2. 先看 dashboard，再看 `ao status` / GitHub 交叉核对
3. 确认每个目标至少出现一个 dashboard 可见产物：
   issue、branch、PR、summary、slot occupancy、activity 之一不再是空白 / null
4. 若未出现，视为“尚未验证成功”，立刻进入 self-heal

这条规则是强制的。
不能因为“消息已经显示 sent”“刚才终端没报错”“tmux 里看起来有进程”就跳过。

## 5. Self-Heal Protocol

### 5.1 Dispatch 未吃到或 F7 stuck

如果 dispatch 后没有 dashboard 可见 activity，且症状像 input buffer 未消费：

1. 先做一次短窗口复核，排除观察延迟
2. 发送 Enter / newline 或重发同一条 brief
3. 再等约 10 秒并重新验证
4. 连续失败或出现明确错误时，再向用户汇报 F1 / F7 类故障

在成功前，不要把状态写成“已派出”。

### 5.2 Dashboard 空白，但诊断通道显示“好像活着”

这种情况一律按“未被权威通道证实”处理。

- 可以打开 tmux pane、看 API、看进程树、看日志
- 但对外状态仍然是 “dashboard 尚未显示有效产物”
- 只有 dashboard 恢复可见，或出现明确错误，状态才算收敛

### 5.3 过去时误读

如果巡检只看到 `Worked for ...` 或其他 past signal：

- 立刻把该 slot / session 重新归类为 idle
- 不要继续等待它“自动往下跑”
- 需要后续动作时，按当前权威来源决定是 self-heal 还是进入下一项工作

### 5.4 池空闲且显式待办仍存在

如果相关池位全部 idle，并且“下一项工作”已经在当前运行的权威来源里明确存在，可以直接 pull 下一项，不必额外向用户追问。

允许的来源必须满足两个条件：

- 对当前运行是显式可见的
- 不依赖私人记忆或未落盘的暗账

可接受的例子是：当前批次明确指定的待处理项、当前会话已承认的 canonical queue、已存在的 issue / parked item / discovery item。
不可接受的例子是：“我记得还有 3 个 PM 没派”“270 秒后再想起来补发”“先写进隐藏状态文件”。

### 5.5 何时必须停止自愈并汇报

以下情况必须向用户汇报，而不是继续静默修：

- 已有真实交付或 merge-ready PR
- 出现明确 F1 / F7 / auth / infra error
- 重试窗口已经耗尽
- 下一步需要新的范围判断、优先级判断或产品决策

## 6. Zero-Backlog Coherence

zero-backlog 仍然成立，本协议不是回退到 backlog CEO。

必须同时满足下面四条：

- 不维护隐藏 backlog、memo、cache 或 state file
- wake-up 只用于重新观察、重试验证、或继续处理已显式存在的 canonical item
- self-heal 不制造新任务，只修复 dispatch / observation，或推进下一个已授权且可见的 item
- 如果没有可见的下一项，就如实报告“当前池 idle”，而不是脑补 pending work

这四条与 self-heal 不冲突。
真正被禁止的不是“继续推进”，而是“靠记忆或暗账推进”。
