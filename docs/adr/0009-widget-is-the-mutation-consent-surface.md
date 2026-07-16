# ADR 0009: Make the widget the explicit consent surface for Offshift mutations

**Status:** Accepted

**Date:** 2026-07-16

## Context

The first UX and accessibility audit found that a protective app cannot use ambiguous mutation labels or leave a bounded override without a way back. A model-initiated mutation and a widget-initiated mutation also create two different consent experiences for the same action.

## Decision

The ChatGPT widget is the sole MCP consent surface for `schedule_break`, `snooze_break`, `set_on_call_override`, and `resume_reminders`. These tools have UI visibility `["app"]`; the model may use read-only snapshot, preview, and render tools to explain a proposed action, but it cannot apply an override itself.

The widget must name the real effect, display the local start/end time, explain that no scene or lock is executed by ChatGPT, and provide `Resume reminders` whenever an on-call override is active. The new resume action clears only the demo scheduling override; it cannot trigger a device, scene, or Lock Screen action.

## Consequences

- The model remains useful for explaining a plan while the user retains the final action click.
- Every local schedule/override has an explicit, visible way to return to the normal reminder state.
- The Worker and Node MCP surfaces keep matching tool names and visibility rules; a widget resource URI is bumped on this metadata/interaction change.
- This does not change the separate macOS local consent gates for a Home Assistant scene or Lock Screen rule.
