# Offshift safety model

## Protected boundaries

- Home automation credentials remain outside ChatGPT, the widget, and model-visible `structuredContent`.
- A scene is selected by opaque allowlisted id, not by an arbitrary URL or freeform command.
- Widget state is presentation state, never authorization state.
- The server validates duration limits, scene ids, device identity, and idempotency before changing a schedule.

## Consent model

Scheduling and snoozing require an explicit current-turn action. The future companion asks for direct local confirmation before an external scene is run unless the user enabled a specific automation rule locally.

## Logging

Keep audit records to action type, opaque schedule id, timestamp, result, and non-sensitive device alias. Do not log source code, screen content, raw usage history, OAuth tokens, or smart-home credentials.
