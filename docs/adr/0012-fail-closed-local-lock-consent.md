# ADR 0012: Fail closed when local Lock Screen consent is no longer fresh

**Status:** Accepted

**Date:** 2026-07-17

## Context

The optional Lock Screen rule is a high-impact local action. A persisted enable
boolean alone does not prove that the user still has the required macOS
Accessibility permission or intends the rule to survive repeated cancellation
and an operating-system change.

## Decision

The local companion records a consented macOS version only after an explicit
Settings confirmation while Accessibility is currently granted. Before any
countdown it checks both the saved version and the current permission. A
permission loss, operating-system version change, or three cancelled
countdowns disables the local rule immediately and requires a new local
confirmation.

This policy is entirely local. The Worker, MCP, widget, ChatGPT, and Codex do
not receive the state and cannot enable, refresh, or bypass it.

## Consequences

- A previously enabled rule fails closed instead of silently regaining power
  when permission changes.
- A person who repeatedly rejects the countdown gets a direct escape hatch
  rather than an escalating interruption.
- The product may be less convenient after a macOS update, by design, because
  re-consent is the safer default for a system-lock authority.
