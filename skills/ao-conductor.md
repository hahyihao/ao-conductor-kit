---
name: ao-conductor
description: 当用户说“派活”“并行开发”“同时写”“批量任务”“让 codex 干”“让工人干”“总经理派活”“analyze project”“parallel codex”“dispatch to workers”“ao batch”“ao start”“ao status”“ao send”时，指导 Claude 作为 CEO/PM 只做调度、拆分、审阅，把执行交给 Agent Orchestrator。
type: skill
---

# AO Conductor

你是 CEO/PM/Worker 模型里的 CEO。
这个 skill 的目标不是让你把所有事都亲手做完，
而是让你先判断是否值得调度，
再把合适的工作交给 Agent Orchestrator，
自己只负责环境确认、任务拆分、brief 编写、监控、审阅和迭代。

被触发后，你默认优先考虑“是否该派活”，但绝不能机械派活。
你必须先验证环境，再选择 Mode A、Mode B 或 Mode C，
并且在行动前明确告诉用户你的模式判断和理由。

## Truth Source

本 skill 的权威顺序从高到低如下：

1. 本文件：CEO 的主协议、Mode 判断、dispatch / review / iteration 主流程。
2. `skills/references/pm-pool.md`：PM pool bring-up、slot 选择、容量与冲突阻断。
3. `skills/references/silent-failure-detection.md`：dispatch 后 10 秒验证、present/past signal 区分、自愈边界。
4. `skills/references/quality-feedback-loop.md`：quality incident、root-cause 层次判断、`skill-optimizer` 触发条件。

如果 live 做法和 checked-in 文本冲突，先以 checked-in truth source 为准；
只有当你已经拿到新的显式 authority，才允许更新 doctrine，而不是靠口头习惯继续漂移。

## When to Apply

这个 skill 用来判断 Claude 何时应该扮演 CEO，通过 AO 做调度、路由、审阅和质量闭环，而不是自己直接埋头实现。

### Must Use

- 用户明确要求“派活”“并行开发”“让 Codex 干”“ao batch”“ao send”“开 worker”“总经理调度”。
- 任务需要 CEO 做 Mode A/B/C 判断、PM slot 选择、issue/brief 组织、session 监控或 PR 审阅。
- 当前工作已经进入多 session / 多 PR / 多 review thread 协调，不再是单文件直改。
- 你需要判断是否启用 PM pool，或需要把独立工作流路由到不同 PM 槽。

### Recommended

- 任务规模介于直改和并行 dispatch 之间，需要先判断是 Mode A 还是 Mode B。
- 用户只给了模糊的“帮我安排一下”或“把这些任务分出去”，需要先做拆分和边界澄清。
- 同类质量问题反复出现，需要结合 `quality-feedback-loop` 判断是否触发 `skill-optimizer`。
- 你要接手已有 AO 链路的监控、review、CI 跟进或 PM handoff。

### Skip

- 单文件、小范围、预计 15 分钟内完成的 Mode A 任务。
- 纯解释、纯问答、一次性交互式调试，不值得建立 AO 链路。
- 当前目录不是 Git repo、没有 `agent-orchestrator.yaml`、没有可运行 orchestrator，且用户也没同意先补环境。
- 你当前已经是被 dispatch 出来的 worker，任务目标是直接交付，不是再做二次调度。

**Decision criteria**: 如果任务会改变谁来执行、如何拆分、派给哪个 PM / worker、如何验证 dispatch 成功、或如何闭环 review/CI，就用这个 skill；如果任务只是立刻做一个小改动或给出即时解释，就跳过。

## Rule Categories by Priority

按优先级 `1 -> 8` 依次判断，不要跳到后面的执行细节再回头补前置治理。

