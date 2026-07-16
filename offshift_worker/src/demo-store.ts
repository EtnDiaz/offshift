import {
  BREAK_ACTIONS,
  type BehaviorPolicy,
  type BehaviorSnapshot,
  type BreakAction,
  type BreakPlan,
  type BreakPreview,
  type DemoStore,
  type FocusSnapshot,
  type ScheduleInput,
  type WorkPatternBand,
} from "./types.js";

const FIXED_SNAPSHOT_TIME = "2026-07-16T09:00:00.000Z";
const MAX_SNOOZES = 3;

const BEHAVIOR_POLICY: BehaviorPolicy = {
  policyVersion: "2026-07-16",
  mode: "shadow",
  decisionOwner: "local-companion",
  bands: [
    {
      band: "routine",
      meaning: "The observed aggregate session is within the user's chosen rhythm.",
      response: "Show the next optional break without interrupting the user.",
    },
    {
      band: "drift",
      meaning: "Long uninterrupted activity or quiet-hours context suggests a gentle check-in may help.",
      response: "A local companion may offer a reversible break invitation after the user enables nudges.",
    },
    {
      band: "protect",
      meaning: "A locally configured, repeated pattern needs a clearer invitation to step away.",
      response: "Only the local companion may show its cancellable protection flow; this Worker cannot lock or control a device.",
    },
  ],
  allowedSignalCategories: [
    "aggregate active-app timing",
    "aggregate idle gaps",
    "configured quiet-hours state",
    "accepted, snoozed, or dismissed break events",
    "optional boolean Codex-session-active state",
  ],
  excludedDataCategories: [
    "source code, prompts, diffs, terminal output, or filenames",
    "screen or browser content, screenshots, keystrokes, camera, or microphone",
    "device credentials, arbitrary URLs, and smart-home commands",
  ],
  forbiddenRemoteActions: [
    "remote lock commands",
    "ending a Codex session or submitting code",
    "arbitrary webhooks or device commands",
  ],
};

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
  private readonly idempotencyResults = new Map<string, BreakPlan>();
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

  getBehaviorPolicy(): BehaviorPolicy {
    return BEHAVIOR_POLICY;
  }

  getBehaviorSnapshot(userId: string): BehaviorSnapshot {
    const focus = this.getFocusSnapshot(userId);
    const band = behaviorBandFor(focus.activeMinutes);
    const contributingCategories = [
      `${focus.activeMinutes} minutes of aggregate active-app time`,
      "No raw app, screen, source-code, or prompt content is available to this Worker",
    ];

    return {
      userId,
      band,
      mode: "shadow",
      activeMinutes: focus.activeMinutes,
      contributingCategories,
      explanation: behaviorExplanation(band, focus.activeMinutes),
      canTriggerRemoteAction: false,
      generatedAt: FIXED_SNAPSHOT_TIME,
    };
  }

  preview(action: BreakAction): BreakPreview {
    return PREVIEWS[action];
  }

  schedule({ action, userId, startInMinutes }: ScheduleInput, idempotencyKey?: string): BreakPlan {
    const previous = idempotencyKey ? this.idempotencyResults.get(idempotencyKey) : undefined;
    if (previous) return previous;

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
    if (idempotencyKey) this.idempotencyResults.set(idempotencyKey, plan);
    return plan;
  }

  snooze(id: string, minutes: number, idempotencyKey?: string): BreakPlan | undefined {
    const previous = idempotencyKey ? this.idempotencyResults.get(idempotencyKey) : undefined;
    if (previous) return previous;

    const current = this.plans.get(id);
    if (!current || current.snoozeCount >= MAX_SNOOZES) return undefined;

    const plan: BreakPlan = {
      ...current,
      status: "snoozed",
      startAt: new Date(Date.parse(current.startAt) + minutes * 60_000).toISOString(),
      snoozeCount: current.snoozeCount + 1,
    };
    this.plans.set(id, plan);
    if (idempotencyKey) this.idempotencyResults.set(idempotencyKey, plan);
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

function behaviorBandFor(activeMinutes: number): WorkPatternBand {
  if (activeMinutes >= 85) return "protect";
  if (activeMinutes >= 60) return "drift";
  return "routine";
}

function behaviorExplanation(band: WorkPatternBand, activeMinutes: number): string {
  if (band === "routine") {
    return `${activeMinutes} minutes of aggregate activity is within this demo policy's routine band. Offshift remains in shadow mode.`;
  }
  if (band === "drift") {
    return `${activeMinutes} minutes of aggregate activity reached the drift band. A future local companion could offer a gentle, user-enabled nudge.`;
  }
  return `${activeMinutes} minutes of aggregate activity reached the protect band in this fixture. Only a local companion may offer a cancellable protection flow; this Worker takes no action.`;
}
