# Offshift safety model

## Protected boundaries

- Home automation credentials remain outside ChatGPT, the widget, and model-visible `structuredContent`.
- A scene is selected by one opaque allowlisted id (`wind-down`), not by an arbitrary URL or freeform command.
- Widget state is presentation state, never authorization state.
- The server validates duration limits, scene ids, device identity, and idempotency before changing a schedule.

## Consent model

Scheduling and snoozing require an explicit current-turn action. The companion asks for direct local confirmation before the only external scene is run. It does not currently expose an automatic scene rule.

Behaviour monitoring is opt-in. The user selects quiet hours, a maximum uninterrupted-work window, whether a Codex-session-active signal is allowed, whether an early-start reminder may be used, and an immediate local disable switch. The macOS companion also owns a local pause-until-tomorrow gate that cancels an active countdown and suppresses all local interventions; MCP, the Worker, and ChatGPT cannot change it. Incident/on-call mode must silence all nudges for a bounded duration and leave an audit entry; it must never be a hidden bypass.

## Behaviour-model guardrails

- A `work-pattern risk` is a product heuristic, not a medical, sleep, mental-health, productivity, or performance score.
- Signals are coarse local aggregates only: elapsed active time, idle gaps, local time relative to user-configured quiet hours, accepted/snoozed/dismissed break events, an explicitly configured next-day early-start bit, and optionally a boolean that a Codex session is active. No prompt text, diffs, terminal output, filenames, keystrokes, screenshots, microphone data, or camera frames are collected.
- A future camera-presence experiment needs a separate local consent control and visible indicator. It may retain only a present/absent outcome on-device long enough to prevent a false nudge; raw frames are never persisted, logged, sent to the Worker, sent to ChatGPT, or made model-visible. It must not infer or claim fatigue, emotion, identity, age, gaze, attention, sleep, or health.
- Screen Time / Family Controls remains outside this MVP. If a native workstream is approved, it may use only user-authorized, coarse category aggregates; it may not read browsing content or present a category as proof of "doomscrolling."
- Every nudge exposes the contributing categories (for example, "90 minutes active" and "quiet hours started"), controls to snooze/disable it, and a way to mark it unhelpful.
- Start in shadow mode: record what *would* have been suggested locally, but show nothing until the participant turns on nudges. The model never chooses thresholds or punishment actions.
- Higher-risk states escalate only the clarity of the invitation. They cannot lock the computer, end a Codex session, submit code, message a colleague, or run an external action without an existing explicit local rule.

## Optional Lock Screen rule

The macOS companion may invoke the system Lock Screen only after the user enables one named local rule. The MVP rule is fixed and locally confirmed: while Protect remains active, show a black intervention surface and a 10-second countdown, then make one system Lock Screen attempt. It is disabled by default. The rule is evaluated locally; ChatGPT, the model, and the Worker cannot create, relax, or invoke it.

- Show a visible local countdown with a one-click cancel and a bounded on-call override before every lock.
- Limit automatic locking to one attempt per protect episode unless the user has actively re-enabled it after the policy leaves Protect.
- The adapter may only post macOS's standard Lock Screen shortcut after macOS Accessibility permission is available. Permission denial must fail closed, show an explanation, and never emulate a lock screen.
- Never present the intervention surface as macOS's system lock, conceal its local `Take 5` / pause / cancel exits, prevent the user from unlocking with macOS, or request passwords.
- Stop and require local re-consent after an OS upgrade, permission change, or repeatedly cancelled countdowns.

## Logging

Keep audit records to action type, opaque schedule id, timestamp, result, non-sensitive device alias, and coarse signal categories that caused a shown nudge. Home Assistant's endpoint is local preference data and its token stays in Keychain. Do not log source code, screen content, raw usage history, camera frames, biometric outputs, OAuth tokens, Home Assistant tokens, or smart-home credentials.
