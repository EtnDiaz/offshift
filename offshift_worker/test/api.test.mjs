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

async function mcp(worker, id, method, params = {}) {
  const response = await worker.fetch(request("/mcp", {
    method: "POST",
    headers: { "content-type": "application/json", "mcp-protocol-version": "2026-01-26" },
    body: JSON.stringify({ jsonrpc: "2.0", id, method, params }),
  }), {}, {});
  assert.equal(response.status, 200);
  const body = await responseJson(response);
  assert.equal(body.jsonrpc, "2.0");
  assert.equal(body.id, id);
  assert.equal(body.error, undefined);
  return body.result;
}

test("health returns a stable service response", async () => {
  const response = await app().fetch(request("/health"), {}, {});
  assert.equal(response.status, 200);
  assert.deepEqual(await responseJson(response), {
    status: "ok",
    service: "offshift-demo-api",
    mcpPath: "/mcp",
    widgetUri: "ui://widget/offshift-worker-v3.html",
  });
});

test("focus snapshot is deterministic for a user", async () => {
  const worker = app();
  const first = await responseJson(await worker.fetch(request("/v1/focus/snapshot?userId=ada"), {}, {}));
  const second = await responseJson(await worker.fetch(request("/v1/focus/snapshot?userId=ada"), {}, {}));
  assert.deepEqual(first, second);
  assert.equal(first.userId, "ada");
  assert.ok(first.focusScore >= 55 && first.focusScore <= 90);
});

test("behavior policy and snapshot REST endpoints are explainable and local-only", async () => {
  const worker = app();
  const policy = await responseJson(await worker.fetch(request("/v1/behavior/policy"), {}, {}));
  const snapshot = await responseJson(await worker.fetch(request("/v1/behavior/snapshot?userId=ada"), {}, {}));
  assert.equal(policy.mode, "shadow");
  assert.equal(policy.decisionOwner, "local-companion");
  assert.deepEqual(policy.forbiddenRemoteActions, [
    "remote lock commands",
    "ending a Codex session or submitting code",
    "arbitrary webhooks or device commands",
  ]);
  assert.equal(snapshot.userId, "ada");
  assert.equal(snapshot.canTriggerRemoteAction, false);
  assert.match(snapshot.explanation, /aggregate activity/);
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

test("schedule retries with an idempotency key do not create another break", async () => {
  const worker = app();
  const options = {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ action: "walk", userId: "ada", startInMinutes: 15, idempotencyKey: "rest-plan-0001" }),
  };
  const first = await responseJson(await worker.fetch(request("/v1/breaks/schedule", options), {}, {}));
  const second = await responseJson(await worker.fetch(request("/v1/breaks/schedule", options), {}, {}));
  assert.deepEqual(second, first);
  assert.equal(second.id, "break-0001");
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

test("MCP exposes the decoupled tools with accurate safety annotations", async () => {
  const worker = app();
  const initialized = await mcp(worker, 1, "initialize", { protocolVersion: "2026-01-26", capabilities: {}, clientInfo: { name: "test", version: "1" } });
  assert.equal(initialized.protocolVersion, "2026-01-26");
  assert.match(initialized.instructions, /never infer health/);

  const { tools } = await mcp(worker, 2, "tools/list");
  assert.deepEqual(tools.map((tool) => tool.name), [
    "get_focus_snapshot",
    "get_work_pattern_snapshot",
    "preview_break_plan",
    "schedule_break",
    "resume_reminders",
    "snooze_break",
    "set_on_call_override",
    "render_offshift_dashboard",
  ]);
  const schedule = tools.find((tool) => tool.name === "schedule_break");
  assert.deepEqual(schedule.annotations, {
    readOnlyHint: false,
    destructiveHint: false,
    openWorldHint: false,
    idempotentHint: true,
  });
  const render = tools.find((tool) => tool.name === "render_offshift_dashboard");
  assert.deepEqual(schedule._meta.ui.visibility, ["app"]);
  assert.equal(render._meta.ui.resourceUri, "ui://widget/offshift-worker-v3.html");
  assert.equal(render._meta["openai/outputTemplate"], "ui://widget/offshift-worker-v3.html");
  assert.equal(tools.some((tool) => /webhook|lock|command/i.test(tool.name)), false);
});

test("MCP resource read returns the React widget with a tightly scoped CSP", async () => {
  const worker = app();
  const { contents } = await mcp(worker, 3, "resources/read", { uri: "ui://widget/offshift-worker-v3.html" });
  assert.equal(contents.length, 1);
  assert.equal(contents[0].mimeType, "text/html;profile=mcp-app");
  assert.deepEqual(contents[0]._meta.ui.csp, {
    connectDomains: [],
    resourceDomains: ["https://offshift-demo-api.tixo-digital.workers.dev"],
  });
  assert.match(contents[0].text, /offshift\.js/);
  assert.doesNotMatch(contents[0].text, /window\.openai/);
});

test("MCP work-pattern snapshot is explainable, shadow-only, and cannot trigger remote actions", async () => {
  const worker = app();
  const result = await mcp(worker, 4, "tools/call", {
    name: "get_work_pattern_snapshot",
    arguments: { userId: "ada" },
  });
  const { behaviour } = result.structuredContent;
  assert.equal(behaviour.shadowMode, true);
  assert.equal(behaviour.lockScreenRule, "not-configured");
  assert.ok(["routine", "drift", "protect"].includes(behaviour.level));
  assert.match(behaviour.reasons.join(" "), /aggregate active-app time/);
});

test("MCP mutation retries are idempotent and require explicit idempotency keys", async () => {
  const worker = app();
  const params = {
    name: "schedule_break",
    arguments: { durationMinutes: 5, sceneId: "wind-down", idempotencyKey: "mcp-plan-0001" },
  };
  const first = await mcp(worker, 5, "tools/call", params);
  const second = await mcp(worker, 6, "tools/call", params);
  assert.deepEqual(second.structuredContent.plan, first.structuredContent.plan);

  const invalid = await worker.fetch(request("/mcp", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 7, method: "tools/call", params: { name: "schedule_break", arguments: { durationMinutes: 5, sceneId: "wind-down" } } }),
  }), {}, {});
  const invalidBody = await responseJson(invalid);
  assert.equal(invalidBody.error.code, -32602);
  assert.match(invalidBody.error.message, /idempotencyKey is required/);
});

