# Safe Codex ↔ Offshift synchronization and allowlisted webhook control plane

## Purpose

This document defines a safe synchronization design for Offshift’s current ChatGPT/Apps SDK surfaces, the local macOS companion, and a future allowlisted webhook control plane that may carry coarse Codex-related state.

The design is intentionally conservative:

- it preserves the current separation between model-visible data tools, app-visible mutation tools, and local-only device actions;
- it never lets Codex or ChatGPT directly control a computer, close a session, run arbitrary webhooks, or issue free-form device commands;
- it minimizes payloads to coarse, explainable state;
- it requires explicit user consent for every boundary that could increase authority.

This is a design proposal for the next step in Offshift’s architecture. It does not change the existing runtime contracts in `offshift_worker`, `offshift_server_node`, or `offshift_companion`.

## Baseline contracts this design must preserve

The current repository already establishes the following boundaries:

- the worker and local Node server expose read-only status tools plus bounded break/on-call mutations;
- all mutations require an explicit user click and an idempotency key;
- the only smart-home action in scope is the allowlisted `wind-down` scene mapped locally to `scene.offshift_wind_down`;
- the local companion owns device-side action, including the optional local Lock Screen rule;
- the model may explain, preview, and schedule bounded plans, but it cannot lock the device, end a Codex session, inspect source code, upload telemetry, or invoke arbitrary webhooks.

This design keeps those rules intact and makes them explicit for synchronization traffic as well.

## Design goals

1. Keep Codex-aware state useful but coarse.
2. Ensure every remote write is allowlisted, authenticated, replay-safe, and user-authorized.
3. Make sync events idempotent and easy to audit.
4. Keep the local companion the only authority for device-side actions.
5. Prevent the model from becoming a hidden control path.

## Non-goals

- Reading prompts, source code, diffs, terminal output, browser content, screenshots, keystrokes, microphone data, or raw camera frames.
- Remote locking, remote command execution, or arbitrary automation.
- Automatic inference of fatigue, health, emotion, attention, identity, or burnout.
- Screen Time / Family Controls integration in the MVP.
- Any server-side authority to relax the local Lock Screen rule or the local pause/disable gate.

## Entities

### 1. Codex session

A Codex session is treated as an external, opt-in signal source. The only acceptable session facts are coarse lifecycle markers and user-owned, non-content state such as:

- session started / session paused / session resumed / session ended;
- whether the user explicitly marked the session as active for Offshift;
- an opaque session handle supplied by the local integration;
- optional coarse activity aggregates such as elapsed focus minutes.

The session must never contribute prompt text, code, filenames, diffs, or terminal contents.

### 2. Offshift state

Offshift state is the combination of:

- current work-pattern band: `routine`, `drift`, or `protect`;
- current local companion gate state;
- current scheduled break / snooze / on-call override;
- current consent state for sync and webhook targets;
- delivery status for outbound allowlisted webhooks.

### 3. Control plane

The control plane is a narrow, signed event system for passing coarse state between the local companion and any allowlisted external receiver.

It has two distinct directions:

- inbound sync into Offshift from a local trusted producer;
- outbound allowlisted webhooks from Offshift to a user-approved target.

The model never gets to invent endpoints, payloads, or targets.

## Event model

### Canonical event envelope

All sync and webhook messages should use one canonical envelope:

```json
{
  "eventId": "evt_01J2X5Q8D4J2M4Q8H6F2M9V5E7",
  "eventType": "codex.session.started",
  "occurredAt": "2026-07-17T08:30:00Z",
  "source": {
    "kind": "local-companion",
    "instanceId": "mac-8f1c",
    "channel": "sync"
  },
  "subject": {
    "userId": "user-opaque",
    "sessionId": "codex-opaque-9a7"
  },
  "sequence": 1042,
  "idempotencyKey": "sync:codex-session-started:codex-opaque-9a7:1042",
  "payload": {}
}
```

Rules:

- `eventId` is globally unique.
- `sequence` is monotonic per source instance and subject.
- `idempotencyKey` is required for every write event.
- `payload` must be sparse and schema-validated.
- PII, content, URLs, credentials, and raw identifiers do not belong in the envelope.

### Inbound event types

Recommended inbound events:

