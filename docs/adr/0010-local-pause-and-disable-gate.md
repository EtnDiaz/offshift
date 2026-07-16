# ADR 0010: Keep pause and disable authority inside the macOS companion

**Status:** Accepted

**Date:** 2026-07-17

## Context

An intervention product must let a person immediately silence an unhelpful
nudge, pause it for the rest of the night, or turn it off altogether. The
ChatGPT widget cannot safely be that switch: it is not guaranteed to be open,
and a public MCP request must never gain authority over a local Lock Screen
rule or local notifications.

## Decision

The macOS companion owns an explicit local control gate with three states:

- **Active** — normal local observation and the separately configured local
  intervention rules may run.
- **Paused until tomorrow** — sampling can continue only as local aggregate
  timing, but no overlay, countdown, Lock Screen request, or smart-home scene
  can be started. The state returns to Active only after the saved local time
  or a direct local resume.
- **Turned off** — sampling and local interventions stop until the person
  explicitly enables Offshift in local Settings again.

Entering either non-active state cancels an in-progress pre-lock countdown
immediately. ChatGPT, the Worker, MCP tools, and Home Assistant cannot enter,
extend, or clear this gate.

## Consequences

- The native surface provides the reliable escape hatch promised by the
  product, even when ChatGPT is closed or offline.
- A pause is bounded and explainable; a disable is durable until a local user
  re-enables it.
- The existing Home Assistant confirmation and Lock Screen consent rules are
  unchanged and remain separately local.
