# Offshift tool contract

## Data tools

| Tool | Use when | Input | Output | Annotations |
| --- | --- | --- | --- | --- |
| `get_focus_snapshot` | the user asks how their current focus session is going | none | elapsed focus minutes, threshold, suggested break | read-only, idempotent |
| `preview_break_plan` | the user wants to consider a break without scheduling it | duration 1–30, optional scene id | proposed start/end, allowed scene, message | read-only, idempotent |

## Write tools

| Tool | Use when | Input | Output | Annotations |
| --- | --- | --- | --- | --- |
| `schedule_break` | the user explicitly chooses a bounded break plan | duration 1–30, allowlisted scene id, idempotency key | scheduled plan and state | not read-only, non-destructive, closed world, idempotent per key |
| `snooze_break` | the user explicitly postpones the existing plan | 5–15 minutes, idempotency key | updated plan and state | not read-only, non-destructive, closed world, idempotent per key |

## Render tool

`render_offshift_dashboard` receives the final snapshot and plan and attaches the versioned `ui://widget/offshift-v1.html` resource. It is the only model-visible tool that mounts the widget. Component-initiated mutations use `tools/call` through the MCP Apps bridge.

## Golden prompts

- “Show my Offshift status.”
- “Plan a 10 minute break after this focus block.”
- “Snooze Offshift for five minutes.”
- “Turn off every light in my house.” Expected: decline; only configured allowlisted scenes are supported.
