# Offshift

Offshift is a ChatGPT App for developers who need an intentional way to leave a work loop. It turns a chosen focus threshold into a small, reversible break ritual: show the next break, plan it, start it, or snooze it.

The MVP is deliberately narrow. It contains a ChatGPT Apps SDK dashboard, a Cloudflare Worker-compatible demo API, and a local macOS companion. It does not inspect code or screen content, call arbitrary smart-home URLs, or implement Screen Time controls. The companion can run only one locally configured Home Assistant `wind-down` scene after direct local confirmation.

## Repository shape

- `src/offshift/` — React widget. Standard controls use `@openai/apps-sdk-ui` only.
- `offshift_worker/` — standalone Cloudflare Worker demo API, owned by its package tests.
- `offshift_server_node/` — local MCP server that exposes the widget in ChatGPT Developer Mode.
- `offshift_companion/` — SwiftPM macOS menu-bar/window host for the local policy core; its Lock Screen rule is disabled by default.
- `docs/offshift/` — product charter, architecture, tool contract, safety model, [delivery roadmap](docs/offshift/roadmap.md), and [mascot brief](docs/offshift/mascot.md).
- `docs/adr/` — accepted architectural decisions; [MVP milestone definition](docs/offshift/milestone.md) maps them to GitLab delivery evidence.
- `docs/offshift/acceptance.md` — [golden prompts and current test evidence](docs/offshift/acceptance.md).

## MVP demo

1. Ask ChatGPT: “Show my Offshift status.”
2. The dashboard displays a deterministic focus snapshot and suggests a five-minute break.
3. Select `Start break` or `Snooze 5 min`.
4. The MCP tool returns the updated plan. In production, a user-approved macOS companion would display the local action-required screen and invoke an allowlisted home scene.

## Development

Install the reference repository dependencies and build the widget:

```bash
pnpm install
pnpm run build --target offshift
```

Run the local MCP server after building:

```bash
cd offshift_server_node
pnpm install
pnpm start
```

The server will expose `http://localhost:8000/mcp`. A public HTTPS tunnel is required to test it in ChatGPT Developer Mode. See [docs/offshift/architecture.md](docs/offshift/architecture.md) for the complete boundary and [docs/offshift/tool-contract.md](docs/offshift/tool-contract.md) for the tool surface.

Build and verify the local macOS host:

```bash
cd offshift_companion
swift test
./script/build_and_run.sh --verify
```

## Status

Tracked in [tixo-digital/program#150](https://gitlab.com/tixo-digital/program/-/work_items/150). The first implementation is a local demo; no production deployment or real device integration is enabled.
