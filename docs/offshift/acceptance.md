# Offshift acceptance evidence

## Current evidence

| Area | Check | Status | Evidence |
| --- | --- | --- | --- |
| Node domain | Idempotent prepare/snooze/on-call/resume, explainable risk snapshot, and one opaque scene id | Pass | `pnpm --dir offshift_server_node test` — 6 tests; only `wind-down` is accepted and arbitrary URLs are rejected, 2026-07-16 |
| Node server | Type safety | Pass | `pnpm --dir offshift_server_node typecheck`, 2026-07-16 |
| Widget | Type safety, bundle, safe stale-session explanation, and explicit reversible controls | Partial | `pnpm run tsc:app`; `pnpm run build --target offshift`; the local Browser preview reaches the safe stale-session state with one refresh control and no console errors, 2026-07-17. A root-width defect was found in that preview and fixed immediately afterward; a fresh visual pass and full ChatGPT-host rendering remain unverified. |
| MCP runtime | Health, scene contract, and versioned widget resource | Pass locally | `GET /health` returned only `scenes:["wind-down"]`; MCP `tools/list` and `resources/read` verified `ui://widget/offshift-v3.html` and `text/html;profile=mcp-app`, 2026-07-16 |
| Node MCP HTTPS | Public `/mcp` endpoint and current widget resource response | Partial | An earlier Cloudflare Quick Tunnel verified public `health`, `tools/list`, and `resources/read`. The current `v3` local endpoint is verified, but its new Quick Tunnel stalled while requesting a URL, so `v3` is not claimed public yet. |
| Worker MCP HTTPS | Public deployment, React widget resource, and mutation authority contract | Pass (contract) | `https://offshift-demo-api.tixo-digital.workers.dev/mcp` returned health with `ui://widget/offshift-worker-v4.html`; `tools/list` exposed eight tools, and every mutation is `app`-visible plus requires a server-verified five-minute dashboard capability. The public Worker now echoes the MCP protocol version offered at `initialize` (deployment `9095119e-7bb3-4a7b-be10-bb3a89dc20a1`), and direct `initialize` plus `tools/list` checks pass, 2026-07-17. ChatGPT-host rendering remains unverified. |
| Codex relay | Signed, coarse, opt-in lifecycle receiver | Pass locally; not deployed | `npm test` and `npm run typecheck` in `offshift_worker` — 17 tests. `/v1/codex/events` is disabled without `CODEX_RELAY_SECRET`; it accepts only signed `session.started`, `session.heartbeat`, and `session.ended` envelopes, rejects stale/unsigned/content-bearing payloads, and deduplicates event IDs. It cannot command a lock, scene, companion setting, or Codex session, 2026-07-17. |
| ChatGPT | Developer Mode connection and golden prompts | Blocked by ChatGPT connector provisioning | Developer Mode is enabled in a signed-in ChatGPT session. The direct New Plugin form accepted the Offshift name, safety description, public HTTPS `/mcp` URL, `No Auth`, and the unreviewed-server acknowledgement, but Create returned the host toast: “Error creating connector — Something went wrong.” This was repeated after the Worker’s MCP version negotiation fix, while public `initialize` and `tools/list` remained valid. The connector was not created, so golden prompts cannot run; this is an external ChatGPT provisioning failure, not a claimed app pass, 2026-07-17. |
| macOS companion | Multi-factor policy, local aggregate sampler, sleeping Codex brand, black monitor-covering intervention, reversible pause/off gate, local host, one direct-confirmation scene, and optional system Lock Screen rule | Partial — automated pass | `swift test` — 28 tests; `./script/build_and_run.sh --verify`, 2026-07-17. The redesigned Today, native Settings, and care screen compile. The new pure visibility gate proves that every fresh Protect episode starts hidden and must receive a local “surface visible” event before countdown eligibility; closing the care surface now cancels a running countdown. Visual Computer QA is pending because the Mac is currently at its system Lock Screen; no automated or UI test invokes the system Lock Screen. |
| UX redesign gate | One decision on Today, durable controls only in Settings, intentional full-screen care composition, and no technical policy tokens in ordinary flow | Partial — automated pass | The redesign moves Today into `OffshiftTodayView`, moves development fixtures into a Debug-only menu, simplifies the Apps SDK widget to one primary decision plus a reversible deferral, and records the local visibility-before-countdown rule in ADR 0016. Visual acceptance at default desktop size awaits the same manual-unlock QA pass. |
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
