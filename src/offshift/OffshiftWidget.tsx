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
  const riskCopy = data.behaviour.level === "protect" ? "Wind-down suggested" : data.behaviour.level === "drift" ? "A pause may help" : "Check-in";

  return (
    <main className="offshift-widget" aria-labelledby="offshift-title" aria-busy={isWorking}>
      <section className="offshift-widget__snapshot" aria-labelledby="offshift-title">
        <div className="offshift-widget__heading-row">
          <div>
            <p className="offshift-widget__eyebrow">Offshift</p>
            <h1 id="offshift-title">A small check-in</h1>
          </div>
          <Badge color={data.behaviour.level === "protect" ? "danger" : "secondary"}>{riskCopy}</Badge>
        </div>
        <dl className="offshift-widget__metrics">
          <div><dt>Active work</dt><dd>{formatMinutes(data.snapshot.focusMinutes)}</dd></div>
          <div><dt>Break cadence</dt><dd>{formatMinutes(data.snapshot.thresholdMinutes)}</dd></div>
        </dl>
        <p className="offshift-widget__privacy">{data.snapshot.privacyNote}</p>
      </section>

      <section className="offshift-widget__pattern" aria-labelledby="work-pattern-title">
        <div>
          <p className="offshift-widget__eyebrow">Offshift companion</p>
          <h2 id="work-pattern-title">{data.behaviour.level === "protect" ? "It looks like a good time to wind down" : "Here is what Offshift noticed"}</h2>
          <ul className="offshift-widget__reasons">
            {data.behaviour.reasons.map((reason) => <li key={reason}>{reason}</li>)}
          </ul>
          <p className="offshift-widget__availability">
            {data.behaviour.shadowMode ? "Observation only — nothing will interrupt you." : "A local reminder is active."} {data.behaviour.lockScreenRule === "not-configured" ? "Lock Screen is not enabled on this Mac." : "Lock Screen stays under local control on this Mac."}
          </p>
        </div>
      </section>

      <section className="offshift-widget__plan" aria-labelledby="break-plan-title">
        <div className="offshift-widget__plan-header">
          <div>
            <p className="offshift-widget__eyebrow">Suggested next step</p>
            <h2 id="break-plan-title">{formatMinutes(data.plan.durationMinutes)} away from the screen</h2>
          </div>
          <Badge color="secondary">{data.plan.status}</Badge>
        </div>
        <p className="offshift-widget__focus-label">{timingCopy(data.plan)}</p>
        <p className="offshift-widget__availability">Your optional lights scene always asks for confirmation in Offshift Companion. ChatGPT cannot run it or lock your device.</p>
        {data.plan.status === "on-call" ? (
          <div className="offshift-widget__actions">
            <Button color="primary" variant="solid" size="md" disabled={isWorking} onClick={() => void runAction("resume")}>
              {isWorking ? "Updating…" : "Resume reminders"}
            </Button>
          </div>
        ) : (
          <div className="offshift-widget__actions">
            <Button color="primary" variant="solid" size="md" disabled={isWorking} onClick={() => void runAction("schedule")}>
              {isWorking ? "Updating…" : `Prepare a ${formatMinutes(data.plan.durationMinutes)} reset`}
            </Button>
            <Button color="secondary" variant="outline" size="md" disabled={isWorking} onClick={() => void runAction("snooze")}>
              Snooze 5 min
            </Button>
            <Button color="secondary" variant="outline" size="md" disabled={isWorking} onClick={() => void runAction("onCall")}>
              I’m on call for 60 min
            </Button>
          </div>
        )}
        {message && <p ref={messageRef} tabIndex={-1} className={`offshift-widget__message offshift-widget__message--${status}`} role={status === "error" ? "alert" : "status"}>{message}</p>}
      </section>
    </main>
  );
}
