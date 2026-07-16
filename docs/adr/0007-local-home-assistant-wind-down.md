# ADR 0007: Execute one Home Assistant scene only from the local companion

**Status:** Accepted

**Date:** 2026-07-16

## Context

An ambient action makes Offshift's break ritual tangible, but a model-directed webhook or an arbitrary Home Assistant service call would give the ChatGPT App inappropriate authority over a home.

## Decision

The MVP supports one opaque scene id: `wind-down`. The Node MCP server may include that id in a break plan, but it cannot execute it. The macOS companion maps it to exactly `scene.offshift_wind_down`, uses Home Assistant's local REST service endpoint `POST /api/services/scene/turn_on`, and sends the configured endpoint and bearer token only after a direct local confirmation dialog.

The Home Assistant base URL lives only in local preferences and the long-lived token lives only in the local macOS Keychain. Neither is emitted to ChatGPT, the MCP server, the Worker, the model, or audit logs. The implementation does not auto-retry an unavailable call, does not enumerate entities, and does not allow a scene/entity/service/URL to come from model text.

## Consequences

- Users create `scene.offshift_wind_down` in their own Home Assistant instance before enabling the integration.
- A rejected token, missing scene, offline Home Assistant, and retry are visible to the local user; no other device action is attempted.
- A future second scene or automatic scene rule needs a new ADR and an explicit local consent design.
