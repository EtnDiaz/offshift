# Offshift MVP pilot readiness

This is a small, opt-in shadow-pilot protocol. It is deliberately a readiness
artifact, not evidence that a pilot has happened.

## Before a session

1. Explain that Offshift is not a medical product and does not diagnose
   fatigue, attention, or sleep.
2. Confirm the participant can leave care off, pause it locally, and close a
   visible care surface. Keep the local Lock Screen rule disabled for the
   shadow-pilot phase.
3. State exactly what is observed: local aggregate active/idle timing and only
   the user-configured schedule/context switches. No code, prompts, filenames,
   screen content, camera frames, or smart-home credentials are collected.
4. Ask separately for permission to retain the session's coarse event counts
   and feedback. A refusal must not affect use of the app.

## Per-session record

Use an anonymous participant label (for example `P-01`), never a name, email,
screen recording, source code, or free-form activity history.

| Field | Record |
| --- | --- |
| Participant label | `P-__` |
| Session date / local timezone | |
| Care mode | shadow only / visible overlay, with Lock Screen disabled |
| Number of shown events | |
| Reasons shown | coarse named factors only (for example `late-session`, `repeated-snooze`) |
| Number deferred or disabled | |
| Was each reason understandable? | yes / no, with optional short non-identifying note |
| Was the timing helpful? | yes / no |
| Any unhelpful interruption? | count only |
| Could the participant find pause/off and explain it? | yes / no |
| Would they keep the overlay enabled? | yes / no / unsure |

## Decision rule

Collect five independent opt-in sessions. Keep the overlay in shadow mode
unless at least three participants judge shown events timely and the combined
rate stays below one unhelpful interruption per two active hours. Do not enable
or recommend the Lock Screen rule unless every participant can state its local
rule and reports no surprise lock. Record the outcome in
`docs/offshift/acceptance.md` and the coordination work item.
