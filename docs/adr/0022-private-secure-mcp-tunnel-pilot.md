# ADR 0022: Run the first ChatGPT pilot through a private Secure MCP Tunnel

**Status:** Accepted

**Date:** 2026-07-17

## Context

The anonymous Cloudflare Worker is useful only as a fixture/demo and cannot
hold user-specific state. A working ChatGPT demonstration is still valuable for
the MVP and Build Week review, but exposing a developer's local MCP server via
a public quick tunnel would expand the attack surface without solving identity
or tenant isolation.

## Decision

The first external ChatGPT path is a **single-user, fixture-only Secure MCP
Tunnel**. `tunnel-client` runs on the developer's Mac, reaches the local Node
MCP server over loopback, and opens only outbound HTTPS to the OpenAI tunnel
control plane. The local server remains deterministic demo data and does not
receive macOS timing, companion state, Home Assistant credentials, Codex work
data, or personal schedules.

The pilot requires a user-created OpenAI-hosted `tunnel_id`, a runtime
control-plane key held only in the current shell, and a tunnel profile created
by the user from documented `tunnel-client init` parameters. The repository
provides a launcher that validates prerequisites and runs `doctor`; it never
creates tunnels, persists credentials, or configures a ChatGPT connector.

## Consequences

- ChatGPT Developer Mode can exercise a private MCP endpoint without a public
  listener or an unauthenticated production API.
- This is not a multi-user beta and does not replace ADR 0021's OAuth,
  account-isolation, pairing, and durable-state requirements.
- The tunnel is an optional testing transport; no ChatGPT, Worker, or Codex
  path gains authority over the local companion, Lock Screen, Home Assistant,
  or Offshift settings.
- The runbook must state that the demo returns fixture data and must not be
  presented as personal activity monitoring.
