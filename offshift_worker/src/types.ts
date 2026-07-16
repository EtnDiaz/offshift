export const BREAK_ACTIONS = ["stretch", "walk", "breathe", "hydrate"] as const;

export type BreakAction = (typeof BREAK_ACTIONS)[number];
export type BreakStatus = "scheduled" | "snoozed";

export interface FocusSnapshot {
  userId: string;
  focusScore: number;
  activeMinutes: number;
  suggestedAction: BreakAction;
  generatedAt: string;
}

export type WorkPatternBand = "routine" | "drift" | "protect";

export interface BehaviorPolicy {
  policyVersion: "2026-07-16";
  mode: "shadow";
  decisionOwner: "local-companion";
  bands: readonly {
    band: WorkPatternBand;
    meaning: string;
    response: string;
  }[];
  allowedSignalCategories: readonly string[];
  excludedDataCategories: readonly string[];
  forbiddenRemoteActions: readonly string[];
}

export interface BehaviorSnapshot {
  userId: string;
  band: WorkPatternBand;
  mode: "shadow";
  activeMinutes: number;
  contributingCategories: readonly string[];
  explanation: string;
  canTriggerRemoteAction: false;
  generatedAt: string;
}

export interface BreakPreview {
  action: BreakAction;
  durationMinutes: number;
  title: string;
  steps: readonly string[];
}

export interface BreakPlan extends BreakPreview {
  id: string;
  userId: string;
  status: BreakStatus;
  startAt: string;
  createdAt: string;
  snoozeCount: number;
}

export interface DemoStore {
  getFocusSnapshot(userId: string): FocusSnapshot;
  getBehaviorPolicy(): BehaviorPolicy;
  getBehaviorSnapshot(userId: string): BehaviorSnapshot;
  preview(action: BreakAction): BreakPreview;
  schedule(input: ScheduleInput, idempotencyKey?: string): BreakPlan;
  snooze(id: string, minutes: number, idempotencyKey?: string): BreakPlan | undefined;
}

export interface ScheduleInput {
  action: BreakAction;
  userId: string;
  startInMinutes: number;
}

export interface WorkerHandler {
  fetch(request: Request, env: unknown, ctx: unknown): Promise<Response>;
}
