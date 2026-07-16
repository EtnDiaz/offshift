# Offshift product charter

## Problem

Developers can stay in an active monitoring loop long after the work needs their full attention. In particular, a builder can keep iterating with Codex late at night in pursuit of a marginally better result, then dismiss ordinary timers without changing course. Existing timers are easy to dismiss because they do not preserve context or make a chosen break feel actionable.

## Promise

Offshift notices an opt-in *work-pattern risk* and gives a developer a clear next action: take a short break, postpone it deliberately, or plan an end-of-day wind-down. It preserves agency: it does not diagnose a health condition or claim to detect sleep deprivation. A user may separately enable a local macOS Lock Screen action for the highest protection mode; it is never available to the model, widget, or server as an arbitrary command.

## MVP user journey

1. A local companion aggregates only opted-in, non-content signals such as active duration, idle gaps, configured quiet hours, prior snoozes, and an explicitly configured early-start reminder. It explains factors instead of judging fatigue or doomscrolling.
2. A developer opens Offshift in ChatGPT and asks for their status, or the local companion raises a bounded nudge at an agreed threshold.
3. The app presents the observed pattern and an explicit break plan.
4. The developer starts the break, snoozes it by five minutes, or selects an on-call override with a reason and a return time. In a separately enabled Protect mode, they see a local pre-lock countdown and can cancel it before the macOS Lock Screen is invoked.
5. The local companion, introduced after this MVP, receives only the approved schedule and shows a local action-required overlay.
6. One preconfigured Home Assistant scene (`wind-down`) may run only after the user confirms it locally in the companion. Its endpoint and token never leave the Mac.

## Non-goals

- Surveillance of editor contents, screenshots, keystrokes, or conversations.
- Medical, sleep, or burnout advice.
- Inferring a mental-health condition or presenting a score as a diagnosis.
- Arbitrary remote device controls triggered by model text; only the locally mapped `wind-down` scene exists in this MVP.
- A custom or deceptive lock screen; only the operating system's own Lock Screen may be invoked by the local companion.
- Screen Time API integration; it requires a separate native iOS workstream and Apple entitlements.
- Facial fatigue, emotion, identity, gaze, or health inference. A future camera-presence experiment cannot retain or transmit frames.

## Success criteria

- A user can understand the next planned break in one screen.
- In a shadow pilot, a developer can recognize why a nudge appeared and can disable it instantly.
- Every state-changing action is explicit, bounded, retry-safe, and audit-ready.
- A judge can run the app locally and see a working ChatGPT App widget without real smart-home hardware.
