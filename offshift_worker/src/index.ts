import { createDemoStore } from "./demo-store.js";
import { BREAK_ACTIONS, type BreakAction, type DemoStore, type WorkerHandler } from "./types.js";

const DEFAULT_USER_ID = "demo-user";
const MAX_USER_ID_LENGTH = 64;
const MIN_START_IN_MINUTES = 0;
const MAX_START_IN_MINUTES = 480;
const MIN_SNOOZE_MINUTES = 5;
const MAX_SNOOZE_MINUTES = 60;
const MCP_PROTOCOL_VERSION = "2026-01-26";
const MCP_SERVER_VERSION = "0.2.0";
const OFFSHIFT_WIDGET_URI = "ui://widget/offshift-worker-v1.html";

const DATA_TOOL_META = { ui: { visibility: ["model"] } };
const MUTATION_ANNOTATIONS = {
  readOnlyHint: false,
  destructiveHint: false,
  openWorldHint: false,
  idempotentHint: true,
};
const READ_ANNOTATIONS = {
  readOnlyHint: true,
  destructiveHint: false,
  openWorldHint: false,
  idempotentHint: true,
};

const OFFSHIFT_WIDGET_HTML = `<!doctype html>
<html lang="en">
  <head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Offshift</title></head>
  <body>
    <main aria-live="polite">
      <h1>Offshift</h1>
      <p id="summary">Loading the latest safe focus snapshot…</p>
      <p id="privacy">Offshift uses only aggregate local timing. It cannot read code, prompts, terminal output, or screen content.</p>
    </main>
    <script type="module">
      const summary = document.querySelector("#summary");
      let requestId = 0;
      const pending = new Map();
      const send = (message) => window.parent.postMessage(message, "*");
      const request = (method, params) => new Promise((resolve, reject) => {
        const id = ++requestId;
        pending.set(id, { resolve, reject });
        send({ jsonrpc: "2.0", id, method, params });
      });
      const render = (result) => {
        const data = result && result.structuredContent;
        const focus = data && data.focusSnapshot;
        const behavior = data && data.behaviorSnapshot;
        if (!focus || !behavior) return;
        summary.textContent = behavior.explanation + " Suggested break: " + focus.suggestedAction + ".";
      };
      window.addEventListener("message", (event) => {
        if (event.source !== window.parent) return;
        const message = event.data;
        if (!message || message.jsonrpc !== "2.0") return;
        if (typeof message.id === "number" && pending.has(message.id)) {
          const entry = pending.get(message.id);
          pending.delete(message.id);
          if (message.error) entry.reject(message.error); else entry.resolve(message.result);
          return;
        }
        if (message.method === "ui/notifications/tool-result") render(message.params);
      }, { passive: true });
      request("ui/initialize", { appInfo: { name: "offshift-worker", version: "${MCP_SERVER_VERSION}" }, appCapabilities: {}, protocolVersion: "${MCP_PROTOCOL_VERSION}" })
        .then(() => send({ jsonrpc: "2.0", method: "ui/notifications/initialized", params: {} }))
        .catch(() => { summary.textContent = "Offshift could not initialize the host bridge."; });
    </script>
  </body>
</html>`;

