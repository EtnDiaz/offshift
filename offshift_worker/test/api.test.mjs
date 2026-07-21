import assert from "node:assert/strict";
import { webcrypto } from "node:crypto";
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

async function mcpError(worker, id, method, params = {}) {
  const response = await worker.fetch(request("/mcp", {
    method: "POST",
    headers: { "content-type": "application/json", "mcp-protocol-version": "2026-01-26" },
    body: JSON.stringify({ jsonrpc: "2.0", id, method, params }),
  }), {}, {});
  assert.equal(response.status, 200);
  const body = await responseJson(response);
  assert.equal(body.jsonrpc, "2.0");
  assert.equal(body.id, id);
  assert.equal(body.result, undefined);
  return body.error;
}

function widgetCapability(result) {
  const capability = result?._meta?.["offshift/widgetCapability"];
  assert.equal(typeof capability, "string");
  assert.ok(capability.length >= 32);
  assert.equal(result.structuredContent.widgetCapability, undefined);
  return capability;
}

async function renderDashboard(worker, id = 1, userId = "demo-user") {
  return mcp(worker, id, "tools/call", { name: "render_offshift_dashboard", arguments: { userId } });
}

test("health returns a stable service response", async () => {
  const response = await app().fetch(request("/health"), {}, {});
  assert.equal(response.status, 200);
  assert.deepEqual(await responseJson(response), {
    status: "ok",
    service: "offshift-demo-api",
    mcpPath: "/mcp",
    widgetUri: "ui://widget/offshift-worker-v5.html",
    codexRelayPath: "/v1/codex/events",
  });
});

async function relaySignature(secret, timestamp, body) {
  const encoder = new TextEncoder();
  const key = await webcrypto.subtle.importKey("raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const digest = await webcrypto.subtle.sign("HMAC", key, encoder.encode(`${timestamp}.${body}`));
  return `sha256=${Buffer.from(digest).toString("hex")}`;
}

async function codexRelay(worker, event, options = {}) {
  const secret = options.secret ?? "offshift-test-secret";
  const timestamp = options.timestamp ?? String(Date.parse("2026-07-16T10:00:00.000Z"));
  const body = JSON.stringify(event);
  const signature = options.signature ?? await relaySignature(secret, timestamp, body);
  return worker.fetch(request("/v1/codex/events", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-offshift-timestamp": timestamp,
      "x-offshift-signature": signature,
    },
    body,
  }), { CODEX_RELAY_SECRET: secret }, {});
}

test("Codex relay only accepts signed, coarse lifecycle events and deduplicates them", async () => {
  const currentTime = Date.parse("2026-07-16T10:00:00.000Z");
  const worker = createWorker(createDemoStore(clock), undefined, { now: () => currentTime });
  const event = {
    version: "2026-07-17",
    eventId: "evt_00000001",
    installationId: "install_00000001",
    type: "session.started",
    occurredAt: "2026-07-16T10:00:00.000Z",
  };
  const first = await codexRelay(worker, event);
  assert.equal(first.status, 202);
  assert.deepEqual(await responseJson(first), {
    accepted: true,
    deduplicated: false,
    status: {
      state: "active",
      lastEventAt: event.occurredAt,
      sessionActive: true,
      privacyNote: "Only the opted-in Codex session state is synchronized. Prompts, code, repositories, terminal output, and screen content are never sent.",
    },
  });

  const duplicate = await codexRelay(worker, event);
  assert.equal(duplicate.status, 202);
  assert.equal((await responseJson(duplicate)).deduplicated, true);

  const contentAttempt = await codexRelay(worker, { ...event, eventId: "evt_00000002", prompt: "ship this feature" });
  assert.equal(contentAttempt.status, 400);
  assert.match((await responseJson(contentAttempt)).error, /unsupported data/);
});

