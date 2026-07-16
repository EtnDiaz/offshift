# Offshift Worker MCP-host candidate

This package is a local-testable Cloudflare Worker candidate for the Offshift MCP host. It keeps the existing bounded REST demo API and adds a stateless JSON-RPC 2.0 MCP endpoint at `/mcp`.

It is deliberately safe by construction: there are no outbound `fetch` calls, credentials, arbitrary webhooks, remote device commands, remote lock actions, or source/screen/content collection. Schedules are only demo records in Worker-isolate memory.

## MCP contract

The endpoint follows the project's interactive-decoupled Apps SDK shape:

| Tool | Role | Safety |
| --- | --- | --- |
| `get_focus_snapshot` | Data | Read-only aggregate focus data; omits the legacy REST `focusScore` from model-visible output. |
| `get_behavior_policy_snapshot` | Data | Read-only, explainable routine/drift/protect policy plus a shadow-mode aggregate snapshot. |
| `preview_break_plan` | Data | Read-only preview of one allowlisted action. |
| `schedule_break` | Mutation | Explicit, bounded, closed-world; requires an idempotency key. |
| `snooze_break` | Mutation | Explicit, bounded, closed-world; requires an idempotency key. |
| `render_offshift_dashboard` | Render | The only tool with `_meta.ui.resourceUri` and `openai/outputTemplate`. |

`resources/read` serves the versioned `ui://widget/offshift-worker-v1.html` resource as `text/html;profile=mcp-app`. Its deliberate CSP has empty `connectDomains` and `resourceDomains`, and its small read-only renderer uses the MCP Apps `postMessage` bridge (`ui/initialize` and `ui/notifications/tool-result`) rather than `window.openai`.

The resource is a host-contract smoke-test renderer, not a replacement for the repository's React dashboard. It intentionally has no custom buttons or external assets; the existing React widget remains the standard-control implementation. A production integration must inject a built, version-bumped widget bundle into the Worker resource before claiming ChatGPT UI verification.

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
  -d '{"jsonrpc":"2.0","id":2,"method":"resources/read","params":{"uri":"ui://widget/offshift-worker-v1.html"}}'

curl 'http://localhost:8787/v1/behavior/snapshot?userId=ada'
```

Run the focused checks:

```sh
npm run typecheck
npm test
```

ChatGPT Developer Mode is intentionally not verified by this package: it needs a public HTTPS `/mcp` endpoint and a metadata refresh. Do not describe a local Worker as a verified ChatGPT runtime.

## Persistence limitation

`InMemoryDemoStore` deliberately stores plans and idempotency records only in the Worker isolate's memory. State may disappear after a restart, scale-out, or a request on another isolate. Use a durable Cloudflare binding (for example, Durable Objects or D1) before relying on scheduling in production; keep behavior-policy evaluation and any lock-screen action local to the future macOS companion.
