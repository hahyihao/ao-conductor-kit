# path-sanitization worker report

PR: #62

## 0) 适配定位

这个 patch 不适用于裸 `@composio/ao@0.2.2` 标签。

复核结果：

- 在 `@composio/ao@0.2.2` 上做 patch 预检会失败，因为目标文件
  `packages/core/src/agent-workspace-hooks.ts` 与对应测试文件当时还不存在。
- 这个 patch 已在 2026-04-12 的 upstream `main` checkout 上验证通过；当时
  `/root/agent-orchestrator` 的提交是
  `2ebe111af002a19566dd03c96b7c9dbb817f000c`，版本描述输出是
  `@composio/ao-cli@0.2.2-386-g2ebe111a`。

因此，本 PR 把 artifact 改名为
`patches/ao-main-2ebe111a-sanitize-windows-path.patch`，避免继续误导成
“AO 0.2.2 patch”。

## 1) 根因

这是一个 Mode B 单 worker 任务，适合单 PR 收口。

`/root/agent-orchestrator/packages/core/src/agent-workspace-hooks.ts` 里的 `buildAgentPath(process.env["PATH"])` 会把当前 WSL shell 继承到的 PATH 原样带进 agent/orchestrator 环境。现网 PATH 里包含 `/mnt/c/...`、`/mnt/d/...` 这类 WSL 翻译后的 Windows PATH 片段，所以 AO 为 agent 构造的新 PATH 也会继续带着这些污染项，进而触发 orchestrator 启动时的 Windows PATH 污染告警。

共享 helper 被 `agent-codex`、`agent-cursor`、`agent-opencode`、`agent-aider` 复用，所以最小且正确的修复点就是 `buildAgentPath()` 本身。

## 2) 改了哪些文件

- `/root/agent-orchestrator/packages/core/src/agent-workspace-hooks.ts`
  - 在 `buildAgentPath()` 中新增最小 sanitization：过滤 `^/mnt/<drive-letter>/...` 形式的 WSL Windows PATH 项
  - 保留原有的顺序、去重、`~/.ao/bin` 置前、`/usr/local/bin` 提前逻辑
- `/root/agent-orchestrator/packages/core/src/__tests__/agent-workspace-hooks.test.ts`
  - 新增“去掉 `/mnt/c`、`/mnt/d` 污染项”的定向单测
  - 新增“保留非 drive-letter 的 `/mnt/*` Linux 路径”的保护性单测，避免误伤
- `/root/agent-orchestrator/packages/plugins/agent-codex/src/index.test.ts`
  - 新增 agent env 级别断言，验证 Codex 环境里生成的 PATH 已不再包含 WSL Windows PATH 片段
- `patches/ao-main-2ebe111a-sanitize-windows-path.patch`
  - vendored patch artifact
- `INSTALL.md`
  - 增加 operator-facing 应用步骤，说明这个 patch 只面向 post-0.2.2 的 upstream `main` checkout
- `TROUBLESHOOTING.md`
  - 增加 PATH 污染 warning 的症状、根因、应用 patch 的修复路径与兼容性边界
- `ROADMAP.md`
  - 将 tech debt #2 更新为“已接入 kit 工作流”，并注明是通过 patch + 文档落地，而不是宣称 `0.2.2` 已原生修复

## 3) 测试/验证结果

已执行：

- `pnpm --dir /root/agent-orchestrator --filter @aoagents/ao-core test -- src/__tests__/agent-workspace-hooks.test.ts`
  - 通过，`1 passed`, `10 passed`
- `pnpm --dir /root/agent-orchestrator --filter @aoagents/ao-core build`
  - 通过
  - 说明：`agent-codex` 测试依赖 `@aoagents/ao-core/dist`，先 build 才能让插件测试拿到新的 shared helper 实现
- `pnpm --dir /root/agent-orchestrator --filter @aoagents/ao-plugin-agent-codex test -- src/index.test.ts`
  - 通过，`1 passed`, `143 passed`
- `node --input-type=module -e "import { buildAgentPath } from '/root/agent-orchestrator/packages/core/dist/index.js'; const polluted='/mnt/c/Users/Administrator/bin:/usr/local/bin:/usr/bin:/mnt/d/Program Files/Git/usr/bin:/bin'; const result=buildAgentPath(polluted); console.log(result); if (result.includes('/mnt/c/') || result.includes('/mnt/d/')) process.exit(1);"`
  - 通过
  - 输出：`/root/.ao/bin:/usr/local/bin:/usr/bin:/bin`
- 对 `@composio/ao@0.2.2` 做 patch 预检
  - 失败，目标文件不存在，说明这不是 `0.2.2` patch
- 对 2026-04-12 验证过的 upstream `main@2ebe111a` 快照做 patch 预检
  - 通过，说明当前 artifact 与重命名后的版本定位一致

## 4) patch 路径

- `patches/ao-main-2ebe111a-sanitize-windows-path.patch`

## 5) 为什么这能消掉 warning

warning 的直接来源不是 wrapper 脚本本身，而是 agent/orchestrator 启动时拿到的 PATH 里仍然混入了 `/mnt/<drive>/...` 的 Windows 路径片段。现在 `buildAgentPath()` 在共享入口处就把这些污染项剔掉，所以之后由 AO 构造出来的 agent PATH 不再包含 `/mnt/c/...`、`/mnt/d/...` 这类条目。

也就是说，orchestrator/agent 看到的是“AO wrapper 目录 + Linux 常规 PATH”的干净结果，而不是“Linux PATH + WSL 翻译后的 Windows PATH”。因此启动时针对 Windows PATH 污染的检查将不再命中这些条目，warning 会消失。
