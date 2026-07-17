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

## Private ChatGPT pilot — Secure MCP Tunnel

For a real ChatGPT Developer Mode demonstration, prefer the private tunnel path
over the public Worker. It keeps the MCP server on your Mac and opens an
outbound-only connection to OpenAI; it does **not** turn Offshift into a
multi-user product or send macOS/companion data to ChatGPT.

This pilot serves deterministic fixture data only. It cannot read code,
prompts, terminals, screenshots, Screen Time, a real Offshift status, or any
smart-home credential. The companion remains entirely local.

### 1. Create the tunnel

In [OpenAI Platform tunnel settings](https://platform.openai.com/settings/organization/tunnels), create a tunnel and associate it with the ChatGPT workspace you will use. You need Tunnels **Read + Use** to run/select it and **Manage** to create or edit it. Download the latest
[`tunnel-client`](https://github.com/openai/tunnel-client/releases/latest) binary.

![Sanitized OpenAI Platform tunnel settings](https://developers.openai.com/images/platform/guides/secure-mcp-tunnels/platform-tunnels-settings.png)

### 2. Initialise one local profile

Keep the runtime key in the current shell only — never put it in `.env`, a
commit, a screen recording, or the Devpost submission.

```bash
export CONTROL_PLANE_API_KEY="sk-..."
export OFFSHIFT_TUNNEL_ID="tunnel_..."

tunnel-client init \
  --profile offshift-private \
  --tunnel-id "$OFFSHIFT_TUNNEL_ID" \
  --mcp-server-url "http://127.0.0.1:8000/mcp"

tunnel-client doctor --profile offshift-private --explain
```

The profile points only at the loopback fixture server. Do not configure it to
reach the macOS companion, Home Assistant, or an arbitrary internal endpoint.

### 3. Run the fixture server and tunnel

```bash
CONTROL_PLANE_API_KEY="sk-..." \
./script/run_private_tunnel.sh
```

The launcher rebuilds the widget, starts `offshift_server_node` on loopback,
waits for `/health`, runs `tunnel-client doctor`, and keeps the tunnel in the
foreground. Press `Ctrl-C` to stop both processes. It does not create a tunnel,
write a credential, or launch the macOS companion.

### 4. Connect the private app in ChatGPT

Enable Developer Mode, then open [ChatGPT Plugins](https://chatgpt.com/plugins), create a developer-mode app, choose **Tunnel**, and select `offshift-private`. Start a fresh conversation, enable Offshift, and try the golden prompts in [acceptance.md](docs/offshift/acceptance.md).

![Sanitized ChatGPT tunnel connection](https://developers.openai.com/images/platform/guides/secure-mcp-tunnels/chatgpt-connectors-tunnel.png)

Record only the Offshift widget and connector state for the pilot. Do not
record an active terminal, other apps, keys, or a personal desktop. If the
tunnel does not appear, first check the workspace association and `Read + Use`
permission, then re-run `tunnel-client doctor --profile offshift-private --explain`.

This is a **single-user private test transport**, not a public deployment.
See [ADR 0022](docs/adr/0022-private-secure-mcp-tunnel-pilot.md) and
[ADR 0021](docs/adr/0021-public-user-identity-and-tenant-isolation.md) for the
security boundary.

## OpenAI Build Week

Offshift is being prepared for the **Apps for Your Life** track as a
local-first off-ramp for developers caught in late-night AI building loops.
The submission checklist, judge path, evidence requirements, and clean-video
plan are in [docs/offshift/build-week-submission.md](docs/offshift/build-week-submission.md).

The sleeping companion is Red Card-derived art under Apache-2.0, with its
upstream license, `NOTICE`, source attribution, and Offshift modification notice
bundled in the repository and app. It is not an official OpenAI/Codex product
character or endorsement; the separately licensed Red Card whistle is not used.
See [the third-party notice](docs/third-party/redcard-codex-mascot.md).

Build and verify the local macOS host:

```bash
cd offshift_companion
swift test
./script/build_and_run.sh --verify
```

## Status

Tracked in [tixo-digital/program#150](https://gitlab.com/tixo-digital/program/-/work_items/150). The public Worker is a demo control plane only: no production credentials, real device integration, or remote lock authority is enabled.
