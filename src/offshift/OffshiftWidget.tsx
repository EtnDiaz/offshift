import { useApp } from "@modelcontextprotocol/ext-apps/react";
import type { App as McpApp } from "@modelcontextprotocol/ext-apps";
import { Badge } from "@openai/apps-sdk-ui/components/Badge";
import { Button } from "@openai/apps-sdk-ui/components/Button";
import { LoadingDots } from "@openai/apps-sdk-ui/components/Indicator";
import { useState } from "react";

import {
  OFFSHIFT_TOOLS,
  toOffshiftWidgetData,
  type ActionName,
  type ActionStatus,
  type OffshiftWidgetData,
} from "./models";

function formatMinutes(minutes: number): string {
  return `${minutes} min${minutes === 1 ? "" : "s"}`;
}

function CompanionMascot({ level }: { level: OffshiftWidgetData["behaviour"]["level"] }) {
  const expression = level === "protect" ? "•_•" : level === "drift" ? "o_o" : "^_^";
  return (
    <div className={`offshift-widget__companion offshift-widget__companion--${level}`} aria-hidden="true">
      <span className="offshift-widget__moon">☾</span>
      <span className="offshift-widget__companion-face">{expression}</span>
    </div>
  );
}

function idempotencyKey(action: ActionName): string {
  const random = typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : Math.random().toString(36).slice(2);
  return `${action}-${Date.now()}-${random}`;
}

function dataFromToolResult(result: unknown): OffshiftWidgetData | null {
  if (!result || typeof result !== "object") return null;
  const toolResult = result as { structuredContent?: unknown };
  return toOffshiftWidgetData(toolResult.structuredContent);
}

export default function OffshiftWidget() {
  const [data, setData] = useState<OffshiftWidgetData | null>(null);
  const [status, setStatus] = useState<ActionStatus>("idle");
  const [message, setMessage] = useState<string | null>(null);

  const { app, error } = useApp({
    appInfo: { name: "offshift", version: "0.1.0" },
    capabilities: {},
    onAppCreated: (createdApp: McpApp) => {
      createdApp.ontoolresult = (result) => {
        const next = toOffshiftWidgetData(result.structuredContent);
        if (next) setData(next);
      };
    },
  });

  const runAction = async (action: ActionName) => {
    if (!app || !data) return;
    setStatus("working");
    setMessage(null);

    try {
      const result = await app.callServerTool({
        name: action === "schedule"
          ? OFFSHIFT_TOOLS.scheduleBreak
          : action === "snooze"
            ? OFFSHIFT_TOOLS.snoozeBreak
            : OFFSHIFT_TOOLS.onCallOverride,
        arguments: action === "schedule"
          ? {
              durationMinutes: data.plan.durationMinutes,
              sceneId: data.plan.sceneId,
              idempotencyKey: idempotencyKey(action),
            }
          : { minutes: action === "snooze" ? 5 : 60, idempotencyKey: idempotencyKey(action) },
      });
      if (result.isError) throw new Error("Offshift could not complete that action.");
      const next = dataFromToolResult(result);
      if (!next) throw new Error("Offshift returned an incomplete break plan.");
      setData(next);
      setStatus("success");
      setMessage(
        action === "schedule"
          ? "Break scheduled. Take it when the local prompt appears."
          : action === "snooze"
            ? "Break reminder snoozed for 5 minutes."
            : "On-call override set for 60 minutes. Your local rule remains under your control.",
      );
    } catch (cause) {
      setStatus("error");
      setMessage(cause instanceof Error ? cause.message : "Offshift could not complete that action.");
    }
  };

  if (error) {
    return <main className="offshift-widget offshift-widget--state"><p role="alert">Offshift could not connect: {error.message}</p></main>;
  }

  if (!app || !data) {
    return (
      <main className="offshift-widget offshift-widget--state" aria-live="polite">
        <LoadingDots />
        <p>Loading your Offshift plan…</p>
      </main>
    );
  }

  const isWorking = status === "working";
  const riskCopy = data.behaviour.level === "protect" ? "Protect" : data.behaviour.level === "drift" ? "Drift" : "Routine";

  return (
    <main className="offshift-widget" aria-labelledby="offshift-title">
      <section className="offshift-widget__snapshot" aria-labelledby="offshift-title">
        <div className="offshift-widget__heading-row">
          <div>
            <p className="offshift-widget__eyebrow">Offshift</p>
            <h1 id="offshift-title">Focus snapshot</h1>
          </div>
          <Badge color={data.behaviour.level === "protect" ? "danger" : "secondary"}>{riskCopy}</Badge>
        </div>
        <dl className="offshift-widget__metrics">
          <div><dt>Focused</dt><dd>{formatMinutes(data.snapshot.focusMinutes)}</dd></div>
          <div><dt>Threshold</dt><dd>{formatMinutes(data.snapshot.thresholdMinutes)}</dd></div>
        </dl>
        <p className="offshift-widget__privacy">{data.snapshot.privacyNote}</p>
      </section>

      <section className="offshift-widget__pattern" aria-labelledby="work-pattern-title">
        <CompanionMascot level={data.behaviour.level} />
        <div>
          <p className="offshift-widget__eyebrow">Offshift companion</p>
          <h2 id="work-pattern-title">{data.behaviour.level === "protect" ? "Time to protect your wind-down" : "Here is what Offshift noticed"}</h2>
          <ul className="offshift-widget__reasons">
            {data.behaviour.reasons.map((reason) => <li key={reason}>{reason}</li>)}
          </ul>
          <p className="offshift-widget__availability">
            {data.behaviour.shadowMode ? "Shadow-mode data is explainable and local." : "This is an active local reminder."} Lock Screen rule: {data.behaviour.lockScreenRule}.
          </p>
        </div>
      </section>

      <section className="offshift-widget__plan" aria-labelledby="break-plan-title">
        <div className="offshift-widget__plan-header">
          <div>
            <p className="offshift-widget__eyebrow">Your next break</p>
            <h2 id="break-plan-title">{formatMinutes(data.plan.durationMinutes)} away from the screen</h2>
          </div>
          <Badge color="secondary">{data.plan.status}</Badge>
        </div>
        <p className="offshift-widget__focus-label">{data.plan.message}</p>
        <p className="offshift-widget__availability">Scene: {data.plan.sceneId}. It runs only after local confirmation.</p>
        <div className="offshift-widget__actions">
          <Button color="primary" variant="solid" size="md" disabled={isWorking} onClick={() => void runAction("schedule")}>
            {isWorking ? "Updating…" : "Start break"}
          </Button>
          <Button color="secondary" variant="outline" size="md" disabled={isWorking} onClick={() => void runAction("snooze")}>
            Snooze 5 min
          </Button>
          <Button color="secondary" variant="outline" size="md" disabled={isWorking} onClick={() => void runAction("onCall")}>
            On call for 60 min
          </Button>
        </div>
        {message && <p className={`offshift-widget__message offshift-widget__message--${status}`} role={status === "error" ? "alert" : "status"}>{message}</p>}
      </section>
    </main>
  );
}
