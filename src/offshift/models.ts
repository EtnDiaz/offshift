export const OFFSHIFT_TOOLS = {
  scheduleBreak: "schedule_break",
  snoozeBreak: "snooze_break",
  onCallOverride: "set_on_call_override",
  resumeReminders: "resume_reminders",
} as const;

export const OFFSHIFT_WIDGET_CAPABILITY_META_KEY = "offshift/widgetCapability";

export interface FocusSnapshot {
  focusMinutes: number;
  thresholdMinutes: number;
  suggestedBreakMinutes: number;
  privacyNote: string;
}

export interface BreakPlan {
  id: string;
  status: "suggested" | "scheduled" | "snoozed" | "started" | "on-call";
  durationMinutes: number;
  sceneId: "wind-down";
  startsAt: string;
  endsAt: string;
  message: string;
}

export interface WorkPatternSnapshot {
  level: "routine" | "drift" | "protect";
  reasons: readonly string[];
  shadowMode: boolean;
  lockScreenRule: "not-configured" | "local-only";
}

export interface OffshiftWidgetData {
  snapshot: FocusSnapshot;
  behaviour: WorkPatternSnapshot;
  plan: BreakPlan;
  allowedSceneIds: readonly string[];
}

export type ActionName = "schedule" | "snooze" | "onCall" | "resume";
export type ActionStatus = "idle" | "working" | "success" | "error";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function isPositiveInt(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value > 0;
}

function isIsoString(value: unknown): value is string {
  return typeof value === "string" && !Number.isNaN(Date.parse(value));
}

export function toOffshiftWidgetData(value: unknown): OffshiftWidgetData | null {
  if (!isRecord(value) || !isRecord(value.snapshot) || !isRecord(value.behaviour) || !isRecord(value.plan)) return null;

  const snapshot = value.snapshot;
  const behaviour = value.behaviour;
  const plan = value.plan;
  if (
    "activeAppCategory" in snapshot ||
    !isPositiveInt(snapshot.focusMinutes) ||
    !isPositiveInt(snapshot.thresholdMinutes) ||
    !isPositiveInt(snapshot.suggestedBreakMinutes) ||
    typeof snapshot.privacyNote !== "string" ||
    (behaviour.level !== "routine" && behaviour.level !== "drift" && behaviour.level !== "protect") ||
    !Array.isArray(behaviour.reasons) ||
    behaviour.reasons.length === 0 ||
    !behaviour.reasons.every((reason) => typeof reason === "string") ||
    typeof behaviour.shadowMode !== "boolean" ||
    (behaviour.lockScreenRule !== "not-configured" && behaviour.lockScreenRule !== "local-only") ||
    typeof plan.id !== "string" ||
    !isPositiveInt(plan.durationMinutes) ||
    plan.sceneId !== "wind-down" ||
    typeof plan.message !== "string" ||
    !isIsoString(plan.startsAt) ||
    !isIsoString(plan.endsAt) ||
    (plan.status !== "suggested" && plan.status !== "scheduled" && plan.status !== "snoozed" && plan.status !== "started" && plan.status !== "on-call")
  ) {
    return null;
  }

  return {
    snapshot: {
      focusMinutes: snapshot.focusMinutes,
      thresholdMinutes: snapshot.thresholdMinutes,
      suggestedBreakMinutes: snapshot.suggestedBreakMinutes,
      privacyNote: snapshot.privacyNote,
    },
    behaviour: {
      level: behaviour.level,
      reasons: behaviour.reasons,
      shadowMode: behaviour.shadowMode,
      lockScreenRule: behaviour.lockScreenRule,
    },
    plan: {
      id: plan.id,
      status: plan.status,
      durationMinutes: plan.durationMinutes,
      sceneId: plan.sceneId,
      startsAt: plan.startsAt,
      endsAt: plan.endsAt,
      message: plan.message,
    },
    allowedSceneIds: Array.isArray(value.allowedSceneIds)
      ? value.allowedSceneIds.filter((scene): scene is string => typeof scene === "string")
      : [],
  };
}

export function widgetCapabilityFromToolResult(value: unknown): string | null {
  if (!isRecord(value) || !isRecord(value._meta)) return null;
  const capability = value._meta[OFFSHIFT_WIDGET_CAPABILITY_META_KEY];
  return typeof capability === "string" && capability.length >= 32 && capability.length <= 128 ? capability : null;
}
