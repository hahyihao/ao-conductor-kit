#!/usr/bin/env node
// Accepts AO events, enriches them via AO dashboard API, writes to local inbox log, and forwards summaries to ao-channel-bridge.

import http from "node:http";
import { appendFileSync, mkdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

import { normalizeAoPayload } from "./lib/ao-event-record.mjs";

const HOST = process.env.AO_EVENT_SINK_HOST || "127.0.0.1";
const PORT = Number.parseInt(process.env.AO_EVENT_SINK_PORT || "8765", 10);
const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const DEFAULT_INBOX_DIR = resolve(SCRIPT_DIR, "..", ".ao-inbox");
const INBOX_DIR = process.env.AO_EVENT_SINK_DIR || DEFAULT_INBOX_DIR;
const EVENTS_FILE = join(INBOX_DIR, "events.jsonl");
const MAX_BODY_BYTES = Number.parseInt(process.env.AO_EVENT_SINK_MAX_BODY_BYTES || "1048576", 10);
const FORWARD_TO = typeof process.env.AO_EVENT_SINK_FORWARD_TO === "string" ? process.env.AO_EVENT_SINK_FORWARD_TO.trim() : "";
const FORWARD_TIMEOUT_MS = Number.parseInt(process.env.AO_EVENT_SINK_FORWARD_TIMEOUT_MS || "3000", 10);
const AO_DASHBOARD_PORT = Number.parseInt(process.env.AO_DASHBOARD_PORT || "3000", 10);
const AO_ENRICH_TIMEOUT_MS = Number.parseInt(process.env.AO_ENRICH_TIMEOUT_MS || "2000", 10);

/**
 * 用 AO dashboard API 补全 record 里缺失的 issue 和 pr 字段。
 * AO 的 lifecycle 事件 data 里不带 issueId/prNumber，这里做一次回查补全。
 * 失败时静默返回原 record，不阻塞写入。
 */
async function enrichFromAoApi(record) {
  if (!record.session) return record;
  if (record.issue !== null && record.pr?.number !== null) return record;

  try {
    const res = await fetch(
      `http://127.0.0.1:${AO_DASHBOARD_PORT}/api/sessions/${record.session}`,
      { signal: AbortSignal.timeout(AO_ENRICH_TIMEOUT_MS) },
    );
    if (!res.ok) return record;
    const data = await res.json();

    const issue = record.issue ?? (data.issueId ? String(data.issueId) : null);
    const prNumber = record.pr?.number ?? (typeof data.pr?.number === "number" ? data.pr.number : null);
    const prUrl = record.pr?.url ?? (typeof data.pr?.url === "string" ? data.pr.url : null);

    const pr = (record.pr || prNumber !== null || prUrl !== null)
      ? { ...(record.pr ?? {}), number: prNumber, url: prUrl, status: record.pr?.status ?? null }
      : null;

    // 重建 summary，把补全后的 issue/pr 加进去
    const parts = [record.eventType || "unknown"];
    if (record.session) parts.push(`session=${record.session}`);
    if (issue) parts.push(`issue=${issue}`);
    if (pr?.number !== null && pr?.number !== undefined) parts.push(`pr=#${pr.number}`);
    if (pr?.url) parts.push(`prUrl=${pr.url}`);
    if (pr?.status) parts.push(`prStatus=${pr.status}`);
    if (record.ci?.status) parts.push(`ci=${record.ci.status}`);
    if (record.review?.status) parts.push(`review=${record.review.status}`);
    const summary = parts.join(" ");

    return { ...record, issue, pr, summary };
  } catch {
    return record;
  }
}

function buildForwardPayload(record) {
  return {
    receivedAt: record.receivedAt,
    source: record.source,
    eventType: record.eventType,
    session: record.session,
    issue: record.issue,
    pr: record.pr,
    ci: record.ci,
    review: record.review,
    summary: record.summary,
  };
}

async function forwardRecord(record) {
  if (!FORWARD_TO) {
    return { enabled: false, forwarded: false, statusCode: null, error: null };
  }

  try {
    const response = await fetch(FORWARD_TO, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=utf-8" },
      body: JSON.stringify(buildForwardPayload(record)),
      signal: AbortSignal.timeout(FORWARD_TIMEOUT_MS),
    });

    let responseBody = null;
    try {
      responseBody = await response.json();
    } catch {
      responseBody = null;
    }

    return {
      enabled: true,
      forwarded: response.ok,
      statusCode: response.status,
      error: response.ok ? null : responseBody?.error || `HTTP ${response.status}`,
    };
  } catch (error) {
    return {
      enabled: true,
      forwarded: false,
      statusCode: null,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

function appendRecord(record) {
  mkdirSync(INBOX_DIR, { recursive: true });
  appendFileSync(EVENTS_FILE, `${JSON.stringify(record)}\n`, "utf8");
}

function sendJson(res, statusCode, payload) {
  if (res.writableEnded) return;
  res.writeHead(statusCode, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(payload));
}

const server = http.createServer((req, res) => {
  if (req.method === "GET" && req.url === "/health") {
    sendJson(res, 200, {
      ok: true,
      inboxDir: INBOX_DIR,
      eventsFile: EVENTS_FILE,
      forwardTo: FORWARD_TO || null,
      forwardTimeoutMs: FORWARD_TIMEOUT_MS,
    });
    return;
  }

  if (req.method !== "POST") {
    sendJson(res, 405, { ok: false, error: "Only POST / is supported" });
    return;
  }

  if (req.url !== "/" && req.url !== "") {
    sendJson(res, 404, { ok: false, error: "Only POST / is supported" });
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
        const raw = Buffer.concat(chunks).toString("utf8");
        const payload = JSON.parse(raw);
        const record = await enrichFromAoApi(normalizeAoPayload(payload));
        let written = true;
        let errorMessage = null;

        try {
          appendRecord(record);
        } catch (error) {
          written = false;
          errorMessage = error instanceof Error ? error.message : String(error);
        }

        // 有 session 状态变化时，后台异步刷新 ceo-state.md，不阻塞响应
        if (written && record.session) {
          const stateScript = resolve(SCRIPT_DIR, "ao-update-ceo-state.mjs");
          spawn(process.execPath, [stateScript], {
            detached: true,
            stdio: "ignore",
            env: { ...process.env, AO_EVENT_SINK_DIR: INBOX_DIR },
          }).unref();
        }

        const forward = await forwardRecord(record);

        sendJson(res, 202, {
          ok: true,
          written,
          eventsFile: EVENTS_FILE,
          eventType: record.eventType,
          session: record.session,
          summary: record.summary,
          forwardTo: forward.enabled ? FORWARD_TO : null,
          forwarded: forward.forwarded,
          forwardStatusCode: forward.statusCode,
          error: errorMessage,
          forwardError: forward.error,
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

server.listen(PORT, HOST, () => {
  console.log(
    JSON.stringify({
      ok: true,
      host: HOST,
      port: PORT,
      inboxDir: INBOX_DIR,
      eventsFile: EVENTS_FILE,
      forwardTo: FORWARD_TO || null,
    }),
  );
});

function shutdown(signal) {
  server.close(() => {
    console.log(JSON.stringify({ ok: true, signal, stopped: true }));
    process.exit(0);
  });
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));
