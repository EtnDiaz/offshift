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
  preview(action: BreakAction): BreakPreview;
  schedule(input: ScheduleInput): BreakPlan;
  snooze(id: string, minutes: number): BreakPlan | undefined;
}

export interface ScheduleInput {
  action: BreakAction;
  userId: string;
  startInMinutes: number;
}

export interface WorkerHandler {
  fetch(request: Request, env: unknown, ctx: unknown): Promise<Response>;
}
