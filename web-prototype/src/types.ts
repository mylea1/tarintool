export type PageId = "today" | "train" | "records" | "exercises" | "recognition" | "plans" | "ai" | "progress" | "profile";

export type SetSemantic = "warmup" | "work" | "excluded";

export type SetType = {
  id: string;
  label: string;
  shortLabel: string;
  semantic: SetSemantic;
  color: string;
};

export type LoadMode = "total" | "perSide" | "bodyweight" | "assisted" | "duration" | "distance";

export type Exercise = {
  id: string;
  name: string;
  englishName: string;
  family: "蹲" | "髋铰链" | "推" | "拉" | "肩部孤立" | "肘部孤立" | "膝部孤立" | "核心" | "髋部孤立";
  muscle: string;
  secondary: string;
  equipment: string;
  camera: string;
  cue: string;
  image?: string;
  loadMode: LoadMode;
};

export type WorkoutSet = {
  id: string;
  typeId: string;
  weight: number;
  reps: number;
  targetMin: number;
  targetMax: number;
  restSeconds: number;
  completed: boolean;
  failed?: boolean;
  rpe?: number;
  durationSeconds?: number;
};

export type WorkoutExercise = {
  id: string;
  exerciseId: string;
  restSeconds: number;
  collapsed: boolean;
  sets: WorkoutSet[];
  supersetId?: string | null;
};

export type ExerciseResourceScope = "library" | "workout" | "plan";

export type ExerciseResource = {
  note: string;
  link: string;
};

export type ExerciseResourceMap = Record<string, Partial<Record<ExerciseResourceScope, ExerciseResource>>>;

export type RoutineFolder = {
  id: string;
  name: string;
};

export type WorkoutRoutine = {
  id: string;
  name: string;
  folderId: string;
  exercises: WorkoutExercise[];
  updatedAt: string;
};

export type WorkoutRecord = {
  id: string;
  name: string;
  date: string;
  startTime: string;
  durationSeconds: number;
  volume: number;
  effectiveSets: number;
  note: string;
  exerciseIds: string[];
  prs: string[];
};

export type TimerState = {
  status: "idle" | "running" | "paused";
  durationSeconds: number;
  remainingSeconds: number;
  targetEndAt: number | null;
  exerciseName: string;
  nextSetLabel: string;
};

export type ChatMessage = {
  id: string;
  role: "user" | "assistant";
  body: string;
  citations?: { title: string; detail: string }[];
};

export type PrototypeScenario = "normal" | "low-confidence" | "offline" | "empty";

export type AppState = {
  page: PageId;
  trainView: "workout" | "plans" | "history";
  workoutStarted: boolean;
  workoutStartedAt: number | null;
  workoutElapsedSeconds: number;
  workoutDraft: boolean;
  workoutCompleted: boolean;
  workoutTimerPaused: boolean;
  workoutName: string;
  workoutNote: string;
  workout: WorkoutExercise[];
  setTypes: SetType[];
  timer: TimerState;
  selectedSetIds: string[];
  batchMode: boolean;
  exerciseQuery: string;
  exerciseMuscle: string;
  exerciseEquipment: string;
  selectedExerciseId: string | null;
  selectedWorkoutExerciseId: string | null;
  customExercises: Exercise[];
  exerciseResources: ExerciseResourceMap;
  resourceEditorExerciseId: string | null;
  resourceEditorScope: ExerciseResourceScope;
  exerciseSelectionMode: "add" | "replace" | "routine-add" | "routine-replace";
  replaceWorkoutExerciseId: string | null;
  replaceRoutineExerciseId: string | null;
  routineFolders: RoutineFolder[];
  routines: WorkoutRoutine[];
  selectedRoutineId: string | null;
  routineFolderFilter: string;
  workoutHistory: WorkoutRecord[];
  selectedRecordId: string | null;
  defaultRestSeconds: number;
  previousPlanId: string | null;
  previousValueMode: "exercise" | "routine";
  rpeTrackingEnabled: boolean;
  livePrEnabled: boolean;
  planLevelFilter: string;
  planGoalFilter: string;
  planEquipmentFilter: string;
  recognitionStatus: "idle" | "ready" | "processing" | "complete";
  recognitionProgress: number;
  recognitionExerciseId: string;
  recognitionCamera: string;
  selectedPlanId: string | null;
  activePlanId: string;
  selectedPlanSessionIndex: number | null;
  selectedCalendarDate: string;
  scheduledWorkouts: Record<string, string>;
  selectedRep: number | null;
  selectedCitation: number | null;
  savedCue: boolean;
  analysisAttached: boolean;
  progressMetric: "best" | "volume" | "e1rm";
  selectedSetTypeId: string | null;
  aiUseTrainingData: boolean;
  aiConsentSeen: boolean;
  aiTyping: boolean;
  chat: ChatMessage[];
  scenario: PrototypeScenario;
  devicePanelOpen: boolean;
  deviceConnections: {
    appleWatch: boolean;
    liveActivity: boolean;
    androidNotifications: boolean;
  };
  routineBuilderReturn: "none" | "workout-settings" | "schedule";
  modal: "none" | "exercise-library" | "set-types" | "ai-consent" | "plan-builder" | "workout-complete" | "workout-save" | "workout-settings" | "exercise-actions" | "exercise-note" | "plate-calculator" | "routine-builder" | "routine-folders" | "workout-record" | "record-overview" | "record-history" | "calendar" | "schedule" | "custom-exercise" | "rep-detail" | "citation" | "muscle-method";
  toast: string | null;
};

export type OfficialPlan = {
  id: string;
  title: string;
  subtitle: string;
  days: number;
  weeks: number;
  level: string;
  focus: string;
  sessions: { day: string; name: string; exercises: number; duration: string; exerciseIds: string[] }[];
};