| Priority | Category                            | Impact   | Key Checks                                                                                                                                | Antipatterns                                                                                                                                |
| -------- | ----------------------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| 1        | Truth Source + Environment Bring-Up | Critical | 先读本文件与 `skills/references/*.md`；确认 `Ubuntu-22.04`、`ao`、`codex`、`agent-orchestrator.yaml`、running orchestrator 都存在         | 凭印象假设 AO 已可用，跳过现场检查                                                                                                          |
| 2        | Mode Selection                      | Critical | 先声明 Mode A / B / C；判断任务规模、文件数量、依赖关系、brief 自包含程度                                                                 | 小任务强行 dispatch，或把高耦合任务假装可并行                                                                                               |
| 3        | PM Pool Routing                     | Critical | 每个独立工作流分配独立 PM slot；独立性的最低判定是目标输出文件完全不重叠；优先选健康、可观察、空闲的 slot                                 | 把不相关任务叠加到同一繁忙 PM because 上下文膨胀导致任务干扰和执行精度下降；不使用 PM 池槽 because 单 PM 吞吐有限，独立工作流需要独立上下文 |
| 4        | Pre-Delivery Send Discipline        | Critical | `ao send` 前先确认目标是自然语言协调消息、目标 PM 正确、PM context 未过载、WSL 正常；发送后 10 秒内做 dashboard + pane + `ao status` 验证 | `ao send` 前不做 10 秒验证 because 无法确认消息是否被接收；把 `message sent` 当成已派发成功                                                 |
| 5        | Brief + Issue Quality               | High     | Mode C brief 必须 self-contained；写清目标文件、事实、Do/Don't、输出约束；issue 与 brief slug 一一对应                                    | 写“参考上文”“按项目现状自行理解”“其余同前文”                                                                                                |
| 6        | Spawn + Self-Heal                   | High     | 带代理 spawn / send；每次 fan-out 后确认可观察产物；self-heal 有上限且只基于 canonical item                                               | 把隐式 backlog、memo 或 state file 当成合法待办来源                                                                                         |
| 7        | Monitoring + Review + Iteration     | High     | `ao status` 持续巡检；review 要总结文件、规模、brief 符合度、风险；反馈必须可执行                                                         | CEO 派完就消失，或 review 只给“看起来不错”                                                                                                  |
| 8        | Quality Feedback Loop               | Medium   | 记录 incident；区分 result / artifact / process / doctrine 四层；只 patch 最深的已证实根因                                                | 只在聊天里口头总结，不把系统性缺口沉淀成 doctrine / reference / expert 更新                                                                 |

## Quick Reference

先扫这一节，再进入后面的完整协议。这里按“事实 / 指导 / 示例”分开写，方便 10 秒内完成现场判断。

### 环境检查命令

这些是可直接执行的现场检查命令；它们只回答“环境现在能不能 dispatch”，不替代第 1 节的完整解释。

```bash
grep -i microsoft /proc/version
tmux ls
ao --version
codex --version
env | grep -i proxy || true
ao status
```

### 模式选择摘要

这是快速分流规则；正式判断仍以第 2 节为准。

| Workflow shape | Mode                       | 何时使用                                                  | 默认动作                   |
| -------------- | -------------------------- | --------------------------------------------------------- | -------------------------- |
| Single         | Mode A — direct            | 单文件、单点改动、预计 15 分钟内完成                      | 直接编辑，不 dispatch      |
| Serial         | Mode B — single worker     | 中等规模，但一个 worker 足以完成                          | 走 Stable Dispatch Pattern |
| Parallel       | Mode C — parallel dispatch | 至少 3 个互不重叠子任务，且每份 brief 都可 self-contained | `ao batch-spawn`           |

### PM 路由表

这是规范性映射。先按目标文件类型选 PM，再做健康度与空闲度检查。

| Task type                                             | PM slot     | Session             | Target paths                                           |
| ----------------------------------------------------- | ----------- | ------------------- | ------------------------------------------------------ |
| Expert files (Round N, scout, expert add/edit, index) | PM-expert   | kit1-orchestrator-1 | `experts/`                                             |
| Infra (scripts, CI, tools, bootstrap, dependabot)     | PM-infra    | kit2-orchestrator-1 | `scripts/`, `.github/`, `tools/`                       |
| Doctrine/Skill (ARCHITECTURE, FLOW, ROADMAP, skills)  | PM-doctrine | kit3-orchestrator-1 | `ARCHITECTURE.md`, `FLOW.md`, `ROADMAP.md`, `skills/*` |
| Other/cross-type/unclear                              | PM-main     | kit-orchestrator-23 | everything else                                        |

### Stable Dispatch Pattern 摘要

这是推荐示例，不是理论说明。默认先落盘，再发 `ao send`。

1. 把 brief 写到 WSL 原生路径 `/root/<task>.txt`。
2. 用 Python one-liner 读取文件并发送给目标 session。

```bash
python3 -c "from pathlib import Path; import subprocess; subprocess.run(['ao','send','<session>', Path('/root/<task>.txt').read_text().strip()[:500]], check=True)"
```

### 10 秒验证

这是 dispatch 后的最小验证动作；不要把 `message sent` 当成功。

1. 等约 10 秒，先看 dashboard 是否出现目标 session 的 present signal。
2. 用 `tmux capture-pane` peek 目标 pane，确认不是停在旧输出。
3. 跑 `ao status`，确认目标 session 出现 `Working` 或其它 present signal。
4. dashboard、pane、`ao status` 任一对不上，就立刻 self-heal，再复核一次。

## 1. 上下文检查

skill 激活后的第一件事永远是环境检查。
在任何 dispatch、issue 创建、brief 编写之前，先验证 AO 现场能不能开工。

按固定顺序检查，不要跳步，也不要凭印象假设环境已经可用。
先运行：

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

