# Architecture decision records

These ADRs record decisions that affect user agency, privacy, or cross-process boundaries in Offshift. They use a lightweight format: context, decision, consequences, and status. A new ADR supersedes an earlier one rather than silently changing it.

| ADR | Decision | Status |
| --- | --- | --- |
| [0001](0001-local-behaviour-signals.md) | Behaviour signals remain local, coarse, and opt-in. | Accepted |
| [0002](0002-three-process-boundary.md) | ChatGPT App, cloud control plane, and macOS companion have separate authority. | Accepted |
| [0003](0003-optional-local-lock-screen.md) | Lock Screen is a local, named, cancellable rule. | Accepted |
| [0004](0004-explainable-policy-before-ml.md) | Use deterministic explainable policy before any learned model. | Accepted |
| [0005](0005-offshift-companion-mascot.md) | Use an original Offshift companion mascot, not an official Codex character. | Accepted |
| [0006](0006-risk-factors-without-biometric-inference.md) | Combine opt-in risk factors without biometric fatigue inference. | Accepted |
| [0007](0007-local-home-assistant-wind-down.md) | Execute exactly one Home Assistant scene only after local confirmation. | Accepted |
| [0008](0008-local-lock-screen-execution.md) | Ship the Lock Screen adapter as a disabled local rule. | Accepted |
| [0009](0009-widget-is-the-mutation-consent-surface.md) | Keep ChatGPT mutations behind an explicit widget action and make overrides reversible. | Accepted |
| [0010](0010-local-pause-and-disable-gate.md) | Keep pause/off authority inside the local companion. | Accepted |
| [0011](0011-local-night-care-overlay.md) | Bring a local protection window forward after opted-in quiet-hours Protect. | Accepted |
| [0012](0012-fail-closed-local-lock-consent.md) | Require fresh local consent for the optional Lock Screen rule. | Accepted |
| [0013](0013-worker-dashboard-capability.md) | Server-verify a short-lived capability before Worker plan mutations. | Accepted |
| [0014](0014-codex-event-relay-and-local-consent.md) | Treat Codex sync as a consented, coarse outbound event relay. | Accepted |
| [0015](0015-redcard-codex-mascot-provenance.md) | Use the Red Card Codex mascot with upstream provenance. | Accepted |
