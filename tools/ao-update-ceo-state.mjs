#!/usr/bin/env node
/**
 * ao-update-ceo-state.mjs
 *
 * 用 AO dashboard API 拉取当前 session 列表 + 读取最近事件，
 * 写成 .ao-inbox/ceo-state.md。
 *
 * CEO 每次派完活后调用一次：
 *   node tools/ao-update-ceo-state.mjs
 *
 * 新窗口打开时，SessionStart hook 会把这个文件注入进来，
 * 让 Claude 知道上次派了什么、现在什么状态。
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const INBOX_DIR = process.env.AO_EVENT_SINK_DIR || resolve(SCRIPT_DIR, "..", ".ao-inbox");
const STATE_FILE = join(INBOX_DIR, "ceo-state.md");
const EVENTS_FILE = join(INBOX_DIR, "events.jsonl");
const AO_PORT = Number.parseInt(process.env.AO_DASHBOARD_PORT || "3000", 10);
const TIMEOUT_MS = Number.parseInt(process.env.AO_STATE_TIMEOUT_MS || "3000", 10);
const RECENT_EVENTS_COUNT = 8;

async function fetchJson(path) {
  const res = await fetch(`http://127.0.0.1:${AO_PORT}${path}`, {
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

function readLastEvents(n) {
  if (!existsSync(EVENTS_FILE)) return [];
  const lines = readFileSync(EVENTS_FILE, "utf8").trim().split("\n").filter(Boolean);
  return lines.slice(-n).map((line) => {
    try { return JSON.parse(line); } catch { return null; }
  }).filter(Boolean);
}

function statusIcon(status) {
  if (!status) return "?";
  if (/work|spawn/i.test(status)) return "⚙";
  if (/pr_open|review/i.test(status)) return "📝";
  if (/merg/i.test(status)) return "✅";
  if (/fail|error|stuck/i.test(status)) return "❌";
  if (/idle|done|complete/i.test(status)) return "✓";
  return "·";
}

async function main() {
  const now = new Date().toISOString();
  const lines = [`# CEO State Snapshot`, ``, `Updated: ${now}`, ``];

  // --- Sessions ---
  let sessions = [];
  try {
    const data = await fetchJson("/api/sessions");
    sessions = Array.isArray(data) ? data : [];
  } catch {
    lines.push(`> ⚠ AO dashboard not reachable (port ${AO_PORT}) — session list unavailable.`, ``);
  }

  if (sessions.length > 0) {
    const active = sessions.filter((s) => !/idle|done|merged|complete/i.test(s.status ?? ""));
    const terminal = sessions.filter((s) => /idle|done|merged|complete/i.test(s.status ?? ""));

    if (active.length > 0) {
      lines.push(`## 进行中 Sessions (${active.length})`, ``);
      lines.push(`| Session | Issue | Status | PR |`);
      lines.push(`|---------|-------|--------|----|`);
      for (const s of active) {
        const pr = s.pr?.number ? `[#${s.pr.number}](${s.pr.url ?? ""})` : "—";
        lines.push(`| ${s.id} | ${s.issueId ?? "—"} | ${statusIcon(s.status)} ${s.status} | ${pr} |`);
      }
      lines.push(``);
    } else {
      lines.push(`## 进行中 Sessions`, ``, `无。`, ``);
    }

    if (terminal.length > 0) {
      lines.push(`## 最近完成 (${terminal.length})`, ``);
      for (const s of terminal.slice(-5)) {
        const pr = s.pr?.number ? ` PR #${s.pr.number}` : "";
        lines.push(`- ${s.id} issue ${s.issueId ?? "?"} → ${s.status}${pr}`);
      }
      lines.push(``);
    }
  } else if (sessions.length === 0 && !lines.some((l) => l.includes("⚠"))) {
    lines.push(`## Sessions`, ``, `当前无 session。`, ``);
  }

  // --- Recent Events ---
  const events = readLastEvents(RECENT_EVENTS_COUNT);
  if (events.length > 0) {
    lines.push(`## 最近 ${events.length} 条事件`, ``);
    for (const ev of events) {
      const time = ev.receivedAt ? ev.receivedAt.replace("T", " ").slice(0, 19) : "?";
      lines.push(`- \`${time}\` ${ev.summary || ev.eventType}`);
    }
    lines.push(``);
  }

  lines.push(`---`, `*新窗口打开时由 SessionStart hook 自动注入*`);

  mkdirSync(INBOX_DIR, { recursive: true });
  writeFileSync(STATE_FILE, lines.join("\n"), "utf8");
  process.stdout.write(`✔ CEO state written → ${STATE_FILE}\n`);
}

main().catch((e) => {
  process.stderr.write(`ao-update-ceo-state: ${e.message}\n`);
  process.exit(1);
});