| Event type | Meaning | Payload | Notes |
| --- | --- | --- | --- |
| `codex.session.started` | A local integration observed that a Codex session began. | `sessionClass`, optional `focusBudgetMinutes` | Coarse only. Never includes prompt or repo data. |
| `codex.session.paused` | The user paused the local Codex-aware integration. | `reasonCode` | Optional; user-facing reasons only. |
| `codex.session.resumed` | The local integration resumed after a pause. | none | Coarse lifecycle signal. |
| `codex.session.ended` | The local integration ended. | `durationMinutes` | Rounded, not exact if that improves minimization. |
| `offshift.local.activity.sampled` | The companion sampled aggregate active/idle time. | `activeMinutes`, `idleMinutes`, `appSwitches` | No app titles. |
| `offshift.local.band.changed` | The local heuristic changed band. | `fromBand`, `toBand`, `reasons[]` | Reasons remain high-level and explainable. |
| `offshift.consent.changed` | User changed sync/webhook consent locally. | `scope`, `enabled` | Used to gate outbound traffic. |
| `offshift.pause.changed` | User paused or resumed interventions locally. | `availability`, `until?` | Local-only gate state. |

### Outbound webhook event types

Allowlisted outbound events are not a general notification system. They exist only for coarse, user-approved state transitions.

| Event type | Typical target | Meaning | Payload |
| --- | --- | --- | --- |
| `offshift.plan.previewed` | Analytics sink or local companion | A proposed plan was generated. | `planId`, `durationMinutes`, `sceneId` |
| `offshift.plan.scheduled` | Local companion or approved downstream automation | A plan was committed. | `planId`, `startsAt`, `endsAt`, `sceneId` |
| `offshift.plan.snoozed` | Local companion or approved downstream automation | A plan was delayed. | `planId`, `snoozeMinutes`, `newStartsAt` |
| `offshift.oncall.started` | Local companion or approved downstream automation | A bounded on-call override started. | `overrideMinutes`, `endsAt` |
| `offshift.oncall.ended` | Local companion or approved downstream automation | The override ended. | `endedAt` |
| `offshift.protect.entered` | Local companion | A protect episode began. | `band`, `reasonCodes[]` |
| `offshift.protect.exited` | Local companion | A protect episode ended. | `band`, `reasonCodes[]` |

No webhook should ever carry a device credential, a Home Assistant token, a terminal command, or an arbitrary URL chosen by the model.

## State flow

### 1. Local observation

The companion samples only coarse local facts:

- active minutes;
- idle minutes;
- app-switch counts;
- whether the user opted into Codex-session-active as a boolean;
- local time relative to quiet hours;
- prior snoozes and current pause/disable state.

The companion converts those into the existing work-pattern bands and writes a local snapshot.

### 2. Optional Codex sync

If the user enables Codex sync, the local integration may emit coarse lifecycle events into the companion.

That sync may influence only:

- an explanation string;
- whether the next local nudge is eligible;
- whether the local companion should add `Codex session active` to its own reason set.

It may not:

- create a lock action;
- bypass quiet hours;
- create a remote command;
- reveal prompts, code, or repository data;
- auto-start or auto-end a session inside Codex.

### 3. ChatGPT / Apps SDK read path

ChatGPT reads snapshots through the existing data tools:

- focus status;
- work-pattern explanation;
- preview of a bounded break;
- render of the dashboard.

Those tools should remain read-only except for the existing bounded mutations.

### 4. User-approved mutation path

When the user clicks a dashboard control, the Apps SDK app-visible mutation is sent with:

- a server-verified dashboard capability;
- an idempotency key;
- bounded arguments;
- no arbitrary webhook target.

The worker or local server validates the request, updates the plan state, and then may emit a matching outbound allowlisted webhook event if that target was pre-approved.

### 5. Local companion execution

Any device-side action remains local-only:

- optional local Lock Screen rule;
- direct Home Assistant wind-down scene;
- local pause/disable gates.

Neither the worker nor ChatGPT should ever receive enough authority to execute those directly.

## Authentication model

### Inbound sync authentication

Inbound sync should require one of:

- a locally minted symmetric secret stored only on the Mac;
- a mutual-authenticated local transport on loopback;
- or another local-only trust mechanism that never exposes the secret to ChatGPT or the Worker.

Recommended properties:

- single-purpose secret per device;
- short-lived session token for the current sync period;
- source instance identifier bound to the secret;
- refusal by default when the source is unknown.

### Outbound webhook authentication

Outbound webhooks should use target-specific credentials that are:

- allowlisted by target id;
- stored locally or in a hardened server secret store;
- never visible to the model;
- never copied into event payloads.

Recommended options, in descending preference:

1. pre-shared HMAC signature on the payload;
2. OAuth or bearer token held by the local companion;
3. mTLS to a known endpoint.

The model may request an allowlisted target be used, but it may not supply the credential.

### Trust separation

