# Offshift Agent Guide

## Coordination

- Coordination issue: `tixo-digital/program#150` until this repository has its own remote.
- GitLab milestone: `Offshift MVP — Protective Loop` (`tixo-digital/program#1`). Keep its definition of done and issue evidence current.
- Follow the Tixo claim protocol before changing the project: claim the issue, state branch/worktree/files in scope, retain a recoverable handoff, and update the issue for a material scope or verification change.
- Add or supersede a record in `docs/adr/` before changing an authority, consent, privacy, or external-action boundary.
- Work on `agent/<agent-name>/<issue-iid>-<slug>` branches. Do not reset or overwrite another agent's work.

## Product boundaries

Offshift helps a developer intentionally leave a work loop. It is not a medical product and it must never diagnose fatigue, enforce sleep, read source code, or capture screen content.

- Only aggregate active/idle timing is in scope for the macOS MVP. A future camera experiment may use a separately enabled, local-only presence signal, but must never retain or transmit frames or infer fatigue, emotion, health, age, identity, or attention quality.
- A next-day early-start signal must be explicitly configured or consented to; do not infer it from a calendar by default. Screen Time / Family Controls data, if ever used, stays in its separately entitled native workstream and must remain coarse category aggregates.
- Smart-home actions are allowlisted user-owned scenes. Never let a model provide arbitrary URLs, commands, or device credentials.
- Screen Time / Family Controls is explicitly out of the MVP.
- Mascot provenance: the bundled Red Card character art may be adapted and redistributed, including in public prototype releases, under its upstream Apache-2.0 terms. Preserve the upstream Apache-2.0 license, `NOTICE`, source attribution, and a notice of Offshift modifications with every redistribution; do not use the separately attributed whistle sound. Treat the mascot as a Red Card-derived decorative asset, never as original Offshift artwork, an official OpenAI/Codex product character, an endorsement, or a user-authentication signal. Use `OpenAI` and `Codex` only as customary source attribution, not in Offshift product branding.

## ChatGPT Apps SDK

- Keep the application `interactive-decoupled`: data tools stay separate from the render tool.
- Use the MCP Apps bridge first; use `window.openai` only as a compatibility enhancement.
- Every widget resource must use `text/html;profile=mcp-app`, a versioned `ui://` URI, and deliberate CSP metadata.
- Use `@openai/apps-sdk-ui` for standard controls, icons, transitions, tokens, and host styling. Do not import `@tixo/ui`, `lucide-react`, or create lookalike controls.
- Mutating tools need accurate `readOnlyHint`, `destructiveHint`, `openWorldHint`, and idempotency handling. The server, not annotations, enforces safety.

## Verification

- Run the focused package typecheck/test commands after changes.
- Before claiming runtime success, verify `/health`, `tools/list`, and `resources/read` from a running MCP endpoint.
- ChatGPT UI verification requires a public HTTPS endpoint and a Developer Mode refresh; do not describe a local build as a verified ChatGPT runtime.
- Keep `docs/offshift/acceptance.md` current with golden prompts, assertions, and the latest evidence status.