test("Codex relay fails closed when disabled, stale, or unsigned", async () => {
  const currentTime = Date.parse("2026-07-16T10:00:00.000Z");
  const worker = createWorker(createDemoStore(clock), undefined, { now: () => currentTime });
  const event = {
    version: "2026-07-17",
    eventId: "evt_00000003",
    installationId: "install_00000001",
    type: "session.heartbeat",
    occurredAt: "2026-07-16T10:00:00.000Z",
  };
  const disabled = await worker.fetch(request("/v1/codex/events", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(event),
  }), {}, {});
  assert.equal(disabled.status, 503);

  const stale = await codexRelay(worker, event, { timestamp: String(currentTime - 300_001) });
  assert.equal(stale.status, 401);
  assert.match((await responseJson(stale)).error, /timestamp is stale/);

  const invalid = await codexRelay(worker, event, { signature: "sha256=" + "0".repeat(64) });
  assert.equal(invalid.status, 401);
  assert.match((await responseJson(invalid)).error, /signature is invalid/);

  const futureEvent = await codexRelay(worker, { ...event, eventId: "evt_00000004", occurredAt: "2026-07-16T10:05:01.000Z" });
  assert.equal(futureEvent.status, 400);
  assert.match((await responseJson(futureEvent)).error, /occurredAt must be recent/);
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
  const initialized = await mcp(worker, 1, "initialize", { protocolVersion: "2025-03-26", capabilities: {}, clientInfo: { name: "test", version: "1" } });
  assert.equal(initialized.protocolVersion, "2025-03-26");
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
  assert.deepEqual(schedule.inputSchema.required, ["idempotencyKey", "widgetCapability"]);
  assert.equal(schedule.inputSchema.properties.widgetCapability.minLength, 32);
  assert.equal(render._meta.ui.resourceUri, "ui://widget/offshift-worker-v5.html");
  assert.equal(render._meta["openai/outputTemplate"], "ui://widget/offshift-worker-v5.html");
  assert.equal(tools.some((tool) => /webhook|lock|command/i.test(tool.name)), false);
});

test("MCP resource read returns the React widget with a tightly scoped CSP", async () => {
  const worker = app();
  const { contents } = await mcp(worker, 3, "resources/read", { uri: "ui://widget/offshift-worker-v5.html" });
  assert.equal(contents.length, 1);
  assert.equal(contents[0].mimeType, "text/html;profile=mcp-app");
  assert.deepEqual(contents[0]._meta.ui.csp, {
    connectDomains: [],
    resourceDomains: ["https://offshift-demo-api.tixo-digital.workers.dev"],
  });
  assert.match(contents[0].text, /offshift\.js/);
  assert.match(contents[0].text, /rel="stylesheet" href="https:\/\/offshift-demo-api\.tixo-digital\.workers\.dev\/offshift\.css"/);
  assert.doesNotMatch(contents[0].text, /window\.openai/);
});

