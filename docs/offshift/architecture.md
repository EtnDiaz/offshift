# Offshift architecture

## Components

```text
ChatGPT model
  -> MCP tools (Offshift server)
  -> Apps SDK widget (Offshift dashboard)

Cloudflare Worker
  -> schedule/focus API and future D1 persistence

Future macOS companion
  -> aggregate active-app timing
  -> local work-pattern heuristic and shadow-mode log
  -> action-required overlay
  -> optional user-configured system Lock Screen rule
  -> signed command to an allowlisted Home Assistant scene
```

The ChatGPT App is the planner and dashboard. A local companion owns desktop notifications and any device-side action because a sandboxed ChatGPT iframe cannot force a monitor-level interaction. This is an architectural boundary, not a workaround.

## Deployment stages

### Local demo

`offshift_server_node` serves `/mcp` through a local Node process. The widget is bundled into a self-contained MCP resource so the ChatGPT iframe does not depend on external asset loading.

### Cloudflare preview

`offshift_worker` provides a Worker-compatible API surface. The Worker will become the stable MCP host after the initial local resource path is verified. D1 persistence, device registration, and scheduled jobs belong to this stage.

### Local companion

`offshift_companion` now provides a SwiftPM menu-bar/window host around the local core: a dashboard, an intervention window, and a Settings scene. It uses deterministic fixture states until a local aggregate-time sampler is connected. The companion sends only aggregate session facts such as `coding_active_seconds`, idle state, configured quiet-hours state, and bounded break-action history. It may accept an opt-in boolean that a Codex session is active, but never prompt, code, terminal, repository, or screen content. The companion owns the optional Lock Screen rule entirely locally. It receives a signed, short-lived, device-scoped instruction only for local overlay changes or user-approved scene identifiers; server instructions cannot lock a device.

## Data minimization

The MVP uses deterministic fixture data. Future production telemetry must not include filenames, source code, browser history, screenshots, input events, or raw device identifiers.
