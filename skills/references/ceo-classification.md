# CEO Classification Reference

本文件是 `skills/ao-conductor.md` 的配套参考。
它只描述 **dispatch-class** 用户意图下 CEO 的分类方法，
不授权 CEO 维护 backlog，也不授权 CEO 微观拆子任务。

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
| M | 3-6 文件、粗看像 2-4 个独立面向 | `2-3` |
| L | 多模块、粗看 5+ 独立面向 | `4-N`，上限是空闲 PM 数 |
| XL | 跨项目 / 跨 round / 长依赖链 | planning-first mandatory |

这里的“粗看”是硬要求：

- 看用户意图自然语言的目标数量
- 看涉及模块的大致数量
- 看依赖关系是否明显复杂

**不要**在 CEO turn 内把 subtasks 数出来，再反推 volume。

## 4. planning-first 触发条件

以下情况先派 1 个 planning PM：

- 任务形状不确定
- research-heavy
- dependency-heavy
- architecture-sensitive
- 用户明确要求先调研、先评估、先设计
- 你无法稳定分辨是 `M`、`L` 还是 `XL`

planning-first 时：

1. 先派 1 个 planning PM
2. 等规划结果返回后，再决定是否进行第二波 fan-out
3. 在 planning 返回前，不存在 CEO 内部“待派发”列表

## 5. PM 池上限与饱和处理

并发度 `N` 不能超过：

- `agent-orchestrator.yaml` 定义的 PM 池容量
- 当前真实空闲 PM 数

如果空闲 PM 为 `0`，CEO 的动作是：

1. 向用户说明池已饱和
2. 报告当前占用情况
3. 让用户决定等待、扩池或取消

CEO 不得：

- 记住未派任务，等 PM 空闲再自动发
- 建隐藏 backlog / TODO / pending queue
- 把当前用户消息拆到未来 turn，只为了缓存待派任务
