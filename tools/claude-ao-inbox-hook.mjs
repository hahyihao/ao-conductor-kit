#!/usr/bin/env node

import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const LEGACY_DEFAULT_INBOX_DIR = "/mnt/d/脚本程序/agent-orchestrator/.ao-inbox";
const MAX_DETAIL_EVENTS = Number.parseInt(process.env.AO_CLAUDE_INBOX_MAX_DETAIL || "8", 10);
const MAX_CONTEXT_CHARS = Number.parseInt(process.env.AO_CLAUDE_INBOX_MAX_CONTEXT || "6000", 10);
const EVENT_SINK_FILE = fileURLToPath(new URL("./ao-event-sink.mjs", import.meta.url));

function readStdin() {
  return new Promise((resolve, reject) => {
    const chunks = [];
    process.stdin.on("data", (chunk) => chunks.push(chunk));
    process.stdin.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    process.stdin.on("error", reject);
  });
}

function safeParseJson(value) {
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function asString(value) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function asNumber(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && /^\d+$/.test(value.trim())) {
    return Number.parseInt(value.trim(), 10);
  }
  return null;
}

function discoverDefaultInboxDir() {
  try {
    const source = readFileSync(EVENT_SINK_FILE, "utf8");
    const match = source.match(/const INBOX_DIR\s*=\s*process\.env\.AO_EVENT_SINK_DIR\s*\|\|\s*["']([^"']+)["'];/);
    return match?.[1] || LEGACY_DEFAULT_INBOX_DIR;
  } catch {
    return LEGACY_DEFAULT_INBOX_DIR;
  }
}

function resolvePaths() {
  const inboxDir = process.env.AO_EVENT_SINK_DIR || discoverDefaultInboxDir();
  return {
    inboxDir,
    eventsFile: join(inboxDir, "events.jsonl"),
    cursorFile: process.env.AO_CLAUDE_INBOX_CURSOR || join(inboxDir, "cursor"),
  };
}

function readCursor(cursorFile, fileSize) {
  if (!existsSync(cursorFile)) {
    return 0;
  }

  const raw = readFileSync(cursorFile, "utf8").trim();
  const offset = Number.parseInt(raw, 10);
  if (!Number.isFinite(offset) || offset < 0) {
    return 0;
  }
  if (offset > fileSize) {
    return 0;
  }
  return offset;
}

function readUnreadRecords(eventsFile, offset) {
  const buffer = readFileSync(eventsFile);
  const unread = buffer.subarray(offset);
  const lastNewlineIndex = unread.lastIndexOf(0x0a);

  if (lastNewlineIndex < 0) {
    return {
      nextOffset: offset,
      records: [],
      malformedLines: 0,
    };
  }

  const completeChunk = unread.subarray(0, lastNewlineIndex + 1);
  const text = completeChunk.toString("utf8");
  const lines = text.split("\n");
  const records = [];
  let malformedLines = 0;

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) {
      continue;
    }

    const record = safeParseJson(trimmed);
    if (record === null) {
      malformedLines += 1;
      continue;
    }
    records.push(record);
  }

  return {
    nextOffset: offset + completeChunk.length,
    records,
    malformedLines,
  };
}