const MCP_TOOLS = [
  {
    name: "get_focus_snapshot",
    title: "Get focus snapshot",
    description: "Use this when the user asks about their current focus session or wants a safe, aggregate break suggestion.",
    inputSchema: optionalUserInputSchema(),
    outputSchema: { type: "object", required: ["snapshot"], properties: { snapshot: focusSnapshotSchema() } },
    annotations: READ_ANNOTATIONS,
    _meta: DATA_TOOL_META,
  },
  {
    name: "get_behavior_policy_snapshot",
    title: "Get explainable work-pattern policy and snapshot",
    description: "Use this when the user asks why Offshift would suggest a break or what privacy and local-action boundaries apply.",
    inputSchema: optionalUserInputSchema(),
    outputSchema: {
      type: "object",
      required: ["policy", "snapshot"],
      properties: { policy: { type: "object" }, snapshot: behaviorSnapshotSchema() },
    },
    annotations: READ_ANNOTATIONS,
    _meta: DATA_TOOL_META,
  },
  {
    name: "preview_break_plan",
    title: "Preview a break plan",
    description: "Use this when the user wants to review an allowlisted break without changing their schedule.",
    inputSchema: {
      type: "object",
      required: ["action"],
      additionalProperties: false,
      properties: { action: { type: "string", enum: BREAK_ACTIONS } },
    },
    outputSchema: { type: "object", required: ["plan"], properties: { plan: breakPlanSchema() } },
    annotations: READ_ANNOTATIONS,
    _meta: DATA_TOOL_META,
  },
  {
    name: "schedule_break",
    title: "Schedule a break",
    description: "Use this only when the user explicitly chooses an allowlisted break action and a bounded start time.",
    inputSchema: {
      type: "object",
      required: ["action", "startInMinutes", "idempotencyKey"],
      additionalProperties: false,
      properties: {
        action: { type: "string", enum: BREAK_ACTIONS },
        userId: { type: "string", minLength: 1, maxLength: MAX_USER_ID_LENGTH },
        startInMinutes: { type: "integer", minimum: MIN_START_IN_MINUTES, maximum: MAX_START_IN_MINUTES },
        idempotencyKey: { type: "string", minLength: 8, maxLength: 128 },
      },
    },
    outputSchema: { type: "object", required: ["plan"], properties: { plan: breakPlanSchema() } },
    annotations: MUTATION_ANNOTATIONS,
    _meta: DATA_TOOL_META,
  },
  {
    name: "snooze_break",
    title: "Snooze a break",
    description: "Use this only when the user explicitly postpones an existing Offshift break by 5–60 minutes.",
    inputSchema: {
      type: "object",
      required: ["planId", "minutes", "idempotencyKey"],
      additionalProperties: false,
      properties: {
        planId: { type: "string", pattern: "^break-\\d{4}$" },
        minutes: { type: "integer", minimum: MIN_SNOOZE_MINUTES, maximum: MAX_SNOOZE_MINUTES },
        idempotencyKey: { type: "string", minLength: 8, maxLength: 128 },
      },
    },
    outputSchema: { type: "object", required: ["plan"], properties: { plan: breakPlanSchema() } },
    annotations: MUTATION_ANNOTATIONS,
    _meta: DATA_TOOL_META,
  },
  {
    name: "render_offshift_dashboard",
    title: "Show Offshift dashboard",
    description: "Use this after reading the focus and behavior state to render the Offshift dashboard.",
    inputSchema: optionalUserInputSchema(),
    outputSchema: {
      type: "object",
      required: ["focusSnapshot", "behaviorSnapshot", "suggestedPlan"],
      properties: {
        focusSnapshot: focusSnapshotSchema(),
        behaviorSnapshot: behaviorSnapshotSchema(),
        suggestedPlan: breakPlanSchema(),
      },
    },
    annotations: READ_ANNOTATIONS,
    _meta: {
      ui: { resourceUri: OFFSHIFT_WIDGET_URI, visibility: ["model"] },
      "openai/outputTemplate": OFFSHIFT_WIDGET_URI,
      "openai/toolInvocation/invoking": "Preparing the Offshift dashboard…",
      "openai/toolInvocation/invoked": "Offshift dashboard ready.",
    },
  },
] as const;

export function createWorker(store: DemoStore = createDemoStore()): WorkerHandler {
  return {
    async fetch(request): Promise<Response> {
      if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders() });

      try {
        return await route(request, store);
      } catch (error) {
        if (error instanceof ApiError) return json({ error: error.message }, error.status);
        return json({ error: "Internal server error" }, 500);
      }
    },
  };
}

const worker = createWorker();
export default worker;

