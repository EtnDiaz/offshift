import { createDemoStore } from "./demo-store.js";
import { BREAK_ACTIONS, type BreakAction, type DemoStore, type WorkerHandler } from "./types.js";

const DEFAULT_USER_ID = "demo-user";
const MAX_USER_ID_LENGTH = 64;
const MIN_START_IN_MINUTES = 0;
const MAX_START_IN_MINUTES = 480;
const MIN_SNOOZE_MINUTES = 5;
const MAX_SNOOZE_MINUTES = 60;

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
    return json({ status: "ok", service: "offshift-demo-api" });
  }

  if (request.method === "GET" && url.pathname === "/v1/focus/snapshot") {
    return json(store.getFocusSnapshot(readUserId(url.searchParams.get("userId"))));
  }

  if (request.method === "POST" && url.pathname === "/v1/breaks/preview") {
    const body = await readJson(request);
    return json(store.preview(readAction(body.action)));
  }

  if (request.method === "POST" && url.pathname === "/v1/breaks/schedule") {
    const body = await readJson(request);
    const startInMinutes = readBoundedInteger(body.startInMinutes, "startInMinutes", MIN_START_IN_MINUTES, MAX_START_IN_MINUTES);
    const plan = store.schedule({
      action: readAction(body.action),
      userId: readUserId(body.userId),
      startInMinutes,
    });
    return json(plan, 201);
  }

  const snoozeMatch = /^\/v1\/breaks\/(break-\d{4})\/snooze$/.exec(url.pathname);
  if (request.method === "POST" && snoozeMatch) {
    const body = await readJson(request);
    const minutes = readBoundedInteger(body.minutes, "minutes", MIN_SNOOZE_MINUTES, MAX_SNOOZE_MINUTES);
    const plan = store.snooze(snoozeMatch[1], minutes);
    if (!plan) throw new ApiError(409, "Break cannot be snoozed; it is missing or reached the snooze limit");
    return json(plan);
  }

  throw new ApiError(404, "Route not found");
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

function readBoundedInteger(value: unknown, name: string, minimum: number, maximum: number): number {
  if (!Number.isInteger(value) || (value as number) < minimum || (value as number) > maximum) {
    throw new ApiError(400, `${name} must be an integer from ${minimum} to ${maximum}`);
  }
  return value as number;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", ...corsHeaders() },
  });
}

function corsHeaders(): Record<string, string> {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET, POST, OPTIONS",
    "access-control-allow-headers": "content-type",
  };
}

class ApiError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}
