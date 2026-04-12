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

export function normalizeAoPayload(payload) {
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

export function isNormalizedAoRecord(payload) {
  return isObject(payload) && getString(payload.eventType) !== null && getString(payload.summary) !== null;
}

export function coerceAoRecord(payload) {
  if (isNormalizedAoRecord(payload)) {
    return payload;
  }
  if (isNormalizedAoRecord(payload?.record)) {
    return payload.record;
  }
  if (isNormalizedAoRecord(payload?.eventRecord)) {
    return payload.eventRecord;
  }
  return normalizeAoPayload(payload);
}
