# ADR 0019: Keep the developer care preview locally testable

**Status:** Accepted

**Date:** 2026-07-17

## Context

The real Offshift protection surface is deliberately an accessory-process,
screen-saver-level, monitor-covering window. That is appropriate only after
local policy presents a real care episode: it must remain above ordinary work
windows, while its optional Lock Screen countdown stays local and cancellable.

The same window level prevents the local Computer Use accessibility backend
from discovering or targeting the Debug `--care-preview` route. This made it
impossible to run an automated visual/four-Escape QA pass even though the
preview could not lock the Mac.

## Decision

Keep the real local-behaviour route unchanged: it uses the screen-saver window
level, accessory activation policy, and all existing visibility/countdown
gates.

Only a Debug `developerPreview` source uses a developer-QA presentation:

- the process temporarily uses normal macOS activation so local QA tooling can
  address it;
- the otherwise identical black, main-display care composition uses a floating
  window level rather than screen-saver level;
- the process returns to accessory activation when that preview closes or
  terminates.

This presentation distinction is derived only from the local trigger source.
It is not an MCP tool, URL, IPC command, setting, or model-controlled option.
The preview remains non-persistent and must continue to suppress both the
optional Lock Screen countdown and smart-home actions.

## Consequences

- A human or a compatible local QA tool can inspect the actual care content
  and deliver the four local Escape presses through a repeatable debug route.
  A particular accessibility backend may still be unable to snapshot a local
  window; that backend limitation is evidence about the harness, not a reason
  to alter production care authority.
- The preview does not prove system-wide screen-saver compositing; production
  monitor coverage remains a narrow AppKit behaviour covered by code review
  and a human desktop check when display topology changes.
- No remote or new user authority is introduced.
