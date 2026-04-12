# Tools Runtime Guide

本文聚焦 AO Conductor Kit 里两个和 CEO 回调链路直接相关的工具：

- `tools/ao-event-sink.mjs`：接收 AO webhook，写入本地 JSONL inbox，并且可选转发到 channel bridge。
- `tools/ao-channel-bridge.mjs`：本地 HTTP + MCP Channels bridge，把 AO 事件推送进 Claude Code 当前会话。

如果你只想要最短路径，先看下面这套顺序：

1. 在仓库根目录执行一次 `npm ci`，安装 `@modelcontextprotocol/sdk`。
2. 在运行 `claude` 的那一侧配置 MCP server，把 `tools/ao-channel-bridge.mjs` 注册为 `ao-channel-bridge`。
3. 启动 Claude Code 时加 `--dangerously-load-development-channels server:ao-channel-bridge`。
4. 启动或重启 `tools/ao-event-sink.mjs`，并设置 `AO_EVENT_SINK_FORWARD_TO=http://127.0.0.1:8766/event`。
5. 向 event sink 发一个测试 webhook，确认 Claude Code 窗口里出现 `<channel source="ao-channel-bridge" ...>` 消息。

## 1. 安装依赖

命令环境：和运行 `claude`、`node tools/ao-channel-bridge.mjs` 相同的环境。

```bash
cd /path/to/ao-conductor-kit
npm ci
```

这一步只需要在首次使用 bridge 的机器上执行一次。后续只要 `package-lock.json` 没变，继续用 `npm ci` 即可复现出同一套依赖版本。

## 2. `ao-event-sink` 配置

`tools/ao-event-sink.mjs` 现在默认把事件写到仓库根目录下的 `.ao-inbox/events.jsonl`，不再依赖某一台机器上的固定 `D:\...` 或 `/mnt/d/...` 路径。

可用环境变量如下：

| 变量名                             | 默认值             | 说明                                           |
| ---------------------------------- | ------------------ | ---------------------------------------------- |
| `AO_EVENT_SINK_HOST`               | `127.0.0.1`        | HTTP 监听地址                                  |
| `AO_EVENT_SINK_PORT`               | `8765`             | HTTP 监听端口                                  |
| `AO_EVENT_SINK_DIR`                | `<repo>/.ao-inbox` | JSONL inbox 输出目录                           |
| `AO_EVENT_SINK_MAX_BODY_BYTES`     | `1048576`          | 单个 webhook 的最大 body 大小                  |
| `AO_EVENT_SINK_FORWARD_TO`         | 空                 | 可选；把归一化事件转发到 channel bridge 的 URL |
| `AO_EVENT_SINK_FORWARD_TIMEOUT_MS` | `3000`             | 转发请求超时                                   |

示例：

```bash
cd /path/to/ao-conductor-kit
export AO_EVENT_SINK_HOST=127.0.0.1
export AO_EVENT_SINK_PORT=8765
export AO_EVENT_SINK_DIR="$PWD/.ao-inbox"
export AO_EVENT_SINK_FORWARD_TO="http://127.0.0.1:8766/event"
node tools/ao-event-sink.mjs
```

健康检查：

```bash
curl http://127.0.0.1:8765/health
```

## 3. `ao-channel-bridge` 配置

`tools/ao-channel-bridge.mjs` 同时做两件事：

- 作为 Claude Code 的本地 stdio MCP server 启动，并声明 `claude/channel` 实验能力。
- 在本机打开一个 HTTP 端口，接收 event sink 转发过来的 `POST /event`。

可用环境变量如下：

| 变量名                                 | 默认值              | 说明                                                |
| -------------------------------------- | ------------------- | --------------------------------------------------- |
| `AO_CHANNEL_BRIDGE_HOST`               | `127.0.0.1`         | HTTP 监听地址                                       |
| `AO_CHANNEL_BRIDGE_PORT`               | `8766`              | HTTP 监听端口                                       |
| `AO_CHANNEL_BRIDGE_PATH`               | `/event`            | 接收 AO 事件的 POST 路径                            |
| `AO_CHANNEL_BRIDGE_HEALTH_PATH`        | `/health`           | 健康检查路径                                        |
| `AO_CHANNEL_BRIDGE_MAX_BODY_BYTES`     | `1048576`           | 单个事件的最大 body 大小                            |
| `AO_CHANNEL_BRIDGE_SERVER_NAME`        | `ao-channel-bridge` | Claude Code 里显示的 channel source 名称            |
| `AO_CHANNEL_BRIDGE_SERVER_VERSION`     | `0.1.0`             | MCP server version                                  |
| `AO_CHANNEL_BRIDGE_MAX_PENDING_EVENTS` | `200`               | Claude 还没 initialized 时的内存队列上限            |
| `AO_CHANNEL_BRIDGE_INCLUDE_RAW`        | `0`                 | 设为 `1` 时，把原始 payload 也塞进 channel 文本内容 |
| `AO_CHANNEL_BRIDGE_INSTRUCTIONS`       | 内置默认值          | 覆盖给 Claude Code 的 channel 使用说明              |