async function route(request: Request, store: DemoStore): Promise<Response> {
  const url = new URL(request.url);

  if (request.method === "GET" && url.pathname === "/health") {
    return json({ status: "ok", service: "offshift-demo-api", mcpPath: "/mcp", widgetUri: OFFSHIFT_WIDGET_URI });
  }

  if (url.pathname === "/mcp") {
    if (request.method !== "POST") throw new ApiError(405, "MCP requests must use POST");
    return handleMcpRequest(request, store);
  }

  if (request.method === "GET" && url.pathname === "/v1/focus/snapshot") {
    return json(store.getFocusSnapshot(readUserId(url.searchParams.get("userId"))));
  }

  if (request.method === "GET" && url.pathname === "/v1/behavior/policy") {
    return json(store.getBehaviorPolicy());
  }

  if (request.method === "GET" && url.pathname === "/v1/behavior/snapshot") {
    return json(store.getBehaviorSnapshot(readUserId(url.searchParams.get("userId"))));
  }

  if (request.method === "POST" && url.pathname === "/v1/breaks/preview") {
    const body = await readJson(request);
    return json(store.preview(readAction(body.action)));
  }

  if (request.method === "POST" && url.pathname === "/v1/breaks/schedule") {
    const body = await readJson(request);
    const startInMinutes = readBoundedInteger(body.startInMinutes, "startInMinutes", MIN_START_IN_MINUTES, MAX_START_IN_MINUTES);
    const idempotencyKey = readIdempotencyKey(body.idempotencyKey, false);
    const plan = store.schedule({ action: readAction(body.action), userId: readUserId(body.userId), startInMinutes }, idempotencyKey && `schedule:${idempotencyKey}`);
    return json(plan, 201);
  }

  const snoozeMatch = /^\/v1\/breaks\/(break-\d{4})\/snooze$/.exec(url.pathname);
  if (request.method === "POST" && snoozeMatch) {
    const body = await readJson(request);
    const minutes = readBoundedInteger(body.minutes, "minutes", MIN_SNOOZE_MINUTES, MAX_SNOOZE_MINUTES);
    const idempotencyKey = readIdempotencyKey(body.idempotencyKey, false);
    const plan = store.snooze(snoozeMatch[1], minutes, idempotencyKey && `snooze:${idempotencyKey}`);
    if (!plan) throw new ApiError(409, "Break cannot be snoozed; it is missing or reached the snooze limit");
    return json(plan);
  }

  throw new ApiError(404, "Route not found");
}

async function handleMcpRequest(request: Request, store: DemoStore): Promise<Response> {
  const message = await readJson(request);
  if (message.jsonrpc !== "2.0" || typeof message.method !== "string") {
    return mcpError(null, -32600, "Invalid JSON-RPC request");
  }

  const id = isMcpId(message.id) ? message.id : null;
  if (message.method === "notifications/initialized") return new Response(null, { status: 202, headers: corsHeaders() });

  try {
    const result = handleMcpMethod(message.method, recordOrEmpty(message.params), store);
    return mcpResult(id, result);
  } catch (error) {
    if (error instanceof ApiError) return mcpError(id, -32602, error.message);
    if (error instanceof McpMethodError) return mcpError(id, error.code, error.message);
    return mcpError(id, -32603, "Internal MCP error");
  }
}

function handleMcpMethod(method: string, params: Record<string, unknown>, store: DemoStore): unknown {
  if (method === "initialize") {
    return {
      protocolVersion: MCP_PROTOCOL_VERSION,
      capabilities: { tools: { listChanged: false }, resources: { listChanged: false } },
      serverInfo: { name: "offshift-worker", version: MCP_SERVER_VERSION },
      instructions: "Offshift provides safe focus and break planning. Use only aggregate local timing; never infer health, read content, or request remote device actions. Schedule and snooze only after explicit user intent.",
    };
  }
  if (method === "ping") return {};
  if (method === "tools/list") return { tools: MCP_TOOLS };
  if (method === "resources/list") {
    return {
      resources: [{ uri: OFFSHIFT_WIDGET_URI, name: "Offshift dashboard", mimeType: "text/html;profile=mcp-app", description: "A compact bridge-first Offshift summary resource." }],
    };
  }
  if (method === "resources/read") {
    if (params.uri !== OFFSHIFT_WIDGET_URI) throw new ApiError(404, "Offshift widget resource not found");
    return {
      contents: [{
        uri: OFFSHIFT_WIDGET_URI,
        mimeType: "text/html;profile=mcp-app",
        text: OFFSHIFT_WIDGET_HTML,
        _meta: {
          ui: {
            prefersBorder: true,
            csp: { connectDomains: [], resourceDomains: [] },
          },
          "openai/widgetDescription": "A safe Offshift focus summary. It has no controls for devices, locks, webhooks, or external commands.",
        },
      }],
    };
  }
  if (method === "tools/call") return callMcpTool(params, store);
  throw new McpMethodError(-32601, `MCP method not found: ${method}`);
}

