# bug-1 worker report

## 1) 根因

AO 0.2.2 的 `lifecycle-manager` 和 `ao status` 都把 session metadata 里的 `branch` 直接传给 `scm.detectPR()`。当 worker 在 spawn 后把分支从初始名改成 live worktree branch 时，metadata 里的 branch 会漂移，GitHub PR 检测继续查旧 branch，结果就是：

- `ao status` 的 `PR` / `CI` / `Rev` 长期显示 `-`
- lifecycle 进不了 `pr_open` / `ci_failed` / `review_*` 后续状态
- 依赖这些状态的 reaction 和通知链路一起失效

这个根因和上游 `#368`、`#545`、`PR #544` 的分析一致，并且适配本地 0.2.2 代码结构。

## 2) 改了哪些文件

- `/root/agent-orchestrator/packages/core/src/lifecycle-manager.ts`
  - 在 PR autodetect 前读取 live worktree branch
  - 把 live branch 传给 `scm.detectPR()`
  - 检测到 metadata branch 漂移时，自愈更新 session metadata 里的 `branch`
- `/root/agent-orchestrator/packages/cli/src/commands/status.ts`
  - 在 `ao status` 里把 live branch 透传给 `scm.detectPR()`
- `/root/agent-orchestrator/packages/core/src/__tests__/lifecycle-manager.test.ts`
  - 新增 lifecycle 用 live worktree branch autodetect PR 并自愈 metadata 的测试
- `/root/agent-orchestrator/packages/cli/__tests__/commands/status.test.ts`
  - 新增 `ao status` 用 live branch 查 PR 而不是 stale metadata branch 的测试

## 3) 测试/验证结果

已执行：

- `pnpm --dir /root/agent-orchestrator --filter @aoagents/ao-core test -- src/__tests__/lifecycle-manager.test.ts`
  - 通过，`56 passed`
- `pnpm --dir /root/agent-orchestrator --filter @aoagents/ao-cli test -- __tests__/commands/status.test.ts`
  - 通过，`33 passed`
- `pnpm --dir /root/agent-orchestrator --filter @aoagents/ao-core typecheck`
  - 通过
- `pnpm --dir /root/agent-orchestrator --filter @aoagents/ao-cli typecheck`
  - 通过

## 4) 生成的 patch 文件路径

- `/root/.worktrees/ao-kit-slot-2/kit2-1/patches/ao-0.2.2-bug1-live-branch-pr-detection.patch`

## 5) 推荐引用的上游 issue/PR 链接

- https://github.com/ComposioHQ/agent-orchestrator/issues/368
- https://github.com/ComposioHQ/agent-orchestrator/issues/545
- https://github.com/ComposioHQ/agent-orchestrator/pull/544
