import { useApp } from "@modelcontextprotocol/ext-apps/react";
import type { App as McpApp } from "@modelcontextprotocol/ext-apps";
import { Badge } from "@openai/apps-sdk-ui/components/Badge";
import { Button } from "@openai/apps-sdk-ui/components/Button";
import { LoadingDots } from "@openai/apps-sdk-ui/components/Indicator";
import { useEffect, useRef, useState } from "react";

import {
  OFFSHIFT_TOOLS,
  toOffshiftWidgetData,
  widgetCapabilityFromToolResult,
  type ActionName,
  type ActionStatus,
  type OffshiftWidgetData,
} from "./models";

function formatMinutes(minutes: number): string {
  return `${minutes} min${minutes === 1 ? "" : "s"}`;
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

function dashboardResultFromToolResult(result: unknown): { data: OffshiftWidgetData; widgetCapability: string } | null {
  const data = dataFromToolResult(result);
  const widgetCapability = widgetCapabilityFromToolResult(result);
  return data && widgetCapability ? { data, widgetCapability } : null;
}

function formatTime(iso: string): string {
  return new Intl.DateTimeFormat(undefined, { hour: "numeric", minute: "2-digit" }).format(new Date(iso));
}

function timingCopy(plan: OffshiftWidgetData["plan"]): string {
  if (plan.status === "on-call") return `Paused until ${formatTime(plan.startsAt)}.`;
  if (plan.status === "snoozed") return `Offshift will check in again at ${formatTime(plan.startsAt)}.`;
  if (plan.status === "scheduled") return `Prepared at ${formatTime(plan.startsAt)}.`;
  return "Nothing has been started yet.";
}

export default function OffshiftWidget() {
  const [data, setData] = useState<OffshiftWidgetData | null>(null);
  const [status, setStatus] = useState<ActionStatus>("idle");
  const [message, setMessage] = useState<string | null>(null);
  const [connectionIssue, setConnectionIssue] = useState<string | null>(null);
  const actionKeys = useRef<Partial<Record<ActionName, string>>>({});
  const widgetCapability = useRef<string | null>(null);
  const messageRef = useRef<HTMLParagraphElement>(null);

  const { app, error } = useApp({
    appInfo: { name: "offshift", version: "0.1.0" },
    capabilities: {},
    onAppCreated: (createdApp: McpApp) => {
      createdApp.ontoolresult = (result) => {
        const next = dashboardResultFromToolResult(result);
        if (next) {
          widgetCapability.current = next.widgetCapability;
          setData(next.data);
          setConnectionIssue(null);
        } else {
          setConnectionIssue("Offshift needs a fresh dashboard session before it can safely update this plan.");
        }
      };
    },
  });

  useEffect(() => {
    if (app && !data && !connectionIssue) {
      const timer = window.setTimeout(() => setConnectionIssue("Offshift did not receive a current plan."), 10_000);
      return () => window.clearTimeout(timer);
    }
    return undefined;
  }, [app, connectionIssue, data]);

  useEffect(() => {
    if (message) window.setTimeout(() => messageRef.current?.focus(), 0);
  }, [message]);

  const runAction = async (action: ActionName) => {
    if (!app || !data) return;
    const capability = widgetCapability.current;
    if (!capability) {
      setConnectionIssue("This dashboard session is no longer valid. Refresh Offshift before making a change.");
      return;
    }
    setStatus("working");
    setMessage(null);

    const key = actionKeys.current[action] ?? idempotencyKey(action);
    actionKeys.current[action] = key;
    try {
      const result = await app.callServerTool({
        name: action === "schedule"
          ? OFFSHIFT_TOOLS.scheduleBreak
          : action === "snooze"
            ? OFFSHIFT_TOOLS.snoozeBreak
            : action === "onCall"
              ? OFFSHIFT_TOOLS.onCallOverride
              : OFFSHIFT_TOOLS.resumeReminders,
        arguments: action === "schedule"
          ? {
              durationMinutes: data.plan.durationMinutes,
              sceneId: data.plan.sceneId,
              idempotencyKey: key,
              widgetCapability: capability,
            }
          : action === "resume"
            ? { idempotencyKey: key, widgetCapability: capability }
            : { minutes: action === "snooze" ? 5 : 60, idempotencyKey: key, widgetCapability: capability },
      });
      if (result.isError) throw new Error("Offshift could not complete that action.");
      const next = dashboardResultFromToolResult(result);
      if (!next) throw new Error("Offshift returned an incomplete break plan.");
      widgetCapability.current = next.widgetCapability;
      setData(next.data);
      setStatus("success");
      delete actionKeys.current[action];
      setMessage(
        action === "schedule"
          ? "Your five-minute reset is prepared. Open Offshift Companion to choose any local reminder, scene, or lock action."
          : action === "snooze"
            ? "Break reminder snoozed for 5 minutes."
            : action === "onCall"
              ? "Reminders are paused for 60 minutes. You can resume them here at any time."
              : "Reminders are back on.",
      );
    } catch {
      setStatus("error");
      setMessage("That update did not complete. Retry only if this dashboard session is still current; otherwise refresh Offshift.");
    }
  };

  if (error || connectionIssue) {
    return (
      <main className="offshift-widget offshift-widget--state offshift-widget--error" role="alert">
        <h1>Offshift needs a refresh</h1>
        <p>This dashboard session is missing or stale, so Offshift did not change your plan. No break, lock, scene, or Codex session was started or stopped.</p>
        <p className="offshift-widget__availability">Refreshing creates a new short-lived dashboard session. Your local companion settings stay exactly as they are.</p>
        <Button color="secondary" variant="outline" size="md" onClick={() => window.location.reload()}>Refresh Offshift</Button>
      </main>
    );
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
  const riskCopy = data.behaviour.level === "protect" ? "Time to wind down" : data.behaviour.level === "drift" ? "A pause may help" : "Check-in";
  const resetTitle = data.behaviour.level === "protect"
    ? "Take a short reset before you continue"
    : `Prepare a ${formatMinutes(data.plan.durationMinutes)} reset`;

  return (
    <main className="offshift-widget" aria-labelledby="offshift-title" aria-busy={isWorking}>
      <section className="offshift-widget__decision" aria-labelledby="offshift-title">
        <div className="offshift-widget__heading-row">
          <div>
            <p className="offshift-widget__eyebrow">Offshift</p>
            <h1 id="offshift-title">{resetTitle}</h1>
          </div>
          <Badge color={data.behaviour.level === "protect" ? "danger" : "secondary"}>{riskCopy}</Badge>
        </div>
        <p className="offshift-widget__summary">
          {data.behaviour.reasons[0]} · {formatMinutes(data.snapshot.focusMinutes)} of aggregate active time.
        </p>
        <p className="offshift-widget__timing">{timingCopy(data.plan)}</p>
        {data.plan.status === "on-call" ? (
          <div className="offshift-widget__actions">
            <Button color="primary" variant="solid" size="md" disabled={isWorking} onClick={() => void runAction("resume")}>
              {isWorking ? "Updating…" : "Resume reminders"}
            </Button>
          </div>
        ) : (
          <div className="offshift-widget__actions">
            <Button color="primary" variant="solid" size="md" disabled={isWorking} onClick={() => void runAction("schedule")}>
              {isWorking ? "Preparing…" : `Prepare a ${formatMinutes(data.plan.durationMinutes)} reset`}
            </Button>
            <Button color="secondary" variant="outline" size="md" disabled={isWorking} onClick={() => void runAction("snooze")}>
              Not now — 5 min
            </Button>
          </div>
        )}
        {message && <p ref={messageRef} tabIndex={-1} className={`offshift-widget__message offshift-widget__message--${status}`} role={status === "error" ? "alert" : "status"}>{message}</p>}
        <details className="offshift-widget__why">
          <summary>Why am I seeing this?</summary>
          <ul className="offshift-widget__reasons">
            {data.behaviour.reasons.map((reason) => <li key={reason}>{reason}</li>)}
          </ul>
          <p>{data.snapshot.privacyNote}</p>
        </details>
        <p className="offshift-widget__availability">
          This only prepares your plan. Open Offshift Companion for any local reminder, scene, or Lock Screen choice.
        </p>
      </section>
    </main>
  );
}
