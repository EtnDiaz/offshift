# ADR 0006: Combine opt-in risk factors without biometric inference

**Status:** Accepted

**Date:** 2026-07-16

## Context

Late work is rarely a single-timer problem. A developer may have been active for a long time, be inside their chosen quiet hours, have repeatedly snoozed a break, and have an early start configured for the next day. The product should be able to explain that combination without claiming to know whether the person is tired, healthy, stressed, or doomscrolling.

The proposed camera and Screen Time ideas create especially sensitive data boundaries. A face image cannot reliably establish fatigue, and Screen Time / Family Controls requires a separate native entitlement and consent path.

## Decision

Offshift uses a deterministic, local, opt-in work-pattern policy. Its allowed inputs are:

- aggregate active and idle duration;
- user-configured quiet hours;
- bounded break snooze/dismissal history;
- an explicitly configured or consented boolean that an early start is planned for the next day; and
- later, only coarse Screen Time or user-selected app-category aggregates through an approved native integration.

An optional future camera feature may provide only a local presence-at-device signal to reduce false positives. It is disabled by default, cannot persist or transmit frames, and may not perform face, emotion, fatigue, age, identity, gaze, or health classification. It cannot independently escalate an intervention.

The policy exposes contributing categories and deterministic thresholds. Time or calendar context can add explanation; it cannot cause a lock on its own. A high-protection state still requires sustained local activity plus the explicitly configured rule.

## Consequences

- “You look tired” and “you are doomscrolling” are prohibited product claims.
- The product may say: “It is inside your quiet hours, you have been active for 90 minutes, you snoozed twice, and you enabled an early-start reminder.”
- Screen Time remains out of the macOS MVP and gets its own iOS/native feasibility decision before implementation.
- Camera work is a future privacy review and pilot, not a dependency of the MVP.
