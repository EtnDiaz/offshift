# Offshift safety model

## Protected boundaries

- Home automation credentials remain outside ChatGPT, the widget, and model-visible `structuredContent`.
- A scene is selected by opaque allowlisted id, not by an arbitrary URL or freeform command.
- Widget state is presentation state, never authorization state.
- The server validates duration limits, scene ids, device identity, and idempotency before changing a schedule.

## Consent model

Scheduling and snoozing require an explicit current-turn action. The future companion asks for direct local confirmation before an external scene is run unless the user enabled a specific automation rule locally.

Behaviour monitoring is opt-in. The user selects quiet hours, a maximum uninterrupted-work window, whether a Codex-session-active signal is allowed, and an immediate disable switch. Incident/on-call mode must silence all nudges for a bounded duration and leave an audit entry; it must never be a hidden bypass.

## Behaviour-model guardrails

- A `work-pattern risk` is a product heuristic, not a medical, sleep, mental-health, productivity, or performance score.
- Signals are coarse local aggregates only: elapsed active time, idle gaps, local time relative to user-configured quiet hours, accepted/snoozed/dismissed break events, and optionally a boolean that a Codex session is active. No prompt text, diffs, terminal output, filenames, keystrokes, screenshots, camera, or microphone data is collected.
- Every nudge exposes the contributing categories (for example, "90 minutes active" and "quiet hours started"), controls to snooze/disable it, and a way to mark it unhelpful.
- Start in shadow mode: record what *would* have been suggested locally, but show nothing until the participant turns on nudges. The model never chooses thresholds or punishment actions.
- Higher-risk states escalate only the clarity of the invitation. They cannot lock the computer, end a Codex session, submit code, message a colleague, or run an external action without an existing explicit local rule.

## Optional Lock Screen rule

The macOS companion may invoke the system Lock Screen only after the user enables one named local rule, for example: "during quiet hours, lock after 120 active minutes and two snoozes." It must be disabled by default and require a local confirmation with the exact thresholds before activation. The rule is evaluated locally; ChatGPT, the model, and the Worker cannot create, relax, or invoke it.

- Show a visible local countdown with a one-click cancel and a bounded on-call override before every lock.
- Limit automatic locking to one event per configured quiet-hours window unless the user has actively re-enabled it.
- Never implement a fake full-screen lock, conceal an exit route, prevent the user from unlocking with macOS, or request passwords.
- Stop and require local re-consent after an OS upgrade, permission change, or repeatedly cancelled countdowns.

## Logging

Keep audit records to action type, opaque schedule id, timestamp, result, non-sensitive device alias, and coarse signal categories that caused a shown nudge. Do not log source code, screen content, raw usage history, OAuth tokens, or smart-home credentials.
