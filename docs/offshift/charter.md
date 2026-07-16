# Offshift product charter

## Problem

Developers can stay in an active monitoring loop long after the work needs their full attention. Existing timers are easy to dismiss because they do not preserve context or make a chosen break feel actionable.

## Promise

Offshift gives a developer a clear next action: take a short break, postpone it deliberately, or plan an end-of-day wind-down. It preserves agency; it does not lock a device or infer a health condition.

## MVP user journey

1. A developer opens Offshift in ChatGPT and asks for their status.
2. The app presents a focus snapshot and an explicit break plan.
3. The developer starts the break or snoozes it by five minutes.
4. The local companion, introduced after this MVP, receives only the approved schedule and shows a local action-required overlay.
5. A preconfigured Home Assistant scene may run after the user confirms the action.

## Non-goals

- Surveillance of editor contents, screenshots, keystrokes, or conversations.
- Medical, sleep, or burnout advice.
- Arbitrary remote device controls triggered by model text.
- Screen Time API integration; it requires a separate native iOS workstream and Apple entitlements.

## Success criteria

- A user can understand the next planned break in one screen.
- Every state-changing action is explicit, bounded, retry-safe, and audit-ready.
- A judge can run the app locally and see a working ChatGPT App widget without real smart-home hardware.
