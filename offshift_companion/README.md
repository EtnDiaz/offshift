# Offshift macOS companion core

This SwiftPM package contains the local decision core for the future macOS companion. It deliberately accepts only aggregate active-application intervals with opaque identifiers. It does not inspect source code or screen contents, request permissions, make network calls, diagnose a person, or contain a real screen-lock implementation.

## Behaviour

- `WorkPatternHeuristic` is deterministic: the same intervals, configuration, and `now` produce the same assessment and ordered reasons.
- `WorkPatternRiskPolicy` can add user-configured quiet-hours, repeated-snooze, and next-day-early-start facts to that explanation. Context never creates an intervention without local activity, and an early start cannot independently escalate it.
- `InterventionController` moves between `routine`, `drift`, and `protect`; it exposes a manually driven, cancellable pre-lock countdown.
- An on-call override is capped by duration and grants per protect episode.
- `ProtectionConfiguration` disables `LocalLockScreenRule` by default. A fired countdown is logged as suppressed and cannot contact an adapter until a host explicitly enables a locally configured rule.
- `NeverLockingTestAdapter` is the only default `LocalLockAdapter`. It records requests and **never locks the screen**.
- `InMemoryShadowModeLog` is suitable for tests; `LocalShadowModeLog` appends JSON-lines to a caller-selected local file.

The included macOS host is a menu-bar and window-based fixture over the core. It samples aggregate local active/idle time once per minute using only elapsed durations, then feeds opaque `active-session` intervals into the heuristic. It makes routine/drift/protect state, the cancellable intervention window, and bounded on-call behaviour visible. Its Lock Screen control is deliberately disabled and no real adapter ships in this build.

The companion also supports exactly one locally configured Home Assistant scene: `wind-down`, mapped to `scene.offshift_wind_down`. The base URL is stored locally, the long-lived token is stored in the macOS Keychain, and every call requires the local confirmation dialog. A rejected token, missing scene, or unavailable host produces an explanatory local result and is never retried automatically.

Camera, Screen Time, and facial-fatigue detection are not implemented. A future camera experiment could only use a separately enabled local presence signal; it cannot retain/transmit frames or infer fatigue, identity, emotion, health, or attention.

## Development

```sh
cd offshift_companion
swift test
./script/build_and_run.sh --verify
```

## Coordination handoff

Scope: `offshift_companion/**` only, on branch `agent/codex/150-offshift-mvp`. The required coordination issue is `tixo-digital/program#150`; this checkout cannot resolve that repository through GitHub CLI, so a remote claim/update could not be recorded from this environment. The implementation is self-contained and the test command above is the verification handoff.
