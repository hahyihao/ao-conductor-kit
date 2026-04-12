# CEO Callback Channel

This guide documents the current CEO <-> AO callback path used in this repository.

The committed source of truth is:

- `tools/ao-event-sink.mjs`
- AO's built-in `webhook` notifier plugin

Important:

- This repo ships the local event sink and the AO-side webhook delivery pattern.
- This repo does not ship your personal Claude Code inbox bridge or `~/.claude/settings.json`.
- Merge the example snippets below into your own config manually. Do not replace your real config files blindly.

## What The Callback Channel Does

The callback channel gives the CEO an async status inbox for worker events.

The flow is:

1. AO emits lifecycle events through `notifier-webhook`.
2. The local sink accepts the webhook POST and appends a normalized record to `.ao-inbox/events.jsonl`.
3. A separate Claude Code `UserPromptSubmit` hook reads unread events from that JSONL file.
4. The hook tracks progress in `.ao-inbox/cursor`.
5. On the CEO's next prompt, the hook injects a short callback summary as `additionalContext`.

That means this behaves like a local, file-backed version of Claude Code Agent tool `run_in_background`: updates arrive asynchronously, but the CEO sees them on the next interaction rather than as a live interrupt in the middle of the current turn.

## Architecture Overview

```text
AO lifecycle worker / orchestrator
        |
        | notifier-webhook POST
        v
http://127.0.0.1:8765/
  tools/ao-event-sink.mjs
        |
        | normalize + append
        v
.ao-inbox/events.jsonl
        ^
        | read unread events
        |
.ao-inbox/cursor  <---- UserPromptSubmit bridge script
        |
        | returns additionalContext
        v
Claude Code CEO session
        |
        | next CEO prompt
        v
system-reminder style callback context
```

## What Is Implemented Today

Implemented in this repo:

- AO can send webhook notifications to a configured URL through the `webhook` notifier plugin.
- `tools/ao-event-sink.mjs` listens on `127.0.0.1:8765` by default.
- The sink writes normalized JSONL records to `.ao-inbox/events.jsonl`.
- The sink exposes `GET /health` and accepts `POST /`.

Not implemented in this repo as committed code:

- The `.ao-inbox/cursor` consumer state file
- The personal Claude Code `UserPromptSubmit` hook
- The bridge script that reads unread events and returns `additionalContext`

Those pieces are still part of the operating model for this callback channel, but they are user-managed glue, not shipped repository code.

## Start The Local Event Sink

Background start:

```bash
./tools/start-ao-event-sink.sh
```

Foreground start:

```bash
node tools/ao-event-sink.mjs
```

Useful environment variables:

```bash
AO_EVENT_SINK_HOST=127.0.0.1
AO_EVENT_SINK_PORT=8765
AO_EVENT_SINK_DIR=/mnt/d/脚本程序/agent-orchestrator/.ao-inbox
AO_EVENT_SINK_MAX_BODY_BYTES=1048576
```

Health check:

```bash
curl http://127.0.0.1:8765/health
```

Expected response:

```json
{
  "ok": true,
  "inboxDir": "/mnt/d/脚本程序/agent-orchestrator/.ao-inbox",
  "eventsFile": "/mnt/d/脚本程序/agent-orchestrator/.ao-inbox/events.jsonl"
}
```

## Directory Convention

Use one inbox directory that both AO and the Claude-side bridge can see.

| Purpose     | WSL view                                                    | Windows view                                            |
| ----------- | ----------------------------------------------------------- | ------------------------------------------------------- |
| Event log   | `/mnt/d/脚本程序/agent-orchestrator/.ao-inbox/events.jsonl` | `D:\脚本程序\agent-orchestrator\.ao-inbox\events.jsonl` |
| Cursor file | `/mnt/d/脚本程序/agent-orchestrator/.ao-inbox/cursor`       | `D:\脚本程序\agent-orchestrator\.ao-inbox\cursor`       |

Note on the Windows path in issue text:

- You may see `D:\脚本程序^Ggent-orchestrator\...` in some escaped renderings because `\a` can be displayed as a bell escape.
- The actual directory name on disk is `agent-orchestrator`.

Also note:

- `events.jsonl` is written by the sink.
- `cursor` is owned by your bridge script, not by the sink.

## `agent-orchestrator.yaml` Example

Merge this into your real config manually.

```yaml
defaults:
  notifiers:
    - webhook

notifiers:
  webhook:
    plugin: webhook
    url: http://127.0.0.1:8765/
```

How this maps to the current implementation:

- `defaults.notifiers` enables the named notifier for AO events.
- `notifiers.webhook.plugin` must be `webhook`.
- `notifiers.webhook.url` is the sink endpoint.
- The built-in webhook notifier always POSTs JSON. You do not need a separate `method` field for the current implementation.

