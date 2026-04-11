1. Root Cause

- The root cause is both parts together.
- First, the real delivery bug is a tmux `paste-buffer` to `Enter` race in [`/root/agent-orchestrator/packages/plugins/runtime-tmux/src/index.ts`](/root/agent-orchestrator/packages/plugins/runtime-tmux/src/index.ts): multi-line and long messages go through the paste path, but AO 0.2.2 sends `Enter` after a fixed 300 ms delay, which is not reliable for Codex/Ink-style TUIs once the pasted draft is still rendering.
- Second, the apparent success on the CLI/PM side comes from confirmation false positives in session-manager: once the pasted draft changes pane output, the current confirmation logic can treat that as delivery even if the draft was never actually submitted. I did not change session-manager because it is outside this worker's ownership.
- The minimal 0.2.2-friendly fix is therefore to harden the runtime send path itself: wait for pasted content to settle, retry `Enter`, and fail explicitly when the draft is still visibly unsubmitted after all retries.
- I did not choose the broader transports discussed in #853 and #184 because they are architecture work, not a small 0.2.2 patch.

2. Changed Files

- Modified [`/root/agent-orchestrator/packages/plugins/runtime-tmux/src/index.ts`](/root/agent-orchestrator/packages/plugins/runtime-tmux/src/index.ts)
  Adds paste-buffer detection constants, pane capture helpers, draft/submission heuristics, paste-settle waiting, repeated `Enter` retries, and an explicit error when the draft remains visible after all retries.
- Modified [`/root/agent-orchestrator/packages/plugins/runtime-tmux/src/__tests__/index.test.ts`](/root/agent-orchestrator/packages/plugins/runtime-tmux/src/__tests__/index.test.ts)
  Adds coverage for long-message settle/submit flow, multiline content with Windows-style backslashes, retry-on-still-draft behavior, and explicit failure when submission cannot be confirmed.
- Generated vendored patch [`/root/.worktrees/ao-kit-slot-2/kit2-2/patches/ao-0.2.2-bug2-send-paste-race.patch`](/root/.worktrees/ao-kit-slot-2/kit2-2/patches/ao-0.2.2-bug2-send-paste-race.patch)
- I intentionally did not modify [`/root/agent-orchestrator/packages/core/src/tmux.ts`](/root/agent-orchestrator/packages/core/src/tmux.ts) or [`/root/agent-orchestrator/packages/core/src/__tests__/tmux.test.ts`](/root/agent-orchestrator/packages/core/src/__tests__/tmux.test.ts) to keep the patch scoped to the active `ao send` production path for this bug.

3. Test / Validation Results

- `pnpm -C /root/agent-orchestrator/packages/plugins/runtime-tmux test src/__tests__/index.test.ts`
  Passed: 28 tests.
- `pnpm -C /root/agent-orchestrator/packages/plugins/runtime-tmux typecheck`
  Passed.
- The new test coverage verifies:
  long paste-buffer sends submit after pane settle,
  multiline messages with Windows-style backslashes are preserved literally,
  a swallowed first `Enter` triggers another retry,
  repeated visible-draft failure now throws instead of returning silent success.
- I did not run a full repo test sweep, and I did not modify unrelated bug-1 / bug-3 files.

4. Generated Patch File

- [`/root/.worktrees/ao-kit-slot-2/kit2-2/patches/ao-0.2.2-bug2-send-paste-race.patch`](/root/.worktrees/ao-kit-slot-2/kit2-2/patches/ao-0.2.2-bug2-send-paste-race.patch)

5. Recommended Upstream Issue / PR References

- Issue #373: long-message paste-buffer `Enter` race background
- Issue #564: paste succeeded visually but submit/confirmation was false-positive
- Issue #853: file-based communication RFC for a larger future fix, explicitly not taken here
- Issue #184: Codex app-server client background, also not taken here because it is broader infra
- PR #374: closest shape to this patch, runtime-side settle plus retry logic
- PR #541: earlier adaptive-delay and retry attempt for the same bug family
- PR #494: smaller retry-after-paste approach in core helpers
- PR #571: later bracketed-paste direction; useful context, but more than I needed for this scoped 0.2.2 patch
