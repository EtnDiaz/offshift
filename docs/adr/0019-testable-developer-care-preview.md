# ADR 0019: Keep the developer care preview locally testable

**Status:** Accepted

**Date:** 2026-07-17

## Context

The real Offshift protection surface is deliberately an accessory-process,
screen-saver-level, monitor-covering window. That is appropriate only after
local policy presents a real care episode: it must remain above ordinary work
windows, while its optional Lock Screen countdown stays local and cancellable.

The former floating preview left the Dock and menu bar visible. It was easier
for one accessibility backend to inspect, but looked like a broken care screen
and produced the wrong visual result for the primary product interaction.

## Decision

Keep the real local-behaviour route unchanged: it uses the screen-saver window
level, accessory activation policy, and all existing visibility/countdown
gates. The Debug `developerPreview` uses the **same monitor-covering
presentation** and accessory policy so `--care-preview` is visually useful:

- the process retains its normal accessory activation, so it remains a
  tray-first companion without a Dock icon;
- the otherwise identical black, main-display care composition covers the
  monitor above ordinary work windows;
- a visible Preview label states that Lock Screen and smart-home actions are
  disabled;
- closing or terminating the preview leaves that tray-first policy unchanged.

This authority distinction is derived only from the local trigger source.
It is not an MCP tool, URL, IPC command, setting, or model-controlled option.
The preview remains non-persistent and must continue to suppress both the
optional Lock Screen countdown and smart-home actions.

## Consequences

- The preview does not prove system-wide screen-saver compositing. Both preview
  and production monitor coverage still require a human desktop check on one
  and two displays; an accessibility backend that cannot inspect this window is
  a harness limitation, not a reason to weaken the product surface.
- No remote or new user authority is introduced.
