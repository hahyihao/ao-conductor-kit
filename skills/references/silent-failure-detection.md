# Silent Failure Detection Under Zero-Backlog CEO

本文件描述 CEO 零 backlog doctrine 下的静默失败检测。
目标不是“自愈 CEO 手里的 backlog”，
而是尽快发现 fan-out 丢失、会话无响应、状态误读和 dashboard 假象。

## 0. 设计动机：为什么宁可重观察，也不靠记忆

零 backlog doctrine 的根基是：

- observation failure is loud
- memory failure is silent

如果 CEO 通过 `ao status`、`gh pr list`、tmux pane 重新观察现场，失败会表现为报错、超时、空白或状态矛盾；
这类失败是可见的，可以立刻触发修复。

如果 CEO 通过 backlog、memo、cache、state file 或“我记得还差一个 PM”来维持 dispatch 状态，
失败通常是静默的，往往要到用户追问或 reviewer 指出时才暴露。

因此本 doctrine 明确偏向反复重观察，且禁止任何把 dispatch 管理重新变成记忆问题的 cache / state file / memo 机制。

## 1. 零 backlog 下，检测目标变了

旧模型会试图回答：

- “CEO 是不是还有没派完的活？”
- “池空下来后要不要自动补派？”

新 doctrine 下，这两个问题都无效。
CEO 不持有 backlog，因此也没有 backlog 自愈。

新模型只回答：

- `ao send` 是否真的发出去了
- 目标 PM 是否真的进入工作态
- dashboard / PR / tmux 观测是否一致
- reviewer 报告是否回来了

## 2. Post-dispatch 10 秒验证必须保留

每一条 fan-out 都必须在 dispatch 后约 10 秒做一次确认。
这条规则在同一次 user message 收到后的当前 CEO turn 连续 fan-out 多个 PM 时更重要，而不是更弱。

最低要求：

1. 发送后等待短窗口
2. 重新观察 `ao status`、tmux pane 或其他现场信号
3. 确认目标 PM 出现新的进行时 activity、branch、PR 或上下文反应
4. 如果没有，立即强制 Enter、重发或显式修复

允许在首次 fan-out 之后跨 turn 修复补发，
但这属于对同一条 user message 派发结果的修复，不是“先记住以后再派”。

## 3. P1：grep 语义必须区分进行时和过去时

静默失败常见根因不是“没有输出”，而是“把错误输出当成正确信号”。
因此 grep / 日志判断必须区分：

- 进行时信号：正在编辑、正在实现、正在运行、正在调查
- 过去时信号：已完成、已修复、已推送、已合并

不要把历史完成语句当成当前 activity，
也不要把一次性结果行误判成持续进度。
如果现场工具支持多源观测，优先把进行时和过去时分开匹配，再做交叉核对。

## 4. P3：Dashboard authority 仍然成立

下列信号源的优先级高于 CEO 记忆和 worker 自述：

1. `ao status`
2. dashboard / session activity
3. `gh pr list`、`gh pr view`
4. tmux pane 现场输出

如果这些信号互相矛盾，先报告矛盾，再继续观察；
不要用“我记得它刚才应该已经发出去了”来覆盖现场事实。

## 5. 巡检时不再做 backlog 自愈

如果巡检发现 PM 池全部 idle：

- 正确动作：向用户汇报当前池空闲，等待下一条用户意图或 reviewer 报告
- 错误动作：从隐藏 backlog / TODO / pending queue 里补派任务

如果需要 wake-up，只能用于：

- 被动等待 reviewer 回报
- 定期重新观察现场状态

wake-up 不能承载：

- “等 PM 空了我再派”
- “270 秒后补发 backlog”
- “替 CEO 暂存未派任务”
