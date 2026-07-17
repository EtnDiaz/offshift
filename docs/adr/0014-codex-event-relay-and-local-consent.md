# ADR 0014: Treat Codex sync as an outbound, coarse event relay

**Status:** Accepted

**Date:** 2026-07-17

## Context

Offshift can make a work loop easier to notice when a developer has opted in
to share that an active Codex session exists. This must not turn Codex, a
ChatGPT App, or the public Worker into an authority that can lock a Mac,
change a local policy, control a smart-home device, inspect work, or end a
developer's coding session.

## Decision

Codex integration is an optional, outbound relay of a small versioned event
allowlist: `session.started`, `session.heartbeat`, and `session.ended`. Events
carry a generated installation identifier, an event identifier, occurrence
time, and a boolean session state only. They never contain prompts, code,
repository names, terminal output, file paths, window titles, screen content,
or model transcripts.

The relay accepts only HTTPS requests authenticated by a per-installation
secret, rejects stale timestamps and duplicate event identifiers, and stores
only the latest coarse state for its short retention period. It has no outbound
webhook feature. A future production transport needs a separate durable-state
and retention ADR.

The local macOS companion remains the sole authority for behavior policy,
overlays, local notification, allowlisted Home Assistant scenes, and the
optional Lock Screen flow. A Codex event may be shown as one explanation input
after the user has enabled the integration; it may not raise an intervention
level by itself. The companion never accepts a remotely initiated lock,
pause/disable, policy edit, scene execution, or session-termination command.

In the ChatGPT App, the model may read and explain the coarse sync status.
Any request to change an Offshift plan continues to require a fresh,
server-verified dashboard capability and a deliberate dashboard click. Sync
can be disconnected locally at any time; disconnect deletes the local secret
and suppresses further relay events.

## Consequences

- Codex can participate as a consented signal without observing developer work
  or controlling the developer's machine.
- The Worker has a narrow inbound event endpoint rather than a general
  webhook/automation surface.
- An unavailable relay must degrade to an "unknown" explanation state, never
  to a stricter intervention.
- The product needs clear onboarding and dashboard copy explaining what is and
  is not synchronized.
