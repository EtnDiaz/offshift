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