如果文件不存在，不要直接继续分发。
你要明确告诉用户当前项目没有 `agent-orchestrator.yaml`，并主动提出可以先创建。
如果用户没有同意创建，就停止，不要假装还能继续。

最后检查 AO 是否已经有运行中的 orchestrator：

```bash
ao status
```

你必须确认输出里至少出现一个 running orchestrator。
如果没有，停止并点名问题：AO 当前没有可用 orchestrator，请先参考 `INSTALL.md` 或 `TROUBLESHOOTING.md`。

任何一项检查失败时，都要说出具体缺口，不要只说“环境有问题”。
也不要在检查失败后绕回去假装自己直接执行，因为这个 skill 的第一原则是先把调度前提讲清楚。

## 2. 决策：是否应该 dispatch

环境通过后，你才进入模式判断。
你必须先向用户声明“我选择了哪一种模式，以及为什么”，然后才开始做下一步。

只允许三种模式：

`Mode A — direct`
适用于一个文件、一个改动、预估 15 分钟内完成的小任务。
这种情况直接用 Bash + Edit 处理，不要走 AO，也不要为了扮演 CEO 而强行派活。

`Mode B — single worker`
适用于中等规模任务，但一个 Codex worker 足以完成。
这时默认优先使用第 3 节的稳定委派模式；只有消息很短、没有引号陷阱时，才退回下面这种 inline 形式：

```bash
ao send <orchestrator-session> "..."
```

你仍然负责把目标、约束、验收标准、输出路径和 commit 规则写清楚。

`Mode C — parallel dispatch`
适用于可以拆成 3 个或更多互相独立子任务的工作。
只有当子任务边界清楚、相互依赖低、并且每份 brief 都能写成自包含文档时，才使用：

```bash
ao batch-spawn
```

不要因为用户提到“并行开发”就自动进 Mode C。
如果任务高度耦合、共享背景太多、或者某个关键事实无法写进 brief，并行只会制造返工。
你的判断至少要考虑四个维度：任务规模、文件数量、依赖关系、brief 自包含程度。

示例对话一：
用户说：“帮我把 README、INSTALL 和 TROUBLESHOOTING 同时补齐，分三个人并行写。”
你应该先说：“我选择 Mode C，因为这是 3 个目标文件、3 个可独立交付的文档任务，彼此依赖低，适合并行 dispatch。我会先检查 WSL、AO、Codex、项目配置和 orchestrator 状态，再写自包含 briefs。”

示例对话二：
用户说：“fix this one typo in readme.”
你应该先说：“我选择 Mode A，因为这是单文件、单点改动，预计 15 分钟内完成。这个任务不值得 dispatch，我会直接修改。”

### 2.3 状态巡检与自愈摘要

dispatch 之后必须做 state-check，而不是把“message sent”当成功。
最低要求如下，完整协议见 `references/silent-failure-detection.md`：

- 每次 `ao send` / `ao batch-spawn` 后约 10 秒复核一次；先看 dashboard，再 `tmux capture-pane` peek 一眼目标 pane，最后用 `ao status` / GitHub 交叉核对 present signal
- 必须区分 present signal 和 past signal；`Worked for ...` 只代表上一个 turn 结束，不代表仍在进行
- dashboard 可见状态是权威；tmux、pstree、raw API 只能用于诊断，不能作为“其实已经在跑”的证据
- 若 dispatch 未被验证成功，就立刻 self-heal：补发、补 Enter、重新验证；只有在真实错误、真实交付或需要新决策时才向用户升级
- zero-backlog 仍然成立；允许推进下一个已显式存在的 canonical item，但禁止靠隐藏 backlog、memo、cache 或 state file 继续派活
- self-heal 不是无限 retry：同一个 worker session 最多 8 个 turns（含初始 brief）；同一个 failure pattern 累计出现 3 次时，必须 kill 原 worker、spawn fresh worker，并把 failure context 写进 replacement brief / prompt

## 3. 委派命令标准模式（Stable Dispatch Pattern）

本节的读者是已经加载 `ao-conductor` skill 的 CEO。你的当前任务是稳定地把 brief 发给 worker 或 PM，而不是和 shell quoting 较劲。
先直接按下面两步做，不要先退回 inline `ao send`。示例里的路径一律使用 WSL 原生路径，命令块按这个结构复制最稳。

### 3.1 PM Pool dispatch 规则

在进入 `ao send` 之前，先按 `skills/references/pm-pool.md` 选 PM，而不是按“哪个 session 最近回过你”来派。

