# ADR 0016: Require a visible local protection surface before a Lock Screen countdown

**Status:** Accepted

**Date:** 2026-07-17

## Context

The optional macOS Lock Screen rule is an unusually consequential local action.
The first implementation could begin the ten-second countdown as soon as the
work-pattern reducer entered `Protect`, before the borderless protection window
had confirmed that it was visible and key. That ordering makes the countdown
harder to understand and weakens its cancellable, user-controlled character.

## Decision

An automatic local Lock Screen countdown may begin only after all of the
following are true:

1. the local policy is still in `Protect`;
2. the separately enabled local rule still has fresh consent and Accessibility
   permission; and
3. the dedicated black protection window has configured itself, become key, and
   notified the local store that it is visible.

The visible surface must show the countdown status, `Cancel countdown`, and the
bounded on-call override. Repeated window callbacks are idempotent; they cannot
start more than one countdown in a protect episode. No MCP, Worker, ChatGPT,
Home Assistant, or Codex relay path may call the visibility acknowledgement.

## Consequences

- A local user sees and can cancel the intervention before macOS receives a
  Lock Screen request.
- Enabling the rule while an old protect assessment is present does not start a
  hidden or background countdown.
- The macOS UI owns the acknowledgement; policy code remains testable and
  external integrations retain no new authority.