If you already use other notifiers, append `webhook` instead of replacing the list.

## Event Schema

The sink normalizes incoming webhook payloads into one JSON object per line in `events.jsonl`.

Current normalized shape:

```json
{
  "receivedAt": "2026-04-12T15:20:31.456Z",
  "source": "ao-webhook",
  "eventType": "review.pending",
  "session": "kit-32",
  "issue": "32",
  "pr": {
    "number": 150,
    "url": "https://github.com/hahyihao/ao-conductor-kit/pull/150",
    "status": "review_pending"
  },
  "ci": {
    "status": "passing"
  },
  "review": {
    "status": "pending"
  },
  "summary": "review.pending session=kit-32 issue=32 pr=#150 prStatus=review_pending ci=passing review=pending",
  "raw": {
    "type": "notification",
    "event": {
      "id": "evt_123",
      "type": "review.pending",
      "priority": "action",
      "sessionId": "kit-32",
      "projectId": "ao-kit",
      "timestamp": "2026-04-12T15:20:31.000Z",
      "message": "PR is ready for review",
      "data": {
        "issueId": "32",
        "prNumber": 150,
        "prUrl": "https://github.com/hahyihao/ao-conductor-kit/pull/150"
      }
    }
  }
}
```

Field notes:

- `receivedAt` is when the sink appended the record.
- `source` is always `ao-webhook`.
- `eventType` comes from the webhook event type.
- `session` and `issue` are best-effort extracted fields and may be `null`.
- `pr`, `ci`, and `review` are inferred convenience objects and may be `null`.
- `summary` is the best short string for the CEO-side bridge to inject.
- `raw` preserves the original webhook payload for debugging or richer formatting later.

The sink currently recognizes three webhook payload families:

- `notification`
- `notification_with_actions`
- `message`

Action buttons are preserved under `raw.actions`; the sink does not project them to top-level normalized fields.

## Example Claude Code Hook Wiring

Claude Code's `UserPromptSubmit` hook is the piece that turns the inbox into next-turn callback context.

Merge this into your real `~/.claude/settings.json` manually.

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "AO_INBOX_DIR=/mnt/d/脚本程序/agent-orchestrator/.ao-inbox python3 ~/.claude/hooks/ao_inbox_bridge.py"
          }
        ]
      }
    ]
  }
}
```

This repo does not ship `~/.claude/hooks/ao_inbox_bridge.py`. The snippet above is an example hook entry only.

## Example Bridge Script

The bridge below is an example, not committed repo code. It uses a line-count cursor so the CEO only sees new events once.

```python
#!/usr/bin/env python3
import json
import os
from pathlib import Path

inbox_dir = Path(os.environ.get("AO_INBOX_DIR", "/mnt/d/脚本程序/agent-orchestrator/.ao-inbox"))
events_file = inbox_dir / "events.jsonl"
cursor_file = inbox_dir / "cursor"

if not events_file.exists():
    raise SystemExit(0)

lines = events_file.read_text(encoding="utf-8").splitlines()
cursor = int(cursor_file.read_text(encoding="utf-8").strip()) if cursor_file.exists() else 0

if cursor < 0:
    cursor = 0
if cursor > len(lines):
    cursor = 0

new_lines = lines[cursor:]
if not new_lines:
    raise SystemExit(0)

records = [json.loads(line) for line in new_lines[-10:]]
summary_lines = []
for record in records:
    summary_lines.append(
        f"- {record.get('summary') or record.get('eventType') or 'unknown event'}"
    )

cursor_file.parent.mkdir(parents=True, exist_ok=True)
cursor_file.write_text(str(len(lines)), encoding="utf-8")

payload = {
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": "AO callback inbox updates since your last prompt:\\n"
        + "\\n".join(summary_lines)
    }
}

print(json.dumps(payload))
```

Why this works:

- The sink appends newline-delimited JSON records.
- The bridge remembers how many lines it has already consumed in `.ao-inbox/cursor`.
- On the next CEO prompt, Claude Code receives the unread summaries as `additionalContext`.

If you prefer a byte-offset cursor instead of a line-count cursor, keep the bridge and troubleshooting rules consistent with that choice.

## How The CEO Reads Callback Events

There are two ways the CEO consumes the inbox.

Normal path:

1. The CEO submits the next prompt.
2. The `UserPromptSubmit` bridge reads unread records from `events.jsonl`.
3. The bridge advances `.ao-inbox/cursor`.
4. The bridge returns a short callback digest as `additionalContext`.
5. Claude sees that digest on the next turn and can react to new PRs, CI failures, or review events.

Manual fallback:

```bash
tail -n 20 /mnt/d/脚本程序/agent-orchestrator/.ao-inbox/events.jsonl
```

For manual triage, focus on:

- `summary`
- `session`
- `issue`
- `pr`
- `ci`
- `review`

When the summary is too thin, inspect `raw`.

## Quick End-To-End Test

1. Start the sink.
2. Confirm `curl http://127.0.0.1:8765/health` returns `ok: true`.
3. Add the webhook notifier config.
4. Send a synthetic event:

