# Offshift acceptance evidence

## Current evidence

| Area | Check | Status | Evidence |
| --- | --- | --- | --- |
| Node domain | Idempotent prepare/snooze/on-call/resume, explainable risk snapshot, and one opaque scene id | Pass | `pnpm --dir offshift_server_node test` — 6 tests; only `wind-down` is accepted and arbitrary URLs are rejected, 2026-07-16 |
| Node server | Type safety | Pass | `pnpm --dir offshift_server_node typecheck`, 2026-07-16 |
| Widget | Type safety, bundle, safe stale-session explanation, and explicit reversible controls | Pass locally | `pnpm run tsc:app`; `pnpm run build --target offshift`; Browser QA at `http://localhost:4445/offshift.html` verified the loading fallback becomes a readable stale-session state with one safe refresh control and no console errors, 2026-07-17. Full ChatGPT host rendering remains unverified. |
| MCP runtime | Health, scene contract, and versioned widget resource | Pass locally | `GET /health` returned only `scenes:["wind-down"]`; MCP `tools/list` and `resources/read` verified `ui://widget/offshift-v3.html` and `text/html;profile=mcp-app`, 2026-07-16 |
| Node MCP HTTPS | Public `/mcp` endpoint and current widget resource response | Partial | An earlier Cloudflare Quick Tunnel verified public `health`, `tools/list`, and `resources/read`. The current `v3` local endpoint is verified, but its new Quick Tunnel stalled while requesting a URL, so `v3` is not claimed public yet. |
| Worker MCP HTTPS | Public deployment, React widget resource, and mutation authority contract | Pass (contract) | `https://offshift-demo-api.tixo-digital.workers.dev/mcp` returned health with `ui://widget/offshift-worker-v4.html`; `tools/list` exposed eight tools, and every mutation is `app`-visible plus requires a server-verified five-minute dashboard capability. The public Worker now echoes the MCP protocol version offered at `initialize` (deployment `9095119e-7bb3-4a7b-be10-bb3a89dc20a1`), and direct `initialize` plus `tools/list` checks pass, 2026-07-17. ChatGPT-host rendering remains unverified. |
| Codex relay | Signed, coarse, opt-in lifecycle receiver | Pass locally; not deployed | `npm test` and `npm run typecheck` in `offshift_worker` — 17 tests. `/v1/codex/events` is disabled without `CODEX_RELAY_SECRET`; it accepts only signed `session.started`, `session.heartbeat`, and `session.ended` envelopes, rejects stale/unsigned/content-bearing payloads, and deduplicates event IDs. It cannot command a lock, scene, companion setting, or Codex session, 2026-07-17. |
| ChatGPT | Developer Mode connection and golden prompts | Blocked by ChatGPT connector provisioning | Developer Mode is enabled in a signed-in ChatGPT session. The direct New Plugin form accepted the Offshift name, safety description, public HTTPS `/mcp` URL, `No Auth`, and the unreviewed-server acknowledgement, but Create returned the host toast: “Error creating connector — Something went wrong.” This was repeated after the Worker’s MCP version negotiation fix, while public `initialize` and `tools/list` remained valid. The connector was not created, so golden prompts cannot run; this is an external ChatGPT provisioning failure, not a claimed app pass, 2026-07-17. |
| macOS companion | Multi-factor policy, local aggregate sampler, animated sleeping Codex care mascot, black monitor-covering intervention, reversible pause/off gate, local host, one direct-confirmation scene, and optional system Lock Screen rule | Pass (non-locking tests) | `swift test` — 27 tests; `./script/build_and_run.sh --verify`; Computer verification on 2026-07-17 opened the borderless black care surface with the new local six-frame sleeping-Codex sequence. The sequence has a user-supplied Red Card-derived adaptation, deterministic magenta-background/panel-border removal, bundled source notice, and visual QA contact sheet. Its default keyboard action reads “Start a 5-minute break and leave”; helper text stays high-contrast. A quiet-hours fixture reads “A kind time to call it tonight” and explains that work/tokens remain. The local `Sleep care` → `Off` transition cancels sampling, countdowns, and interventions; it does not read Apple Screen Time in the MVP. The gentle path has no on-call or Lock Screen controls. `Protect` retains on-call/cancel controls and, only with its separately enabled local rule, uses a visible 10-second countdown before the macOS Lock Screen request. No automated or UI test invokes the system Lock Screen. |
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
