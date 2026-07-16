# Offshift

Offshift is a ChatGPT App for developers who need an intentional way to leave a work loop. It turns a chosen focus threshold into a small, reversible break ritual: inspect the suggestion, prepare a reset, snooze it, or take a bounded on-call override.

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
3. Select `Prepare a 5-minute reset`, `Snooze 5 min`, or `I’m on call for 60 min`.
4. The MCP tool returns the updated plan. It never starts a local notification, scene, or Lock Screen action. Those actions belong solely to the separately configured macOS companion.

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

The server will expose `http://localhost:8000/mcp`. A public HTTPS endpoint is required to test it in ChatGPT Developer Mode. The current Worker candidate is available at `https://offshift-demo-api.tixo-digital.workers.dev/mcp`; it remains a demo until the Developer Mode golden prompts are recorded. See [docs/offshift/architecture.md](docs/offshift/architecture.md) for the complete boundary and [docs/offshift/tool-contract.md](docs/offshift/tool-contract.md) for the tool surface.

Build and verify the local macOS host:

```bash
cd offshift_companion
swift test
./script/build_and_run.sh --verify
```

## Status

Tracked in [tixo-digital/program#150](https://gitlab.com/tixo-digital/program/-/work_items/150). The public Worker is a demo control plane only: no production credentials, real device integration, or remote lock authority is enabled.
