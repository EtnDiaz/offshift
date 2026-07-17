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
| macOS companion | Tray-first local companion, consent-first onboarding, aggregate sampler, sleeping Codex animation, black monitor-covering intervention, reversible pause/off gate, local host, one direct-confirmation scene, and optional system Lock Screen rule | Partial — automated pass | `swift test` — 33 tests; `./script/build_and_run.sh --verify`, 2026-07-17. First launch stays off until a local choice in onboarding; optional Focus Status is requested only from its local control and is explanation-only. Today and Settings are now explicit AppKit-on-demand windows, so normal launch is tray-only. ADR 0016 ensures every fresh Protect episode starts hidden and needs a local “surface visible” event before countdown eligibility; closing the care surface cancels a running countdown. ADR 0017 adds a Debug-only local care preview, including the local `--care-preview` script route, that cannot start the Lock Screen countdown or a smart-home action; four local Escape presses within ten seconds terminate the companion as an emergency exit. Visual Computer QA is in progress; no automated or UI test invokes the system Lock Screen. |
| UX redesign gate | Tray-first entry, simple consent-first setup, one decision on Today, durable controls only in Settings, intentional full-screen care composition, and no technical policy tokens in ordinary flow | Partial — manual + automated pass | Computer Use verified the first-run onboarding and its `Not now` path: no permission is requested, Offshift remains off, and Today shows the explicit local enable control. A real tray-only launch has no Today window; an on-demand AppKit window coordinator now owns Today and care windows. The care preview launches through the local `--care-preview` route without a Lock Screen countdown. Its monitor-level window is intentionally outside Computer Use’s accessibility capture after launch, so its final visual/keyboard inspection still needs a human desktop pass; its former borderless-key-window warning is fixed. The Apps SDK widget remains one primary decision plus a reversible deferral; it may never control a local companion window. |
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

## Closure audit — 2026-07-17

The implementation-facing verification was repeated from the current
`b93f01d` worktree:

| Check | Result |
| --- | --- |
| Worker | `npm run typecheck` and `npm test` pass (17 tests). The public Worker returns `/health`, negotiates `initialize` at `2025-03-26`, exposes eight tools with no lock tool, and serves `ui://widget/offshift-worker-v4.html` as `text/html;profile=mcp-app`. |
| Node MCP domain | `pnpm test` and `pnpm typecheck` pass (6 tests). |
| macOS companion | `swift test` passes (33 tests); `./script/build_and_run.sh --verify` builds, signs, and launches the tray-first bundle. |
| Care preview | `./script/build_and_run.sh --care-preview` launches the local visual-only process with `--care-preview`. It cannot enter a Lock Screen countdown or execute Home Assistant; that boundary is covered by the focused test. |

The remaining evidence is intentionally not inferred from these checks:

1. ChatGPT's Developer Mode host has not provisioned the public connector, so the golden prompts and host-rendered widget remain unverified. The form previously returned “Error creating connector — Something went wrong”; a current deep link opens Plugins but does not restore that form.
2. Computer Use cannot obtain accessibility state for the screen-saver-level care window, and therefore cannot perform the final visual/real-keyboard pass. The four-Escape gate is unit-tested, but a human desktop pass is still required for that monitor-level surface.
3. No five-person opt-in pilot evidence exists yet. The pilot protocol and non-identifying recording template are in [pilot-readiness.md](pilot-readiness.md); they are preparation, not pilot results.