The design should preserve three trust tiers:

- model-visible data: safe to explain in ChatGPT;
- app-visible mutations: safe only after explicit user click and capability proof;
- local-only execution: safe only on the Mac.

No tier can silently promote itself to another tier.

## Idempotency and replay protection

Every write-capable event must be idempotent.

Required fields:

- `eventId` for global uniqueness;
- `idempotencyKey` for request-level dedupe;
- `sequence` for source-order conflict detection;
- `retryCount` or equivalent delivery metadata for transport retries.

Rules:

- repeated delivery of the same `idempotencyKey` must produce the same effect and the same logical result;
- stale or out-of-order sequence numbers should be ignored or rejected, depending on the receiver’s statefulness;
- duplicate outbound webhooks should be retried only on safe transport failures;
- semantic replays must not recreate a plan, a lock attempt, or a scene request.

Recommended dedupe windows:

- dashboard mutation idempotency: at least 24 hours;
- outbound webhook delivery: at least 7 days of delivery log retention, but only opaque metadata;
- local sync event dedupe: at least the current session and next startup recovery window.

## Consent gates

The design needs explicit consent at each authority boundary.

### Required opt-ins

- Codex session active signal: explicit local opt-in.
- Sync channel activation: explicit local opt-in on the Mac.
- Outbound webhook target registration: explicit local configuration and approval.
- On-call override: explicit current-turn user action.
- Local Lock Screen rule: explicit local configuration in the companion.

### Required confirmations

- first sync handshake on a new device;
- first webhook target registration;
- first delivery to a target after credentials change;
- any transition from shadow mode to active nudges;
- any escalation from routine to drift or protect;
- any attempt to use the local wind-down scene;
- any optional local Lock Screen countdown.

### Permanent local-only gates

The following are never remotely changeable:

- local pause-until-tomorrow;
- local disable switch;
- local Lock Screen rule enablement;
- Home Assistant base URL and token storage;
- any device permission changes.

## Data minimization rules

The sync plane should collect only what is needed to preserve explainability and idempotency.

Allowed:

- opaque user id;
- opaque session id;
- aggregate active/idle minutes;
- app-switch counts;
- coarse band;
- reason codes;
- explicit user choices;
- delivery status metadata.

Disallowed:

- prompt text;
- code, diffs, filenames, or repository names;
- terminal output;
- browser history;
- screenshots;
- device credentials;
- raw webhook URLs in model-visible content;
- smart-home tokens;
- exact app titles unless the user has separately opted into a local diagnostic mode and the title is still treated as non-exportable.

Retention should be as short as possible:

- keep raw delivery attempts only long enough to debug transport;
- keep aggregate state longer than raw events;
- prefer derived state over stored history;
- purge failed webhook bodies once the failure is classified.

## Failure behavior

### Inbound sync failures

If the sync source is unauthenticated, out of order, malformed, or expired:

- reject the event;
- keep the last known safe state;
- surface a local error only if the user needs to fix configuration;
- never downgrade to a weaker trust mode automatically.

### Outbound webhook failures

If a webhook delivery fails:

- mark the event undelivered;
- retry only under a bounded backoff policy;
- stop after a fixed number of attempts;
- preserve the user-visible Offshift plan even if the webhook fails;
- never broaden the target list to “make it work”.

### Local companion failures

If the companion is offline:

- ChatGPT can still show snapshots and previews from the worker or local demo store;
- no local scene or lock action should be assumed to succeed;
- outbound webhooks should queue only if the queue itself is local and replay-safe;
- do not fabricate confirmation.

### Worker or server failures

If the worker or local server is unavailable:

- read-only tools may fail closed with a clear error;
- mutation tools must not partially apply;
- the user should remain able to retry with the same idempotency key;
- local-only actions remain local and independent.

### Consent withdrawal

If consent is withdrawn:

- stop future sync immediately;
- quarantine or delete queued outbound webhook deliveries per policy;
- keep only the minimum audit record necessary to explain that consent was removed;
- do not use stale consent for retries.

## What Codex and ChatGPT may never control

Codex and ChatGPT must never directly or indirectly control any of the following:

- arbitrary URLs;
- arbitrary webhooks;
- device credentials;
- Home Assistant tokens;
- the local Mac’s Lock Screen rule;
- the local pause-until-tomorrow gate;
- the local disable switch;
- the end of a Codex session;
- code submission;
- repository writes;
- screen capture;
- prompt capture;
- microphone or camera capture;
- screen-content-based decisions;
- any non-allowlisted smart-home scene;
- any command that is not tied to a user-approved, schema-validated, allowlisted target.

