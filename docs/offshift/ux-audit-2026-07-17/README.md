# Offshift UX audit — 2026-07-17

## Scope and evidence

This audit covers the local macOS companion's default dashboard and its
full-screen care surface. Captures were made from the running companion on
2026-07-17:

1. `01-dashboard-current.png` — routine dashboard.
2. `02-care-screen-current.png` — local full-screen care surface.

The ChatGPT Apps SDK dashboard was also inspected from its current tool
contract. A live ChatGPT-host rendering could not be captured because the
Developer Mode connector remains externally blocked; that part of the audit is
limited to the rendered tool data and widget source.

## Findings

### 1. Dashboard — needs redesign

The first screen mixes three incompatible jobs: deciding what to do now,
explaining local privacy, and changing persistent controls. The result is a
weak next action and a dense, vertically stacked surface.

- The state `belowDriftThreshold` is an internal policy token presented as
  user-facing copy. It should become one plain sentence or be hidden.
- "A gentle check-in is ready" and "Open care screen" make the user perform a
  second step before knowing the proposed outcome. The primary action should
  name the outcome: for example, `Start a 5-minute reset`.
- Sleep care, pause, destructive off, repeated privacy copy, and developer
  fixtures compete with the decision. Persistent settings belong in Settings;
  developer fixtures must not be visible in the ordinary product flow.
- The sleeping Codex mark is good visual identity, but it is currently too
  small to establish a calm, caring hierarchy.

### 2. Protective screen — needs redesign

The local black surface is correctly non-destructive and exposes a keyboard
default action, but its content occupies too little of a wide display. In the
captured 1280 × 800 window, the message reads as a small cluster in a large
black field.

- The mascot and headline need a much larger, intentional composition.
- The primary action is understandable but "and leave" is vague. It should say
  what is happening locally and what stays untouched.
- Pause and turn-off controls are legitimate exit paths, but need a quieter
  hierarchy and a single concise explanation of reversibility.
- The current screenshot suggests body/supporting text is too small for a
  full-screen interruption. Keyboard focus and native button labels exist, but
  contrast, dynamic type, VoiceOver order, and escape-route behavior still
  need runtime accessibility testing after the redesign.

### 3. ChatGPT Apps SDK widget — simplify the handoff

The widget currently presents three bordered sections: session metrics,
reasons, and plan. This repeats context before reaching the only useful
decision. The redesign should make one plan the hero, retain a one-line reason
and a privacy boundary, and clearly label the action as preparation only.
ChatGPT must continue to have no authority to lock the Mac or run a local
smart-home scene.

## Direction for implementation

Use the supplied sleeping Codex art as the Offshift brand mark. Make the macOS
dashboard a native sidebar + focused detail window:

- **Today:** one current recommendation, one primary action, one deferral, and
  an expandable “Why now?” explanation.
- **Settings:** sleep care, pause/off, local Lock Screen consent, quiet hours,
  and Home Assistant configuration.
- **Developer fixtures:** removed from the normal dashboard and retained only
  behind a development-only command.

The protective screen should remain a black, local, reversible interruption,
but make Codex and the primary reset action visually dominant. The Apps SDK
widget should mirror the same single-decision hierarchy and plainly hand off
local-only choices to the companion.

## Verification status

- Captured and visually inspected both macOS flow steps.
- Verified the current care surface is a local dialog with a 5-minute default
  action, a pause option, an off option, and no Lock Screen countdown in its
  gentle state.
- The companion's prior functional run passed `swift test` (27 tests) and
  `./script/build_and_run.sh --verify`.
- The redesign itself is not implemented or usability-tested yet. Image-based
  design exploration is blocked by the current built-in Image Gen 403 response.
