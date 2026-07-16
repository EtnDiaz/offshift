import { BREAK_ACTIONS, type BreakAction, type BreakPlan, type BreakPreview, type DemoStore, type FocusSnapshot, type ScheduleInput } from "./types.js";

const FIXED_SNAPSHOT_TIME = "2026-07-16T09:00:00.000Z";
const MAX_SNOOZES = 3;

const PREVIEWS: Record<BreakAction, BreakPreview> = {
  stretch: {
    action: "stretch",
    durationMinutes: 3,
    title: "Three-minute desk reset",
    steps: ["Roll your shoulders", "Stand and reach overhead", "Relax your jaw"],
  },
  walk: {
    action: "walk",
    durationMinutes: 8,
    title: "Short screen-free walk",
    steps: ["Step away from the screen", "Walk at an easy pace", "Notice three things around you"],
  },
  breathe: {
    action: "breathe",
    durationMinutes: 2,
    title: "Two-minute breathing pause",
    steps: ["Inhale for four", "Exhale for six", "Repeat at a comfortable pace"],
  },
  hydrate: {
    action: "hydrate",
    durationMinutes: 2,
    title: "Water and posture check",
    steps: ["Fill a glass of water", "Drink slowly", "Reset your seated posture"],
  },
};

export class InMemoryDemoStore implements DemoStore {
  private readonly plans = new Map<string, BreakPlan>();
  private nextId = 1;

  constructor(private readonly now: () => Date = () => new Date()) {}

  getFocusSnapshot(userId: string): FocusSnapshot {
    const hash = stableHash(userId);
    return {
      userId,
      focusScore: 55 + (hash % 36),
      activeMinutes: 40 + (hash % 51),
      suggestedAction: BREAK_ACTIONS[hash % BREAK_ACTIONS.length],
      generatedAt: FIXED_SNAPSHOT_TIME,
    };
  }

  preview(action: BreakAction): BreakPreview {
    return PREVIEWS[action];
  }

  schedule({ action, userId, startInMinutes }: ScheduleInput): BreakPlan {
    const createdAt = this.now();
    const id = `break-${String(this.nextId++).padStart(4, "0")}`;
    const preview = this.preview(action);
    const plan: BreakPlan = {
      ...preview,
      id,
      userId,
      status: "scheduled",
      startAt: new Date(createdAt.getTime() + startInMinutes * 60_000).toISOString(),
      createdAt: createdAt.toISOString(),
      snoozeCount: 0,
    };
    this.plans.set(id, plan);
    return plan;
  }

  snooze(id: string, minutes: number): BreakPlan | undefined {
    const current = this.plans.get(id);
    if (!current || current.snoozeCount >= MAX_SNOOZES) return undefined;

    const plan: BreakPlan = {
      ...current,
      status: "snoozed",
      startAt: new Date(Date.parse(current.startAt) + minutes * 60_000).toISOString(),
      snoozeCount: current.snoozeCount + 1,
    };
    this.plans.set(id, plan);
    return plan;
  }
}

export function createDemoStore(now?: () => Date): DemoStore {
  return new InMemoryDemoStore(now);
}

function stableHash(value: string): number {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}
