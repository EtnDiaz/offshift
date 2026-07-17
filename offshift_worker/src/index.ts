import { createDemoStore } from "./demo-store.js";
import { BREAK_ACTIONS, type BreakAction, type DemoStore, type WorkerHandler } from "./types.js";

const DEFAULT_USER_ID = "demo-user";
const MAX_USER_ID_LENGTH = 64;
const MIN_START_IN_MINUTES = 0;
const MAX_START_IN_MINUTES = 480;
const MIN_SNOOZE_MINUTES = 5;
const MAX_SNOOZE_MINUTES = 60;
const MIN_BREAK_DURATION_MINUTES = 1;
const MAX_BREAK_DURATION_MINUTES = 30;
const MCP_PROTOCOL_VERSION = "2026-01-26";
const MCP_SERVER_VERSION = "0.5.0";
const OFFSHIFT_WIDGET_URI = "ui://widget/offshift-worker-v4.html";
const WIDGET_ASSET_ORIGIN = "https://offshift-demo-api.tixo-digital.workers.dev";
const ALLOWED_SCENE_ID = "wind-down";
const DASHBOARD_NOW = new Date("2026-07-16T10:00:00.000Z");
const WIDGET_CAPABILITY_TTL_MS = 5 * 60_000;
const WIDGET_CAPABILITY_META_KEY = "offshift/widgetCapability";
const CODEX_EVENT_TTL_MS = 5 * 60_000;
const CODEX_SYNC_STALE_AFTER_MS = 15 * 60_000;
const CODEX_EVENT_VERSION = "2026-07-17";
const CODEX_RELAY_PATH = "/v1/codex/events";

const DATA_TOOL_META = { ui: { visibility: ["model"] } };
const INTERACTIVE_TOOL_META = { ui: { visibility: ["app"] } };
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

interface AssetBinding {
  fetch(request: Request): Promise<Response>;
}

interface WorkerEnvironment {
  ASSETS?: AssetBinding;
  CODEX_RELAY_SECRET?: string;
}

type CodexEventType = "session.started" | "session.heartbeat" | "session.ended";

interface CodexSyncEvent {
  version: typeof CODEX_EVENT_VERSION;
  eventId: string;
  installationId: string;
  type: CodexEventType;
  occurredAt: string;
}

interface CodexSyncStatus {
  state: "not-connected" | "active" | "stale";
  lastEventAt: string | null;
  sessionActive: boolean;
  privacyNote: string;
}

interface CodexRelayState {
  seenEventIds: Map<string, number>;
  statusByInstallation: Map<string, CodexSyncStatus>;
}

interface DashboardPlan {
  id: string;
  status: "suggested" | "scheduled" | "snoozed" | "on-call";
  durationMinutes: number;
  sceneId: typeof ALLOWED_SCENE_ID;
  startsAt: string;
  endsAt: string;
  message: string;
}

interface DashboardState {
  currentPlan: DashboardPlan | null;
  idempotencyResults: Map<string, DashboardPlan>;
  nextPlanNumber: number;
}

interface DashboardSession {
  capability: string;
  expiresAt: number;
  userId: string;
  state: DashboardState;
}

interface WorkerOptions {
  now?: () => number;
  createWidgetCapability?: () => string;
  widgetCapabilityTtlMs?: number;
}

interface WorkerDependencies {
  now: () => number;
  createWidgetCapability: () => string;
  widgetCapabilityTtlMs: number;
}

function widgetHtml(assetOrigin: string): string {
  return `<!doctype html><html><head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" /></head><body><div id="offshift-root"></div><script type="module" src="${assetOrigin}/offshift.js"></script></body></html>`;
}

