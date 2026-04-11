# AO 0.2.2 生产问题补丁汇总

本文件汇总当前批次 3 个生产问题的本地 patch、验证结论与上游参考信息，供 reviewer 和后续提交 PR 时统一引用。

- AO 源码基线：`/root/agent-orchestrator`，0.2.2
- 本次交付只整理当前 worktree 内的 patch 和文档，不修改共享 AO 源码
- 当前 repo 不存在 `docs/ceo-exceptions.md`；本次未阻塞整合交付

| Bug | 症状 | 根因 | 本地 patch | 上游链接 | 状态 |
| --- | --- | --- | --- | --- | --- |
| bug-1 | `ao status` 的 `PR` / `CI` / `Rev` 长期显示 `-`，lifecycle 无法进入 `pr_open` / `ci_failed` / `review_*` | session metadata 的 stale `branch` 被直接传给 `scm.detectPR()`，live worktree branch 漂移后未自愈 | `patches/ao-0.2.2-bug1-live-branch-pr-detection.patch` | #368 / #545 / PR #544 | 已整理，worker 已验证 |
| bug-2 | `ao send` 的多行消息被 paste 到 Codex 输入区，但没有真正提交；CLI/PM 侧可能看起来像成功 | `paste-buffer` 后 `Enter` race，加上“任意输出变化即视为送达”的误判组合 | `patches/ao-0.2.2-bug2-send-paste-race.patch` | #373 / #564 / #853 / #184 / PR #374 / #541 / #494 / #571 | 已整理，worker 已验证 |
| bug-3 | Web API 创建 orchestrator 时 `agent: codex` 报 `Agent plugin 'codex' not found` | web 静态 plugin registry 漏掉 codex import / register / 依赖声明 | `patches/ao-0.2.2-bug3-web-codex-plugin.patch` | #1137 / PR #1138 | 已整理，worker 已验证 |

## Bug 1：live branch PR 检测失效

### 症状

- `ao status` 的 `PR` / `CI` / `Rev` 长期显示 `-`
- lifecycle 无法推进到 `pr_open`、`ci_failed`、`review_*`
- 依赖这些状态的 reaction、通知、后续派活链路一起失效

### 复现条件

- session spawn 之后，worker 实际工作分支已经切到 live worktree branch
- session metadata 里的 `branch` 仍停留在初始分支名
- `ao status` 与 lifecycle 继续拿 stale metadata branch 做 PR autodetect

### 根因

- `lifecycle-manager` 和 `ao status` 都把 session metadata 里的 `branch` 直接传给 `scm.detectPR()`
- 当 live worktree branch 与 metadata branch 漂移时，PR 检测持续查询旧分支，因此状态面板和 lifecycle 都看不到真实 PR

### 修复思路

- 在 PR autodetect 前优先读取 live worktree branch
- 把 live branch 传给 `scm.detectPR()`
- 检测到 metadata branch 漂移时，自愈更新 session metadata 里的 `branch`

### Patch 文件

- `patches/ao-0.2.2-bug1-live-branch-pr-detection.patch`

### 本地验证

- `pnpm --dir /root/agent-orchestrator --filter @aoagents/ao-core test -- src/__tests__/lifecycle-manager.test.ts`
  - 通过，`56 passed`
- `pnpm --dir /root/agent-orchestrator --filter @aoagents/ao-cli test -- __tests__/commands/status.test.ts`
  - 通过，`33 passed`
- `pnpm --dir /root/agent-orchestrator --filter @aoagents/ao-core typecheck`
  - 通过
- `pnpm --dir /root/agent-orchestrator --filter @aoagents/ao-cli typecheck`
  - 通过

### 上游 issue / PR

- Issue: https://github.com/ComposioHQ/agent-orchestrator/issues/368
- Issue: https://github.com/ComposioHQ/agent-orchestrator/issues/545
- PR: https://github.com/ComposioHQ/agent-orchestrator/pull/544

### 未决风险 / 建议

- 该 patch 修的是 stale metadata 与 live branch 漂移问题，仍依赖 worktree 能被正常解析
- reviewer 建议重点看 branch 自愈逻辑是否会影响已归档 session，及 `ao status` / lifecycle 是否保持同一套 branch 解析语义

## Bug 2：`ao send` paste 后未提交但被误判成功

### 症状

- `ao send` 发送多行或较长消息时，消息会出现在 Codex 输入缓冲区
- 消息没有真正提交，agent 仍停留在空闲或等待状态
- CLI / PM 侧仍可能显示“Message sent and processing”或等价成功状态

### 复现条件

- 使用 tmux runtime
- `ao send` 发送多行消息，或长度超过 paste-buffer 阈值的消息
- 消息内容包含特殊字符时更容易暴露问题，尤其是 Windows 路径反斜杠场景，例如多行消息里出现 `C:\Users\me\repo\file.ts`

### 根因

