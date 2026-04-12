#!/usr/bin/env node

import http from "node:http";
import process from "node:process";

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

import { coerceAoRecord } from "./lib/ao-event-record.mjs";

const HOST = process.env.AO_CHANNEL_BRIDGE_HOST || "127.0.0.1";
const PORT = Number.parseInt(process.env.AO_CHANNEL_BRIDGE_PORT || "8766", 10);
const MAX_BODY_BYTES = Number.parseInt(process.env.AO_CHANNEL_BRIDGE_MAX_BODY_BYTES || "1048576", 10);
const SERVER_NAME = process.env.AO_CHANNEL_BRIDGE_SERVER_NAME || "ao-channel-bridge";
const SERVER_VERSION = process.env.AO_CHANNEL_BRIDGE_SERVER_VERSION || "0.1.0";
const MAX_PENDING_EVENTS = Number.parseInt(process.env.AO_CHANNEL_BRIDGE_MAX_PENDING_EVENTS || "200", 10);
const EVENT_PATH = normalizePath(process.env.AO_CHANNEL_BRIDGE_PATH || "/event");
const HEALTH_PATH = normalizePath(process.env.AO_CHANNEL_BRIDGE_HEALTH_PATH || "/health");
const INCLUDE_RAW = process.env.AO_CHANNEL_BRIDGE_INCLUDE_RAW === "1";
const INSTRUCTIONS =
  process.env.AO_CHANNEL_BRIDGE_INSTRUCTIONS ||
  [
    `This server emits AO orchestration callbacks through Claude Code channels as <channel source="${SERVER_NAME}" ...>.`,
    "Treat channel notifications as authoritative AO state updates.",
    "Useful metadata attributes are event_type, session, issue, pr_number, pr_status, ci_status, review_status, and pr_url.",
    "The server is one-way only. Do not try to reply through this channel server.",
  ].join(" ");

const bridgeServer = new Server(
  { name: SERVER_NAME, version: SERVER_VERSION },
  {
    capabilities: {
      experimental: {
        "claude/channel": {},
      },
    },
    instructions: INSTRUCTIONS,
  },
);

const transport = new StdioServerTransport();
const pendingEvents = [];
let droppedEvents = 0;
let bridgeReady = false;
let httpServer;

bridgeServer.oninitialized = () => {
  bridgeReady = true;
  void flushPendingEvents();
};

function normalizePath(value) {
  if (!value || value === "/") {
    return "/";
  }
  return value.startsWith("/") ? value : `/${value}`;
}

function logError(message, error = null) {
  const details = error instanceof Error ? error.message : error ? String(error) : null;
  console.error(`[ao-channel-bridge] ${message}${details ? `: ${details}` : ""}`);
}

function pushPendingEvent(record) {
  pendingEvents.push(record);
  while (pendingEvents.length > MAX_PENDING_EVENTS) {
    pendingEvents.shift();
    droppedEvents += 1;
  }
}

function setMeta(meta, key, value) {
  if (value === null || value === undefined || value === "") {
    return;
  }
  meta[key] = String(value);
}

function buildChannelMeta(record) {
  const meta = {};

  setMeta(meta, "event_type", record.eventType);
  setMeta(meta, "session", record.session);
  setMeta(meta, "issue", record.issue);
  setMeta(meta, "received_at", record.receivedAt);
  setMeta(meta, "pr_number", record.pr?.number);
  setMeta(meta, "pr_status", record.pr?.status);
  setMeta(meta, "pr_url", record.pr?.url);
  setMeta(meta, "ci_status", record.ci?.status);
  setMeta(meta, "review_status", record.review?.status);

  return meta;
}

function buildChannelContent(record) {
  const lines = [
    "AO callback received.",
    `Type: ${record.eventType || "unknown"}`,
    `Summary: ${record.summary || "No summary provided"}`,
  ];

  if (record.session) lines.push(`Session: ${record.session}`);
  if (record.issue) lines.push(`Issue: ${record.issue}`);
  if (record.pr?.number !== null && record.pr?.number !== undefined) lines.push(`PR: #${record.pr.number}`);
  if (record.pr?.status) lines.push(`PR status: ${record.pr.status}`);
  if (record.pr?.url) lines.push(`PR URL: ${record.pr.url}`);
  if (record.ci?.status) lines.push(`CI status: ${record.ci.status}`);
  if (record.review?.status) lines.push(`Review status: ${record.review.status}`);
  if (record.receivedAt) lines.push(`Received at: ${record.receivedAt}`);

  if (INCLUDE_RAW && record.raw !== undefined) {
    lines.push("", "Raw payload:", JSON.stringify(record.raw, null, 2));
  }

  return lines.join("\n");
}

