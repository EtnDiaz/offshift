# ADR 0002: Split authority across ChatGPT App, Worker, and macOS companion

- Status: Accepted
- Date: 2026-07-16

## Context

ChatGPT widgets cannot show an operating-system-level interruption, while a local desktop process should not be given broad cloud or smart-home authority.

## Decision

The ChatGPT App is the planner and explainer. The Cloudflare Worker is the constrained schedule/control-plane API. The macOS companion owns local sensing, intervention UI, and any operating-system action. Cross-process messages are narrow, typed, and short-lived.

## Consequences

The system has more integration work than a single process, but each authority is auditable. The Worker cannot lock a Mac and the widget cannot access local activity data directly.