function callMcpTool(params: Record<string, unknown>, store: DemoStore): unknown {
  if (typeof params.name !== "string") throw new ApiError(400, "MCP tool name must be a string");
  const args = recordOrEmpty(params.arguments);

  if (params.name === "get_focus_snapshot") {
    const snapshot = modelSafeFocusSnapshot(store.getFocusSnapshot(readUserId(args.userId)));
    return toolResult({ snapshot }, "Here is the aggregate focus snapshot. It does not contain app, screen, or source-code content.");
  }
  if (params.name === "get_behavior_policy_snapshot") {
    const userId = readUserId(args.userId);
    return toolResult(
      { policy: store.getBehaviorPolicy(), snapshot: store.getBehaviorSnapshot(userId) },
      "Here is the explainable shadow-mode policy and its aggregate work-pattern snapshot.",
    );
  }
  if (params.name === "preview_break_plan") {
    const plan = store.preview(readAction(args.action));
    return toolResult({ plan }, `Previewing the allowlisted ${plan.action} break. No schedule changed.`);
  }
  if (params.name === "schedule_break") {
    const plan = store.schedule({
      action: readAction(args.action),
      userId: readUserId(args.userId),
      startInMinutes: readBoundedInteger(args.startInMinutes, "startInMinutes", MIN_START_IN_MINUTES, MAX_START_IN_MINUTES),
    }, `schedule:${readIdempotencyKey(args.idempotencyKey, true)}`);
    return toolResult({ plan }, `Scheduled the allowlisted ${plan.action} break. No device action is sent from this Worker.`);
  }
  if (params.name === "snooze_break") {
    const planId = readPlanId(args.planId);
    const plan = store.snooze(
      planId,
      readBoundedInteger(args.minutes, "minutes", MIN_SNOOZE_MINUTES, MAX_SNOOZE_MINUTES),
      `snooze:${readIdempotencyKey(args.idempotencyKey, true)}`,
    );
    if (!plan) throw new ApiError(409, "Break cannot be snoozed; it is missing or reached the snooze limit");
    return toolResult({ plan }, `Snoozed the break for a bounded interval. No remote action was taken.`);
  }
  if (params.name === "render_offshift_dashboard") {
    const userId = readUserId(args.userId);
    const focusSnapshot = modelSafeFocusSnapshot(store.getFocusSnapshot(userId));
    const behaviorSnapshot = store.getBehaviorSnapshot(userId);
    const suggestedPlan = store.preview(focusSnapshot.suggestedAction);
    return toolResult({ focusSnapshot, behaviorSnapshot, suggestedPlan }, "Showing the Offshift dashboard with its local-only safety boundary.");
  }
  throw new McpMethodError(-32602, `Unknown Offshift tool: ${params.name}`);
}

function toolResult(structuredContent: unknown, text: string): Record<string, unknown> {
  return { structuredContent, content: [{ type: "text", text }] };
}

function modelSafeFocusSnapshot(snapshot: ReturnType<DemoStore["getFocusSnapshot"]>) {
  return {
    userId: snapshot.userId,
    activeMinutes: snapshot.activeMinutes,
    suggestedAction: snapshot.suggestedAction,
    generatedAt: snapshot.generatedAt,
    privacyNote: "Aggregate demo timing only. Offshift does not inspect source code, prompts, terminal output, filenames, or screen content.",
  };
}

async function readJson(request: Request): Promise<Record<string, unknown>> {
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.includes("application/json")) throw new ApiError(415, "Content-Type must be application/json");
  try {
    const value: unknown = await request.json();
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new ApiError(400, "JSON body must be an object");
    return value as Record<string, unknown>;
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(400, "Invalid JSON body");
  }
}

function readAction(value: unknown): BreakAction {
  if (typeof value === "string" && (BREAK_ACTIONS as readonly string[]).includes(value)) return value as BreakAction;
  throw new ApiError(400, `action must be one of: ${BREAK_ACTIONS.join(", ")}`);
}

