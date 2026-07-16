# ADR 0004: Use deterministic, explainable policy before learned inference

- Status: Accepted
- Date: 2026-07-16

## Context

The product must earn trust when it interrupts someone. A learned score would require more data, obscure why it acted, and can imply an unsupported health claim.

## Decision

The first policy uses user-configured thresholds over local active duration, idle gaps, quiet hours, and bounded snooze history. It emits the contributing categories and a routine, drift, or protect state. Shadow-mode evidence and explicit user feedback determine future tuning.

## Consequences

The early system is easy to unit-test, explain, and disable. Any learned or personalized model requires a new ADR, local pilot evidence, a data-minimization review, and a non-medical product claim review.
