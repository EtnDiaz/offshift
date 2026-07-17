# ADR 0018: Require first-run consent and request permissions just in time

**Status:** Accepted

**Date:** 2026-07-17

## Context

Offshift handles personal local context and has optional system-facing
capabilities. A tray utility must not silently begin sampling, request a
permission, or make the user discover those choices after the fact.

macOS exposes `INFocusStatusCenter` on macOS 12 and later. It requires a
system authorization request and exposes only whether the user has Focus
enabled; it does not provide the Focus name, calendar, notification contents,
or Screen Time data. Accessibility is separately required only for the
optional local Lock Screen rule. Screen Time and Family Controls remain out of
scope for this MVP.

## Decision

On the first launch, Offshift opens one small local onboarding window before
settling into its tray-only behaviour. The user must explicitly choose whether
to turn on local aggregate timing. Choosing “not now” completes onboarding
with Offshift disabled; it does not sample in the background.

Every optional OS permission is requested only next to the feature that needs
it and only after an explicit local action:

1. Focus Status is an optional, local-only signal. Offshift calls the Apple
   authorization request only when the user presses **Allow Focus status**.
   The result is displayed locally and is explanation-only: it cannot trigger
   a care screen or Lock Screen action by itself.
2. Accessibility is requested only while the user enables the optional local
   Lock Screen rule. macOS may direct the user to Privacy & Security; Offshift
   must explain that step and retain the rule as disabled until the user
   returns and gives fresh local confirmation.
3. Home Assistant credentials remain an explicit local form entry, stored in
   Keychain. No other permission, including Screen Time, camera, calendar, or
   screen recording, is requested by this MVP.

Focus status, permission results, and onboarding state never enter MCP,
ChatGPT, Worker, Home Assistant, shadow logs, or Codex relay payloads.

## Consequences

- A first-run window is intentional; after completion Offshift returns to its
  no-Dock tray-only behaviour.
- New installs are off by default until the user enables local care.
- The product gains a narrow, consented Focus signal without turning it into a
  behavioural or health inference.
