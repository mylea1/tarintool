import { initialWorkout, setTypes } from "./data";
import type { AppState, WorkoutRecord, WorkoutRoutine } from "./types";

const STORAGE_KEY = "kilo-web-prototype-v2";

const cloneWorkout = () => structuredClone(initialWorkout);

const createDefaultRoutines = (): WorkoutRoutine[] => {
  const upper = cloneWorkout();
  const lower = cloneWorkout().map((item, index) => ({
    ...item,
    id: `routine-lower-${index}`,
    exerciseId: ["barbell_squat", "romanian_deadlift", "leg_curl"][index] ?? item.exerciseId,
    collapsed: index !== 0,
  }));
  return [
    { id: "routine-upper-a", name: "上肢力量 A", folderId: "folder-strength", exercises: upper, updatedAt: "2026-08-02" },
    { id: "routine-lower-b", name: "下肢力量 B", folderId: "folder-strength", exercises: lower, updatedAt: "2026-08-01" },
    { id: "routine-upper-hypertrophy", name: "上肢增肌", folderId: "folder-hypertrophy", exercises: upper, updatedAt: "2026-07-29" },
  ];
};

const createDefaultHistory = (): WorkoutRecord[] => [
  { id: "history-0801", name: "上肢力量 A", date: "2026-08-01", startTime: "18:32", durationSeconds: 3258, volume: 6842.5, effectiveSets: 12, note: "卧推最后一组保持了目标次数。", exerciseIds: ["bench_press", "chest_supported_row", "lateral_raise"], prs: ["卧推重复次数 PR"] },
  { id: "history-0730", name: "下肢力量 B", date: "2026-07-30", startTime: "19:10", durationSeconds: 4020, volume: 8260, effectiveSets: 15, note: "深蹲节奏稳定。", exerciseIds: ["barbell_squat", "romanian_deadlift", "leg_curl"], prs: [] },
  { id: "history-0727", name: "推拉混合", date: "2026-07-27", startTime: "17:45", durationSeconds: 3510, volume: 6410, effectiveSets: 13, note: "", exerciseIds: ["bench_press", "row", "shoulder_press"], prs: ["坐姿划船重量 PR"] },
  { id: "history-0724", name: "上肢容量", date: "2026-07-24", startTime: "18:05", durationSeconds: 3360, volume: 5985, effectiveSets: 14, note: "", exerciseIds: ["dumbbell_press", "lat_pulldown", "lateral_raise"], prs: [] },
];

export const createDefaultState = (): AppState => ({
  page: "today",
  trainView: "workout",
  workoutStarted: false,
  workoutStartedAt: null,
  workoutElapsedSeconds: 0,
  workoutDraft: false,
  workoutCompleted: false,
  workoutTimerPaused: false,
  workoutName: "上肢力量 A",
  workoutNote: "",
  workout: cloneWorkout(),
  setTypes: structuredClone(setTypes),
  timer: {
    status: "idle",
    durationSeconds: 150,
    remainingSeconds: 150,
    targetEndAt: null,
    exerciseName: "杠铃卧推",
    nextSetLabel: "正式组 1",
  },
  selectedSetIds: [],
  batchMode: false,
  exerciseQuery: "",
  exerciseMuscle: "全部",
  exerciseEquipment: "全部",
  selectedExerciseId: null,
  selectedWorkoutExerciseId: null,
  customExercises: [],
  exerciseResources: {
    bench_press: {
      library: { note: "保持肩胛稳定，杠铃落到胸骨下段。", link: "https://www.youtube.com/results?search_query=bench+press+technique" },
      workout: { note: "今天每次触胸停顿 1 秒。", link: "" },
      plan: { note: "正式组使用 6–8 次范围，全部达上限后加重。", link: "" },
    },
  },
  resourceEditorExerciseId: null,
  resourceEditorScope: "library",
  exerciseSelectionMode: "add",
  replaceWorkoutExerciseId: null,
  replaceRoutineExerciseId: null,
  routineFolders: [
    { id: "folder-strength", name: "力量周期" },
    { id: "folder-hypertrophy", name: "增肌模板" },
  ],
  routines: createDefaultRoutines(),
  selectedRoutineId: null,
  routineFolderFilter: "all",
  workoutHistory: createDefaultHistory(),
  selectedRecordId: null,
  defaultRestSeconds: 120,
  previousPlanId: "routine-upper-a",
  previousValueMode: "exercise",
  rpeTrackingEnabled: true,
  livePrEnabled: true,
  planLevelFilter: "全部",
  planGoalFilter: "全部",
  planEquipmentFilter: "全部",
  recognitionStatus: "idle",
  recognitionProgress: 0,
  recognitionExerciseId: "bench_press",
  recognitionCamera: "侧前方 30-45°",
  selectedPlanId: null,
  activePlanId: "upper-lower-4",
  selectedPlanSessionIndex: null,
  selectedCalendarDate: "2026-08-01",
  scheduledWorkouts: {
    "2026-07-29": "上肢容量补练",
    "2026-08-01": "上肢力量 A",
    "2026-08-02": "下肢容量补练",
    "2026-08-03": "下肢力量 B",
    "2026-08-05": "上肢增肌",
    "2026-08-08": "下肢增肌",
  },
  selectedRep: null,
  selectedCitation: null,
  savedCue: false,
  analysisAttached: false,
  progressMetric: "best",
  selectedSetTypeId: null,
  aiUseTrainingData: false,
  aiConsentSeen: false,
  aiTyping: false,
  chat: [
    {
      id: "coach-welcome",
      role: "assistant",
      body: "可以直接问训练技术、计划安排或恢复问题。我会优先使用知识库，并把依据放在回答下面。",
    },
  ],
  scenario: "normal",
  devicePanelOpen: false,
  deviceConnections: {
    appleWatch: false,
    liveActivity: true,
    androidNotifications: false,
  },
  routineBuilderReturn: "none",
  modal: "none",
  toast: null,
});

