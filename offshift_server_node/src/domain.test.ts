import assert from "node:assert/strict";
import test from "node:test";

import { createDemoState, scheduleBreak, snoozeBreak } from "./domain.js";

test("scheduleBreak returns the same result for an idempotency key", () => {
  const state = createDemoState();
  const now = new Date("2026-07-16T12:00:00.000Z");
  const input = {
    durationMinutes: 5,
    sceneId: "stretch-lights" as const,
    idempotencyKey: "schedule-1",
  };

  const first = scheduleBreak(state, input, now);
  const second = scheduleBreak(state, input, new Date("2026-07-16T13:00:00.000Z"));

  assert.deepEqual(second, first);
  assert.equal(first.status, "scheduled");
});

test("snoozeBreak preserves the chosen scene", () => {
  const state = createDemoState();
  const now = new Date("2026-07-16T12:00:00.000Z");
  scheduleBreak(state, {
    durationMinutes: 10,
    sceneId: "wind-down",
    idempotencyKey: "schedule-2",
  }, now);

  const snoozed = snoozeBreak(state, { minutes: 5, idempotencyKey: "snooze-1" }, now);

  assert.equal(snoozed.status, "snoozed");
  assert.equal(snoozed.sceneId, "wind-down");
  assert.equal(snoozed.startsAt, "2026-07-16T12:05:00.000Z");
});
