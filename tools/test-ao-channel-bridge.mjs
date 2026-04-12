#!/usr/bin/env node

import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import net from "node:net";
import os from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const ROOT_DIR = resolve(dirname(fileURLToPath(import.meta.url)), "..");

async function getAvailablePort() {
  return new Promise((resolvePort, reject) => {
    const server = net.createServer();
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      if (!address || typeof address === "string") {
        server.close(() => reject(new Error("Failed to allocate a test port")));
        return;
      }

      const { port } = address;
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolvePort(port);
      });
    });
    server.on("error", reject);
  });
}

async function waitForHealth(url, timeoutMs = 5000) {
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    try {
      const response = await fetch(url);
      if (response.ok) {
        return await response.json();
      }
    } catch {
      // Retry until timeout.
    }
    await new Promise((resolveWait) => setTimeout(resolveWait, 100));
  }

  throw new Error(`Timed out waiting for ${url}`);
}

async function terminateChild(child) {
  if (!child || child.exitCode !== null || child.killed) {
    return;
  }

  await new Promise((resolveStop) => {
    const timeout = setTimeout(() => {
      child.kill("SIGKILL");
    }, 2000);

    child.once("exit", () => {
      clearTimeout(timeout);
      resolveStop();
    });

    child.kill("SIGTERM");
  });
}

async function main() {
  const sinkPort = await getAvailablePort();
  const bridgePort = await getAvailablePort();
  const inboxDir = await mkdtemp(join(os.tmpdir(), "ao-channel-bridge-"));
  const notifications = [];
  const bridgeLogs = [];
  const sinkLogs = [];

  const bridgeTransport = new StdioClientTransport({
    command: "node",
    args: [resolve(ROOT_DIR, "tools/ao-channel-bridge.mjs")],
    cwd: ROOT_DIR,
    stderr: "pipe",
    env: {
      AO_CHANNEL_BRIDGE_HOST: "127.0.0.1",
      AO_CHANNEL_BRIDGE_PORT: String(bridgePort),
      AO_CHANNEL_BRIDGE_PATH: "/event",
      AO_CHANNEL_BRIDGE_HEALTH_PATH: "/health",
      AO_CHANNEL_BRIDGE_SERVER_NAME: "ao-channel-bridge",
      AO_CHANNEL_BRIDGE_MAX_PENDING_EVENTS: "20",
    },
  });

  bridgeTransport.stderr?.on("data", (chunk) => {
    bridgeLogs.push(chunk.toString("utf8"));
  });

  const client = new Client({ name: "ao-channel-bridge-smoke-test", version: "1.0.0" }, { capabilities: {} });
  client.fallbackNotificationHandler = async (notification) => {
    notifications.push(notification);
  };

  let sinkProcess;

  try {
    await client.connect(bridgeTransport);
    const bridgeHealth = await waitForHealth(`http://127.0.0.1:${bridgePort}/health`);
    assert.equal(bridgeHealth.ok, true);
    assert.equal(bridgeHealth.serverName, "ao-channel-bridge");

    sinkProcess = spawn("node", [resolve(ROOT_DIR, "tools/ao-event-sink.mjs")], {
      cwd: ROOT_DIR,
      env: {
        ...process.env,
        AO_EVENT_SINK_HOST: "127.0.0.1",
        AO_EVENT_SINK_PORT: String(sinkPort),
        AO_EVENT_SINK_DIR: inboxDir,
        AO_EVENT_SINK_FORWARD_TO: `http://127.0.0.1:${bridgePort}/event`,
        AO_EVENT_SINK_FORWARD_TIMEOUT_MS: "3000",
      },
      stdio: ["ignore", "pipe", "pipe"],
    });

    sinkProcess.stdout.on("data", (chunk) => {
      sinkLogs.push(chunk.toString("utf8"));
    });
    sinkProcess.stderr.on("data", (chunk) => {
      sinkLogs.push(chunk.toString("utf8"));
    });

    const sinkHealth = await waitForHealth(`http://127.0.0.1:${sinkPort}/health`);
    assert.equal(sinkHealth.ok, true);
    assert.equal(sinkHealth.forwardTo, `http://127.0.0.1:${bridgePort}/event`);

    const payload = {
      event: {
        type: "review.changes_requested",
        sessionId: "kit-94",
        data: {
          issueId: "148",
          prNumber: 17,
          prUrl: "https://github.com/hahyihao/ao-conductor-kit/pull/17",
          reactionKey: "changes-requested",
          newStatus: "changes_requested",
        },
      },
      context: {
        sessionId: "kit-94",
        issueId: "148",
      },
    };

    const sinkResponse = await fetch(`http://127.0.0.1:${sinkPort}/`, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=utf-8" },
      body: JSON.stringify(payload),
    });
    const sinkResult = await sinkResponse.json();
    assert.equal(sinkResponse.status, 202);
    assert.equal(sinkResult.forwarded, true);

    const deadline = Date.now() + 5000;
    while (notifications.length === 0 && Date.now() < deadline) {
      await new Promise((resolveWait) => setTimeout(resolveWait, 50));
    }

    assert.equal(notifications.length > 0, true, `No channel notification received.\nBridge logs:\n${bridgeLogs.join("")}`);
    const channelNotification = notifications.find((notification) => notification.method === "notifications/claude/channel");
    assert.ok(channelNotification, `Expected notifications/claude/channel notification.\nSink logs:\n${sinkLogs.join("")}`);
    assert.match(channelNotification.params.content, /AO callback received\./);
    assert.match(channelNotification.params.content, /review\.changes_requested/);
    assert.equal(channelNotification.params.meta.event_type, "review.changes_requested");
    assert.equal(channelNotification.params.meta.pr_number, "17");
    assert.equal(channelNotification.params.meta.review_status, "changes_requested");

    const eventsJsonl = await readFile(join(inboxDir, "events.jsonl"), "utf8");
    assert.match(eventsJsonl, /review\.changes_requested/);

    console.log("AO channel bridge smoke test passed.");
  } finally {
    await terminateChild(sinkProcess);
    await client.close().catch(() => {});
    await bridgeTransport.close().catch(() => {});
    await rm(inboxDir, { recursive: true, force: true }).catch(() => {});
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack || error.message : String(error));
  process.exit(1);
});
