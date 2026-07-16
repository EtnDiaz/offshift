// The model can plan this opaque id, but only the local companion can map it to
// a Home Assistant entity and execute it after direct local confirmation.
export const ALLOWED_SCENE_IDS = ["wind-down"] as const;

export type AllowedSceneId = (typeof ALLOWED_SCENE_IDS)[number];
export type BreakStatus = "suggested" | "scheduled" | "snoozed" | "started" | "on-call";
export type WorkPatternLevel = "routine" | "drift" | "protect";

export interface FocusSnapshot {
  activeAppCategory: "coding";
  focusMinutes: number;
  thresholdMinutes: number;
  suggestedBreakMinutes: number;
  privacyNote: string;
}

export interface BreakPlan {
  id: string;
  status: BreakStatus;
  durationMinutes: number;
  sceneId: AllowedSceneId;
  startsAt: string;
  endsAt: string;
  message: string;
}

export interface WorkPatternSnapshot {
  level: WorkPatternLevel;
  reasons: readonly string[];
  shadowMode: boolean;
  lockScreenRule: "not-configured" | "local-only";
}

export interface DemoState {
  currentPlan: BreakPlan | null;
  idempotencyResults: Map<string, BreakPlan>;
}

export function createDemoState(): DemoState {
  return { currentPlan: null, idempotencyResults: new Map() };
}

export function focusSnapshot(): FocusSnapshot {
  return {
    activeAppCategory: "coding",
    focusMinutes: 52,
    thresholdMinutes: 50,
    suggestedBreakMinutes: 5,
    privacyNote: "Demo data only. Offshift does not inspect source code or screen content.",
  };
}

export function workPatternSnapshot(snapshot = focusSnapshot()): WorkPatternSnapshot {
  if (snapshot.focusMinutes >= snapshot.thresholdMinutes + 15) {
    return {
      level: "protect",
      reasons: [
        `${snapshot.focusMinutes} minutes of uninterrupted active work`,
        "The configured break threshold has been exceeded",
      ],
      shadowMode: true,
      lockScreenRule: "not-configured",
    };
  }

  if (snapshot.focusMinutes >= snapshot.thresholdMinutes) {
    return {
      level: "drift",
      reasons: [`${snapshot.focusMinutes} minutes of uninterrupted active work`, "The configured break threshold has been reached"],
      shadowMode: true,
      lockScreenRule: "not-configured",
    };
  }

  return {
    level: "routine",
    reasons: ["Focus time is below the configured break threshold"],
    shadowMode: true,
    lockScreenRule: "not-configured",
  };
}

export function isAllowedSceneId(value: string): value is AllowedSceneId {
  return (ALLOWED_SCENE_IDS as readonly string[]).includes(value);
}

function buildPlan(
  id: string,
  status: BreakStatus,
  durationMinutes: number,
  sceneId: AllowedSceneId,
  startsAt: Date,
): BreakPlan {
  const endsAt = new Date(startsAt.getTime() + durationMinutes * 60_000);
  return {
    id,
    status,
    durationMinutes,
    sceneId,
    startsAt: startsAt.toISOString(),
    endsAt: endsAt.toISOString(),
    message:
      status === "snoozed"
        ? "Your break was deliberately postponed. Offshift will ask again at the new time."
        : status === "on-call"
          ? "On-call override is active for this bounded period. Offshift will return to its usual reminders afterwards."
        : "Your break is ready when you are. The local companion will require a direct confirmation before any scene runs.",
  };
}

export function previewBreakPlan(
  durationMinutes: number,
  sceneId: AllowedSceneId,
  now = new Date(),
): BreakPlan {
  return buildPlan("preview", "suggested", durationMinutes, sceneId, now);
}

export function scheduleBreak(
  state: DemoState,
  input: { durationMinutes: number; sceneId: AllowedSceneId; idempotencyKey: string },
  now = new Date(),
): BreakPlan {
  const previous = state.idempotencyResults.get(input.idempotencyKey);
  if (previous) return previous;

  const plan = buildPlan(
    `break-${state.idempotencyResults.size + 1}`,
    "scheduled",
    input.durationMinutes,
    input.sceneId,
    now,
  );
  state.currentPlan = plan;
  state.idempotencyResults.set(input.idempotencyKey, plan);
  return plan;
}

export function snoozeBreak(
  state: DemoState,
  input: { minutes: number; idempotencyKey: string },
  now = new Date(),
): BreakPlan {
  const previous = state.idempotencyResults.get(input.idempotencyKey);
  if (previous) return previous;

  const current = state.currentPlan ?? previewBreakPlan(5, "wind-down", now);
  const startsAt = new Date(now.getTime() + input.minutes * 60_000);
  const plan = buildPlan(
    current.id,
    "snoozed",
    current.durationMinutes,
    current.sceneId,
    startsAt,
  );
  state.currentPlan = plan;
  state.idempotencyResults.set(input.idempotencyKey, plan);
  return plan;
}

export function setOnCallOverride(
  state: DemoState,
  input: { minutes: number; idempotencyKey: string },
  now = new Date(),
): BreakPlan {
  const previous = state.idempotencyResults.get(input.idempotencyKey);
  if (previous) return previous;

  const current = state.currentPlan ?? previewBreakPlan(5, "wind-down", now);
  const until = new Date(now.getTime() + input.minutes * 60_000);
  const plan = buildPlan(current.id, "on-call", current.durationMinutes, current.sceneId, until);
  state.currentPlan = plan;
  state.idempotencyResults.set(input.idempotencyKey, plan);
  return plan;
}

export function resumeReminders(
  state: DemoState,
  input: { idempotencyKey: string },
  now = new Date(),
): BreakPlan {
  const previous = state.idempotencyResults.get(input.idempotencyKey);
  if (previous) return previous;

  const current = state.currentPlan ?? previewBreakPlan(5, "wind-down", now);
  const plan = buildPlan(current.id, "suggested", current.durationMinutes, current.sceneId, now);
  state.currentPlan = plan;
  state.idempotencyResults.set(input.idempotencyKey, plan);
  return plan;
}