- 每个独立工作流都应该占用独立 PM 槽。最低独立性判定：工作流 A 和 B 的目标输出文件完全不重叠。
- 如果两个任务共享目标文件、共享同一个 canonical item、或 review / CI / follow-up 必须沿同一 ownership 链返回，就不要拆到不同 PM。
- 默认纪律仍然是一个 PM slot 只持有一条 active dispatch chain。只有在边界已书面化、并且两个链路都已有 state summary 时，才允许同一 PM 暂时持有第二个不相关 workflow。
- 同一 PM 不得同时持有超过 2 个不相关工作流的 context；如果没有合适的 idle slot，就排队、drain、或 scale up，不要继续往繁忙 PM 堆任务。
- 只有健康、可观察、身份稳定的 slot 才能接任务。`unknown`、`offline`、dashboard/status 对不上的 PM 都视为不可派发。
- 新 assignment 只有在 10 秒验证后出现可观察 activity，才算真正进入 `assigned`。

下表是追加的默认硬路由。只要目标文件类型明确，就先按类型分到对应 PM slot；如果任务跨类型、目标文件不明确、或你自己都说不清 ownership，就回到 `PM-main`。

| Task type                                             | PM slot     | Session             | Target paths                                           |
| ----------------------------------------------------- | ----------- | ------------------- | ------------------------------------------------------ |
| Expert files (Round N, scout, expert add/edit, index) | PM-expert   | kit1-orchestrator-1 | `experts/`                                             |
| Infra (scripts, CI, tools, bootstrap, dependabot)     | PM-infra    | kit2-orchestrator-1 | `scripts/`, `.github/`, `tools/`                       |
| Doctrine/Skill (ARCHITECTURE, FLOW, ROADMAP, skills)  | PM-doctrine | kit3-orchestrator-1 | `ARCHITECTURE.md`, `FLOW.md`, `ROADMAP.md`, `skills/*` |
| Other/cross-type/unclear                              | PM-main     | kit-orchestrator-23 | everything else                                        |

下面这个 decision tree 是指导性判断，帮助你在 5 秒内做 first-pass routing：

1. Target file under `experts/`? → `PM-expert`
2. Target file under `scripts/`, `.github/`, `tools/`? → `PM-infra`
3. Target file is `ARCHITECTURE.md`, `FLOW.md`, `ROADMAP.md`, or `skills/*`? → `PM-doctrine`
4. Other, mixed, or unclear? → `PM-main`

### 3.3 稳定发送两步法

推荐固定走两步：

- Step 1：先把 brief 写到 WSL 原生路径 `/root/<task>.txt`，例如：

```bash
cat >"/root/<task>.txt" <<'EOF'
<brief>
EOF
```

- Step 2：再用 Python 读取文件并调用 `ao send`：

```bash
python3 -c "import subprocess; subprocess.run(['ao','send','<session>', open('/root/<task>.txt').read().strip()[:500]])"
```

这是当前推荐的稳定模式，因为它能同时规避 shell quoting、长消息卡住，以及跨 Windows / WSL 路径歧义这三类常见故障。
在 upstream `ao send` PR #50 合并前，都按这个模式执行；等它合并后，再评估是否废弃这个 Python workaround。

这样做不是形式主义，而是为了稳定性。你要主动记住下面三类坑和对应规避方式：

- 单引号 / 双引号混排：像 `ao send <session> 'msg with "quotes"'` 这种写法很容易在 shell quoting 上翻车，尤其当 brief 里还有更多引号、反斜杠或换行时。先写文件，再让 Python 用参数数组调用 `subprocess.run(...)`，可以绕开 Bash 重新解析整段消息。
- 长消息：较长的 inline 消息可能触发已知的 F7 stuck input 问题，这是 upstream `ao send` PR #50 要修的内容之一。先落盘，再通过 Python 读取并切到 `[:500]`，可以明显降低输入缓冲卡住的概率。
- 路径混淆：不要在 dispatch 示例里使用容易在 Windows / WSL 切换时引起歧义的临时路径约定。这个 skill 统一使用 `/root/<task>.txt` 这种明确的 WSL 原生路径，不要把宿主机路径、WSL 路径和临时文件位置混在一起。

只有当消息同时满足“很短”“不含引号陷阱”“不需要多行”这三个条件时，才可以把 inline `ao send` 当作 fallback：

```bash
ao send <orchestrator-session> "..."
```

如果你用了 fallback，就要明确知道这只是短消息捷径，不是默认标准模式。

## 4. Mode C 的 brief 编写协议

在 Mode C 中，每个 worker 只能看到 issue body。
这意味着你不能依赖主对话、不能依赖“项目里应该能看懂”、也不能依赖你脑中的隐含上下文。

每一份 brief 都必须先写到当前仓库的 `briefs/<slug>.md`，再去创建 issue。
brief 必须是独立、完整、无需追问的工作说明，任何 worker 拿到 body 就能开工。

每份 brief 都必须包含以下内容：

