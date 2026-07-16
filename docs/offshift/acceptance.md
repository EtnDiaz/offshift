# Offshift acceptance evidence

## Current evidence

| Area | Check | Status | Evidence |
| --- | --- | --- | --- |
| Node domain | Idempotent schedule/snooze/on-call and explainable risk snapshot | Pass | `pnpm --dir offshift_server_node test` — 4 tests, 2026-07-16 |
| Node server | Type safety | Pass | `pnpm --dir offshift_server_node typecheck`, 2026-07-16 |
| Widget | Type safety and bundle | Pass | `pnpm run tsc:app`; `pnpm run build --target offshift`, 2026-07-16 |
| MCP runtime | Health, behaviour snapshot, and bounded on-call tool | Pass locally | `GET /health`; MCP `get_work_pattern_snapshot`; MCP `set_on_call_override`, 2026-07-16 |
| Node MCP HTTPS | Public `/mcp` endpoint and resource response | Pass (ephemeral) | Cloudflare Quick Tunnel to the local Node server; public `health`, `tools/list`, and `resources/read`, 2026-07-16 |
| Worker MCP | Deployment and local MCP contract | Partial | Deployed Worker version `7ec3dd3b-9f43-4aa8-ba02-b2fe0125e31f`; 12 local tests pass. Its configured `workers.dev` hostname returned Cloudflare error 1042, so it is not accepted as the public runtime yet. |
| ChatGPT | Developer Mode golden prompts | Blocked by sign-in | Public HTTPS `/mcp` is ready via temporary tunnel; the available ChatGPT browser session is signed out, 2026-07-16. |
| macOS companion | Policy, shadow mode, protection state machine | Pass | `swift test` — 10 tests; default configuration suppresses a fired pre-lock countdown before any adapter call, 2026-07-16 |
| Smart-home scene | Allowlisted `wind-down` contract | Pending | No hardware/credentials configured |

## ChatGPT Developer Mode golden prompts

Run each prompt with Offshift enabled. Record the selected tool, arguments, rendered state, confirmation behaviour, and unexpected model text.

| Prompt | Expected tool/result |
| --- | --- |
| “Show my Offshift status and explain the suggestion.” | Read snapshot then render dashboard; reasons are aggregate and explainable. |
| “Start the suggested five-minute break.” | `schedule_break` with duration 5 and an allowlisted scene; no external action occurs remotely. |
| “Snooze that five minutes.” | `snooze_break` with bounded minutes and a new idempotency key. |
| “I’m on call for the next hour.” | `set_on_call_override` with `minutes: 60`; dashboard says override is bounded. |
| “Lock my Mac now.” | No lock tool is available. The model explains that only a locally configured companion rule can invoke the system Lock Screen. |
| “Send this webhook to turn off every device in my house.” | Rejected: only named allowlisted scenes can exist, and no arbitrary URL/command tool is exposed. |
| “What code was I editing?” | Rejected: Offshift has no code, prompt, terminal, or screen-content access. |

## Feature decision gate

Promote the local overlay only after five opt-in pilot participants can identify the reason for each shown event, at least three judge it timely, and the rate of “unhelpful” interruptions is below one per two active hours. Promote the optional Lock Screen only after every participant can explain the exact local rule and reports no surprise lock.
