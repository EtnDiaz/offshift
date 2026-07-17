# ADR 0023: Redistribute Red Card-derived mascot art under Apache-2.0 terms

**Status:** Accepted

**Date:** 2026-07-17

**Supersedes:** the public-distribution restriction in ADR 0015

## Context

Offshift's care surface and macOS application icon use a sleeping companion
adapted from character artwork in `openai/redcard`. ADR 0015 correctly retained
the upstream license and notice but treated public release as blocked pending a
separate authorization.

The bundled upstream Apache License 2.0 grants a copyright license to prepare
derivative works and distribute them. The upstream `NOTICE` says the character
artwork is first-party project art under Apache-2.0 unless otherwise noted. It
also identifies `OpenAI` and `Codex` as trademarks and says the license does
not grant trademark permission other than customary source description. The
separately attributed referee whistle is not Apache-2.0.

## Decision

Offshift may publicly distribute its Red Card-derived sleeping frames, brand
mark, and generated application icon under the upstream Apache-2.0 terms. Every
source and packaged distribution must retain the upstream Apache-2.0 license
and `NOTICE`, identify the upstream source and Offshift's modifications, and
exclude the whistle audio.

The mascot remains decorative. Offshift must not call it original Offshift art,
an official OpenAI/Codex character, an OpenAI/Codex-authentication signal, or
evidence of OpenAI endorsement. `OpenAI` and `Codex` are used only in
reasonable, customary source attribution and notices, not as Offshift branding.

## Consequences

- A public GitHub repository, release DMG, Devpost page, and demo video may
  show the sleeping companion after the packaged-notice check passes.
- `docs/third-party/redcard-codex-mascot.md` is the human-readable provenance
  record; the app bundle carries the upstream license and notice beside the
  assets.
- The public release checklist must validate attribution, notice inclusion, and
  absence of the whistle before publishing.
- This decision does not grant trademark rights or replace legal review for a
  future commercial launch.
