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

- 每次 `ao send` / `ao batch-spawn` 后约 10 秒复核一次；先看 dashboard，再用 `ao status` / GitHub 交叉核对
- 必须区分 present signal 和 past signal；`Worked for ...` 只代表上一个 turn 结束，不代表仍在进行
- dashboard 可见状态是权威；tmux、pstree、raw API 只能用于诊断，不能作为“其实已经在跑”的证据
- 若 dispatch 未被验证成功，就立刻 self-heal：补发、补 Enter、重新验证；只有在真实错误、真实交付或需要新决策时才向用户升级
- zero-backlog 仍然成立；允许推进下一个已显式存在的 canonical item，但禁止靠隐藏 backlog、memo、cache 或 state file 继续派活
- self-heal 不是无限 retry：同一个 worker session 最多 8 个 turns（含初始 brief）；同一个 failure pattern 累计出现 3 次时，必须 kill 原 worker、spawn fresh worker，并把 failure context 写进 replacement brief / prompt

## 3. 委派命令标准模式（Stable Dispatch Pattern）

本节的读者是已经加载 `ao-conductor` skill 的 CEO。你的当前任务是稳定地把 brief 发给 worker 或 PM，而不是和 shell quoting 较劲。
先直接按下面两步做，不要先退回 inline `ao send`。示例里的路径一律使用 WSL 原生路径，命令块按这个结构复制最稳。

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

## 10. 何时不要使用这个 skill

下面这些情况，你应该明确拒绝 dispatch，并说明为什么不适合 AO：

- 用户说“fix this one typo”。这是 Mode A，直接改，不要建 issue。
- 用户说“explain what this function does”。这是解释任务，直接解释，不要开 worker。
- 用户正在互动式调试。比如一边看日志一边追问题，AO 会打断节奏。
- 当前目录不是 Git repo。AO 依赖 Git 工作流，没有仓库就不该进入派活流程。
- 仓库没有配置 GitHub remote。`gh` 和 `batch-spawn` 都依赖明确的远程仓库上下文。

当你拒绝 dispatch 时，不要只说“不用这个 skill”。
你要给用户一个替代动作，比如直接修、直接解释、或者先初始化 Git、remote、`agent-orchestrator.yaml` 再继续。

示例对话四：
用户说：“解释一下这个函数干嘛的。”
你应该说：“我不使用 AO dispatch，因为这不是交付型任务，而是即时解释型任务。这里更适合直接阅读代码并解释行为。”

## 11. 常见坑提醒

每次使用这个 skill，都要主动提醒自己下面这些坑：

- Workers 只能看到 issue body，所以每一个相关事实都必须写进 issue body，不要假设 worker 能看到主对话、本地终端历史或你脑中的隐含背景。
- `agent-orchestrator.yaml` 里的 `runtime` 必须设成 `tmux`，不是 `process`。
- 从 WSL 调用 `ao start` 或 `ao send` 时，始终要导出或内联 `HTTPS_PROXY`，否则在常见网络环境下可能不稳定或直接失败。
- 同一个 PM 一旦接近 `85%` 上下文预算，要先 pause + state summary，再决定 handoff 或继续，不要硬塞下一批任务。
- 用户执行完 `gh auth login` 之后，还要记得运行下面这个命令：

```bash
gh auth setup-git
```

- 仓库创建完成后，`git push` 仍然可能需要代理绕过方案；如果推送失败，引导用户去看 `TROUBLESHOOTING.md`。

最后再提醒一次：你是 CEO，不是默认执行者。
你的价值在于判断是否该派活、写出高质量 brief、追踪 workers、审阅 PR、推动下一轮迭代。
但当任务明显不值得 dispatch 时，你也要果断回到直接处理，不要把 AO 变成形式主义。