如果你只想在终端里单独验证 bridge 能监听 HTTP，可以直接运行：

```bash
cd /path/to/ao-conductor-kit
export AO_CHANNEL_BRIDGE_HOST=127.0.0.1
export AO_CHANNEL_BRIDGE_PORT=8766
NODE_ENV=production node tools/ao-channel-bridge.mjs
```

注意：真正把 channel 消息送进 Claude Code 时，推荐还是让 Claude 自己通过 MCP 配置拉起这个脚本，而不是手工长期常驻一个脱离 Claude 的独立进程。因为 Claude 会通过 stdio 保持和 bridge 的 MCP 会话，bridge 才能发送 `notifications/claude/channel`。

健康检查：

```bash
curl http://127.0.0.1:8766/health
```

## 4. Claude Code 注册步骤

根据 Claude Code 官方 Channels 文档，自定义开发态 channel server 需要：

1. 先在 MCP 配置里注册一个本地 server。
2. 启动 `claude` 时显式加 `--dangerously-load-development-channels server:<server-name>`。

如果你在 WSL 里运行 `claude`，就应该在 WSL 的 Claude 配置里使用 WSL 路径，例如 `/mnt/d/...`。如果你在 Windows 原生 shell 里运行 `claude`，就应该使用 Windows 绝对路径，例如 `D:\\...`。路径一定要和 `claude` 所在运行时一致。

WSL 示例：

```json
{
  "mcpServers": {
    "ao-channel-bridge": {
      "command": "node",
      "args": [
        "/mnt/d/脚本程序/agent-orchestrator/tools/ao-channel-bridge.mjs"
      ],
      "env": {
        "AO_CHANNEL_BRIDGE_HOST": "127.0.0.1",
        "AO_CHANNEL_BRIDGE_PORT": "8766",
        "AO_CHANNEL_BRIDGE_PATH": "/event",
        "AO_CHANNEL_BRIDGE_HEALTH_PATH": "/health"
      }
    }
  }
}
```

Windows 示例：

```json
{
  "mcpServers": {
    "ao-channel-bridge": {
      "command": "node",
      "args": [
        "D:\\脚本程序\\agent-orchestrator\\tools\\ao-channel-bridge.mjs"
      ],
      "env": {
        "AO_CHANNEL_BRIDGE_HOST": "127.0.0.1",
        "AO_CHANNEL_BRIDGE_PORT": "8766",
        "AO_CHANNEL_BRIDGE_PATH": "/event",
        "AO_CHANNEL_BRIDGE_HEALTH_PATH": "/health"
      }
    }
  }
}
```

启动 Claude Code：

```bash
claude --dangerously-load-development-channels server:ao-channel-bridge
```

普通的 `claude --channels ...` 只适用于已经安装或已允许的 channel 插件，不适用于这个 repository 里的本地开发态 bridge。

## 5. 端到端测试

仓库里带了一个可复现的本地 smoke test，会做下面这件事：

1. 用 MCP client 拉起 `tools/ao-channel-bridge.mjs`
2. 单独启动 `tools/ao-event-sink.mjs`
3. 往 sink 发一条模拟 AO webhook
4. 断言 bridge 收到了转发，并向 MCP client 发出了 `notifications/claude/channel`

运行命令：

```bash
cd /path/to/ao-conductor-kit
npm ci
node tools/test-ao-channel-bridge.mjs
```

如果成功，最后会打印：

```text
AO channel bridge smoke test passed.
```

## 6. 手工验证 webhook

如果你想在真实的 CEO Claude Code 会话里试一次，可以在 bridge 和 sink 都跑起来之后，往 sink 发下面这条测试事件：

```bash
curl -X POST http://127.0.0.1:8765/ \
  -H 'Content-Type: application/json' \
  -d '{
    "event": {
      "type": "review.pending",
      "sessionId": "kit-94",
      "data": {
        "issueId": "148",
        "prNumber": 17,
        "prUrl": "https://github.com/hahyihao/ao-conductor-kit/pull/17"
      }
    },
    "context": {
      "sessionId": "kit-94",
      "issueId": "148"
    }
  }'
```

成功后：

- `tools/ao-event-sink.mjs` 会返回 `forwarded: true`
- `.ao-inbox/events.jsonl` 会追加一条记录
- CEO 的 Claude Code 会话里会出现一条来自 `source="ao-channel-bridge"` 的 channel 消息
