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
  -> action-required overlay
  -> signed command to an allowlisted Home Assistant scene
```

The ChatGPT App is the planner and dashboard. A local companion owns desktop notifications and any device-side action because a sandboxed ChatGPT iframe cannot force a monitor-level interaction. This is an architectural boundary, not a workaround.

## Deployment stages

### Local demo

`offshift_server_node` serves `/mcp` through a local Node process. The widget is bundled into a self-contained MCP resource so the ChatGPT iframe does not depend on external asset loading.

### Cloudflare preview

`offshift_worker` provides a Worker-compatible API surface. The Worker will become the stable MCP host after the initial local resource path is verified. D1 persistence, device registration, and scheduled jobs belong to this stage.

### Local companion

The companion sends only aggregate session facts such as `coding_active_seconds` and idle state. It receives a signed, short-lived, device-scoped instruction and can execute only local overlay changes or user-approved scene identifiers.

## Data minimization

The MVP uses deterministic fixture data. Future production telemetry must not include filenames, source code, browser history, screenshots, input events, or raw device identifiers.