- 根因是两个问题叠加：
- 第一层是真实投递 bug：`packages/plugins/runtime-tmux/src/index.ts` 对多行和长消息走 `paste-buffer` 路径，但 AO 0.2.2 在 paste 之后仅等待固定 300 ms 就发送 `Enter`，对 Codex / Ink 风格 TUI 不可靠，容易出现 `Enter` 被吞掉、草稿仍留在输入区
- 第二层是确认误判：原有上层确认逻辑会把“pane 输出发生任意变化”视为消息已送达，而 paste 出来的草稿本身就会改变 pane 输出，因此会把“已粘贴但未提交”误判成成功

### 修复思路

- 在 runtime tmux send path 内部加固，而不是扩大到更大范围的传输层改造
- 对 paste-buffer 路径先等待 pane 稳定，再发送 `Enter`
- 如果发送后 pane 仍显示草稿输入，则继续重试 `Enter`
- 多次重试后仍无法确认提交时，显式抛错，避免继续出现“静默成功但实际上没提交”
- 测试覆盖明确包含 Windows 路径反斜杠的多行消息场景
- 最终 patch 以当前共享 AO diff 为准整理；与 bug2 worker 产出的 patch 一致

### Patch 文件

- `patches/ao-0.2.2-bug2-send-paste-race.patch`

### 本地验证

- `pnpm -C /root/agent-orchestrator/packages/plugins/runtime-tmux test src/__tests__/index.test.ts`
  - 通过，`28 tests`
- `pnpm -C /root/agent-orchestrator/packages/plugins/runtime-tmux typecheck`
  - 通过
- 新增测试覆盖结论：
  - 长消息 paste-buffer 后可进入提交流程
  - 多行消息中的 Windows 路径反斜杠按字面值保留
  - 首次 `Enter` 被吞时会继续重试
  - 多次重试后仍无法确认提交时，不再静默成功，而是显式失败

### 上游 issue / PR

- Issue: https://github.com/ComposioHQ/agent-orchestrator/issues/373
- Issue: https://github.com/ComposioHQ/agent-orchestrator/issues/564
- Issue: https://github.com/ComposioHQ/agent-orchestrator/issues/853
- Issue: https://github.com/ComposioHQ/agent-orchestrator/issues/184
- PR: https://github.com/ComposioHQ/agent-orchestrator/pull/374
- PR: https://github.com/ComposioHQ/agent-orchestrator/pull/541
- PR: https://github.com/ComposioHQ/agent-orchestrator/pull/494
- PR: https://github.com/ComposioHQ/agent-orchestrator/pull/571

### 未决风险 / 建议

- 本次 patch 选择的是 0.2.2 友好的 runtime 侧最小修补，不是最终架构解
- “任意输出变化即视为送达”的上层误判逻辑仍是背景风险，只是通过 runtime 侧更强的提交确认显著降低了静默失败概率
- 更彻底的长期方案仍是 file-based communication（#853）或 Codex app-server client（#184）
- reviewer 建议重点看 runtime 的草稿检测 heuristic、重试上限，以及失败时显式抛错是否与现有调用链预期一致

## Bug 3：Web 路径缺少 codex plugin 注册

### 症状

- Web API 调用 `POST /api/orchestrators` 时，如果配置 `agent: codex`，会报 `Agent plugin 'codex' not found`
- CLI 路径正常，Web 路径失败

### 复现条件

- 走 Next.js Web API 的静态 plugin 注册路径
- 使用 codex agent

### 根因

- `packages/web/src/lib/services.ts` 的静态 plugin import / `registry.register()` 列表漏掉了 `@aoagents/ao-plugin-agent-codex`
- Web 端走的是静态注册路径，而不是 CLI 的动态 `loadBuiltins()` 路径
- 同时 `packages/web/package.json` / `pnpm-lock.yaml` 也需要补齐对应 workspace 依赖，才能保证 `pnpm install --frozen-lockfile` 和 build 一致

### 修复思路

- 在 web 静态 registry 中补上 codex plugin import 与 `registry.register(pluginAgentCodex)`
- 在 `packages/web/package.json` 补上 `@aoagents/ao-plugin-agent-codex: "workspace:*"`
- 把 `pnpm-lock.yaml` 同步纳入 patch，保证 fresh clone / CI 的 frozen lockfile 安装可通过
- 需要明确记录：上游 issue #1137、PR #1138 已存在

### Patch 文件

- `patches/ao-0.2.2-bug3-web-codex-plugin.patch`

### 本地验证

- `pnpm install --frozen-lockfile`
  - 通过
- `pnpm --filter @aoagents/ao-web build`
  - 通过

### 上游 issue / PR

- Issue: https://github.com/ComposioHQ/agent-orchestrator/issues/1137
- PR: https://github.com/ComposioHQ/agent-orchestrator/pull/1138

### 未决风险 / 建议

- Web 与 CLI 的 builtin plugin 装配路径仍是两套逻辑，后续新增 agent / runtime 时容易再次只修一边
- reviewer 建议重点看 `packages/web/package.json`、`pnpm-lock.yaml` 与静态 registry 是否保持完全一致
