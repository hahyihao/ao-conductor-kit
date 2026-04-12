# Quality Feedback Loop

本文件定义 CEO quality feedback loop 的最小可执行协议。
如果当前 checked-in 的 `skills/ao-conductor.md` 尚未逐字覆盖这些规则，
则以本文件为准，用于指导 CEO / PM / worker / `skill-optimizer`
如何记录质量事件、判断根因所在层、以及把经验折返为可复用的改进。

它解决的不是“当前 PR 怎么修”这一件事，
而是“同类质量问题下一次如何更少发生”。

## 1. 目标与边界

quality feedback loop 的目标有四个：

- 把质量问题从一次性返工，变成可复用的组织记忆
- 区分当前交付缺陷与系统性 doctrine gap
- 明确应该修 doctrine、expert 文件，还是 CEO / PM / worker 流程
- 在 zero-backlog 约束下，把改进动作落到显式 artifact，而不是脑内经验

本协议关注的是 instruction-shaped quality 问题，包括：

- brief 写得不够自包含，导致 worker 猜测
- expert / reference / skill 缺规则，导致多个 session 重复踩坑
- CEO / PM / worker 本该执行某个已有流程，但本轮没有执行
- review、CI、用户反馈暴露出“当前做法无法稳定复现质量”

本协议不替代正常的实现修复。
当前 PR 的 bug、文案错误、测试失败，仍然先在当前 PR 里修；
quality feedback loop 负责判断是否还需要追加更深一层的防复发修补。

## 2. 四层质量观测模型

所有质量事件都先按四层模型观察。
规则是：先记“问题在哪一层被看到”，再判断“根因最深落在哪一层”。
不要一看到 bad output 就直接假设 doctrine 有问题。

### 2.1 第一层：结果层

这一层看用户最终拿到的结果是否正确、完整、可合并。

典型信号：

- 用户明确说“不符合要求”“漏了验收项”“方向错了”
- reviewer 判定有行为回归、风险遗漏、缺关键测试
- CI、静态检查、手动验收直接表明交付不成立

第一层回答的问题只有一个：
“这次交付到底好不好用、能不能接受？”

### 2.2 第二层：产物层

这一层看 issue、brief、PR、diff、测试、review comment、incident report
这些显式产物有没有把要求说清楚、做完整、记录充分。

典型信号：

- issue body 缺目标路径、约束、验收条件
- PR 描述不能解释改动为什么成立
- 没有自测记录，或测试名不能表达场景
- review comment 一再补充“本来 brief 就该写进去的事实”

第二层回答的问题是：
“交付链路上的 artifact 是否足够支撑正确执行与审阅？”

### 2.3 第三层：流程层

这一层看 CEO / PM / worker / reviewer 是否按应有流程工作。

典型信号：

- CEO 选错 Mode，导致本应直改的任务被过度 dispatch，或相反
- PM 没做 brief quality gate，就把半成品 issue 发给 worker
- worker 没有自审、没核对验收项、没响应 review comment
- reviewer 没先读 brief 和真实 diff，就给出结论

第三层回答的问题是：
“已有流程本来足够，但这次有没有被执行、被跳步、或被误用？”

### 2.4 第四层：教义层

这一层看 canonical doctrine 是否缺失、过时、互相矛盾，或者根本没有被落盘。

这里的 canonical artifact 包括：

- `skills/ao-conductor.md`
- `skills/references/*.md`
- `experts/**/*.md`
- 明确承担规则职责的模板或 SOP 文档

典型信号：

- 同类问题跨多个 issue / PR / worker 重复出现
- 不同 PM / worker 都做出“各自看起来合理”的不同决策
- live doctrine 明明在执行，但 repo 里没有对应权威文本
- review 结论稳定依赖口头补充，而不是现有文档

第四层回答的问题是：
“组织当前依赖的规则，是否真的被写成了稳定、可复用、可审计的文本？”

## 3. Loop 的工作方式

quality feedback loop 的最小闭环固定为六步：

1. 在四层模型里记录事件首次被观察到的位置。
2. 先处理当前交付：修 PR、补测试、补 brief、补 review comment，避免继续扩散。
3. 写一份 incident / event report，禁止只留在聊天记录或脑内总结。
4. 判断最深根因落点：是 artifact、流程、expert，还是 doctrine。
5. 选择最小但能防复发的 patch 目标，并明确 owner。
6. 在下一次同类任务中复核：同类问题是否真的减少，而不是只把文本写长。

判断时遵守两条规则：

- 先在浅层止血，再在深层防复发
- 永远 patch “最深的已证实根因”，不要因为 doctrine 最显眼就默认去改 doctrine

## 4. `skill-optimizer` 的触发条件

`skill-optimizer` 不是“任何质量问题都要叫一次”。
它只用于 instruction library 需要被系统性修补的场景。

满足以下任一条件时，应触发 `skill-optimizer`：

- 同一类错误在 2 次或以上独立 issue / PR / session 中重复出现，且不是同一个人手滑
- 当前 expert / reference / skill 缺少能直接阻断该错误的规则、检查项或模板
- review comment 已经指出“这不是实现细节，而是指导文本缺口”
- live 工作方式已经稳定存在，但 repo 内权威文档缺失或落后
- 多个 worker 按现有指令都做出了相似的错误输出，说明问题更像 prompt / doctrine drift，而不是个体执行失误
- CEO 或 PM 需要反复手写同一段补充说明，才能让 worker 正常完成任务

