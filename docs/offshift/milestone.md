# Milestone: Offshift MVP — Protective Loop

- GitLab milestone: [Offshift MVP — Protective Loop](https://gitlab.com/tixo-digital/program/-/milestones/1)
- Coordination issue: [program#150](https://gitlab.com/tixo-digital/program/-/work_items/150)
- Status: active — the safe local-first MVP remains open for a final human care-surface pass and opt-in pilot evidence. A public multi-user release is a separate authenticated-service milestone under ADR 0021.

## Definition of done

1. An HTTPS `/mcp` endpoint exposes the Apps SDK widget and follows the decoupled data/render contract.
2. The widget shows an explainable routine/drift/protect snapshot and supports bounded start, snooze, and on-call actions.
3. A local macOS companion has a consent-first onboarding flow, tested shadow-mode policy, and a disabled-by-default, cancellable, local-only Lock Screen adapter with a one-attempt-per-protect-episode limit.
4. Smart-home capability is exactly one locally mapped, direct-confirmation `wind-down` scene; it has no arbitrary URL, entity, service, token, or model-controlled command path.
5. Unit, API, MCP contract, and companion state-machine tests pass; ChatGPT Developer Mode golden prompts have recorded evidence once an HTTPS endpoint is available.
6. Five opt-in pilot sessions produce enough feedback to decide whether overlay and auto-lock remain enabled features.
7. The local companion and Apps SDK widget pass the UX acceptance gate: each care state presents one named primary action, one reversible deferral, a concise explanation, and an unobtrusive route to local settings; no optional permission is requested before its local explanation; the black care surface remains readable at wide-desktop scale, animates the sleeping mascot, supports the documented four-Escape emergency exit, and does not make a local Lock Screen action appear remote or automatic.

## Explicitly not required to close this milestone

- Apple Screen Time / Family Controls entitlement.
- Automatic reading of Codex prompts, repositories, code, or terminal data.
- Public directory submission or production smart-home credentials.
- OAuth, durable tenant isolation, or a public multi-user cloud service. Those
  are prerequisites for a later public release, not a property of the current
  demo endpoint.