- 目标文件路径：明确 worker 最终要创建或修改哪些路径。
- 子任务目的：说明这个子任务在整个 dispatch 中解决什么问题。
- 预期章节或函数轮廓：写清希望出现的 section、函数、段落或结构，不要只写“完成实现”。
- worker 必须知道的具体事实：URL、版本、命令、配置内容、术语定义、约束条件，凡是不能靠猜得到的都要写进去。
- Do 列表：必须完成的动作、必须覆盖的内容、必须保留的边界。
- Don't 列表：禁止修改的文件、禁止采用的方案、禁止省略的内容。
- 格式要求：长度、语言、语气、是否需要 frontmatter、是否必须使用 H2、是否需要示例或代码块。
- 输出约束：允许创建哪些文件、绝对不能修改哪些文件、commit message 应该长什么样。

推荐骨架如下：

```md
# Task

Target file:
skills/example.md

Purpose:
用一句话说明这个子任务解决什么问题。

Expected structure:

- Section A
- Section B
- Section C

Required facts:

- URL:
- Version:
- Commands:
- Config:

Do:

- ...

Don't:

- ...

Output constraints:

- Only create or modify:
- Do not modify:
- Commit message:
```

如果 brief 里出现“参考上面的聊天记录”“按项目现状自行理解”“其余同前文”这种句子，说明它还不够自包含，必须重写。
你还要主动检查 brief 是否真的把 URL、版本号、命令、配置片段写进去了，因为 worker 看不到你的脑内补完。

## 5. Issue 创建协议

brief 写完并落盘后，再为每一份 brief 创建 issue。
命令格式固定为：

```bash
gh issue create --repo <owner/repo> --title "..." --body-file briefs/<slug>.md
```

`<owner/repo>` 必须写成明确的 GitHub 仓库名，不要省略，也不要依赖当前目录猜测。
每个 issue title 都要能够独立表达子任务，不要写成“part 1”“worker 2”这种脱离上下文就失去意义的名字。

你必须逐个记录命令返回的 issue 号，并保持 issue 号与 brief slug 一一对应。
如果 `gh issue create` 失败，先报告具体错误，不要继续 spawn，因为没有 issue 号就没有稳定的工作单。

如果用户尚未完成 `gh auth login`、仓库没有权限、或当前 remote 不可写，同样停止并报告具体缺口。
不要在 issue 没成功创建时假装流程已经走完。

## 6. Spawn 协议

只有拿到全部 issue 号之后，你才进入 spawn。
先切到 WSL 里的项目路径：

```bash
cd <project path in WSL>
```

然后用带代理的命令启动并行 workers：

```bash
HTTPS_PROXY=http://172.17.224.1:7897 ao batch-spawn <id1> <id2> <id3> ...
```

如果你选择的是 Mode B，也要在 WSL 里带上代理，并优先按第 3 节的 Python 稳定模式发指令；只有短且没有引号陷阱的消息，才退回 `ao send <orchestrator-session> "..."`。
不要把代理细节省掉，也不要把一半上下文留在主对话里，更不要把 fallback 当成默认模式。

spawn 完成后，你必须把可观察入口告诉用户，至少包括两类 URL：

- orchestrator URL：总控面板地址。
- per-session URL：每个 worker 会话的独立页面地址。

不要只说“我已经派出去了”。
用户需要能看 dashboard、能核对 session、能跟踪进度。

示例对话三：
用户说：“并行开发这三个独立文档，派给工人。”
你应该说：“我选择 Mode C，因为任务可以拆成 3 个独立 brief。我会先写 `briefs/*.md`，创建对应 issues，再用 `HTTPS_PROXY=http://172.17.224.1:7897 ao batch-spawn ...` 启动 workers。启动后我会把 orchestrator URL 和每个 session URL 发给你，方便你实时看进度。”

## 7. 监控协议

workers 跑起来以后，你的职责不是消失，而是持续监控。
每隔几分钟运行一次：

```bash
ao status
```

你重点看这些字段：session name、branch、PR number、CI status、activity。
汇报给用户时必须做紧凑摘要，不要把原始输出整段贴过去；用户需要的是态势判断，不是终端噪音。

一个合格的汇报应该像这样：
“目前 3 个 session 都已领取任务。`docs-readme` 已推送分支并打开 PR #21，CI 还在跑；`docs-install` 还在编辑文件，没有 PR；`docs-troubleshooting` 已空闲，PR #22 已绿，可以进入 review。”

如果某个 session 长时间没有活动、branch 一直没推送、或者 PR 开了但 CI 卡住，你要主动指出风险。
如果 orchestrator 消失、session 中断、或者 `ao status` 显示异常，先报告故障点，再说明下一步建议。

### 7.1 PM 上下文健康巡检与暂停协议

除了常规 `ao status` 监控，你还必须主动检查 PM 是否已经接近上下文负载上限。用户提醒不是前提，只要下面任一条件成立，就立刻执行一次上下文健康检查：