function normalizeEvent(record, index) {
  const raw = record?.raw ?? record;
  const pr = record?.pr ?? raw?.pr ?? {};
  const ci = record?.ci ?? raw?.ci ?? {};
  const review = record?.review ?? raw?.review ?? {};
  const eventData = raw?.event?.data ?? raw?.data ?? {};

  const eventType =
    asString(record?.eventType) ||
    asString(raw?.eventType) ||
    asString(raw?.type) ||
    asString(raw?.event?.type) ||
    "unknown";

  const session =
    asString(record?.session) ||
    asString(raw?.session) ||
    asString(raw?.sessionId) ||
    asString(raw?.event?.sessionId) ||
    asString(raw?.context?.sessionId);

  const issueValue =
    record?.issue ??
    raw?.issue ??
    raw?.issueId ??
    raw?.context?.issue ??
    raw?.context?.issueId ??
    eventData?.issue ??
    eventData?.issueId;
  const issue = issueValue === undefined || issueValue === null ? null : String(issueValue);

  const prNumber =
    asNumber(pr?.number) ??
    asNumber(pr?.prNumber) ??
    asNumber(record?.prNumber) ??
    asNumber(raw?.prNumber) ??
    asNumber(eventData?.prNumber) ??
    asNumber(eventData?.pr);

  const prStatus =
    asString(pr?.status) ||
    asString(record?.prStatus) ||
    asString(eventData?.newStatus);

  const ciStatus = asString(ci?.status);
  const reviewStatus = asString(review?.status);
  const summary =
    asString(record?.summary) ||
    asString(raw?.summary) ||
    asString(record?.message) ||
    asString(raw?.message);

  const failedChecks = Array.isArray(ci?.failedChecks)
    ? ci.failedChecks.map((entry) => asString(entry)).filter(Boolean)
    : [];

  const receivedAt =
    asString(record?.receivedAt) ||
    asString(raw?.receivedAt) ||
    asString(raw?.timestamp) ||
    asString(raw?.ts) ||
    null;

  return {
    index,
    eventType,
    session,
    issue,
    prNumber,
    prStatus,
    ciStatus,
    reviewStatus,
    failedChecks,
    summary,
    receivedAt,
  };
}

function priority(event) {
  if (event.ciStatus === "failing") return 100;
  if (event.reviewStatus === "changes_requested") return 95;
  if (/(fail|error|blocked|deny|timeout)/i.test(event.eventType)) return 90;
  if (event.reviewStatus === "approved") return 80;
  if (event.eventType === "merge.ready") return 78;
  if (event.eventType === "pr.created") return 76;
  if (event.reviewStatus === "pending") return 72;
  if (/(completed|stopped|exited|closed|merged)/i.test(event.eventType)) return 68;
  if (event.prStatus === "mergeable") return 66;
  return 40;
}

function formatSubject(event) {
  const parts = [];
  if (event.session) parts.push(event.session);
  if (event.issue) parts.push(`issue ${event.issue}`);
  return parts.join(" / ");
}

function joinSubject(event, detail) {
  const subject = formatSubject(event);
  return subject ? `${subject}: ${detail}` : detail;
}

function truncate(text, maxChars) {
  if (text.length <= maxChars) {
    return text;
  }
  return `${text.slice(0, Math.max(0, maxChars - 1)).trimEnd()}…`;
}

function formatEventLine(event) {
  if (event.eventType === "ci.failing") {
    const checks = event.failedChecks.length ? ` (${event.failedChecks.join(", ")})` : "";
    const prText = event.prNumber !== null ? `PR #${event.prNumber}` : "a PR";
    return joinSubject(event, `CI failing on ${prText}${checks}`);
  }

  if (event.reviewStatus === "changes_requested") {
    const prText = event.prNumber !== null ? `PR #${event.prNumber}` : "the PR";
    return joinSubject(event, `review requested changes on ${prText}`);
  }

  if (event.reviewStatus === "approved") {
    const prText = event.prNumber !== null ? `PR #${event.prNumber}` : "the PR";
    return joinSubject(event, `review approved ${prText}`);
  }

  if (event.eventType === "merge.ready" || event.prStatus === "mergeable") {
    const prText = event.prNumber !== null ? `PR #${event.prNumber}` : "the PR";
    return joinSubject(event, `${prText} is merge-ready`);
  }

  if (event.eventType === "pr.created") {
    const prText = event.prNumber !== null ? `opened PR #${event.prNumber}` : "opened a PR";
    return joinSubject(event, prText);
  }

  if (event.reviewStatus === "pending") {
    const prText = event.prNumber !== null ? `PR #${event.prNumber}` : "the PR";
    return joinSubject(event, `review pending for ${prText}`);
  }

  if (/(completed|stopped|exited|closed|merged)/i.test(event.eventType)) {
    return joinSubject(event, event.eventType.replace(/[._]/g, " "));
  }

  if (event.summary) {
    return joinSubject(event, event.summary);
  }

  const prText = event.prNumber !== null ? ` PR #${event.prNumber}` : "";
  return joinSubject(event, `${event.eventType}${prText}`);
}

