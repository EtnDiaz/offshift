# Offshift macOS companion core

This SwiftPM package contains the local decision core and macOS companion host. It deliberately accepts only aggregate active-application intervals with opaque identifiers. It does not inspect source code or screen contents, diagnose a person, or make any remote decision about a lock or device action.

## Behaviour

- `WorkPatternHeuristic` is deterministic: the same intervals, configuration, and `now` produce the same assessment and ordered reasons.
- `WorkPatternRiskPolicy` can add user-configured quiet-hours, repeated-snooze, and next-day-early-start facts to that explanation. Context never creates an intervention without local activity, and an early start cannot independently escalate it.
- `InterventionController` moves between `routine`, `drift`, and `protect`; it exposes a manually driven, cancellable pre-lock countdown.
- An on-call override is capped by duration and grants per protect episode.
- `ProtectionConfiguration` disables `LocalLockScreenRule` by default. A fired countdown is logged as suppressed and cannot contact an adapter until a host explicitly enables a locally configured rule. Enabled rules use a black intervention surface, one visible 10-second countdown, and permit one lock attempt per protect episode.
- `NeverLockingTestAdapter` remains the default core adapter. The macOS host has a separately opt-in system adapter that posts Control-Command-Q only after local Settings confirmation and macOS Accessibility permission; tests never invoke it.
- `InMemoryShadowModeLog` is suitable for tests; `LocalShadowModeLog` appends JSON-lines to a caller-selected local file.

The included macOS host is a menu-bar and window-based companion. It samples aggregate local active/idle time once per minute using only elapsed durations, then feeds opaque `active-session` intervals into the heuristic. It makes routine/drift/protect state, the cancellable intervention window, and bounded on-call behaviour visible. Night care is a local, opt-in 23:00–07:00 schedule by default; it adds context only after sustained activity and brings the protection window forward on a Protect transition. Its Lock Screen control is disabled by default. After explicit local confirmation and macOS Accessibility permission, the separate system adapter can post Control-Command-Q after a visible cancellable countdown; tests never invoke that adapter.

The companion also supports exactly one locally configured Home Assistant scene: `wind-down`, mapped to `scene.offshift_wind_down`. The base URL is stored locally, the long-lived token is stored in the macOS Keychain, and every call requires the local confirmation dialog. A rejected token, missing scene, or unavailable host produces an explanatory local result and is never retried automatically.

Camera, Screen Time, and facial-fatigue detection are not implemented. A future camera experiment could only use a separately enabled local presence signal; it cannot retain/transmit frames or infer fatigue, identity, emotion, health, or attention.

## Development

```sh
cd offshift_companion
swift test
./script/build_and_run.sh --verify
```

Create a local DMG without launching the app:

```sh
./script/package_dmg.sh
```

The runnable development bundle is staged outside the source checkout under
`$TMPDIR/OffshiftDeveloperBuild`, so running from a workspace in `~/Documents`
does not request access to Documents or create Spotlight app entries. The DMG
is written to `release/` and is ad-hoc signed
for development only; a public release needs Developer ID signing and
notarization credentials.

## Coordination handoff

Scope: `offshift_companion/**` only, on branch `agent/codex/150-offshift-mvp`. The required coordination issue is `tixo-digital/program#150`; material scope and verification updates are recorded there. The implementation is self-contained and the test command above is the verification handoff.
