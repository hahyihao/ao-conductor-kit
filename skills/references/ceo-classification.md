# CEO Classification Reference

本文件是 `skills/ao-conductor.md` 的配套参考。
它只描述 **dispatch-class** 用户意图下 CEO 的分类方法，
不授权 CEO 维护 backlog，也不授权 CEO 微观拆子任务。

零 backlog 的设计动机同样适用于本文件：

- observation failure is loud
- memory failure is silent

因此 CEO 应优先重新观察 `ao status`、`gh pr list` 和现场 pane，
而不是靠记忆、memo 或缓存来维持 dispatch 状态。
AO Kit x Superpowers 的层级边界见 `skills/references/aokit-x-superpowers.md`。

## 1. 适用范围

dispatch-class 意图示例：

- 做某件交付型工作
- 开一轮执行
- 修一个 bug
- 审一个 PR
- 其他明确要产出结果的 delivery 目标

不适用本 doctrine、由 CEO 直接处理的意图：

- 状态查询
- 澄清 / 设计讨论 / 征求建议
- 非阻塞技术问答
- 项目 meta 操作，例如改 yaml 或维护 doctrine allowlist

## 2. 分类轴一：`task type`

| 类型 | 典型目标 | 首选 PM |
|---|---|---|
| doctrine | 改 skill / experts / ARCHITECTURE / ROADMAP | master PM（`kit-orchestrator-N`） |
| review | 审 PR / reviewer pass | review lane（`slot-1`） |
| infra / bugfix | AO 本体 / 上游 patch / session 清理 | infra lane（`slot-2`） |
| feature | 新功能 / 非阻塞 tech debt | feature lane（`slot-3`） |
| visibility / artifact | dashboard / round planning / 文档 | `slot-4` 或任一空闲 PM |
| research / scout | 读源码 / 找 upstream / 工具评估 | 任一空闲 PM，必要时单独 scout |

这是种子路由表，不是硬编码。
现场 PM 命名不同，就按 sessionPrefix 和当前空闲池做对应。

## 3. 分类轴二：`task volume`

| 量级 | 粗判标准 | 默认 `N` |
|---|---|---|
| XS | 单文件、<15 分钟、可逆 | `0`，且仅限现有 Mode A 规则已允许时 |
| S | 1-2 文件、单 PR、无独立并行面向 | `1` |
| M | 3-6 文件、粗看像 2-4 个独立面向 | 默认先 `1` 个 planning PM；有 approved `mini-spec` 后再 `2-3` |
| L | 多模块、粗看 5+ 独立面向 | 默认先 `1` 个 planning PM；有 approved `spec` 后再 `4-N` |
| XL | 跨项目 / 跨 round / 长依赖链 | planning-first mandatory，通常先产出完整 `spec` |

这里的“粗看”是硬要求：

- 看用户意图自然语言的目标数量
- 看涉及模块的大致数量
- 看依赖关系是否明显复杂

**不要**在同一次 user message 收到后的当前 CEO turn 内把 subtasks 数出来，再反推 volume。
如果当前用户消息已经带着 approved `mini-spec / spec draft` 或等价结构化计划，
`M/L` 才可以直接按 implementation fan-out 的 `N` 处理。

## 4. planning-first 触发条件

以下情况先派 1 个 planning PM：

- `task volume >= M` 且当前用户消息没有 approved `mini-spec / spec`
- 任务形状不确定
- research-heavy
- dependency-heavy
- architecture-sensitive
- 用户明确要求先调研、先评估、先设计
- 你无法稳定分辨是 `M`、`L` 还是 `XL`

planning-first 时：

1. 先派 1 个 planning PM，并要求它回报 `mini-spec / spec draft`
2. 只有当前用户消息已经带着 approved `mini-spec / spec` 时，才允许跳过 brainstorming gate
3. 等规划结果返回后，只有当该结果以**新一轮 user message 边界**重新进入 dispatch 时，才允许第二波 fan-out
4. 在 planning 返回前，不存在 CEO 内部“待派发”列表，也不存在“先记着，等下条 turn 再派”的缓存

## 5. PM 池上限与饱和处理

并发度 `N` 不能超过：

- `agent-orchestrator.yaml` 定义的 PM 池容量
- 当前真实空闲 PM 数

先按分类粗定本次 fan-out 的目标 `N`。
只要当前真实空闲 PM 数 **小于** 这个目标 `N`，不论差了多少，都按同一类池满 / 阻塞处理。

如果真实空闲 PM 数小于目标 `N`，CEO 的动作是：

1. 向用户说明池已饱和
2. 报告当前占用情况
3. 让用户决定等待、扩池或取消

CEO 不得：

- 静默把 `N` 降成更小值后先派一部分
- 记住未派任务，等 PM 空闲再自动发
- 建隐藏 backlog / TODO / pending queue
- 把当前 user message 的首次 fan-out 拆到未来 turn，只为了缓存待派任务