test("MCP resource read keeps the immediately preceding widget URI available for cached ChatGPT app descriptors", async () => {
  const worker = app();
  const { contents } = await mcp(worker, 4, "resources/read", { uri: "ui://widget/offshift-worker-v4.html" });

  assert.equal(contents.length, 1);
  assert.equal(contents[0].uri, "ui://widget/offshift-worker-v4.html");
  assert.equal(contents[0].mimeType, "text/html;profile=mcp-app");
  assert.match(contents[0].text, /offshift\.js/);
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

test("MCP mutations require a dashboard capability as well as an idempotency key", async () => {
  const worker = app();
  const dashboard = await renderDashboard(worker, 5);
  const capability = widgetCapability(dashboard);
  const params = {
    name: "schedule_break",
    arguments: { durationMinutes: 5, sceneId: "wind-down", idempotencyKey: "mcp-plan-0001", widgetCapability: capability },
  };
  const first = await mcp(worker, 6, "tools/call", params);
  const second = await mcp(worker, 7, "tools/call", params);
  assert.deepEqual(second.structuredContent.plan, first.structuredContent.plan);

  const missingCapability = await mcpError(worker, 8, "tools/call", {
    name: "schedule_break",
    arguments: { durationMinutes: 5, sceneId: "wind-down", idempotencyKey: "mcp-plan-0002" },
  });
  assert.equal(missingCapability.code, -32602);
  assert.match(missingCapability.message, /widgetCapability is required/);

  for (const [name, argumentsWithoutCapability] of [
    ["snooze_break", { minutes: 5, idempotencyKey: "missing-cap-snooze-0001" }],
    ["set_on_call_override", { minutes: 60, idempotencyKey: "missing-cap-on-call-0001" }],
    ["resume_reminders", { idempotencyKey: "missing-cap-resume-0001" }],
  ]) {
    const error = await mcpError(worker, 8, "tools/call", { name, arguments: argumentsWithoutCapability });
    assert.equal(error.code, -32602);
    assert.match(error.message, /widgetCapability is required/);
  }

  const missingKey = await mcpError(worker, 9, "tools/call", {
    name: "schedule_break",
    arguments: { durationMinutes: 5, sceneId: "wind-down", widgetCapability: capability },
  });
  assert.equal(missingKey.code, -32602);
  assert.match(missingKey.message, /idempotencyKey is required/);
});

test("MCP dashboard capabilities are opaque, short-lived, and isolate mutation state", async () => {
  let now = 0;
  let nextCapability = 1;
  const worker = createWorker(createDemoStore(clock), undefined, {
    now: () => now,
    createWidgetCapability: () => `test-widget-capability-${String(nextCapability++).padStart(40, "0")}`,
    widgetCapabilityTtlMs: 1_000,
  });
  const firstDashboard = await renderDashboard(worker, 10, "ada");
  const secondDashboard = await renderDashboard(worker, 11, "bea");
  const firstCapability = widgetCapability(firstDashboard);
  const secondCapability = widgetCapability(secondDashboard);
  assert.notEqual(firstCapability, secondCapability);

  const firstPlan = await mcp(worker, 12, "tools/call", {
    name: "schedule_break",
    arguments: { durationMinutes: 7, sceneId: "wind-down", idempotencyKey: "shared-key-0001", widgetCapability: firstCapability },
  });
  const secondPlan = await mcp(worker, 13, "tools/call", {
    name: "schedule_break",
    arguments: { durationMinutes: 9, sceneId: "wind-down", idempotencyKey: "shared-key-0001", widgetCapability: secondCapability },
  });
  assert.equal(firstPlan.structuredContent.plan.durationMinutes, 7);
  assert.equal(secondPlan.structuredContent.plan.durationMinutes, 9);
  assert.equal(widgetCapability(firstPlan), firstCapability);
  assert.equal(widgetCapability(secondPlan), secondCapability);

  const invalid = await mcpError(worker, 14, "tools/call", {
    name: "snooze_break",
    arguments: { minutes: 5, idempotencyKey: "invalid-cap-0001", widgetCapability: "x".repeat(64) },
  });
  assert.equal(invalid.code, -32602);
  assert.match(invalid.message, /invalid or expired/);

  now = 1_000;
  const expired = await mcpError(worker, 15, "tools/call", {
    name: "resume_reminders",
    arguments: { idempotencyKey: "expired-cap-0001", widgetCapability: firstCapability },
  });
  assert.equal(expired.code, -32602);
  assert.match(expired.message, /invalid or expired/);
});

test("MCP dashboard output fits the React widget and on-call remains bounded", async () => {
  const worker = app();
  const dashboard = await renderDashboard(worker, 16);
  const capability = widgetCapability(dashboard);
  assert.equal("activeAppCategory" in dashboard.structuredContent.snapshot, false);
  assert.doesNotMatch(JSON.stringify(dashboard.structuredContent), /activeAppCategory|"coding"/i);
  assert.equal(dashboard.structuredContent.plan.sceneId, "wind-down");
  assert.deepEqual(dashboard.structuredContent.allowedSceneIds, ["wind-down"]);

  const override = await mcp(worker, 10, "tools/call", {
    name: "set_on_call_override",
    arguments: { minutes: 60, idempotencyKey: "on-call-0001", widgetCapability: capability },
  });
  assert.equal(override.structuredContent.plan.status, "on-call");
  assert.match(override.content[0].text, /No remote action/);

  const resumed = await mcp(worker, 11, "tools/call", {
    name: "resume_reminders",
    arguments: { idempotencyKey: "resume-0001", widgetCapability: capability },
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
