#!/usr/bin/env node

import http from "node:http";
import { appendFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const HOST = process.env.AO_EVENT_SINK_HOST || "127.0.0.1";
const PORT = Number.parseInt(process.env.AO_EVENT_SINK_PORT || "8765", 10);
const INBOX_DIR = process.env.AO_EVENT_SINK_DIR || "/mnt/d/脚本程序/agent-orchestrator/.ao-inbox";
const EVENTS_FILE = join(INBOX_DIR, "events.jsonl");
const MAX_BODY_BYTES = Number.parseInt(process.env.AO_EVENT_SINK_MAX_BODY_BYTES || "1048576", 10);

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function getString(value) {
  return typeof value === "string" && value ? value : null;
}

function getNumber(value) {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function getObject(value) {
  return isObject(value) ? value : null;
}

function getArray(value) {
  return Array.isArray(value) ? value : null;
}

function extractEvent(payload) {
  if (isObject(payload?.event)) {
    return payload.event;
  }
  if (isObject(payload) && getString(payload.type) && (getString(payload.sessionId) || getString(payload.message))) {
    return payload;
  }
  return null;
}

function inferCI(eventType, data) {
  if (eventType === "review.pending" || eventType === "merge.ready") {
    return { status: "passing" };
  }
  if (eventType === "ci.failing") {
    return {
      status: "failing",
      failedChecks: getArray(data?.failedChecks) || null,
    };
  }
  if (eventType.startsWith("ci.")) {
    return { status: eventType.slice(3) };
  }
  return null;
}

function inferReview(eventType, data) {
  if (eventType === "review.pending") return { status: "pending" };
  if (eventType === "review.changes_requested") return { status: "changes_requested" };
  if (eventType === "review.approved") return { status: "approved" };

  const reactionKey = getString(data?.reactionKey);
  if (reactionKey === "changes-requested") return { status: "changes_requested" };
  if (reactionKey === "approved-and-green") return { status: "approved" };

  return null;
}

function inferPR(eventType, data) {
  const number = getNumber(data?.prNumber) ?? getNumber(data?.pr);
  const url = getString(data?.prUrl) ?? getString(data?.url);
  const status =
    getString(data?.newStatus) ||
    (eventType === "pr.created"
      ? "pr_open"
      : eventType === "merge.ready"
        ? "mergeable"
        : eventType === "review.pending"
          ? "review_pending"
          : eventType === "review.changes_requested"
            ? "changes_requested"
            : eventType === "review.approved"
              ? "approved"
              : null);

  if (number === null && url === null && status === null) {
    return null;
  }

  return {
    number,
    url,
    status,
  };
}

function buildSummary(eventType, session, issue, pr, ci, review, message) {
  if (message) return message;

  const parts = [eventType || "unknown"];
  if (session) parts.push(`session=${session}`);
  if (issue) parts.push(`issue=${issue}`);
  if (pr?.number !== null && pr?.number !== undefined) parts.push(`pr=#${pr.number}`);
  if (pr?.status) parts.push(`prStatus=${pr.status}`);
  if (ci?.status) parts.push(`ci=${ci.status}`);
  if (review?.status) parts.push(`review=${review.status}`);
  return parts.join(" ");
}

function normalizePayload(payload) {
  const event = extractEvent(payload);
  const eventData = getObject(event?.data) || {};
  const context = getObject(payload?.context) || {};
  const eventType = getString(event?.type) || getString(payload?.type) || "unknown";
  const session = getString(event?.sessionId) || getString(context?.sessionId);
  const issue =
    getString(eventData.issueId) ||
    getString(eventData.issue) ||
    getString(context.issueId) ||
    getString(context.issue);
  const pr = inferPR(eventType, eventData);
  const ci = inferCI(eventType, eventData);
  const review = inferReview(eventType, eventData);
  const summary = buildSummary(
    eventType,
    session,
    issue,
    pr,
    ci,
    review,
    getString(event?.message) || getString(payload?.message),
  );

  return {
    receivedAt: new Date().toISOString(),
    source: "ao-webhook",
    eventType,
    session,
    issue,
    pr,
    ci,
    review,
    summary,
    raw: payload,
  };
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
    sendJson(res, 200, { ok: true, inboxDir: INBOX_DIR, eventsFile: EVENTS_FILE });
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

    try {
      const raw = Buffer.concat(chunks).toString("utf8");
      const payload = JSON.parse(raw);
      const record = normalizePayload(payload);
      let written = true;
      let errorMessage = null;

      try {
        appendRecord(record);
      } catch (error) {
        written = false;
        errorMessage = error instanceof Error ? error.message : String(error);
      }

      sendJson(res, 202, {
        ok: true,
        written,
        eventsFile: EVENTS_FILE,
        eventType: record.eventType,
        session: record.session,
        summary: record.summary,
        error: errorMessage,
      });
    } catch (error) {
      sendJson(res, 400, {
        ok: false,
        error: error instanceof Error ? error.message : String(error),
      });
    }
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
