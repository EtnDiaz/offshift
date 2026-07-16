import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import cors from "cors";
import express from "express";
import {
  registerAppResource,
  registerAppTool,
  RESOURCE_MIME_TYPE,
} from "@modelcontextprotocol/ext-apps/server";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { z } from "zod";

import {
  ALLOWED_SCENE_IDS,
  createDemoState,
  focusSnapshot,
  previewBreakPlan,
  scheduleBreak,
  snoozeBreak,
} from "./domain.js";

const VERSION = "0.1.0";
const TEMPLATE_URI = "ui://widget/offshift-v1.html";
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, "..", "..");
const assetsDir = path.join(rootDir, "assets");
const port = Number(process.env.PORT ?? 8000);
const widgetDomain = process.env.WIDGET_DOMAIN?.replace(/\/+$/, "");
const demoState = createDemoState();
const dataToolMeta = { ui: { visibility: ["model"] } };

function findAsset(prefix: string, extension: string): string {
  if (!fs.existsSync(assetsDir)) {
    throw new Error(`Assets are missing at ${assetsDir}. Run pnpm run build --target offshift first.`);
  }

  const matches = fs.readdirSync(assetsDir)
    .filter((file) => file.startsWith(`${prefix}-`) && file.endsWith(extension))
    .sort();
  const exact = path.join(assetsDir, `${prefix}${extension}`);
  if (fs.existsSync(exact)) return exact;
  const latest = matches.at(-1);
  if (!latest) throw new Error(`Offshift ${extension} asset is missing. Build the widget first.`);
  return path.join(assetsDir, latest);
}

function readWidgetHtml(): string {
  const js = fs.readFileSync(findAsset("offshift", ".js"), "utf8");
  const css = fs.readFileSync(findAsset("offshift", ".css"), "utf8");
  return `<!doctype html><html><head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" /><style>${css}</style></head><body><div id="offshift-root"></div><script type="module">${js}</script></body></html>`;
}

const planInput = {
  durationMinutes: z.number().int().min(1).max(30).default(5),
  sceneId: z.enum(ALLOWED_SCENE_IDS).default("stretch-lights"),
};

function toolResult(plan = demoState.currentPlan ?? previewBreakPlan(5, "stretch-lights")) {
  return {
    structuredContent: { snapshot: focusSnapshot(), plan, allowedSceneIds: ALLOWED_SCENE_IDS },
    content: [{ type: "text" as const, text: plan.message }],
  };
}

function createOffshiftServer(): McpServer {
  const server = new McpServer(
    { name: "offshift", version: VERSION },
    { instructions: "Use focus tools to explain the current session. Only schedule or snooze a break after the user explicitly asks. Offshift supports only allowlisted local scenes." },
  );

  registerAppResource(server, "Offshift dashboard", TEMPLATE_URI, {}, async () => ({
    contents: [{
      uri: TEMPLATE_URI,
      mimeType: RESOURCE_MIME_TYPE,
      text: readWidgetHtml(),
      _meta: {
        ui: {
          prefersBorder: true,
          ...(widgetDomain ? { domain: widgetDomain } : {}),
          csp: { connectDomains: widgetDomain ? [widgetDomain] : [], resourceDomains: [] },
        },
        "openai/widgetDescription": "A compact developer break dashboard with explicit, reversible controls.",
      },
    }],
  }));

  registerAppTool(server, "get_focus_snapshot", {
    title: "Get focus snapshot",
    description: "Use this when the user asks about their current focus session or next suggested break.",
    inputSchema: {},
    annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false, idempotentHint: true },
    outputSchema: { snapshot: z.object({ focusMinutes: z.number(), thresholdMinutes: z.number(), suggestedBreakMinutes: z.number(), activeAppCategory: z.literal("coding"), privacyNote: z.string() }) },
    _meta: dataToolMeta,
  }, async () => ({ structuredContent: { snapshot: focusSnapshot() }, content: [{ type: "text", text: "The demo focus threshold has been reached; a five-minute break is suggested." }] }));

  registerAppTool(server, "preview_break_plan", {
    title: "Preview a break plan",
    description: "Use this when the user wants to evaluate a bounded break plan without changing their schedule.",
    inputSchema: planInput,
    annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false, idempotentHint: true },
    _meta: dataToolMeta,
  }, async ({ durationMinutes, sceneId }) => toolResult(previewBreakPlan(durationMinutes, sceneId)));

  registerAppTool(server, "schedule_break", {
    title: "Schedule a break",
    description: "Use this when the user explicitly chooses a 1–30 minute Offshift break and an allowlisted scene.",
    inputSchema: { ...planInput, idempotencyKey: z.string().min(8).max(128) },
    annotations: { readOnlyHint: false, destructiveHint: false, openWorldHint: false, idempotentHint: true },
    _meta: dataToolMeta,
  }, async ({ durationMinutes, sceneId, idempotencyKey }) => toolResult(scheduleBreak(demoState, { durationMinutes, sceneId, idempotencyKey })));

  registerAppTool(server, "snooze_break", {
    title: "Snooze a break",
    description: "Use this when the user explicitly postpones their currently planned Offshift break by 5–15 minutes.",
    inputSchema: { minutes: z.number().int().min(5).max(15).default(5), idempotencyKey: z.string().min(8).max(128) },
    annotations: { readOnlyHint: false, destructiveHint: false, openWorldHint: false, idempotentHint: true },
    _meta: dataToolMeta,
  }, async ({ minutes, idempotencyKey }) => toolResult(snoozeBreak(demoState, { minutes, idempotencyKey })));

  registerAppTool(server, "render_offshift_dashboard", {
    title: "Show Offshift dashboard",
    description: "Use this after reading or preparing the Offshift break state to show the interactive dashboard.",
    inputSchema: {},
    annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false, idempotentHint: true },
    _meta: { ui: { resourceUri: TEMPLATE_URI }, "openai/outputTemplate": TEMPLATE_URI },
  }, async () => toolResult());

  return server;
}

const app = express();
app.use(cors());
app.use(express.json());
app.get("/health", (_request, response) => response.json({ name: "offshift", version: VERSION, widgetUri: TEMPLATE_URI, scenes: ALLOWED_SCENE_IDS }));

app.post("/mcp", async (request, response) => {
  const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined, enableJsonResponse: true });
  response.on("close", () => transport.close());
  const server = createOffshiftServer();
  await server.connect(transport);
  await transport.handleRequest(request, response, request.body);
});

app.get("/mcp", async (request, response) => {
  const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined, enableJsonResponse: true });
  response.on("close", () => transport.close());
  const server = createOffshiftServer();
  await server.connect(transport);
  await transport.handleRequest(request, response);
});

app.delete("/mcp", (_request, response) => response.status(405).end());

app.listen(port, () => console.log(`Offshift MCP server listening on http://localhost:${port}/mcp`));