```bash
curl -sS -X POST http://127.0.0.1:8765/ \
  -H 'Content-Type: application/json' \
  -d '{
    "type": "message",
    "message": "callback test",
    "context": {
      "sessionId": "ceo",
      "issue": "32"
    }
  }'
```

5. Confirm `.ao-inbox/events.jsonl` grows.
6. Submit any CEO prompt and verify the hook injects the unread callback summary.

## Troubleshooting

### Sink Not Receiving POSTs

Symptoms:

- `curl /health` works, but no AO events arrive.

Checks:

- Confirm `defaults.notifiers` includes `webhook`.
- Confirm the notifier config is exactly `plugin: webhook` plus a reachable `url`.
- Confirm the URL points to the sink host and port that are actually running.
- Run the sink in the foreground with `node tools/ao-event-sink.mjs` while testing so you can see startup output immediately.
- Verify the sink only accepts `POST /` and `GET /health`.

### JSONL File Not Growing

Symptoms:

- The sink is running, but `events.jsonl` is missing or stays unchanged.

Checks:

- Send the synthetic `curl` POST above first. If that does not append, the problem is local to the sink or path.
- Verify `AO_EVENT_SINK_DIR` points at a writable directory.
- The sink creates the inbox directory automatically, but it still needs filesystem permission to write there.
- If a POST returns `written: false`, inspect the returned `error` field.

### Cursor Stuck Or Replaying Old Events

Symptoms:

- The CEO keeps seeing the same callback digest.
- Or the CEO stops seeing new events even though `events.jsonl` keeps growing.

Checks:

- Remember that `cursor` belongs to the bridge, not the sink.
- Make sure the bridge updates `.ao-inbox/cursor` only after it successfully formats the unread events.
- If you use the line-count example and `events.jsonl` was truncated or rotated, reset the cursor to `0`.
- If you change cursor strategy later, update both the bridge logic and the troubleshooting assumptions together.

### Claude Hook Not Injecting Context

Symptoms:

- The inbox file grows, but Claude does not mention callback updates on the next prompt.

Checks:

- Confirm the hook is registered under `UserPromptSubmit`.
- Confirm the hook command path is correct and executable.
- Confirm the hook exits successfully.
- For the example bridge, confirm it prints valid JSON with `hookSpecificOutput.hookEventName = "UserPromptSubmit"` and `hookSpecificOutput.additionalContext`.
- If you choose stdout-only delivery instead of structured JSON, remember that the hook must still succeed for Claude to inject that output as context.

### Windows vs WSL Path Mismatch

Symptoms:

- AO writes events, but the Claude-side hook sees an empty inbox.

Checks:

- If the sink runs in WSL, the bridge should usually read the WSL path, not the Windows path string.
- Keep both sides pointed at the same physical directory.
- The default shipped sink path is `/mnt/d/脚本程序/agent-orchestrator/.ao-inbox`, which corresponds to `D:\脚本程序\agent-orchestrator\.ao-inbox` on Windows.
- If you customize `AO_EVENT_SINK_DIR`, update the hook config to match.

## Comparison To `run_in_background`

The analogy is useful, but it is not exact.

Similar to Claude Code Agent tool `run_in_background`:

- Worker progress is captured asynchronously.
- The CEO can keep moving and pick up the result later.
- The next interaction can include a concise reminder that something finished or failed.

Different from `run_in_background`:

- This implementation is local-file based, not a built-in Claude transport.
- Nothing is injected mid-turn; the CEO sees updates on the next prompt.
- The callback quality depends on your sink, cursor, and hook wiring.
- The sink only normalizes and stores events. The "inbox to prompt context" bridge is your own hook layer.

That is the intended mental model: "async callback on next turn", not "live push into the current answer".

## Recommended Operating Rule

Treat the sink and the bridge as separate responsibilities:

- AO webhook delivery writes durable records to `events.jsonl`.
- The CEO-side bridge decides how much unread context to surface and when to advance `cursor`.

That separation makes debugging much easier:

- If `events.jsonl` is wrong, fix AO or the sink.
- If `events.jsonl` is correct but Claude sees nothing, fix the bridge or `UserPromptSubmit` wiring.