const MCP_TOOLS = [
  {
    name: "get_focus_snapshot",
    title: "Get focus snapshot",
    description: "Use this when the user asks about their current focus session or wants a safe, aggregate break suggestion.",
    inputSchema: optionalUserInputSchema(),
    outputSchema: { type: "object", required: ["snapshot"], properties: { snapshot: dashboardSnapshotSchema() } },
    annotations: READ_ANNOTATIONS,
    _meta: DATA_TOOL_META,
  },
  {
    name: "get_work_pattern_snapshot",
    title: "Get explainable work-pattern snapshot",
    description: "Use this when the user asks why Offshift suggested a break or whether a local protection rule is eligible. It returns only explainable aggregate timing, never app categories, code, or screen content.",
    inputSchema: optionalUserInputSchema(),
    outputSchema: {
      type: "object",
      required: ["behaviour"],
      properties: { behaviour: dashboardBehaviourSchema() },
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
      required: [],
      additionalProperties: false,
      properties: {
        durationMinutes: { type: "integer", minimum: MIN_BREAK_DURATION_MINUTES, maximum: MAX_BREAK_DURATION_MINUTES },
        sceneId: { type: "string", enum: [ALLOWED_SCENE_ID] },
      },
    },
    outputSchema: dashboardOutputSchema(),
    annotations: READ_ANNOTATIONS,
    _meta: DATA_TOOL_META,
  },
  {
    name: "schedule_break",
    title: "Schedule a break",
    description: "Use this only when the user explicitly chooses a 1–30 minute Offshift break and the allowlisted wind-down scene.",
    inputSchema: {
      type: "object",
      required: ["idempotencyKey", "widgetCapability"],
      additionalProperties: false,
      properties: {
        durationMinutes: { type: "integer", minimum: MIN_BREAK_DURATION_MINUTES, maximum: MAX_BREAK_DURATION_MINUTES },
        sceneId: { type: "string", enum: [ALLOWED_SCENE_ID] },
        idempotencyKey: { type: "string", minLength: 8, maxLength: 128 },
        widgetCapability: widgetCapabilitySchema(),
      },
    },
    outputSchema: dashboardOutputSchema(),
    annotations: MUTATION_ANNOTATIONS,
    _meta: INTERACTIVE_TOOL_META,
  },
  {
    name: "resume_reminders",
    title: "Resume reminders",
    description: "Use this only when the user explicitly ends their on-call override and resumes normal Offshift reminders.",
    inputSchema: {
      type: "object",
      required: ["idempotencyKey", "widgetCapability"],
      additionalProperties: false,
      properties: {
        idempotencyKey: { type: "string", minLength: 8, maxLength: 128 },
        widgetCapability: widgetCapabilitySchema(),
      },
    },
    outputSchema: dashboardOutputSchema(),
    annotations: MUTATION_ANNOTATIONS,
    _meta: INTERACTIVE_TOOL_META,
  },
  {
    name: "snooze_break",
    title: "Snooze a break",
    description: "Use this only when the user explicitly postpones their current Offshift break by 5–15 minutes.",
    inputSchema: {
      type: "object",
      required: ["minutes", "idempotencyKey", "widgetCapability"],
      additionalProperties: false,
      properties: {
        minutes: { type: "integer", minimum: MIN_SNOOZE_MINUTES, maximum: 15 },
        idempotencyKey: { type: "string", minLength: 8, maxLength: 128 },
        widgetCapability: widgetCapabilitySchema(),
      },
    },
    outputSchema: dashboardOutputSchema(),
    annotations: MUTATION_ANNOTATIONS,
    _meta: INTERACTIVE_TOOL_META,
  },
  {
    name: "set_on_call_override",
    title: "Set an on-call override",
    description: "Use this when the user explicitly needs a bounded 15–120 minute on-call period before Offshift resumes its normal reminder cadence.",
    inputSchema: {
      type: "object",
      required: ["idempotencyKey", "widgetCapability"],
      additionalProperties: false,
      properties: {
        minutes: { type: "integer", minimum: 15, maximum: 120 },
        idempotencyKey: { type: "string", minLength: 8, maxLength: 128 },
        widgetCapability: widgetCapabilitySchema(),
      },
    },
    outputSchema: dashboardOutputSchema(),
    annotations: MUTATION_ANNOTATIONS,
    _meta: INTERACTIVE_TOOL_META,
  },
  {
    name: "render_offshift_dashboard",
    title: "Show Offshift dashboard",
    description: "Use this after reading the focus and behavior state to render the Offshift dashboard.",
    inputSchema: optionalUserInputSchema(),
    outputSchema: {
      type: "object",
      required: ["snapshot", "behaviour", "plan", "allowedSceneIds"],
      properties: {
        snapshot: dashboardSnapshotSchema(),
        behaviour: dashboardBehaviourSchema(),
        plan: dashboardPlanSchema(),
        allowedSceneIds: { type: "array", items: { type: "string", enum: [ALLOWED_SCENE_ID] } },
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

export function createWorker(
  store: DemoStore = createDemoStore(),
  widgetAssetOrigin = WIDGET_ASSET_ORIGIN,
  options: WorkerOptions = {},
): WorkerHandler {
  const dashboardSessions = new Map<string, DashboardSession>();
  const codexRelayState: CodexRelayState = {
    seenEventIds: new Map(),
    statusByInstallation: new Map(),
  };
  const dependencies: WorkerDependencies = {
    now: options.now ?? Date.now,
    createWidgetCapability: options.createWidgetCapability ?? createOpaqueWidgetCapability,
    widgetCapabilityTtlMs: options.widgetCapabilityTtlMs ?? WIDGET_CAPABILITY_TTL_MS,
  };
  return {
    async fetch(request, env): Promise<Response> {
      if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders() });

      try {
        return await route(request, store, dashboardSessions, codexRelayState, widgetAssetOrigin, dependencies, env as WorkerEnvironment);
      } catch (error) {
        if (error instanceof ApiError) return json({ error: error.message }, error.status);
        return json({ error: "Internal server error" }, 500);
      }
    },
  };
}

const worker = createWorker();
export default worker;

async function route(
  request: Request,
  store: DemoStore,
  dashboardSessions: Map<string, DashboardSession>,
  codexRelayState: CodexRelayState,
  widgetAssetOrigin: string,
  dependencies: WorkerDependencies,
  env: WorkerEnvironment,
): Promise<Response> {
  const url = new URL(request.url);

  if (request.method === "GET" && /^\/offshift\.(js|css)$/.test(url.pathname) && env.ASSETS) {
    return assetResponse(await env.ASSETS.fetch(request));
  }

  if (request.method === "GET" && url.pathname === "/health") {
    return json({ status: "ok", service: "offshift-demo-api", mcpPath: "/mcp", widgetUri: OFFSHIFT_WIDGET_URI, codexRelayPath: CODEX_RELAY_PATH });
  }

  if (url.pathname === CODEX_RELAY_PATH) {
    if (request.method !== "POST") throw new ApiError(405, "Codex relay events must use POST");
    return handleCodexRelayEvent(request, env.CODEX_RELAY_SECRET, codexRelayState, dependencies.now);
  }

  if (url.pathname === "/mcp") {
    if (request.method !== "POST") throw new ApiError(405, "MCP requests must use POST");
    return handleMcpRequest(request, store, dashboardSessions, widgetAssetOrigin, dependencies);
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

async function handleMcpRequest(
  request: Request,
  store: DemoStore,
  dashboardSessions: Map<string, DashboardSession>,
  widgetAssetOrigin: string,
  dependencies: WorkerDependencies,
): Promise<Response> {
  const message = await readJson(request);
  if (message.jsonrpc !== "2.0" || typeof message.method !== "string") {
    return mcpError(null, -32600, "Invalid JSON-RPC request");
  }

  const id = isMcpId(message.id) ? message.id : null;
  if (message.method === "notifications/initialized") return new Response(null, { status: 202, headers: corsHeaders() });

  try {
    const result = handleMcpMethod(message.method, recordOrEmpty(message.params), store, dashboardSessions, widgetAssetOrigin, dependencies);
    return mcpResult(id, result);
  } catch (error) {
    if (error instanceof ApiError) return mcpError(id, -32602, error.message);
    if (error instanceof McpMethodError) return mcpError(id, error.code, error.message);
    return mcpError(id, -32603, "Internal MCP error");
  }
}

function handleMcpMethod(
  method: string,
  params: Record<string, unknown>,
  store: DemoStore,
  dashboardSessions: Map<string, DashboardSession>,
  widgetAssetOrigin: string,
  dependencies: WorkerDependencies,
): unknown {
  if (method === "initialize") {
    // MCP clients validate the server-selected version during the initial
    // handshake. This stateless server supports the client's offered version;
    // returning a hard-coded newer version makes otherwise compatible clients
    // reject the connection before they can discover tools.
    const protocolVersion = typeof params.protocolVersion === "string" && params.protocolVersion.length > 0
      ? params.protocolVersion
      : MCP_PROTOCOL_VERSION;
    return {
      protocolVersion,
      capabilities: { tools: { listChanged: false }, resources: { listChanged: false } },
      serverInfo: { name: "offshift-worker", version: MCP_SERVER_VERSION },
      instructions: "Offshift provides safe focus and break planning. Use only aggregate local timing; never infer health, read content, or request remote device actions. The model may explain or preview a plan; only an explicit dashboard click can schedule, snooze, set an on-call override, or resume reminders. The Worker cannot lock a device or run a smart-home scene.",
    };
  }
  if (method === "ping") return {};
  if (method === "tools/list") return { tools: MCP_TOOLS };
  if (method === "resources/list") {
    return {
      resources: [{ uri: OFFSHIFT_WIDGET_URI, name: "Offshift dashboard", mimeType: "text/html;profile=mcp-app", description: "The Offshift React dashboard, connected through the MCP Apps bridge." }],
    };
  }
  if (method === "resources/read") {
    if (params.uri !== OFFSHIFT_WIDGET_URI) throw new ApiError(404, "Offshift widget resource not found");
    return {
      contents: [{
        uri: OFFSHIFT_WIDGET_URI,
        mimeType: "text/html;profile=mcp-app",
        text: widgetHtml(widgetAssetOrigin),
        _meta: {
          ui: {
            prefersBorder: true,
            csp: { connectDomains: [], resourceDomains: [widgetAssetOrigin] },
          },
          "openai/widgetDescription": "A safe Offshift dashboard. Its buttons prepare a reset, snooze, set a bounded on-call override, or resume reminders only; it has no controls for devices, locks, webhooks, or external commands.",
        },
      }],
    };
  }
  if (method === "tools/call") return callMcpTool(params, store, dashboardSessions, dependencies);
  throw new McpMethodError(-32601, `MCP method not found: ${method}`);
}

function callMcpTool(
  params: Record<string, unknown>,
  store: DemoStore,
  dashboardSessions: Map<string, DashboardSession>,
  dependencies: WorkerDependencies,
): unknown {
  if (typeof params.name !== "string") throw new ApiError(400, "MCP tool name must be a string");
  const args = recordOrEmpty(params.arguments);

  if (params.name === "get_focus_snapshot") {
    const snapshot = dashboardData(store, readUserId(args.userId), previewDashboardPlan(5, ALLOWED_SCENE_ID)).snapshot;
    return toolResult({ snapshot }, "Here is the aggregate focus snapshot. It does not contain app, screen, or source-code content.");
  }
  if (params.name === "get_work_pattern_snapshot") {
    const behaviour = dashboardData(store, readUserId(args.userId), previewDashboardPlan(5, ALLOWED_SCENE_ID)).behaviour;
    return toolResult({ behaviour }, "Here is the explainable shadow-mode work-pattern snapshot. The Worker cannot perform a remote action.");
  }
  if (params.name === "preview_break_plan") {
    const plan = previewDashboardPlan(readDuration(args.durationMinutes), readSceneId(args.sceneId));
    return dashboardToolResult(store, readUserId(args.userId), plan, "Previewing the allowlisted wind-down plan. No schedule changed.");
  }
  if (params.name === "schedule_break") {
    const session = requireDashboardSession(args.widgetCapability, dashboardSessions, dependencies.now);
    const key = `schedule:${readIdempotencyKey(args.idempotencyKey, true)}`;
    const previous = session.state.idempotencyResults.get(key);
    const plan = previous ?? scheduledDashboardPlan(session.state, readDuration(args.durationMinutes), readSceneId(args.sceneId));
    session.state.idempotencyResults.set(key, plan);
    return dashboardToolResult(store, session.userId, plan, "A five-minute reset is prepared. Open the local companion to choose any local reminder, scene, or lock action.", session.capability);
  }
  if (params.name === "snooze_break") {
    const session = requireDashboardSession(args.widgetCapability, dashboardSessions, dependencies.now);
    const key = `snooze:${readIdempotencyKey(args.idempotencyKey, true)}`;
    const previous = session.state.idempotencyResults.get(key);
    const plan = previous ?? snoozedDashboardPlan(session.state, readBoundedInteger(args.minutes, "minutes", MIN_SNOOZE_MINUTES, 15));
    session.state.idempotencyResults.set(key, plan);
    return dashboardToolResult(store, session.userId, plan, "Break reminder snoozed for a bounded interval. No remote action was taken.", session.capability);
  }
  if (params.name === "set_on_call_override") {
    const session = requireDashboardSession(args.widgetCapability, dashboardSessions, dependencies.now);
    const key = `on-call:${readIdempotencyKey(args.idempotencyKey, true)}`;
    const previous = session.state.idempotencyResults.get(key);
    const plan = previous ?? onCallDashboardPlan(session.state, readBoundedInteger(args.minutes, "minutes", 15, 120));
    session.state.idempotencyResults.set(key, plan);
    return dashboardToolResult(store, session.userId, plan, "On-call override is active for a bounded period. No remote action was taken.", session.capability);
  }
  if (params.name === "resume_reminders") {
    const session = requireDashboardSession(args.widgetCapability, dashboardSessions, dependencies.now);
    const key = `resume:${readIdempotencyKey(args.idempotencyKey, true)}`;
    const previous = session.state.idempotencyResults.get(key);
    const plan = previous ?? resumedDashboardPlan(session.state);
    session.state.idempotencyResults.set(key, plan);
    return dashboardToolResult(store, session.userId, plan, "Reminders are back on. No remote action was taken.", session.capability);
  }
  if (params.name === "render_offshift_dashboard") {
    const session = mintDashboardSession(dashboardSessions, readUserId(args.userId), dependencies);
    return dashboardToolResult(store, session.userId, previewDashboardPlan(5, ALLOWED_SCENE_ID), "Showing the Offshift dashboard with its local-only safety boundary.", session.capability);
  }
  throw new McpMethodError(-32602, `Unknown Offshift tool: ${params.name}`);
}

function toolResult(structuredContent: unknown, text: string, meta?: Record<string, unknown>): Record<string, unknown> {
  return { structuredContent, content: [{ type: "text", text }], ...(meta ? { _meta: meta } : {}) };
}

function dashboardToolResult(store: DemoStore, userId: string, plan: DashboardPlan, text: string, widgetCapability?: string): Record<string, unknown> {
  return toolResult(
    dashboardData(store, userId, plan),
    text,
    widgetCapability ? { [WIDGET_CAPABILITY_META_KEY]: widgetCapability } : undefined,
  );
}

function dashboardData(store: DemoStore, userId: string, plan: DashboardPlan) {
  const focus = store.getFocusSnapshot(userId);
  const behavior = store.getBehaviorSnapshot(userId);
  return {
    snapshot: {
      focusMinutes: focus.activeMinutes,
      thresholdMinutes: 50,
      suggestedBreakMinutes: 5,
      privacyNote: "Demo data only. Offshift does not inspect source code, prompts, terminal output, filenames, or screen content.",
    },
    behaviour: {
      level: behavior.band,
      reasons: behavior.contributingCategories,
      shadowMode: true,
      lockScreenRule: "not-configured",
    },
    plan,
    allowedSceneIds: [ALLOWED_SCENE_ID],
  };
}

function dashboardPlan(status: DashboardPlan["status"], durationMinutes: number, startsAt: Date, id = "preview"): DashboardPlan {
  return {
    id,
    status,
    durationMinutes,
    sceneId: ALLOWED_SCENE_ID,
    startsAt: startsAt.toISOString(),
    endsAt: new Date(startsAt.getTime() + durationMinutes * 60_000).toISOString(),
    message: status === "snoozed"
      ? "Your break was deliberately postponed. Offshift will ask again at the new time."
      : status === "on-call"
        ? "On-call override is active for this bounded period. Offshift will return to its usual reminders afterwards."
        : "Your break is ready when you are. The local companion will require a direct confirmation before any scene runs.",
  };
}

function previewDashboardPlan(durationMinutes: number, sceneId: string): DashboardPlan {
  if (sceneId !== ALLOWED_SCENE_ID) throw new ApiError(400, "sceneId must be the allowlisted wind-down scene");
  return dashboardPlan("suggested", durationMinutes, DASHBOARD_NOW);
}

function scheduledDashboardPlan(state: DashboardState, durationMinutes: number, sceneId: string): DashboardPlan {
  const plan = { ...previewDashboardPlan(durationMinutes, sceneId), id: `break-${state.nextPlanNumber++}`, status: "scheduled" as const };
  state.currentPlan = plan;
  return plan;
}

function snoozedDashboardPlan(state: DashboardState, minutes: number): DashboardPlan {
  const current = state.currentPlan ?? previewDashboardPlan(5, ALLOWED_SCENE_ID);
  const plan = dashboardPlan("snoozed", current.durationMinutes, new Date(DASHBOARD_NOW.getTime() + minutes * 60_000), current.id);
  state.currentPlan = plan;
  return plan;
}

function onCallDashboardPlan(state: DashboardState, minutes: number): DashboardPlan {
  const current = state.currentPlan ?? previewDashboardPlan(5, ALLOWED_SCENE_ID);
  const plan = dashboardPlan("on-call", current.durationMinutes, new Date(DASHBOARD_NOW.getTime() + minutes * 60_000), current.id);
  state.currentPlan = plan;
  return plan;
}

function resumedDashboardPlan(state: DashboardState): DashboardPlan {
  const current = state.currentPlan ?? previewDashboardPlan(5, ALLOWED_SCENE_ID);
  const plan = dashboardPlan("suggested", current.durationMinutes, DASHBOARD_NOW, current.id);
  state.currentPlan = plan;
  return plan;
}

function mintDashboardSession(
  sessions: Map<string, DashboardSession>,
  userId: string,
  dependencies: WorkerDependencies,
): DashboardSession {
  const now = dependencies.now();
  for (const [capability, session] of sessions) {
    if (session.expiresAt <= now) sessions.delete(capability);
  }

  const capability = dependencies.createWidgetCapability();
  const session: DashboardSession = {
    capability,
    expiresAt: now + dependencies.widgetCapabilityTtlMs,
    userId,
    state: { currentPlan: null, idempotencyResults: new Map(), nextPlanNumber: 1 },
  };
  sessions.set(capability, session);
  return session;
}

function requireDashboardSession(
  value: unknown,
  sessions: Map<string, DashboardSession>,
  now: () => number,
): DashboardSession {
  const capability = readWidgetCapability(value);
  const session = sessions.get(capability);
  if (!session || session.expiresAt <= now()) {
    sessions.delete(capability);
    throw new ApiError(403, "widgetCapability is invalid or expired");
  }
  return session;
}

function createOpaqueWidgetCapability(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function handleCodexRelayEvent(
  request: Request,
  relaySecret: string | undefined,
  relayState: CodexRelayState,
  now: () => number,
): Promise<Response> {
  if (!relaySecret) throw new ApiError(503, "Codex relay is not enabled");
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.includes("application/json")) throw new ApiError(415, "Content-Type must be application/json");

  const rawBody = await request.text();
  let event: CodexSyncEvent;
  try {
    const parsed: unknown = JSON.parse(rawBody);
    event = readCodexSyncEvent(parsed, now());
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(400, "Invalid JSON body");
  }

  const timestamp = readCodexRelayTimestamp(request.headers.get("x-offshift-timestamp"), now());
  const signature = request.headers.get("x-offshift-signature");
  if (!signature || !await hasValidCodexRelaySignature(relaySecret, timestamp, rawBody, signature)) {
    throw new ApiError(401, "Codex relay signature is invalid");
  }

  pruneCodexRelayState(relayState, now());
  const duplicate = relayState.seenEventIds.has(event.eventId);
  if (!duplicate) {
    relayState.seenEventIds.set(event.eventId, now() + CODEX_EVENT_TTL_MS);
    relayState.statusByInstallation.set(event.installationId, {
      state: event.type === "session.ended" ? "stale" : "active",
      lastEventAt: event.occurredAt,
      sessionActive: event.type !== "session.ended",
      privacyNote: "Only the opted-in Codex session state is synchronized. Prompts, code, repositories, terminal output, and screen content are never sent.",
    });
  }

  const status = relayState.statusByInstallation.get(event.installationId);
  return json({ accepted: true, deduplicated: duplicate, status }, 202);
}

function readCodexSyncEvent(value: unknown, now: number): CodexSyncEvent {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new ApiError(400, "Codex relay event must be an object");
  const event = value as Record<string, unknown>;
  const permittedKeys = ["version", "eventId", "installationId", "type", "occurredAt"];
  if (Object.keys(event).some((key) => !permittedKeys.includes(key))) {
    throw new ApiError(400, "Codex relay event includes unsupported data");
  }
  if (event.version !== CODEX_EVENT_VERSION) throw new ApiError(400, "Codex relay event version is unsupported");
  if (typeof event.eventId !== "string" || !/^evt_[A-Za-z0-9_-]{8,124}$/.test(event.eventId)) {
    throw new ApiError(400, "eventId must be an opaque evt_ identifier");
  }
  if (typeof event.installationId !== "string" || !/^install_[A-Za-z0-9_-]{8,120}$/.test(event.installationId)) {
    throw new ApiError(400, "installationId must be an opaque install_ identifier");
  }
  if (event.type !== "session.started" && event.type !== "session.heartbeat" && event.type !== "session.ended") {
    throw new ApiError(400, "Codex relay event type is unsupported");
  }
  if (typeof event.occurredAt !== "string" || Number.isNaN(Date.parse(event.occurredAt))) {
    throw new ApiError(400, "occurredAt must be an ISO timestamp");
  }
  if (Math.abs(now - Date.parse(event.occurredAt)) > CODEX_EVENT_TTL_MS) {
    throw new ApiError(400, "occurredAt must be recent");
  }
  return {
    version: CODEX_EVENT_VERSION,
    eventId: event.eventId,
    installationId: event.installationId,
    type: event.type,
    occurredAt: event.occurredAt,
  };
}

function readCodexRelayTimestamp(value: string | null, now: number): string {
  if (!value || !/^\d{10,13}$/.test(value)) throw new ApiError(401, "Codex relay timestamp is invalid");
  const milliseconds = value.length === 10 ? Number(value) * 1_000 : Number(value);
  if (Math.abs(now - milliseconds) > CODEX_EVENT_TTL_MS) throw new ApiError(401, "Codex relay timestamp is stale");
  return value;
}

async function hasValidCodexRelaySignature(secret: string, timestamp: string, rawBody: string, signature: string): Promise<boolean> {
  if (!/^sha256=[a-f0-9]{64}$/.test(signature)) return false;
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign("HMAC", key, encoder.encode(`${timestamp}.${rawBody}`));
  const expected = `sha256=${Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("")}`;
  if (signature.length !== expected.length) return false;
  let mismatch = 0;
  for (let index = 0; index < signature.length; index += 1) mismatch |= signature.charCodeAt(index) ^ expected.charCodeAt(index);
  return mismatch === 0;
}

function pruneCodexRelayState(relayState: CodexRelayState, now: number): void {
  for (const [eventId, expiresAt] of relayState.seenEventIds) {
    if (expiresAt <= now) relayState.seenEventIds.delete(eventId);
  }
  for (const [installationId, status] of relayState.statusByInstallation) {
    if (status.lastEventAt && now - Date.parse(status.lastEventAt) > CODEX_SYNC_STALE_AFTER_MS && status.state === "active") {
      relayState.statusByInstallation.set(installationId, { ...status, state: "stale", sessionActive: false });
    }
  }
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

function readWidgetCapability(value: unknown): string {
  if (value === undefined || value === null) throw new ApiError(400, "widgetCapability is required");
  if (typeof value !== "string" || value.length < 32 || value.length > 128) {
    throw new ApiError(400, "widgetCapability must be an opaque 32-128 character value");
  }
  return value;
}

function readBoundedInteger(value: unknown, name: string, minimum: number, maximum: number): number {
  if (!Number.isInteger(value) || (value as number) < minimum || (value as number) > maximum) {
    throw new ApiError(400, `${name} must be an integer from ${minimum} to ${maximum}`);
  }
  return value as number;
}

function readDuration(value: unknown): number {
  if (value === undefined || value === null) return 5;
  return readBoundedInteger(value, "durationMinutes", MIN_BREAK_DURATION_MINUTES, MAX_BREAK_DURATION_MINUTES);
}

function readSceneId(value: unknown): string {
  if (value === undefined || value === null) return ALLOWED_SCENE_ID;
  if (value === ALLOWED_SCENE_ID) return value;
  throw new ApiError(400, "sceneId must be the allowlisted wind-down scene");
}

function optionalUserInputSchema(): Record<string, unknown> {
  return {
    type: "object",
    additionalProperties: false,
    properties: { userId: { type: "string", minLength: 1, maxLength: MAX_USER_ID_LENGTH } },
  };
}

function widgetCapabilitySchema(): Record<string, unknown> {
  return {
    type: "string",
    minLength: 32,
    maxLength: 128,
    description: "Opaque, short-lived dashboard capability returned only in the dashboard tool result metadata.",
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

function dashboardSnapshotSchema(): Record<string, unknown> {
  return {
    type: "object",
    additionalProperties: false,
    required: ["focusMinutes", "thresholdMinutes", "suggestedBreakMinutes", "privacyNote"],
    properties: {
      focusMinutes: { type: "integer", minimum: 1 },
      thresholdMinutes: { type: "integer", minimum: 1 },
      suggestedBreakMinutes: { type: "integer", minimum: 1 },
      privacyNote: { type: "string" },
    },
  };
}

function dashboardBehaviourSchema(): Record<string, unknown> {
  return {
    type: "object",
    required: ["level", "reasons", "shadowMode", "lockScreenRule"],
    properties: {
      level: { type: "string", enum: ["routine", "drift", "protect"] },
      reasons: { type: "array", items: { type: "string" } },
      shadowMode: { const: true },
      lockScreenRule: { const: "not-configured" },
    },
  };
}

function dashboardPlanSchema(): Record<string, unknown> {
  return {
    type: "object",
    required: ["id", "status", "durationMinutes", "sceneId", "startsAt", "endsAt", "message"],
    properties: {
      id: { type: "string" },
      status: { type: "string", enum: ["suggested", "scheduled", "snoozed", "on-call"] },
      durationMinutes: { type: "integer", minimum: MIN_BREAK_DURATION_MINUTES, maximum: MAX_BREAK_DURATION_MINUTES },
      sceneId: { const: ALLOWED_SCENE_ID },
      startsAt: { type: "string", format: "date-time" },
      endsAt: { type: "string", format: "date-time" },
      message: { type: "string" },
    },
  };
}

function dashboardOutputSchema(): Record<string, unknown> {
  return {
    type: "object",
    required: ["snapshot", "behaviour", "plan", "allowedSceneIds"],
    properties: {
      snapshot: dashboardSnapshotSchema(),
      behaviour: dashboardBehaviourSchema(),
      plan: dashboardPlanSchema(),
      allowedSceneIds: { type: "array", items: { const: ALLOWED_SCENE_ID } },
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

function assetResponse(response: Response): Response {
  const headers = new Headers(response.headers);
  headers.set("access-control-allow-origin", "*");
  headers.set("cross-origin-resource-policy", "cross-origin");
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
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
