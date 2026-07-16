# ADR 0008: Ship the Lock Screen adapter as a disabled local rule

**Status:** Accepted

**Date:** 2026-07-16

## Context

The MVP needs a real, testable local Lock Screen path rather than a visual imitation or a remote command. It must still be reversible and never surprise a user.

## Decision

The macOS companion ships a system adapter that posts the normal macOS Control-Command-Q Lock Screen shortcut through the public Accessibility event path. It is unavailable until the user grants macOS Accessibility permission and enables the rule in the companion's local Settings confirmation.

The exact rule is fixed for this MVP: while the local policy remains `Protect`, show one visible 30-second countdown. The user may cancel it or take one bounded 15-minute on-call override. At most one lock attempt occurs per protect episode. A missing permission or failed event posts no key event and shows a local explanation.

The Lock Screen adapter, rule state, and timer are local-only. They have no MCP tool, Worker endpoint, Widget state field, or remote configuration path.

## Consequences

- Tests exercise countdown cancellation, disabled-rule suppression, on-call suppression, and the one-attempt limit with a non-locking adapter; automated tests never lock a developer's Mac.
- The first user-facing setup is opt-in and can be disabled immediately in Settings.
- A pilot must still validate whether the rule feels timely before treating it as a recommended default.
