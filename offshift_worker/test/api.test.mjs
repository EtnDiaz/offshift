import assert from "node:assert/strict";
import test from "node:test";
import { createDemoStore } from "../.test-dist/demo-store.js";
import { createWorker } from "../.test-dist/index.js";

const clock = () => new Date("2026-07-16T10:00:00.000Z");

function app() {
  return createWorker(createDemoStore(clock));
}

function request(path, options = {}) {
  return new Request(`https://offshift.test${path}`, options);
}

async function responseJson(response) {
  assert.equal(response.headers.get("content-type"), "application/json; charset=utf-8");
  return response.json();
}

test("health returns a stable service response", async () => {
  const response = await app().fetch(request("/health"), {}, {});
  assert.equal(response.status, 200);
  assert.deepEqual(await responseJson(response), { status: "ok", service: "offshift-demo-api" });
});

test("focus snapshot is deterministic for a user", async () => {
  const worker = app();
  const first = await responseJson(await worker.fetch(request("/v1/focus/snapshot?userId=ada"), {}, {}));
  const second = await responseJson(await worker.fetch(request("/v1/focus/snapshot?userId=ada"), {}, {}));
  assert.deepEqual(first, second);
  assert.equal(first.userId, "ada");
  assert.ok(first.focusScore >= 55 && first.focusScore <= 90);
});

test("preview accepts only allowlisted break actions", async () => {
  const valid = await app().fetch(request("/v1/breaks/preview", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ action: "stretch" }),
  }), {}, {});
  assert.equal(valid.status, 200);
  assert.equal((await responseJson(valid)).durationMinutes, 3);

  const invalid = await app().fetch(request("/v1/breaks/preview", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ action: "send-webhook" }),
  }), {}, {});
  assert.equal(invalid.status, 400);
  assert.match((await responseJson(invalid)).error, /action must be one of/);
});

test("schedule and snooze produce bounded, deterministic plan changes", async () => {
  const worker = app();
  const scheduled = await worker.fetch(request("/v1/breaks/schedule", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ action: "walk", userId: "ada", startInMinutes: 15 }),
  }), {}, {});
  assert.equal(scheduled.status, 201);
  const plan = await responseJson(scheduled);
  assert.equal(plan.id, "break-0001");
  assert.equal(plan.startAt, "2026-07-16T10:15:00.000Z");

  const snoozed = await worker.fetch(request(`/v1/breaks/${plan.id}/snooze`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ minutes: 10 }),
  }), {}, {});
  assert.equal(snoozed.status, 200);
  assert.deepEqual(await responseJson(snoozed), { ...plan, status: "snoozed", startAt: "2026-07-16T10:25:00.000Z", snoozeCount: 1 });
});

test("schedule and snooze reject values beyond their safety bounds", async () => {
  const worker = app();
  const overscheduled = await worker.fetch(request("/v1/breaks/schedule", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ action: "breathe", startInMinutes: 481 }),
  }), {}, {});
  assert.equal(overscheduled.status, 400);

  const missing = await worker.fetch(request("/v1/breaks/break-9999/snooze", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ minutes: 4 }),
  }), {}, {});
  assert.equal(missing.status, 400);
});