The only allowed remote effect remains a bounded, schema-checked request to an allowlisted target. Even that must stay coarse and user-approved.

## Proposed Apps SDK tool table

The current Offshift tools already fit the safe pattern. For a Codex sync and webhook control plane, the Apps SDK should stay split into read-only explanation tools, user-click mutations, and explicit control-plane administration tools.

| Tool | Role | Input shape | Output shape | Safety notes |
| --- | --- | --- | --- | --- |
| `get_focus_snapshot` | Read | none or optional user id | focus minutes, threshold, suggested break | Read-only aggregate data. |
| `get_work_pattern_snapshot` | Read | none or optional user id | band, reasons, shadow mode, local-rule status | No content access. |
| `preview_break_plan` | Read | duration, optional scene id | proposed plan | No schedule change. |
| `schedule_break` | Mutation | duration, scene id, idempotency key, widget capability | committed plan | Requires current-turn user click. |
| `snooze_break` | Mutation | minutes, idempotency key, widget capability | updated plan | Bounded retry-safe mutation. |
| `set_on_call_override` | Mutation | minutes, idempotency key, widget capability | override plan | Must remain bounded. |
| `resume_reminders` | Mutation | idempotency key, widget capability | resumed state | Ends bounded override only. |
| `render_offshift_dashboard` | Render | none or optional user id | snapshot, behaviour, plan, allowed scenes | Mounts the widget. |
| `register_codex_sync` | Admin mutation | local device id, consent ack, session scope | sync lease | Local-only or device-authorized. Never model-only. |
| `pause_codex_sync` | Admin mutation | lease id, idempotency key | paused sync state | Stops future sync immediately. |
| `resume_codex_sync` | Admin mutation | lease id, idempotency key | active sync state | Requires explicit user action. |
| `list_webhook_targets` | Read | none | allowlisted target list | Returns names and coarse metadata only. |
| `preview_webhook_delivery` | Read | target id, event type | sanitized payload preview | Must strip secrets. |
| `register_webhook_target` | Admin mutation | target id, URL, auth kind, consent ack | target registration | Target id must be allowlisted by policy. |
| `disable_webhook_target` | Admin mutation | target id, idempotency key | disabled target state | Safe fail-closed. |
| `deliver_allowlisted_webhook` | Mutation | target id, event envelope, idempotency key | delivery receipt | Never accepts arbitrary URLs. |

Recommended annotations:

- read tools: `readOnlyHint: true`, `destructiveHint: false`, `openWorldHint: false`, `idempotentHint: true`;
- admin or delivery mutations: `readOnlyHint: false`, `destructiveHint: false`, `openWorldHint: false`, `idempotentHint: true`;
- any tool that can touch an external endpoint should remain app-visible, capability-gated, and strictly schema-validated.

## Proposed webhook schemas

### 1. Sync event envelope

```json
{
  "$id": "https://example.invalid/offshift/schemas/event-envelope.json",
  "type": "object",
  "required": ["eventId", "eventType", "occurredAt", "source", "subject", "sequence", "idempotencyKey", "payload"],
  "additionalProperties": false,
  "properties": {
    "eventId": { "type": "string", "minLength": 16, "maxLength": 128 },
    "eventType": {
      "type": "string",
      "enum": [
        "codex.session.started",
        "codex.session.paused",
        "codex.session.resumed",
        "codex.session.ended",
        "offshift.local.activity.sampled",
        "offshift.local.band.changed",
        "offshift.consent.changed",
        "offshift.pause.changed",
        "offshift.plan.previewed",
        "offshift.plan.scheduled",
        "offshift.plan.snoozed",
        "offshift.oncall.started",
        "offshift.oncall.ended",
        "offshift.protect.entered",
        "offshift.protect.exited"
      ]
    },
    "occurredAt": { "type": "string", "format": "date-time" },
    "source": {
      "type": "object",
      "required": ["kind", "instanceId", "channel"],
      "additionalProperties": false,
      "properties": {
        "kind": { "type": "string", "enum": ["local-companion", "offshift-worker", "offshift-server", "approved-external"] },
        "instanceId": { "type": "string", "minLength": 2, "maxLength": 64 },
        "channel": { "type": "string", "enum": ["sync", "webhook"] }
      }
    },
    "subject": {
      "type": "object",
      "required": ["userId"],
      "additionalProperties": false,
      "properties": {
        "userId": { "type": "string", "minLength": 2, "maxLength": 128 },
        "sessionId": { "type": "string", "minLength": 2, "maxLength": 128 }
      }
    },
    "sequence": { "type": "integer", "minimum": 0 },
    "idempotencyKey": { "type": "string", "minLength": 8, "maxLength": 128 },
    "payload": { "type": "object", "additionalProperties": false }
  }
}
```

