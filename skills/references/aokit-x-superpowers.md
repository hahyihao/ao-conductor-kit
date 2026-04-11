# AO Kit x Superpowers Boundary

本文件是 AO Kit x Superpowers merger 的单一边界参考。
目标不是重写 PR #61，而是在不削弱零 backlog doctrine 的前提下，
把 Superpowers 的执行纪律叠加到 AO Kit 之上。

## 1. 分层总则

- AO Kit = infra + dispatch
- Superpowers = execution discipline

两者不是对等替换关系，而是上下层关系：

- AO Kit 负责 session / pool / dispatch / observation 规则
- Superpowers 负责 planning、实现、审阅、验证时的纪律和门禁

如果两者冲突，先保留 AO Kit 的 dispatch 硬约束，再叠加不会削弱它的最严格执行纪律。

## 2. AO Kit 负责什么

AO Kit 的 CEO 层硬约束包括：

- 零 backlog：不缓存、不排队、不维护隐藏 TODO
- same-user-message 首次 fan-out：首次 fan-out 必须在当前 CEO turn 发完
- classification-driven dispatch：先按 `task type x task volume` 粗分类，再决定当轮 fan-out
- pool-saturation blocking：目标 `N` 大于真实空闲 PM 数时，报告阻塞，不做 partial dispatch
- observation over memory：以 `ao status`、dashboard、PR 状态和 doctrine 文件为准，不靠记忆

这些规则是底板，Superpowers 不能把它们改回 backlog / queue / deferred dispatch。

## 3. Superpowers 负责什么

Superpowers 只增加执行纪律：

- `task volume >= M` 且没有 approved `mini-spec / spec` 时，默认先走 brainstorming / planning-first
- implementer brief 必须过质量门，并遵守 no-plan-pointer、TDD、sequential-within-one-PM 等规则
- 每个 PR 都要先过 `spec-compliance`，再过 `code-quality`
- reviewer 通过后，还要跑独立 verifier worker 的 Gate Function
- rework 后不得跳过 re-review 或最终验证

Superpowers 不负责改写 AO Kit 的池管理、turn 边界或 backlog 模型。

## 4. CEO / PM / Worker 边界

### CEO layer

AO Kit 规则：

- 判断是否属于 dispatch-class
- 在当前 turn 内完成首次 fan-out
- 不持有 backlog，不做 partial dispatch
- 不直接读 raw diff，不直接跑 tests / build

Superpowers 增量：

- `M/L/XL` 默认先派 planning PM 产出 `mini-spec / spec`
- 审阅顺序固定为 `spec-compliance -> code-quality`
- 两阶段 reviewer 都通过后，再派 verifier worker 跑 Gate Function

### PM layer

AO Kit 规则：

- 写 plan doc、brief、issue、spawn、monitor
- 只从显式 CEO dispatch 开始，不在 idle 时自拉任务

Superpowers 增量：

- brief 质量门
- implementer sequential only within one PM
- TDD required
- Gate Function evidence bundle required before review
- re-review after rework may not be skipped

### Worker layer

Implementer：

- 按 brief / `mini-spec / spec` 实现
- 先做 failing check，再实现，再给 green evidence
- 不能用“见 plan 文件”代替自包含 brief

Reviewer：

- 先做 `spec-compliance`
- 再做 `code-quality`
- 只报告结构化结论，不把 CEO 拉回 raw diff

Verifier：

- 在 reviewer approval 之后独立执行 Gate Function
- 报告命令、exit code、evidence 和 artifact 路径
- 不替代 reviewer，也不替代 CEO

## 5. 冲突解决

1. 如果某条 Superpowers 习惯会制造 CEO backlog、隐藏队列或 deferred fan-out，AO Kit 胜出。
2. 如果执行纪律要求 raw diff review 或 test execution，交给 reviewer / verifier，不能回流到 CEO 亲自做。
3. 如果 implementation fan-out 需要的 `N` 超过真实空闲 PM 数，报告池饱和；不要把 Superpowers 的 planning 纪律误用成 partial dispatch 借口。
4. 如果文档之间出现灰区，按这个顺序取最严格规则：PR #61 零 backlog 硬约束 -> same-user-message 首次 fan-out -> pool saturation blocking -> Superpowers execution discipline。
