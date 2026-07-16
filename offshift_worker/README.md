# Offshift Worker MCP-host candidate

This package is a local-testable Cloudflare Worker candidate for the Offshift MCP host. It keeps the existing bounded REST demo API and adds a JSON-RPC 2.0 MCP endpoint at `/mcp` with short-lived, per-dashboard in-isolate session state.

It is deliberately safe by construction: there are no outbound `fetch` calls, credentials, arbitrary webhooks, remote device commands, remote lock actions, or source/screen/content collection. Schedules are only demo records in Worker-isolate memory.

## MCP contract

The endpoint follows the project's interactive-decoupled Apps SDK shape:

| Tool | Role | Safety |
| --- | --- | --- |
| `get_focus_snapshot` | Data | Read-only aggregate focus data; omits the legacy REST `focusScore` from model-visible output. |
| `get_work_pattern_snapshot` | Data | Read-only, explainable routine/drift/protect policy plus a shadow-mode aggregate snapshot. |
| `preview_break_plan` | Data | Read-only preview of one allowlisted action. |
| `schedule_break` | Mutation | Explicit, bounded, closed-world; requires an idempotency key and dashboard capability. |
| `snooze_break` | Mutation | Explicit, bounded, closed-world; requires an idempotency key and dashboard capability. |
| `set_on_call_override` | Mutation | Explicit, bounded on-call exception; requires an idempotency key and dashboard capability. |
| `resume_reminders` | Mutation | Explicitly ends the on-call exception; requires an idempotency key and dashboard capability. |
| `render_offshift_dashboard` | Render | The only tool with `_meta.ui.resourceUri` and `openai/outputTemplate`. |

`resources/read` serves the versioned `ui://widget/offshift-worker-v4.html` resource as `text/html;profile=mcp-app`. Its deliberate CSP has empty `connectDomains` and an allowlist only for the Worker-hosted React assets. The widget uses the MCP Apps bridge; it does not depend on `window.openai`.

The Worker injects the repository's built React dashboard as a versioned static asset. Read-only tools remain model-visible; all mutations are `app`-visible only and originate from an explicit dashboard click. `render_offshift_dashboard` mints a random, opaque, five-minute `widgetCapability` for that dashboard only. It is returned exclusively in the tool result `_meta` under `offshift/widgetCapability`; it is never included in tool text or `structuredContent`. The widget holds it only in memory and supplies it with every mutation. The Worker rejects missing, invalid, and expired capabilities server-side.

Each capability owns a separate in-memory dashboard session: its current plan and idempotency results cannot be shared with another dashboard capability. A new render receives a new session. This is intentionally short-lived demo state, not authentication or a durable user identity; it grants only the four bounded dashboard mutations and cannot invoke notifications, a device, a lock, a network request, or a smart-home scene. Scheduling still prepares a reset record only: a separate local companion remains the only authority for notifications, a scene, or Lock Screen.

## REST endpoints

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/health` | Service/MCP metadata. |
| `GET` | `/v1/focus/snapshot?userId=ada` | Deterministic legacy demo focus snapshot. |
| `GET` | `/v1/behavior/policy` | Explainable shadow-mode policy and data boundaries. |
| `GET` | `/v1/behavior/snapshot?userId=ada` | Deterministic aggregate work-pattern snapshot. |
| `POST` | `/v1/breaks/preview` | Preview one allowlisted break action. |
| `POST` | `/v1/breaks/schedule` | Create a bounded demo schedule; accepts optional retry-safe `idempotencyKey`. |
| `POST` | `/v1/breaks/:id/snooze` | Delay a schedule; accepts optional retry-safe `idempotencyKey`. |
| `POST` | `/mcp` | MCP JSON-RPC endpoint (`initialize`, `tools/list`, `tools/call`, `resources/list`, `resources/read`). |

Only `stretch`, `walk`, `breathe`, and `hydrate` are accepted. Clients cannot submit custom plan steps, URLs, webhook targets, device credentials, or lock commands.

## Run and verify locally

```sh
npm install
npm run dev
```

In another terminal, verify the host boundary:

```sh
curl http://localhost:8787/health

curl -X POST http://localhost:8787/mcp \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'

curl -X POST http://localhost:8787/mcp \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":2,"method":"resources/read","params":{"uri":"ui://widget/offshift-worker-v4.html"}}'

curl 'http://localhost:8787/v1/behavior/snapshot?userId=ada'
```

Run the focused checks:

```sh
npm run typecheck
npm test
```

ChatGPT Developer Mode is intentionally not verified by this package: it needs a public HTTPS `/mcp` endpoint and a metadata refresh. Do not describe a local Worker as a verified ChatGPT runtime.

## Persistence limitation

`InMemoryDemoStore` and dashboard capability sessions deliberately keep plans and idempotency records only in Worker-isolate memory. State may disappear after a restart, scale-out, or a request on another isolate. Use a durable Cloudflare binding (for example, Durable Objects or D1) before relying on scheduling in production; keep behavior-policy evaluation and any lock-screen action local to the future macOS companion.
