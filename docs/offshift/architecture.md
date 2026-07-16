# Offshift architecture

## Components

```text
ChatGPT model
  -> MCP tools (Offshift server)
  -> Apps SDK widget (Offshift dashboard)

Cloudflare Worker
  -> schedule/focus API and future D1 persistence

macOS companion
  -> aggregate active-app timing
  -> local work-pattern heuristic and shadow-mode log
  -> action-required overlay
  -> optional user-configured system Lock Screen rule
  -> direct local confirmation for one Home Assistant wind-down scene
```

The ChatGPT App is the planner and dashboard. A local companion owns desktop notifications and any device-side action because a sandboxed ChatGPT iframe cannot force a monitor-level interaction. This is an architectural boundary, not a workaround.

## Deployment stages

### Local demo

`offshift_server_node` serves `/mcp` through a local Node process. The widget is bundled into a self-contained MCP resource so the ChatGPT iframe does not depend on external asset loading.

### Cloudflare preview

`offshift_worker` provides a Worker-compatible API surface. The Worker will become the stable MCP host after the initial local resource path is verified. D1 persistence, device registration, and scheduled jobs belong to this stage.

### Local companion

`offshift_companion` now provides a SwiftPM menu-bar/window host around the local core: a dashboard, an intervention window, and a Settings scene. It samples local elapsed active/idle time and passes opaque aggregate `active-session` intervals into the heuristic; it never retains app titles or content. The companion sends only aggregate session facts such as `coding_active_seconds`, idle state, configured quiet-hours state, and bounded break-action history. It may accept an opt-in boolean that a Codex session is active, but never prompt, code, terminal, repository, or screen content. The companion owns the optional Lock Screen rule entirely locally: after a local Settings confirmation and macOS Accessibility permission, Protect starts one visible 30-second countdown, then may post the standard system Lock Screen shortcut. Server instructions cannot lock a device. It also maps the sole `wind-down` plan id to `scene.offshift_wind_down`; the user configures the Home Assistant base URL locally, the bearer token stays in Keychain, and a local confirmation dialog is required before `POST /api/services/scene/turn_on`. Server instructions cannot supply an endpoint, token, service, or entity id.

## Data minimization

The MVP uses deterministic fixture data. Future production telemetry must not include filenames, source code, browser history, screenshots, input events, or raw device identifiers.