async function sendChannelNotification(record) {
  await bridgeServer.notification({
    method: "notifications/claude/channel",
    params: {
      content: buildChannelContent(record),
      meta: buildChannelMeta(record),
    },
  });
}

async function dispatchRecord(record) {
  if (!bridgeReady) {
    pushPendingEvent(record);
    return {
      delivered: false,
      queued: true,
      queueDepth: pendingEvents.length,
    };
  }

  try {
    await sendChannelNotification(record);
    return {
      delivered: true,
      queued: false,
      queueDepth: pendingEvents.length,
    };
  } catch (error) {
    pushPendingEvent(record);
    logError("Failed to deliver channel notification, queued for retry", error);
    return {
      delivered: false,
      queued: true,
      queueDepth: pendingEvents.length,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

async function flushPendingEvents() {
  while (bridgeReady && pendingEvents.length > 0) {
    const nextRecord = pendingEvents.shift();
    if (!nextRecord) {
      continue;
    }
    try {
      await sendChannelNotification(nextRecord);
    } catch (error) {
      pendingEvents.unshift(nextRecord);
      logError("Failed to flush queued event", error);
      break;
    }
  }
}

function sendJson(res, statusCode, payload) {
  if (res.writableEnded) return;
  res.writeHead(statusCode, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(payload));
}

function createHttpServer() {
  return http.createServer((req, res) => {
    if (req.method === "GET" && req.url === HEALTH_PATH) {
      sendJson(res, 200, {
        ok: true,
        host: HOST,
        port: PORT,
        path: EVENT_PATH,
        healthPath: HEALTH_PATH,
        ready: bridgeReady,
        queuedEvents: pendingEvents.length,
        droppedEvents,
        serverName: SERVER_NAME,
      });
      return;
    }

    if (req.method !== "POST" || req.url !== EVENT_PATH) {
      sendJson(res, 404, {
        ok: false,
        error: `Only POST ${EVENT_PATH} and GET ${HEALTH_PATH} are supported`,
      });
      return;
    }

    const chunks = [];
    let size = 0;
    let aborted = false;

    req.on("data", (chunk) => {
      if (aborted) return;
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        aborted = true;
        sendJson(res, 413, { ok: false, error: "Payload too large" });
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });

    req.on("end", () => {
      if (aborted) return;

      void (async () => {
        try {
          const rawBody = Buffer.concat(chunks).toString("utf8");
          const payload = JSON.parse(rawBody);
          const record = coerceAoRecord(payload);
          const result = await dispatchRecord(record);

          sendJson(res, 202, {
            ok: true,
            eventType: record.eventType,
            session: record.session,
            summary: record.summary,
            delivered: result.delivered,
            queued: result.queued,
            queueDepth: result.queueDepth,
            error: result.error || null,
          });
        } catch (error) {
          sendJson(res, 400, {
            ok: false,
            error: error instanceof Error ? error.message : String(error),
          });
        }
      })();
    });

    req.on("error", (error) => {
      sendJson(res, 500, {
        ok: false,
        error: error instanceof Error ? error.message : String(error),
      });
    });
  });
}

async function main() {
  await bridgeServer.connect(transport);
  httpServer = createHttpServer();

  await new Promise((resolve) => {
    httpServer.listen(PORT, HOST, resolve);
  });

  console.error(
    JSON.stringify({
      ok: true,
      host: HOST,
      port: PORT,
      path: EVENT_PATH,
      healthPath: HEALTH_PATH,
      serverName: SERVER_NAME,
    }),
  );
}

async function shutdown(signal) {
  bridgeReady = false;

  if (httpServer) {
    await new Promise((resolve) => {
      httpServer.close(resolve);
    });
  }

  await bridgeServer.close();
  console.error(JSON.stringify({ ok: true, signal, stopped: true }));
  process.exit(0);
}

process.on("SIGINT", () => {
  void shutdown("SIGINT");
});

process.on("SIGTERM", () => {
  void shutdown("SIGTERM");
});

main().catch((error) => {
  logError("Bridge startup failed", error);
  process.exit(1);
});
