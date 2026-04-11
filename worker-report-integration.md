# integration worker report

## 1) 写了哪些最终文件

- `patches/ao-0.2.2-bug1-live-branch-pr-detection.patch`
- `patches/ao-0.2.2-bug2-send-paste-race.patch`
- `patches/ao-0.2.2-bug3-web-codex-plugin.patch`
- `docs/troubleshooting/ao-production-bugs.md`
- `worker-report-integration.md`

## 2) bug1 / bug2 / bug3 分别引用了哪些来源

### bug1

- patch 来源：`/root/.worktrees/ao-kit-slot-2/kit2-1/patches/ao-0.2.2-bug1-live-branch-pr-detection.patch`
- 报告来源：`/root/.worktrees/ao-kit-slot-2/kit2-1/worker-report-bug1.md`

### bug2

- 报告来源：`/root/.worktrees/ao-kit-slot-2/kit2-2/worker-report-bug2.md`
- source-of-truth patch 来源：共享 AO 当前 diff
  - `packages/plugins/runtime-tmux/src/index.ts`
  - `packages/plugins/runtime-tmux/src/__tests__/index.test.ts`
- 我把共享 AO diff 导出到当前 worktree：
  - `patches/ao-0.2.2-bug2-send-paste-race.patch`
- 一致性校验：
  - 当前 worktree 导出的 bug2 patch 与 `kit2-2` 产出的 patch 做了 `cmp`
  - 结果：一致，退出码 `0`

### bug3

- patch 来源：`/root/.worktrees/ao-kit-slot-2/kit2-3/patches/ao-0.2.2-bug3-web-codex-plugin.patch`
- 报告来源：`/root/.worktrees/ao-kit-slot-2/kit2-3/worker-report-bug3.md`

## 3) 如果 bug2 由我补做验证，命令和结果

- 本次没有重复执行 bug2 的功能测试或 typecheck
- 原因：`kit2-2` 已提供通过记录，且我确认最终交付 patch 与共享 AO 当前 diff 一致
- 我自己额外做的只是 patch 一致性校验，不是重新跑功能验证：
  - `cmp -s /root/.worktrees/ao-kit-slot-2/kit2-2/patches/ao-0.2.2-bug2-send-paste-race.patch <(git -C /root/agent-orchestrator diff -- packages/plugins/runtime-tmux/src/index.ts packages/plugins/runtime-tmux/src/__tests__/index.test.ts)`
  - 结果：退出码 `0`

## 4) 建议 reviewer 重点看什么

- bug1：live worktree branch 优先于 stale metadata branch 的逻辑是否同时覆盖 `ao status` 和 lifecycle，并且 metadata 自愈不会误伤其它 session 状态
- bug2：runtime tmux patch 是否真正消除了“已 paste 但未 submit 仍被当作成功”的窗口，特别是多行和 Windows 路径反斜杠消息场景
- bug3：web 静态 registry、`packages/web/package.json` 和 `pnpm-lock.yaml` 是否保持一致，确保 `pnpm install --frozen-lockfile` 与 web build 都成立
