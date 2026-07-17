# Offshift delivery roadmap

## Product thesis

Offshift should help a developer interrupt an unhealthy-looking work loop before it becomes another ignored notification. The first job is not to measure sleep or diagnose burnout. It is to make a late, uninterrupted, repeatedly-snoozed building session visible and give the person a respectful, reversible way to stop.

The product calls this a **work-pattern risk**, never a health score. All detection is opt-in, explainable, and can be paused until tomorrow or disabled immediately from the local companion.

## What is already built

The first local slice is complete: an Apps SDK widget, local Node MCP server, reversible widget-only schedule/snooze/on-call/resume controls, a tested Cloudflare Worker demo API, and a macOS companion. The dashboard is intentionally honest: it prepares a reset but cannot itself run a reminder, scene, or lock. The companion observes only aggregate active/idle duration locally, has a protection window, supports a disabled-by-default local Lock Screen rule, and can run one locally confirmed Home Assistant `wind-down` scene. It still needs public Apps SDK runtime validation and pilot evidence before the protection rule should be recommended.

## Sequenced milestones

| Milestone | Build | Test / decision gate | Outcome |
| --- | --- | --- | --- |
| 1. Real App loop | Put the MCP endpoint behind HTTPS, bind the Worker persistence boundary, and test the widget in ChatGPT Developer Mode. | Run direct, indirect, and negative golden prompts; confirm tool selection, arguments, repeat-call idempotency, rendering, and recovery state. | A real ChatGPT App can explain and prepare a break; only the local companion may carry out local actions. |
| 2. Shadow behaviour model | Build a local macOS collector that calculates a risk from coarse aggregates but shows no interruption yet. | Five developer participants use it for several work sessions; compare suggested events with a short self-report. | We learn whether the signals feel accurate enough to show. |
| 3. Respectful intervention | Enable a local notification, then a small action-required overlay only for high-confidence patterns. Add a separately enabled, entirely local system Lock Screen rule only after overlay validation. | Measure acceptance, snooze, disable, and “unhelpful” events; test on-call override, local pause-until-tomorrow, instant disable, the pre-lock countdown, and the one-lock-per-night limit. | The ritual helps rather than distracts or traps the user. |
| 4. One ambient action | Integrate exactly one user-owned, allowlisted Home Assistant `wind-down` scene. | Test a fixed request in a sandbox with revoked credentials, retry, offline, and explicit-confirmation cases. | The demo has a real-world action without unsafe open-ended control. |
| 5. Longer-horizon platforms | Evaluate Screen Time separately, only after the core loop is proven and Apple entitlement feasibility is known. The companion already has a local `Sleep care` → `Off` reducer that cancels sampling, countdowns, and the intervention surface; a future adapter may call it, but the MVP does not read Apple’s system mode. | Prototype under Apple’s required consent/entitlement path; abandon if it compromises the product timeline. | No dependency on Screen Time for the product to be useful. |

## Behaviour model: first version

The first heuristic runs locally with user-controlled thresholds. It may consider:

- uninterrupted active-work minutes and lack of meaningful idle gaps;
- local time inside a user-configured quiet-hours window;
- total active time since the last accepted break;
- a run of snoozes or dismissals; and
- an explicitly configured next-day early-start reminder, as explanation only; and
- optionally, a boolean that a Codex session is active.

It may not inspect prompts, code, diffs, terminal output, filenames, browser history, keystrokes, screenshots, microphone input, or camera frames. "Codex session active" is only a coarse opt-in state supplied by a local integration; it is not something the ChatGPT App can infer remotely. A future camera experiment may provide only a local presence-at-device bit to reduce false positives; it never judges whether a face looks tired or infers health, emotion, identity, age, or attention. Screen Time is a later native integration and may contribute only consented category aggregates, never browser or app content.

Use three explainable bands rather than an opaque score:

1. **Routine** — dashboard shows the next break only.
2. **Drift** — normally the dashboard shows a gentle suggestion only. If the user has opted into both quiet hours and a next-day early start, 45 minutes of sustained local activity may bring forward one black, monitor-covering care surface for that drift episode. It offers only `Take 5` and `Pause until 7 AM`; it has no on-call or Lock Screen controls.
3. **Protect** — after the higher sustained-activity threshold, the same black, monitor-covering intervention also offers `On call for 15 min`. Sustained local activity remains required; quiet hours, repeated snoozes, and an early start make the reason clearer but do not independently cause a lock. A user who has explicitly enabled the optional local Lock Screen rule sees one cancellable 10-second countdown on that surface; the companion may then invoke macOS's own Lock Screen once in that protect episode. The surface is not presented as a system lock, locks by no remote/model command, and never ends a Codex session.

The user must see the contributing categories, change thresholds, pause until tomorrow, turn Offshift off, and mark any nudge as unhelpful. The model does not set thresholds or decide escalation.

