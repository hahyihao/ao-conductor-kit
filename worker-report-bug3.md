# Bug3 Worker Report

## 1. Root Cause

`packages/web/src/lib/services.ts` 的静态 plugin import /
`registry.register()` 列表漏掉了
`@aoagents/ao-plugin-agent-codex`。web 端 `POST /api/orchestrators`
走的是 Next.js 兼容的静态注册路径，不是 CLI 那条动态
`loadBuiltins()` 路径，所以 codex agent 在 web API 下会报
`Agent plugin 'codex' not found`。

## 2. Actual Patch Scope

基于 `.bak` 对比确认，最小可上游 patch 一共 3 个文件：

- `packages/web/src/lib/services.ts`
  - 新增 `@aoagents/ao-plugin-agent-codex` 静态 import
  - 新增 `registry.register(pluginAgentCodex)`
- `packages/web/package.json`
  - 新增 workspace 依赖
    `@aoagents/ao-plugin-agent-codex: "workspace:*"`
- `pnpm-lock.yaml`
  - 为 `packages/web` importer 新增
    `@aoagents/ao-plugin-agent-codex` 对应的 workspace link

验证结论：

- `pnpm install --frozen-lockfile` 通过，说明当前 `package.json` 和
  lockfile 一致
- `pnpm --filter @aoagents/ao-web build` 通过，说明 web 侧静态 import /
  打包路径在依赖层面和构建层面成立

## 3. Lockfile Decision

纳入。理由有两点：

- 本地 AO 现状里 `pnpm-lock.yaml` 已出现与
  `packages/web/package.json` 对应的 importer diff，说明这不是纯文本依赖声明，
  而是实际 lockfile 变化
- 上游仓库多个 CI workflow 使用 `pnpm install --frozen-lockfile`，
  如果只提 `package.json` 和 `services.ts` 而不带 lockfile，
  依赖图很容易在 CI 或 fresh clone 上失配

## 4. Generated Patch File

`patches/ao-0.2.2-bug3-web-codex-plugin.patch`

## 5. Recommended Upstream References

- Issue: `https://github.com/ComposioHQ/agent-orchestrator/issues/1137`
- PR: `https://github.com/ComposioHQ/agent-orchestrator/pull/1138`
- 建议上游提交或评论直接引用 `Closes #1137`，并明确说明 patch 含
  `pnpm-lock.yaml`，因为该仓库 CI 使用 `pnpm install --frozen-lockfile`
