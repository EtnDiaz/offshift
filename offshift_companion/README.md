# Offshift macOS companion core

This SwiftPM package contains the local decision core for the future macOS companion. It deliberately accepts only aggregate active-application intervals with opaque identifiers. It does not inspect source code or screen contents, request permissions, make network calls, diagnose a person, or contain a real screen-lock implementation.

## Behaviour

- `WorkPatternHeuristic` is deterministic: the same intervals, configuration, and `now` produce the same assessment and ordered reasons.
- `InterventionController` moves between `routine`, `drift`, and `protect`; it exposes a manually driven, cancellable pre-lock countdown.
- An on-call override is capped by duration and grants per protect episode.
- `ProtectionConfiguration` disables `LocalLockScreenRule` by default. A fired countdown is logged as suppressed and cannot contact an adapter until a host explicitly enables a locally configured rule.
- `NeverLockingTestAdapter` is the only default `LocalLockAdapter`. It records requests and **never locks the screen**.
- `InMemoryShadowModeLog` is suitable for tests; `LocalShadowModeLog` appends JSON-lines to a caller-selected local file.

The host app is responsible for sampling active-app timing, presenting any prompt, ticking the countdown, choosing a local log location, and—only after a separate user-approved integration—providing a real local lock adapter.

## Development

```sh
cd offshift_companion
swift test
```

## Coordination handoff

Scope: `offshift_companion/**` only, on branch `agent/codex/150-offshift-mvp`. The required coordination issue is `tixo-digital/program#150`; this checkout cannot resolve that repository through GitHub CLI, so a remote claim/update could not be recorded from this environment. The implementation is self-contained and the test command above is the verification handoff.