function readUserId(value: unknown): string {
  if (value === undefined || value === null) return DEFAULT_USER_ID;
  if (typeof value !== "string") throw new ApiError(400, "userId must be a string");
  const userId = value.trim();
  if (!userId || userId.length > MAX_USER_ID_LENGTH) throw new ApiError(400, `userId must be 1-${MAX_USER_ID_LENGTH} characters`);
  return userId;
}

function readPlanId(value: unknown): string {
  if (typeof value === "string" && /^break-\d{4}$/.test(value)) return value;
  throw new ApiError(400, "planId must be a valid Offshift break id");
}

function readIdempotencyKey(value: unknown, required: boolean): string | undefined {
  if (value === undefined || value === null) {
    if (!required) return undefined;
    throw new ApiError(400, "idempotencyKey is required");
  }
  if (typeof value !== "string" || value.length < 8 || value.length > 128) {
    throw new ApiError(400, "idempotencyKey must be 8-128 characters");
  }
  return value;
}

function readBoundedInteger(value: unknown, name: string, minimum: number, maximum: number): number {
  if (!Number.isInteger(value) || (value as number) < minimum || (value as number) > maximum) {
    throw new ApiError(400, `${name} must be an integer from ${minimum} to ${maximum}`);
  }
  return value as number;
}

function optionalUserInputSchema(): Record<string, unknown> {
  return {
    type: "object",
    additionalProperties: false,
    properties: { userId: { type: "string", minLength: 1, maxLength: MAX_USER_ID_LENGTH } },
  };
}

function focusSnapshotSchema(): Record<string, unknown> {
  return {
    type: "object",
    required: ["userId", "activeMinutes", "suggestedAction", "generatedAt", "privacyNote"],
    properties: {
      userId: { type: "string" }, activeMinutes: { type: "integer" }, suggestedAction: { type: "string", enum: BREAK_ACTIONS },
      generatedAt: { type: "string", format: "date-time" }, privacyNote: { type: "string" },
    },
  };
}

function behaviorSnapshotSchema(): Record<string, unknown> {
  return {
    type: "object",
    required: ["userId", "band", "mode", "activeMinutes", "contributingCategories", "explanation", "canTriggerRemoteAction", "generatedAt"],
    properties: {
      userId: { type: "string" }, band: { type: "string", enum: ["routine", "drift", "protect"] }, mode: { const: "shadow" },
      activeMinutes: { type: "integer" }, contributingCategories: { type: "array", items: { type: "string" } }, explanation: { type: "string" },
      canTriggerRemoteAction: { const: false }, generatedAt: { type: "string", format: "date-time" },
    },
  };
}

function breakPlanSchema(): Record<string, unknown> {
  return {
    type: "object",
    required: ["action", "durationMinutes", "title", "steps"],
    properties: {
      id: { type: "string" }, userId: { type: "string" }, status: { type: "string", enum: ["scheduled", "snoozed"] },
      action: { type: "string", enum: BREAK_ACTIONS }, durationMinutes: { type: "integer" }, title: { type: "string" },
      steps: { type: "array", items: { type: "string" } }, startAt: { type: "string", format: "date-time" }, createdAt: { type: "string", format: "date-time" }, snoozeCount: { type: "integer" },
    },
  };
}

function recordOrEmpty(value: unknown): Record<string, unknown> {
  if (value === undefined || value === null) return {};
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new ApiError(400, "MCP params must be an object");
  return value as Record<string, unknown>;
}

function isMcpId(value: unknown): value is string | number | null {
  return value === null || typeof value === "string" || typeof value === "number";
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", ...corsHeaders() },
  });
}

function mcpResult(id: string | number | null, result: unknown): Response {
  return json({ jsonrpc: "2.0", id, result });
}

function mcpError(id: string | number | null, code: number, message: string): Response {
  return json({ jsonrpc: "2.0", id, error: { code, message } });
}

function corsHeaders(): Record<string, string> {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET, POST, OPTIONS",
    "access-control-allow-headers": "content-type, mcp-protocol-version, mcp-session-id",
    "access-control-expose-headers": "mcp-session-id",
  };
}

class ApiError extends Error {
  constructor(readonly status: number, message: string) { super(message); }
}

class McpMethodError extends Error {
  constructor(readonly code: number, message: string) { super(message); }
}
