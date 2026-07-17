# OpenAI Build Week submission brief

This is the internal, evidence-first checklist for the Offshift submission.
It is deliberately not a marketing claim and must be updated before the
Devpost form is submitted.

## Recommended track

**Apps for Your Life** — Offshift is a local-first consumer ritual for a
person who wants to leave a late-night AI building loop intentionally. Its
initial audience is developers using Codex, but the product outcome is personal
productivity and agency rather than a team, DevOps, testing, or security tool.

Proposed one-line pitch: **“A local-first off-ramp for developers caught in a
late-night AI building loop.”**

## What judges can test

1. The public, deterministic MCP demo is at
   `https://offshift-demo-api.tixo-digital.workers.dev/mcp`. It contains
   fixture data only and no personal activity or device state.
2. A macOS companion DMG must be attached to a GitHub Release before
   submission. Record the release URL, SHA-256, supported macOS version, and a
   Gatekeeper/install note here.
3. A private Secure MCP Tunnel is for the submitter's ChatGPT Developer Mode
   demonstration only. It is not a judge credential or a public deployment.
4. The public demo and the video must not show a real Home Assistant token,
   control-plane key, terminal prompt, private desktop, source code, or a
   system-lock claim.

## Required evidence before submission

- [ ] Apps for Your Life selected in Devpost.
- [ ] Public English README contains setup, sample-data/fixture explanation,
  supported platform, test commands, and judge path.
- [ ] `/feedback` Codex Session ID for the primary build session is added to
  the Devpost form. Do not put a private session transcript or credential in
  this repository.
- [ ] The owner verifies in the Codex product that the core build session used
  GPT-5.6 before claiming that version in the submission or video.
- [ ] A public YouTube video under three minutes, in English, demonstrates the
  app and narrates how Codex and GPT-5.6 accelerated the work.
- [ ] A tested DMG/release or equally frictionless test build is available free
  through the end of judging.
- [ ] One clean macOS demo pass succeeds: launch, tray presence, onboarding,
  Focus-permission denial path, care preview, reset, on-call, disable, and
  four-Escape exit.
- [ ] The Red Card-derived asset is packaged with its Apache-2.0 license,
  upstream `NOTICE`, attribution, and no whistle audio.

## Codex contribution record

The dated Git history shows the project was materially developed after the
submission period began. Before final submission, link the primary `/feedback`
session ID in the Devpost form and describe only verified contribution areas:

- Apps SDK tool/resource contract and timing-only privacy guard;
- local macOS companion, consent-first onboarding, care-state tests, and DMG
  packaging;
- UX critique/revision of the care screen and its local-only authority;
- private Secure MCP Tunnel fixture-pilot runbook and reproducible checks.

Human product decisions retained deliberately: the safety boundary, local-only
Lock Screen consent, Screen Time exclusion, the chosen track, and what is safe
to claim in the demo.

## P0: mascot packaging and presentation

The sleeping companion is Red Card-derived art distributed under the upstream
Apache-2.0 license. It may appear in the public repository, release, video, and
Devpost images only with the bundled license, `NOTICE`, source attribution, and
Offshift modification notice intact. Never include the separately licensed
whistle sound or present Offshift as an official OpenAI/Codex product or as
endorsed by OpenAI. See [ADR 0023](../adr/0023-public-redcard-mascot-redistribution.md)
and [the third-party notice](../third-party/redcard-codex-mascot.md).

## Three-minute video structure

1. **0:00–0:20 — Problem:** a developer stays in a late-night build loop;
   Offshift uses only local aggregate timing and configured quiet hours.
2. **0:20–1:10 — ChatGPT app:** show the deterministic fixture dashboard over
   the public demo endpoint or the private tunnel; explain that it cannot lock
   a Mac or control a home.
3. **1:10–2:10 — macOS flow:** onboarding, a clean care preview, reset/on-call
   choice, and disable/escape route. Never show a real system Lock Screen.
4. **2:10–2:40 — Trust:** local-first data boundary, no code/screen/camera
   access, and the difference between fixture demo and future multi-user OAuth.
5. **2:40–3:00 — Build story:** the verified Codex/GPT-5.6 session contribution
   and what remains after the hackathon.

## Source rules

This checklist mirrors the official Build Week rules and must be rechecked
against them immediately before submission:

- https://openai.devpost.com/rules
- https://openai.devpost.com/
