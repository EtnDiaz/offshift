export const ALLOWED_SCENE_IDS = ["stretch-lights", "wind-down"] as const;

export type AllowedSceneId = (typeof ALLOWED_SCENE_IDS)[number];
export type BreakStatus = "suggested" | "scheduled" | "snoozed" | "started";

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

  const current = state.currentPlan ?? previewBreakPlan(5, "stretch-lights", now);
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