function buildOmittedSummary(events) {
  const counts = new Map();
  for (const event of events) {
    const key =
      event.ciStatus === "failing"
        ? "ci.failing"
        : event.reviewStatus === "changes_requested"
          ? "review.changes_requested"
          : event.reviewStatus === "approved"
            ? "review.approved"
            : event.eventType;
    counts.set(key, (counts.get(key) || 0) + 1);
  }

  return Array.from(counts.entries())
    .sort((left, right) => right[1] - left[1] || left[0].localeCompare(right[0]))
    .slice(0, 5)
    .map(([key, count]) => `${key} x${count}`)
    .join(", ");
}

function buildAdditionalContext(events, malformedLines, maxChars) {
  if (events.length === 0 && malformedLines === 0) {
    return "";
  }

  if (events.length === 0) {
    return truncate(
      `AO callback inbox warning: no readable new events were delivered; skipped ${malformedLines} malformed inbox line${malformedLines === 1 ? "" : "s"}.`,
      maxChars,
    );
  }

  const sorted = [...events].sort((left, right) => priority(right) - priority(left) || right.index - left.index);
  let detailCount = Math.min(MAX_DETAIL_EVENTS, sorted.length);
  let context = "";

  while (detailCount >= 0) {
    const detail = sorted.slice(0, detailCount);
    const omitted = sorted.slice(detailCount);
    const lines = [`AO callback inbox: ${events.length} new event${events.length === 1 ? "" : "s"} since the last delivery.`];

    for (const event of detail) {
      lines.push(`- ${truncate(formatEventLine(event), 180)}`);
    }

    if (omitted.length > 0) {
      lines.push(`- ${omitted.length} additional event${omitted.length === 1 ? "" : "s"}: ${truncate(buildOmittedSummary(omitted), 180)}`);
    }

    if (malformedLines > 0) {
      lines.push(`- Skipped ${malformedLines} malformed inbox line${malformedLines === 1 ? "" : "s"}.`);
    }

    context = lines.join("\n");
    if (context.length <= maxChars || detailCount === 0) {
      break;
    }
    detailCount -= 1;
  }

  return truncate(context, maxChars);
}

function buildHookOutput(hookEventName, additionalContext) {
  if (!additionalContext) {
    return "";
  }

  return JSON.stringify({
    hookSpecificOutput: {
      hookEventName,
      additionalContext,
    },
  });
}

async function main() {
  const input = safeParseJson(await readStdin()) || {};
  const hookEventName =
    input?.hook_event_name === "SessionStart" || input?.hook_event_name === "UserPromptSubmit"
      ? input.hook_event_name
      : "UserPromptSubmit";

  const { eventsFile, cursorFile } = resolvePaths();
  if (!existsSync(eventsFile)) {
    return;
  }

  const fileSize = statSync(eventsFile).size;
  const offset = readCursor(cursorFile, fileSize);
  const { nextOffset, records, malformedLines } = readUnreadRecords(eventsFile, offset);

  if (nextOffset === offset && malformedLines === 0) {
    return;
  }

  const events = records.map((record, index) => normalizeEvent(record, index));
  const additionalContext = buildAdditionalContext(events, malformedLines, MAX_CONTEXT_CHARS);
  const hookOutput = buildHookOutput(hookEventName, additionalContext);

  mkdirSync(dirname(cursorFile), { recursive: true });
  writeFileSync(cursorFile, `${nextOffset}\n`, "utf8");
  if (hookOutput) {
    process.stdout.write(`${hookOutput}\n`);
  }
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(`claude-ao-inbox-hook: ${message}\n`);
  process.exit(1);
});