const restoreState = (): AppState => {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (!saved) return createDefaultState();
    const parsed = JSON.parse(saved) as Partial<AppState>;
    const defaults = createDefaultState();
    return {
      ...defaults,
      ...parsed,
      timer: { ...defaults.timer, ...parsed.timer },
      deviceConnections: { ...defaults.deviceConnections, ...parsed.deviceConnections },
      workout: Array.isArray(parsed.workout) ? parsed.workout : defaults.workout,
      customExercises: Array.isArray(parsed.customExercises) ? parsed.customExercises : defaults.customExercises,
      routines: Array.isArray(parsed.routines) ? parsed.routines : defaults.routines,
      routineFolders: Array.isArray(parsed.routineFolders) ? parsed.routineFolders : defaults.routineFolders,
      workoutHistory: Array.isArray(parsed.workoutHistory) ? parsed.workoutHistory : defaults.workoutHistory,
      workoutDraft: typeof parsed.workoutDraft === "boolean" ? parsed.workoutDraft : defaults.workoutDraft,
      previousPlanId: typeof parsed.previousPlanId === "string" || parsed.previousPlanId === null
        ? parsed.previousPlanId
        : parsed.previousValueMode === "routine" ? defaults.previousPlanId : null,
      exerciseResources: parsed.exerciseResources && typeof parsed.exerciseResources === "object" ? parsed.exerciseResources : defaults.exerciseResources,
      recognitionExerciseId: parsed.recognitionExerciseId === "bench-press"
        ? "bench_press"
        : parsed.recognitionExerciseId ?? defaults.recognitionExerciseId,
      setTypes: Array.isArray(parsed.setTypes)
        ? parsed.setTypes.map((type) => type.id === "work" ? { ...type, color: "#72e4ff" } : type)
        : defaults.setTypes,
      chat: Array.isArray(parsed.chat) ? parsed.chat : defaults.chat,
      toast: null,
      aiTyping: false,
    };
  } catch {
    return createDefaultState();
  }
};

export let state = restoreState();

type Listener = () => void;
const listeners = new Set<Listener>();

export const subscribe = (listener: Listener) => {
  listeners.add(listener);
  return () => listeners.delete(listener);
};

export const commit = (mutator: (draft: AppState) => void) => {
  mutator(state);
  persist();
  listeners.forEach((listener) => listener());
};

export const persist = () => localStorage.setItem(STORAGE_KEY, JSON.stringify(state));

export const replaceState = (next: AppState) => {
  state = next;
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  listeners.forEach((listener) => listener());
};

export const resetState = () => replaceState(createDefaultState());

export const uid = (prefix: string) => `${prefix}-${crypto.randomUUID()}`;
