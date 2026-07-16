# ADR 0003: Make Lock Screen a local, named, cancellable rule

- Status: Accepted
- Date: 2026-07-16

## Context

A deliberate stop ritual is central to the product idea, yet a surprise lock or a remotely-triggered lock would be coercive and unsafe.

## Decision

The optional rule is configured and evaluated only by the macOS companion. It is off by default and has exact local thresholds, a visible countdown, cancel action, bounded on-call override, and a one-lock-per-quiet-hours limit. The production adapter may call only the operating system's own Lock Screen API/command; the default and test adapters never lock a screen. The model, widget, and Worker have no lock tool or protocol field.

## Consequences

The lock cannot be demonstrated remotely without the user locally enabling it. A full-screen imitation, password collection, remote trigger, or automatic work termination is forbidden.
