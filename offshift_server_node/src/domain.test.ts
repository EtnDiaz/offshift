import assert from "node:assert/strict";
import test from "node:test";

import { ALLOWED_SCENE_IDS, createDemoState, focusSnapshot, isAllowedSceneId, scheduleBreak, setOnCallOverride, snoozeBreak, workPatternSnapshot } from "./domain.js";

test("the MCP contract exposes exactly one opaque local scene", () => {
  assert.deepEqual(ALLOWED_SCENE_IDS, ["wind-down"]);
  assert.equal(isAllowedSceneId("wind-down"), true);
  assert.equal(isAllowedSceneId("stretch-lights"), false);
  assert.equal(isAllowedSceneId("https://example.test/webhook"), false);
});

test("scheduleBreak returns the same result for an idempotency key", () => {
  const state = createDemoState();
  const now = new Date("2026-07-16T12:00:00.000Z");
  const input = {
    durationMinutes: 5,
    sceneId: "wind-down" as const,
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

test("workPatternSnapshot is explainable and never enables a lock rule", () => {
  const snapshot = workPatternSnapshot(focusSnapshot());

  assert.equal(snapshot.level, "drift");
  assert.deepEqual(snapshot.reasons, [
    "52 minutes of uninterrupted active work",
    "The configured break threshold has been reached",
  ]);
  assert.equal(snapshot.shadowMode, true);
  assert.equal(snapshot.lockScreenRule, "not-configured");
});

test("on-call override is bounded and idempotent", () => {
  const state = createDemoState();
  const now = new Date("2026-07-16T12:00:00.000Z");
  const input = { minutes: 60, idempotencyKey: "on-call-1" };

  const first = setOnCallOverride(state, input, now);
  const second = setOnCallOverride(state, input, new Date("2026-07-16T13:00:00.000Z"));

  assert.equal(first.status, "on-call");
  assert.equal(first.startsAt, "2026-07-16T13:00:00.000Z");
  assert.deepEqual(second, first);
});
