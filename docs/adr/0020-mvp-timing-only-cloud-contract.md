# ADR 0020: Keep the MVP cloud contract timing-only

**Status:** Accepted

**Date:** 2026-07-17

**Supersedes:** the app-category-aggregate allowance in ADR 0006 for the MVP

## Context

A real ChatGPT Apps host check exposed a demo dashboard field,
`activeAppCategory: "coding"`. It did not expose source code or screen
content, but it still exceeded the MVP boundary: the cloud contract may carry
only aggregate active and idle timing plus the user-configured local context.

## Decision

The Worker, MCP tools, Apps SDK widget, and any rendered model explanation
must not receive, store, render, or infer an application, activity, website,
or content category in the MVP. Their allowed activity signal is the total
aggregate active duration (and future aggregate idle gaps) only.

The later Screen Time / approved native-integration option in ADR 0006 remains
a future, separately entitled and consented workstream. It cannot reuse this
MVP cloud contract without a new ADR and privacy review.

## Consequences

- Dashboard schemas reject category fields rather than normalizing them.
- Model-visible explanations may say only how long aggregate activity lasted;
  they cannot claim the user was coding, browsing, scrolling, or using any
  specific application.
- Host golden prompts must assert this absence as well as the absence of code,
  prompt, terminal, and screen-content access.
