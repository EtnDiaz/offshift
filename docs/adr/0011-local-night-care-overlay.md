# ADR 0011: Trigger the night-care overlay from local, opted-in quiet hours

**Status:** Accepted

**Date:** 2026-07-17

## Context

Offshift previously had a protection window and a Lock Screen safety rule, but
the companion did not connect a user-configured quiet-hours schedule to its
live local samples or bring the protection window forward when a Protect state
was reached. That made the intended care feel invisible at night.

## Decision

The companion offers a local Night care preference, disabled by default, with
default hours of 23:00–07:00 once enabled. The schedule is evaluated only on
the Mac and contributes the existing `insideQuietHours` reason to the
explainable policy. Local sustained activity remains required for Drift or
Protect; clock time alone cannot trigger an overlay or Lock Screen action.

On a transition into Protect, the companion brings forward a local
action-required protection window. It says why now, makes clear that code and
sessions are not closed, and offers Take 5, bounded on-call, Pause until
tomorrow, and countdown cancellation. The optional Lock Screen countdown still
requires its separate local setting and Accessibility permission.

## Consequences

- A user who opts in to night care can see a respectful local intervention
  after sustained late work without relying on ChatGPT being open.
- The overlay is not an implicit remote lock and does not inspect content or
  infer fatigue.
- The local pause/off gate from ADR 0010 remains a stronger, immediate escape
  hatch.