## Feature priority and proof of need

| Feature | Priority | Why it earns its place | Proof before expansion |
| --- | --- | --- | --- |
| Explainable work-pattern heuristic | Must | It is the distinguishing value over a generic Pomodoro timer. | At least 3 of 5 pilot users say shown events were timely; fewer than one unhelpful interruption per two hours per user. |
| Prepare / snooze / on-call / resume | Must | Preserves agency and produces feedback for tuning. | Every path is explicit, reversible, retry-safe, and auditable. |
| macOS action-required overlay | Must after shadow pilot | ChatGPT cannot create a monitor-level interruption. | Participants choose a break more often than they immediately disable the feature. |
| Local optional Lock Screen rule | Should after overlay validation | It is the strongest version of the promise, similar to Red Card's deliberate stop ritual. | Every pilot participant understands the exact rule, can cancel it, and reports no surprise locks. |
| ChatGPT planner/dashboard | Must | Lets a developer inspect, explain, and modify the ritual conversationally. | Golden prompts pass in Developer Mode through a public HTTPS MCP endpoint. |
| One Home Assistant scene | Should | Makes the ritual tangible; is useful only if the core nudge already helps. | One participant uses it repeatedly and it remains fully allowlisted. |
| Codex active-state integration | Could | Can improve context, but must remain one boolean and optional. | It improves timeliness without requiring content collection. |
| Local camera-presence experiment | Later / opt-in | May reduce false positives when someone has left the desk. | Frames remain on device and unretained; no face/fatigue/emotion inference; users understand the indicator and turn it off easily. |
| Apple Screen Time | Later | Separate native entitlement/distribution risk and not required for macOS value. | Feasibility and user need are both confirmed. |
| Arbitrary smart-home commands, auto-ending work, surveillance | Never | Violates safety, privacy, and user agency. | Not applicable. |

## Testing ladder

1. **Unit and contract tests** — threshold bounds, allowed scenes, idempotency, action transitions, and no-content telemetry schema.
2. **Worker/API tests** — validation, authorization boundaries, offline/retry behaviour, and persistence migration tests.
3. **MCP integration tests** — tool descriptors, UI resource MIME type/CSP, render data, and repeated tool calls.
4. **ChatGPT Developer Mode tests** — use an HTTPS endpoint, execute direct/indirect/negative golden prompts, record selected tools and arguments, and check small layouts. ChatGPT Apps require an HTTPS MCP endpoint; rebuild, restart, and refresh the app metadata while iterating. [OpenAI Apps SDK deployment guide](https://developers.openai.com/apps-sdk/deploy) and [testing guide](https://developers.openai.com/apps-sdk/deploy/testing).
5. **Companion manual tests** — permission denial, quiet-hours boundary, idle/resume, repeat-snooze and early-start explanations, instant disable, reboot, no network, pre-lock cancel, one-lock-per-night, and restoration after the system Lock Screen. Camera work, if ever piloted, adds a local-only/no-frame-retention audit rather than a fatigue test.
6. **Pilot evidence** — five opt-in developers, short interviews after several sessions, and only aggregate local event logs. Review false positives before enabling overlays.
7. **UX acceptance gate** — capture the macOS tray, Today, Settings, and protective-screen flows plus the Apps SDK widget at their target sizes. Verify a user can identify what Offshift noticed, the one immediate action, the bounded deferral, and where local-only settings live without encountering developer fixtures or technical policy tokens. The Debug-only care preview must never start a Lock Screen countdown. Record keyboard focus, text scaling, and no-surprise Lock Screen boundaries.

## Immediate next work

The immediate implementation checkpoint is **Care-loop UX**: turn the local
companion into a focused Today surface, keep durable controls in the native
Settings scene, enlarge the local black care surface around the sleeping Codex
brand mark, and simplify the Apps SDK widget to one prepared reset plus a
clear local-only handoff. This is an MVP quality gate, not a new product
authority: it must preserve all consent, privacy, local Lock Screen, and
allowlisted-scene boundaries above.

The next external dependency is still **Real App loop**: run the golden-prompt suite in ChatGPT Developer Mode against the public HTTPS Worker. The endpoint, Developer Mode setting, and external MCP contract are verified; the remaining dependency is ChatGPT connector provisioning. Its direct New Plugin form accepts Offshift metadata and `No Auth`, but returns a generic “Error creating connector” toast even after a verified MCP version-negotiation fix. The macOS collector, local lock boundary, and one allowlisted Home Assistant action are now built; they need pilot evidence, not broader authority.

The follow-on work is **shadow mode**, not an aggressive blocker: collect only the approved coarse signals, show the participant what would have been suggested, then decide whether a visible nudge is deserved. The auto-lock option comes only after that evidence, and always remains a local, named, cancellable rule.