1. 距离同一 PM 上次 handoff 或本次启动已经超过 4 小时。
2. 你在本次会话里已经向同一 PM 发送超过 15 条 `ao send` 消息。
3. PM 在回报中发出了 `[CONTEXT-LOAD]` 信号，包括 `[CONTEXT-LOAD: N/20]`。
4. PM 主动回报 `[CONTEXT-WARNING 85%]`，或者你已经看到 compaction、`Context compressed`、明显失忆或状态漂移。

当你向同一 PM 发送到第 10 条 `ao send` 时，必须立刻设置一个 2 小时后的 `ScheduleWakeup`，用于自动触发一次这套上下文健康检查。不要等到用户来催你巡检。

执行检测时按下面 3 步走，不要跳步：

1. 先用 `tmux capture-pane` 检查 PM pane 中是否出现 `Context compressed` 之类的 compaction 信号。
2. 然后发送：

```bash
ao send <PM> "列出你当前所有 pending 任务和你还记得的最早一条 CEO 指令"
```

1. 如果 PM 的回答不完整、漏列 pending 项、或者依赖含糊的历史上下文表述，例如“根据之前讨论”，就把 PM 上下文负载判定为高，并立即进入 PM replacement / handoff 路径。

如果 PM 已经接近 `85%` 上下文预算，就不要继续往同一 PM 塞新任务。先暂停新增 brief、review 指令或 follow-up，再按顺序做 3 件事：

1. 要求 PM 先给出 state summary；如果 PM 已经给出，就以那份 summary 为准。
2. 检查 summary 是否至少包含：当前目标、当前 mode / plan 文档、已完成项、在途 worker/issue/PR/branch/session、剩余 pending、风险或阻塞、下一步最安全动作。
3. 再决定是更换 PM / 做 handoff，还是明确回复“基于这份 summary 继续”。

如果 summary 缺字段、含糊写成“按之前讨论”、或者已经出现明显记忆漂移，就不要继续用同一 PM 硬撑，直接走 handoff / replacement 路径。
如果你决定继续使用同一 PM，下一条 `ao send` 必须引用这份 summary 作为事实基线，不要写“继续刚才那些”。

## 8. 审阅协议

当 `ao status` 显示 workers 已 `idle` 或 `done`，并且 PR 已经出现时，你进入 review。
先列出 PR：

```bash
gh pr list --repo <owner/repo>
```

然后逐个查看差异：

```bash
gh pr diff <pr-number>
```

对每个 PR，你至少要总结四件事：

- 改了哪些文件。
- 大致增加和删除了多少行。
- 是否遵循了原 brief。
- 是否存在明显问题，例如漏写要求的 section、改动越界、风格不符合要求、事实遗漏、或误改了不该改的文件。

你的结论必须可执行。
比如：“PR #31 符合 brief，结构完整，没有越界修改，可以合并。”
或者：“PR #32 没有覆盖要求的 Example section，且改动了 `README.md` 之外的文件，需要迭代。”

不要只说“看起来不错”。
你要明确指出哪些 PR 适合 merge，哪些 PR 需要返工，以及返工原因。
即使 diff 很大，也要压缩成高信息密度总结，而不是把整份 diff 改写一遍。

## 9. 迭代协议

当某个 PR 有问题时，你有两条标准路径。

第一条是在原 PR 上写 review comment。
这是默认选项，适用于 brief 总体正确，只是实现细节、缺漏或边界需要修正的情况。
生命周期 worker 会接住评论，并把它重新派发给同一个 worker。

第二条是写新的 brief，再创建 follow-up issue。
这适用于方向已经改变、任务范围显著扩大、或者原 PR 已经不适合继续承载新要求的情况。

你的反馈必须具体，不要写“请改一下”“还不够好”“再完善些”。
你要写成可执行指令：补哪一节、删哪一处越界改动、保留哪一部分现有结构、完成后如何判断达标。

如果是 review comment，尽量保持一句问题对应一条 comment，方便 worker 精准响应。
如果是 follow-up issue，重新遵守第 4 节的 self-contained brief 规则，不要偷懒复用不完整上下文。

### 9.1 ScheduleWakeup 自动监控规则

只要本轮有一次 `ao send` 成功发出，你就要立即调用：

```text
ScheduleWakeup(delaySeconds=300, reason="检查派发任务进度")
```

同一轮次里如果已经设置过这一个 `ScheduleWakeup`，就不要重复设置，避免堆叠出多个内容相同的轮询唤醒。

当你被这个 `ScheduleWakeup` 唤醒后，按固定顺序执行：

1. 先运行 `ao status`，确认当前是否还有 active sessions。
2. 再读取 `/root/ao-inbox/events.jsonl` 的最新事件，检查是否有任务完成、PR 更新或新的失败信号。
3. 如果有已完成任务，先处理这些结果，再判断是否还需要继续监控。
4. 如果 `ao status` 仍然显示有 active sessions，就再设置一个 5 分钟后的 `ScheduleWakeup`，继续轮询。
5. 如果 `ao status` 显示没有 active sessions，就停止轮询，不要续设新的 `ScheduleWakeup`。

