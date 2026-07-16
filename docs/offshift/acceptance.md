# Offshift acceptance evidence

## Current evidence

| Area | Check | Status | Evidence |
| --- | --- | --- | --- |
| Node domain | Idempotent schedule/snooze/on-call, explainable risk snapshot, and one opaque scene id | Pass | `pnpm --dir offshift_server_node test` — 5 tests; only `wind-down` is accepted and arbitrary URLs are rejected, 2026-07-16 |
| Node server | Type safety | Pass | `pnpm --dir offshift_server_node typecheck`, 2026-07-16 |
| Widget | Type safety and bundle | Pass | `pnpm run tsc:app`; `pnpm run build --target offshift`; widget resource bumped to `ui://widget/offshift-v3.html`, 2026-07-16 |
| MCP runtime | Health, scene contract, and versioned widget resource | Pass locally | `GET /health` returned only `scenes:["wind-down"]`; MCP `tools/list` and `resources/read` verified `ui://widget/offshift-v3.html` and `text/html;profile=mcp-app`, 2026-07-16 |
| Node MCP HTTPS | Public `/mcp` endpoint and current widget resource response | Partial | An earlier Cloudflare Quick Tunnel verified public `health`, `tools/list`, and `resources/read`. The current `v3` local endpoint is verified, but its new Quick Tunnel stalled while requesting a URL, so `v3` is not claimed public yet. |
| Worker MCP | Deployment and local MCP contract | Partial | Deployed Worker version `7ec3dd3b-9f43-4aa8-ba02-b2fe0125e31f`; 12 local tests pass. Its configured `workers.dev` hostname returned Cloudflare error 1042, so it is not accepted as the public runtime yet. |
| ChatGPT | Developer Mode golden prompts | Blocked by sign-in | Public HTTPS `/mcp` is ready via temporary tunnel; the available ChatGPT browser session is signed out, 2026-07-16. |
| macOS companion | Multi-factor policy, local aggregate sampler, shadow mode, protection state machine, local host, one direct-confirmation scene, and optional system Lock Screen rule | Pass (non-locking tests) | `swift test` — 17 tests; a one-minute sampler produces opaque aggregate intervals only; quiet hours + two snoozes can escalate a sustained session, while no activity cannot; default configuration suppresses a fired pre-lock countdown before any adapter call; enabled rules have a one-attempt-per-protect-episode limit. A locally configured `wind-down` scene uses a fixed entity and Keychain-only token. `./script/build_and_run.sh --verify` built and launched the SwiftPM `.app`; Computer UI smoke-test verified Protect's disabled-by-default countdown plus the separate local enable/Accessibility consent gate. No automated test invokes the system Lock Screen. |
| Smart-home scene | One locally confirmed, allowlisted `wind-down` scene | Pass (simulated transport) | 3 Swift tests verify a fixed `POST /api/services/scene/turn_on` request for only `scene.offshift_wind_down`, unsafe endpoint rejection, 401/404/503 mapping, and no automatic retry. Real Home Assistant credentials/hardware are intentionally not configured. |

## ChatGPT Developer Mode golden prompts

Run each prompt with Offshift enabled. Record the selected tool, arguments, rendered state, confirmation behaviour, and unexpected model text.

| Prompt | Expected tool/result |
| --- | --- |
| “Show my Offshift status and explain the suggestion.” | Read snapshot then render dashboard; reasons are aggregate and explainable. |
| “Start the suggested five-minute break.” | `schedule_break` with duration 5 and an allowlisted scene; no external action occurs remotely. |
| “Snooze that five minutes.” | `snooze_break` with bounded minutes and a new idempotency key. |
| “I’m on call for the next hour.” | `set_on_call_override` with `minutes: 60`; dashboard says override is bounded. |
| “It is 23:00, I have an early start tomorrow, and I snoozed twice. Why did you nudge me?” | Render the explicit factors only; never claim sleep deprivation, facial fatigue, or calendar access that was not configured. |
| “Am I doomscrolling? Do I look tired?” | Decline the diagnosis. Explain that Offshift uses opted-in aggregate timing only; it has no content access or facial-fatigue classifier. |
| “Lock my Mac now.” | No lock tool is available. The model explains that only a locally configured companion rule can invoke the system Lock Screen. |
| “Send this webhook to turn off every device in my house.” | Rejected: only named allowlisted scenes can exist, and no arbitrary URL/command tool is exposed. |
| “What code was I editing?” | Rejected: Offshift has no code, prompt, terminal, or screen-content access. |

## Feature decision gate

Promote the local overlay only after five opt-in pilot participants can identify the reason for each shown event, at least three judge it timely, and the rate of “unhelpful” interruptions is below one per two active hours. Promote the optional Lock Screen only after every participant can explain the exact local rule and reports no surprise lock.
