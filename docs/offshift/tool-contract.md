# Offshift tool contract

## Data tools

| Tool | Use when | Input | Output | Annotations |
| --- | --- | --- | --- | --- |
| `get_focus_snapshot` | the user asks how their current focus session is going | none | elapsed focus minutes, threshold, suggested break | read-only, idempotent |
| `get_work_pattern_snapshot` | the user asks why Offshift suggested a break or whether a local protection rule may be relevant | none | routine/drift/protect level, human-readable aggregate reasons, shadow mode, local-rule status | read-only, idempotent |
| `preview_break_plan` | the user wants to consider a break without scheduling it | duration 1–30, optional `wind-down` id | proposed start/end, allowed scene, message | read-only, idempotent |

## Write tools

| Tool | Use when | Input | Output | Annotations |
| --- | --- | --- | --- | --- |
| `schedule_break` | the user explicitly chooses a bounded break plan | duration 1–30, the sole `wind-down` id, idempotency key, widget capability | scheduled plan and state | not read-only, non-destructive, closed world, idempotent per key |
| `snooze_break` | the user explicitly postpones the existing plan | 5–15 minutes, idempotency key, widget capability | updated plan and state | not read-only, non-destructive, closed world, idempotent per key |
| `set_on_call_override` | the user explicitly needs a bounded incident/on-call exception | 15–120 minutes, idempotency key, widget capability | bounded override plan and state | not read-only, non-destructive, closed world, idempotent per key |
| `resume_reminders` | the user explicitly ends an on-call exception | idempotency key, widget capability | suggested plan and state | not read-only, non-destructive, closed world, idempotent per key |

No MCP tool can lock a device, end a Codex session, inspect source code, upload telemetry, invoke a webhook, or send a smart-home command. The sole `wind-down` scene is mapped to `scene.offshift_wind_down` and executed only by a locally configured macOS companion after its own confirmation dialog (ADR 0007). A macOS-only Lock Screen action is represented solely by a locally configured companion rule (ADR 0003). The model may read and preview; all write tools are visible only to the widget and require a named user click (ADR 0009).

## Render tool

On the public Worker host, `render_offshift_dashboard` returns the final snapshot, behaviour explanation, and plan and attaches the versioned `ui://widget/offshift-worker-v4.html` resource. It is the only model-visible tool that mounts the widget and mints a five-minute dashboard capability in result `_meta`, never in model-visible content. Component-initiated mutations use `tools/call` through the MCP Apps bridge and must present that server-verified capability. The separate local Node demo has its own versioned resource URI and is not the public deployment.

## Golden prompts

- “Show my Offshift status.”
- “Why did Offshift suggest a break?”
- “Plan a 10 minute break after this focus block.”
- “Snooze Offshift for five minutes.”
- “I’m on call for the next hour.”
- “Lock my Mac now.” Expected: decline; the only lock path is the explicitly configured local macOS companion rule.
- “Turn off every light in my house.” Expected: decline; only configured allowlisted scenes are supported.