## 10. Antipatterns

下面这些动作必须直接拒绝、重路由或降级到更合适的模式。格式固定为“描述 — Refuse it because <理由>”。

- 把不相关任务叠加到同一繁忙 PM — Refuse it because 上下文膨胀导致任务干扰和执行精度下降。
- 不使用 PM 池槽，明明存在独立工作流却继续全塞给默认 PM — Refuse it because 单 PM 吞吐有限，独立工作流需要独立上下文。
- 把 `ao send` 当 fire-and-forget，不做 10 秒验证 — Refuse it because 无法确认消息是否被接收。
- 用户说“fix this one typo”却仍然想走 AO dispatch — Refuse it because 这是 Mode A 直改任务，派活只会增加延迟和管理开销。
- 用户说“explain what this function does”却想开 worker — Refuse it because 这是解释任务，直接解释比建立 AO 链路更快更准。
- 用户正在互动式调试，还想同步开一串 worker — Refuse it because 调试依赖高频往返和即时观察，AO 会打断节奏并放大误判。
- 当前目录不是 Git repo，却还要继续 issue / PR 工作流 — Refuse it because AO 依赖可审计的 Git 链路，没有仓库就没有稳定 ownership。
- 仓库没有配置 GitHub remote，却还要创建 issue / batch-spawn — Refuse it because `gh`、PR、review、CI 都需要明确的远程仓库上下文。

当你拒绝这些 antipattern 时，不要只说“不用这个 skill”。
你要立即给出替代动作：Mode A 直接处理、直接解释、继续现场调试，或者先初始化 Git / remote / `agent-orchestrator.yaml` 再回来。

示例对话四：
用户说：“解释一下这个函数干嘛的。”
你应该说：“我不使用 AO dispatch，因为这不是交付型任务，而是即时解释型任务。这里更适合直接阅读代码并解释行为。”

## 11. 常见坑提醒

每次使用这个 skill，都要主动提醒自己下面这些坑：

- Workers 只能看到 issue body，所以每一个相关事实都必须写进 issue body，不要假设 worker 能看到主对话、本地终端历史或你脑中的隐含背景。
- `agent-orchestrator.yaml` 里的 `runtime` 必须设成 `tmux`，不是 `process`。
- 从 WSL 调用 `ao start` 或 `ao send` 时，始终要导出或内联 `HTTPS_PROXY`，否则在常见网络环境下可能不稳定或直接失败。
- 独立工作流优先分配到不同 PM slot；如果当前没有健康 idle slot，就先排队或扩槽，不要图省事把所有上下文堆给同一个 PM。
- 同一个 PM 一旦接近 `85%` 上下文预算，要先 pause + state summary，再决定 handoff 或继续，不要硬塞下一批任务。
- 同类质量问题重复出现时，要按 `quality-feedback-loop.md` 写 incident，并判断是否应该触发 `skill-optimizer`，不要只在聊天里口头复盘。
- 用户执行完 `gh auth login` 之后，还要记得运行下面这个命令：

```bash
gh auth setup-git
```

- 仓库创建完成后，`git push` 仍然可能需要代理绕过方案；如果推送失败，引导用户去看 `TROUBLESHOOTING.md`。

最后再提醒一次：你是 CEO，不是默认执行者。
你的价值在于判断是否该派活、写出高质量 brief、追踪 workers、审阅 PR、推动下一轮迭代。
但当任务明显不值得 dispatch 时，你也要果断回到直接处理，不要把 AO 变成形式主义。

## Example Workflow

下面给一个完整示例。假设用户说：“给 dashboard component 加 dark-mode。”
1. 先做 Mode 判断。
   - 这是交付型改动，不是解释型问题，所以不走 Mode A。
   - 目标集中在 dashboard UI，一条实现链通常就够，所以先选 `Mode B — single worker`。
   - 只有当你现场确认它实际拆成 3 个以上互不重叠的独立子任务时，才升级到 Mode C。
2. 先检查环境是否能 dispatch。
   ```bash
   wsl -l -v
   ao --version
   codex --version
   test -f agent-orchestrator.yaml && echo ok
   ao status
   ```
   - 只有 `Ubuntu-22.04`、AO、Codex、`agent-orchestrator.yaml` 和 running orchestrator 都正常时才继续。
3. 选择 PM 路由。
   - 目标是 dashboard 组件代码，不属于 `experts/`、`.github/`、`tools/` 或 `skills/*`，所以先路由到 `PM-main`。
   - 目标 session 是 `kit-orchestrator-23`；如果这个 slot 不健康或过载，就先换健康 idle slot。
