# ADR 0013: Require a server-verified dashboard capability for Worker mutations

**Status:** Accepted

**Date:** 2026-07-17

## Context

MCP tool visibility metadata communicates the intended caller to a ChatGPT
host, but it is not authorization. The public Worker must reject a direct
`tools/call` mutation that does not originate from a currently rendered
Offshift dashboard.

## Decision

`render_offshift_dashboard` mints a random opaque capability with a five-minute
expiry. The Worker returns it only in tool-result `_meta` under
`offshift/widgetCapability`; it is not put in model-visible text or
`structuredContent`. The widget holds it only in memory and submits it with
every write tool call.

The Worker validates the capability server-side and scopes each current plan
and idempotency map to that capability session. Missing, invalid, and expired
capabilities are rejected. The capability grants only four bounded demo-plan
mutations; it cannot invoke a device, scene, lock, webhook, or external
network action.

## Consequences

- A direct mutation without a fresh rendered-dashboard capability fails even
  if a caller copies the tool name and schema.
- Worker-isolate session state remains intentionally non-durable and is not
  user authentication. A production scheduling product would need a separate
  identity and durable-state decision.
- No capability or authority crosses into the local macOS companion.