以下情况通常不触发 `skill-optimizer`：

- 当前 PR 的一次性实现 bug，修完即可结束
- 明确的环境、权限、网络、凭证故障
- 需要产品判断、范围裁剪、优先级重排，而不是 instruction 修补
- doctrine 已经写清楚，只是本轮没有按流程执行

简单判断标准：
如果你能把这次经验稳定改写成“未来每次都应默认遵守的一条规则”，
并且这条规则应进入技能库而不是只留在当前 PR，
那就应考虑触发 `skill-optimizer`。

## 5. Incident / Event Report 模板

所有 doctrine gap、expert drift、流程失效，都应至少留下下面这份模板。
它可以作为 issue comment、内部记录草稿、follow-up brief 起点，
但内容必须可被未来的 CEO / PM / worker 直接理解。

```md
# Quality Incident / Event Report

Date:
Reporter:
Observed by role: CEO | PM | worker | reviewer | user | CI

Issue / PR / Session:
Related files:
Stage: brief | implementation | self-review | review | CI | post-merge

Observed layer:
- Result layer | Artifact layer | Process layer | Doctrine layer

Symptom:
- 这次具体出了什么问题

User / delivery impact:
- 影响了什么验收、质量或节奏

Evidence:
- 链接、命令输出摘要、review comment、CI 失败点、具体文件路径

Expected behavior:
- 按当前期望，本来应该发生什么

Actual behavior:
- 实际发生了什么

Root-cause hypothesis:
- 当前判断最深根因位于哪一层
- 为什么不是更浅层、也为什么不是更深层

Immediate containment:
- 当前 PR / 当前 run 立刻要怎么止血

Prevention patch target:
- doctrine | expert file | CEO/PM process | worker process | artifact template

Proposed patch:
- 具体要新增、修改、或收紧什么规则 / 模板 / gate

Owner:
Due trigger:
- 什么后续动作算这个事件真正关闭

Validation on next run:
- 下一次如何确认它真的减少复发
```

使用要求：

- 不允许只写“已修复”，必须写出 expected vs actual
- 不允许只写“需要优化 prompt”，必须点名要 patch 的 artifact
- 如果根因尚不确定，可以写 hypothesis，但不能跳过 evidence

## 6. 如何决定 patch doctrine、expert 文件，还是流程

选择 patch 目标时，先问：
“如果当前团队成员都严格照现有文本做，问题还会不会发生？”

### 6.1 该 patch doctrine 的情况

满足以下任一情况时，优先 patch doctrine：

- 规则本身缺失，导致多个角色只能靠口头约定执行
- 这是跨 expert、跨流程都会用到的基础判断标准
- checked-in 文本落后于 live doctrine，已经造成认知漂移
- 同一个问题无法只靠单个 expert 文件解释清楚

典型动作：

- 更新 `skills/ao-conductor.md`
- 新增或修订 `skills/references/*.md`
- 收紧跨角色共用的 SOP / policy 文档

### 6.2 该 patch expert 文件的情况

当 doctrine 大方向正确，但某个 expert 的执行默认值不够时，patch expert 文件。

适用信号：

- 只有某一类 expert 经常漏同一项检查
- 根因是某角色的 admission rule、output contract、review gate 不完整
- 问题能在单个 expert 范围内被完整修掉，不需要上升到全局 doctrine

典型动作：

- 修改对应的 `experts/**/*.md`
- 补 expert 的 checklist、escalation rule、output format、validation rule

### 6.3 该 patch CEO / PM / worker 流程的情况

当规则已经存在，但执行链路没有照做时，优先修流程，不要滥改 doctrine。

适用信号：

- brief 明明有要求，worker 仍未核对
- expert 明明要求 self-review，但本轮被跳过
- CEO / PM 没做应有的 mode 判断、brief gate、review gate
- 这更像一次执行失误，而不是指导文本缺口

典型动作：

- 在当前 brief / PR / review 流中补 gate
- 要求补 self-review、补验收核对、补 review 证据
- 把本轮遗漏纳入后续 process checklist，而不是立刻扩写 doctrine

### 6.4 决策优先级

如果多个层都需要动，按下面顺序判断：

1. 当前 run 先止血，避免继续交付错误结果。
2. 选择最深、最稳定、最可复用的 patch 点做防复发。
3. 如果 doctrine 和 expert 都要改，先确认 expert 无法单独承接时再上升 doctrine。
4. 如果 doctrine 已经正确，禁止用“再写长一点 doctrine”代替流程执行。

一句话原则：
当前问题在哪一层被发现，不等于最终就该 patch 那一层；
最终 patch 点应是最深的、已被证实能减少复发的那一层。

## 7. 闭环完成的判定

quality feedback loop 只有在下面三件事同时成立时才算完成：

- 当前交付已经被修到可接受状态
- 防复发 patch 已落到显式 artifact，而不是停留在口头提醒
- 下一次同类任务里，相关角色能够在不依赖额外口头补充的情况下做对

如果只完成了前两条，第三条还没被验证，
状态应写成“patched, pending validation”，而不是宣称问题已根治。
