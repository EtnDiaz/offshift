# ADR 0015: Use the Red Card Codex mascot under its upstream provenance

**Status:** Accepted

**Date:** 2026-07-17

**Supersedes:** ADR 0005

**Superseded by:** ADR 0023 for public redistribution conditions

## Context

The product owner clarified that the desired visual identity is the Codex
mascot shipped in the `openai/redcard` repository, rather than a new original
Offshift character. The immediate product need is a detailed, animated figure
on the local black care screen; the Red Card implementation already supplies
frame-based native-overlay art for that purpose.

## Decision

For this private Offshift prototype, the app may use and adapt the bundled
Red Card Codex referee sprite assets from the upstream `openai/redcard`
repository. The imported assets retain their upstream Apache-2.0 provenance:
the repository's license and a source notice must travel with them, and any
modified sprite must state that it was changed for Offshift.

The app must not import Red Card's separately attributed whistle audio. The
private prototype may use the product-owner-supplied six-frame sleeping-Codex
adaptation, after deterministic removal of the chroma background and panel
borders, plus the product-owner-selected front-facing sleeping-Codex mark for
Offshift branding after chroma-background removal. The mascot is decorative;
accessible text and local user controls remain the authoritative explanation
and exit path. It does not observe the user, change behaviour policy, or add
authority over a device, smart-home scene, or Codex session.

## Consequences

- The black care screen can use a detailed, frame-based Codex mascot now,
  instead of waiting for a generated original pet atlas.
- Offshift must name the asset's provenance accurately in source and release
  materials; it must not present the imported mascot as original Nox artwork.
- Any distribution beyond this prototype needs a product/legal review of the
  upstream license, notices, and brand presentation.

This last consequence is superseded by ADR 0023 after verification of the
upstream Apache-2.0 license and `NOTICE`.