### 2. `codex.session.started`

```json
{
  "type": "object",
  "required": ["sessionClass"],
  "additionalProperties": false,
  "properties": {
    "sessionClass": { "type": "string", "enum": ["focused-build", "debugging", "review", "writing", "other-opaque"] },
    "focusBudgetMinutes": { "type": "integer", "minimum": 5, "maximum": 240 }
  }
}
```

### 3. `offshift.local.band.changed`

```json
{
  "type": "object",
  "required": ["fromBand", "toBand", "reasons"],
  "additionalProperties": false,
  "properties": {
    "fromBand": { "type": "string", "enum": ["routine", "drift", "protect"] },
    "toBand": { "type": "string", "enum": ["routine", "drift", "protect"] },
    "reasons": { "type": "array", "items": { "type": "string" }, "minItems": 1, "maxItems": 5 }
  }
}
```

### 4. `offshift.plan.scheduled`

```json
{
  "type": "object",
  "required": ["planId", "startsAt", "endsAt", "sceneId"],
  "additionalProperties": false,
  "properties": {
    "planId": { "type": "string", "minLength": 2, "maxLength": 128 },
    "startsAt": { "type": "string", "format": "date-time" },
    "endsAt": { "type": "string", "format": "date-time" },
    "sceneId": { "type": "string", "enum": ["wind-down"] }
  }
}
```

### 5. Allowlisted webhook target registration

```json
{
  "type": "object",
  "required": ["targetId", "displayName", "endpoint", "authKind", "eventTypes"],
  "additionalProperties": false,
  "properties": {
    "targetId": { "type": "string", "pattern": "^[a-z0-9_-]{3,64}$" },
    "displayName": { "type": "string", "minLength": 1, "maxLength": 80 },
    "endpoint": {
      "type": "object",
      "required": ["url", "method"],
      "additionalProperties": false,
      "properties": {
        "url": { "type": "string", "format": "uri" },
        "method": { "type": "string", "enum": ["POST"] }
      }
    },
    "authKind": { "type": "string", "enum": ["hmac-sha256", "bearer-local", "mtls"] },
    "eventTypes": {
      "type": "array",
      "items": {
        "type": "string",
        "enum": [
          "offshift.plan.previewed",
          "offshift.plan.scheduled",
          "offshift.plan.snoozed",
          "offshift.oncall.started",
          "offshift.oncall.ended",
          "offshift.protect.entered",
          "offshift.protect.exited"
        ]
      },
      "minItems": 1,
      "maxItems": 8
    }
  }
}
```

### 6. Delivery receipt

```json
{
  "type": "object",
  "required": ["targetId", "eventId", "status", "attempt"],
  "additionalProperties": false,
  "properties": {
    "targetId": { "type": "string" },
    "eventId": { "type": "string" },
    "status": { "type": "string", "enum": ["delivered", "retrying", "failed", "disabled", "rejected"] },
    "attempt": { "type": "integer", "minimum": 1 },
    "httpStatus": { "type": "integer", "minimum": 100, "maximum": 599 },
    "failureClass": { "type": "string", "enum": ["timeout", "auth", "schema", "replay", "target_disabled", "network", "unknown"] }
  }
}
```

## Recommended control-flow split

### Apps SDK / ChatGPT

Use the Apps SDK for:

- read-only explanation and preview;
- explicit bounded mutations initiated by the user;
- display of current control-plane health;
- selection of an allowlisted webhook target by name, not by arbitrary URL.

Never use the Apps SDK for:

- raw device control;
- arbitrary outbound webhooks;
- locking;
- code execution;
- direct sync credential management.

### Worker or server

Use the worker or server for:

- validating user clicks, idempotency keys, and schema;
- storing coarse plan state;
- emitting allowlisted webhook deliveries;
- serving explainable snapshots.

Do not let it become the authority for local device actions.

### Local companion

Use the companion for:

- device-side execution;
- local trust decisions;
- sync source authentication;
- final confirmation for the wind-down scene;
- final control over lock and pause gates.

## Key recommendation

Keep Codex sync local-first and deny-by-default: the only safe way to connect Codex awareness to Offshift is through coarse, consented lifecycle events from the Mac, with outbound webhooks restricted to an explicit allowlist of named targets and event types. If a payload cannot be explained in one sentence without mentioning content, credentials, or commands, it should not cross the boundary.