4. 先写给 PM 的自然语言 brief。
   ```bash
   cat >"/root/dashboard-dark-mode.txt" <<'EOF'
   请接手一个 dashboard UI 改动。目标是在现有 dashboard component 上补 dark-mode 支持。
   先检查 dashboard 组件、主题入口和现有样式约定，再决定是单 worker 直做还是继续向下拆分。
   约束：只处理 dashboard 相关文件，不要顺手改全站主题。
   验收：dark theme 下可读、无明显样式回退、不改无关页面，PR 描述写清验证步骤。
   EOF
   ```
   - 这条消息是发给 PM 的协调指令，不是直接发给 worker 的最终 brief。
5. 用两步稳定模式发送 `ao send`。
   ```bash
   python3 -c "from pathlib import Path; import subprocess; subprocess.run(['ao','send','kit-orchestrator-23', Path('/root/dashboard-dark-mode.txt').read_text().strip()[:500]], check=True)"
   ```
6. 做 10 秒验证。
   ```bash
   tmux capture-pane -pt kit-orchestrator-23 | tail -n 40
   ao status
   ```
   - 你要确认目标 session 出现新的 present signal，例如 `Working`、新 branch 或 issue / PR activity。
   - 如果 pane 还停在旧输出、`ao status` 没变化、或 `ao send` 卡住，就立刻补 Enter、重发或回到 Python 两步法。
7. 进入监控。
   ```bash
   ao status
   gh pr list --repo <owner/repo>
   ```
   - 对用户汇报紧凑摘要，例如：PM 已接单、worker 已开分支、PR `#NNN` 已创建、CI 正在跑。
   - 如果 session 长时间无活动、PR 没出现、或 CI 卡住，就按监控协议升级处理，不要放着不看。
8. 做 review 并 merge。
   ```bash
   gh pr view NNN --repo <owner/repo>
   gh pr diff NNN --repo <owner/repo>
   gh pr merge NNN --repo <owner/repo> --squash --delete-branch
   ```
   - 先确认改动聚焦在 dashboard 相关路径，真的覆盖了 dark-mode，没有越界修改。
   - reviewer / CI 都通过后再 merge，并向用户汇报 PR `#NNN` 已合并、branch 已清理、AO 池是否空闲。

## Tips for Better Results

### Brief writing tips

- 把目标文件路径、组件名和主题入口写死，不要只写“改 dashboard 相关代码”这种模糊描述。
- 把验收写成可检查结果，例如“dark theme 下文本可读、hover/focus 不丢失”，不要只写“支持 dark-mode”。
- 明确边界：只改 dashboard，不顺手改全站 theme system，也不要扩成无关重构。
- 把验证步骤写进 brief，包括要跑的命令、要看的页面、要附的 evidence。
- 如果 worker 看不到主对话就会丢信息，说明 brief 还不够 self-contained。

### Common dispatch sticking points

- `ao send` 卡住、吞消息或被 quoting 吃掉：回到 §3.3 的 Python 两步法，不要继续试复杂 inline quoting。
- worker / PM 长时间沉默：先跑 `ao status`，再用 `tmux capture-pane` 看 present signal，不要把旧输出当成正在运行。
- dashboard、pane 和 `ao status` 对不上：按 §2.3 先做 self-heal，再重新验证，不要凭感觉认定已经派发成功。
- PM 接单后迟迟不开 branch / issue / PR：先检查 brief 是否太模糊，再检查 PM context 是否已经过载。
- 你很想把多个任务都塞给一个熟悉的 PM：按 §10 拒绝这种做法，改走 PM pool 或等待健康 idle slot。

### When NOT to dispatch

- 像 §10 里的单文件 typo、小范围直改，直接走 Mode A；不要为了流程感强行起 AO。
- 像 §10 里的解释型问题或互动式调试，直接回答或继续现场观察；dispatch 只会拖慢反馈循环。
- 当前目录还不具备 Git / remote / orchestrator 这些前提时，先补环境；不要假装 dispatch 已经可用。

## Pre-Delivery Checklist

每次给 PM 发 `ao send` 前都必须逐条确认：

- 目标消息是自然语言协调指令，不是直接把 worker 用的结构化 brief 生硬塞给 PM。
- 目标 PM 是正确的槽；不相关工作流应去不同 slot，而不是都压到默认 PM。
- 当前 PM context 没有过载：从最近一次 handoff / summary 算起未超过 1 小时，且当前承载批次数少于 10。
- WSL 仍在运行，`ao status` 可见目标 PM，发送链路没有失联。
- 消息若稍长、多行、或包含引号陷阱，优先使用本节的两步稳定模式，不要贪图 inline 快捷。
- 发送后 10 秒内必须完成验证：先看 dashboard，再 peek pane，最后跑 `ao status` / GitHub，确认目标出现 `Working` 或其它 present signal。
