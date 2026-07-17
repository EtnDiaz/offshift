# ADR 0017: Make Offshift tray-first and keep care-screen triggers local

**Status:** Accepted

**Date:** 2026-07-17

## Context

Offshift is a companion that normally waits in the macOS menu bar. Showing a
Dock icon or a primary window at launch makes that behaviour unclear: it looks
like a conventional always-open app instead of a quiet, local companion.

The product owner also needs a repeatable way to inspect the black care screen
while developing. A ChatGPT Apps SDK/MCP request is remote relative to the
macOS companion, however. Letting that request create, focus, cover the
monitor with, or lock a local window would grant a server and model authority
over the user's desktop.

## Decision

Offshift launches as a menu-bar-only (`.accessory`) process with no Dock icon
and no Today window at launch. Its tray menu is the normal entry point for
opening the singleton Today window and native Settings. Closing either window
returns the app to the menu bar; it does not quit Offshift.

The black care screen may be opened only by local behaviour policy or by a
Debug-only **Developer: care screen** preview. The developer preview is
explicitly local, does not persist, and suppresses the optional Lock Screen
countdown and smart-home actions.

MCP/ChatGPT may read or render a care **preview** inside ChatGPT, but may not
open, focus, cover, dismiss, or lock any macOS companion window. It has no
local IPC command for that purpose. A future bridge would require a separate,
user-mediated local pairing and a new ADR.

## Consequences

- The tray is the obvious home of Offshift; the Dock no longer suggests a
  background main window.
- Developers can examine the actual full-screen composition without risking a
  system Lock Screen request.
- ChatGPT can explain the experience without gaining remote desktop control.