test("MCP dashboard output fits the React widget and on-call remains bounded", async () => {
  const worker = app();
  const dashboard = await mcp(worker, 9, "tools/call", { name: "render_offshift_dashboard", arguments: {} });
  assert.equal(dashboard.structuredContent.snapshot.activeAppCategory, "coding");
  assert.equal(dashboard.structuredContent.plan.sceneId, "wind-down");
  assert.deepEqual(dashboard.structuredContent.allowedSceneIds, ["wind-down"]);

  const override = await mcp(worker, 10, "tools/call", {
    name: "set_on_call_override",
    arguments: { minutes: 60, idempotencyKey: "on-call-0001" },
  });
  assert.equal(override.structuredContent.plan.status, "on-call");
  assert.match(override.content[0].text, /No remote action/);

  const resumed = await mcp(worker, 11, "tools/call", {
    name: "resume_reminders",
    arguments: { idempotencyKey: "resume-0001" },
  });
  assert.equal(resumed.structuredContent.plan.status, "suggested");
});

test("Worker wraps widget asset responses with cross-origin headers", async () => {
  const worker = app();
  const assets = { fetch: async () => new Response("bundle", { headers: { "content-type": "text/javascript" } }) };
  const response = await worker.fetch(request("/offshift.js"), { ASSETS: assets }, {});
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("access-control-allow-origin"), "*");
  assert.equal(response.headers.get("cross-origin-resource-policy"), "cross-origin");
});

test("the Worker exposes no remote lock action on either REST or MCP", async () => {
  const worker = app();
  const rest = await worker.fetch(request("/v1/devices/lock", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: "{}",
  }), {}, {});
  assert.equal(rest.status, 404);

  const mcpResponse = await worker.fetch(request("/mcp", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 8, method: "tools/call", params: { name: "lock_device", arguments: {} } }),
  }), {}, {});
  const mcpBody = await responseJson(mcpResponse);
  assert.equal(mcpBody.error.code, -32602);
  assert.match(mcpBody.error.message, /Unknown Offshift tool/);
});
