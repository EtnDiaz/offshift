# ADR 0001: Keep behaviour signals local, coarse, and opt-in

- Status: Accepted
- Date: 2026-07-16

## Context

Offshift should recognize a late, uninterrupted, repeatedly-snoozed build loop without becoming an activity-surveillance product.

## Decision

The companion may retain locally only elapsed active time, idle gaps, user-configured quiet-hours state, break-action history, and an optional boolean that a Codex session is active. It must not collect prompt text, code, diffs, terminal output, filenames, browser history, keystrokes, screen images, camera, or microphone data.

## Consequences

The first heuristic will be less granular than a surveillance-based alternative, but remains explainable and viable without sensitive telemetry. Cloud services receive only the minimal aggregate state needed for an explicitly requested schedule; the local shadow log remains local by default.
