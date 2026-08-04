import "@phosphor-icons/web/regular";
import "@phosphor-icons/web/bold";
import "@phosphor-icons/web/fill";
import "./styles.css";

import { exercises, getExercise, officialPlans } from "./data";
import { commit, persist, resetState, state, subscribe, uid } from "./state";
import type { Exercise, ExerciseResourceScope, PageId, SetSemantic, WorkoutExercise, WorkoutSet } from "./types";
import { formatTime, renderApp } from "./ui";

const app = document.querySelector<HTMLDivElement>("#app");
if (!app) throw new Error("App root is missing");

const particleCanvas = document.createElement("canvas");
particleCanvas.className = "particle-field";
particleCanvas.setAttribute("aria-hidden", "true");
document.body.prepend(particleCanvas);

const startParticleField = () => {
  const context = particleCanvas.getContext("2d");
  if (!context) return;
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  let width = 0;
  let height = 0;
  let frame = 0;
  let points: Array<{ x: number; y: number; vx: number; vy: number; radius: number; alpha: number }> = [];

  const resize = () => {
    const dpr = Math.min(window.devicePixelRatio || 1, 1.5);
    width = window.innerWidth;
    height = window.innerHeight;
    particleCanvas.width = Math.floor(width * dpr);
    particleCanvas.height = Math.floor(height * dpr);
    particleCanvas.style.width = `${width}px`;
    particleCanvas.style.height = `${height}px`;
    context.setTransform(dpr, 0, 0, dpr, 0, 0);
    const count = Math.min(48, Math.max(22, Math.round((width * height) / 29000)));
    points = Array.from({ length: count }, () => ({
      x: Math.random() * width,
      y: Math.random() * height,
      vx: (Math.random() - 0.5) * 0.12,
      vy: -0.04 - Math.random() * 0.12,
      radius: 0.7 + Math.random() * 1.5,
      alpha: 0.16 + Math.random() * 0.42,
    }));
  };

  const draw = () => {
    context.clearRect(0, 0, width, height);
    points.forEach((point, index) => {
      if (!reduceMotion) {
        point.x += point.vx;
        point.y += point.vy;
        if (point.y < -8) point.y = height + 8;
        if (point.x < -8) point.x = width + 8;
        if (point.x > width + 8) point.x = -8;
      }
      context.beginPath();
      context.arc(point.x, point.y, point.radius, 0, Math.PI * 2);
      context.fillStyle = `rgba(11, 102, 212, ${point.alpha * 0.42})`;
      context.fill();
      for (let next = index + 1; next < points.length; next += 1) {
        const target = points[next];
        const distance = Math.hypot(point.x - target.x, point.y - target.y);
        if (distance < 94) {
          context.beginPath();
          context.moveTo(point.x, point.y);
          context.lineTo(target.x, target.y);
          context.strokeStyle = `rgba(11, 102, 212, ${(1 - distance / 94) * 0.035})`;
          context.stroke();
        }
      }
    });
    if (!reduceMotion && !document.hidden) frame = window.requestAnimationFrame(draw);
  };

  resize();
  draw();
  window.addEventListener("resize", () => { window.cancelAnimationFrame(frame); resize(); draw(); }, { passive: true });
  document.addEventListener("visibilitychange", () => {
    window.cancelAnimationFrame(frame);
    if (!document.hidden && !reduceMotion) draw();
  });
};

startParticleField();

const validPages: PageId[] = ["today", "train", "records", "exercises", "recognition", "plans", "ai", "progress", "profile"];
let toastTimer: number | null = null;
let analysisTimer: number | null = null;

const render = () => {
  app.innerHTML = renderApp();
};

subscribe(render);
render();

const showToast = (message: string) => {
  if (toastTimer) window.clearTimeout(toastTimer);
  commit((draft) => { draft.toast = message; });
  toastTimer = window.setTimeout(() => {
    if (state.toast === message) commit((draft) => { draft.toast = null; });
  }, 2600);
};

const findSet = (setId: string): { exercise: WorkoutExercise; setItem: WorkoutSet; index: number } | null => {
  for (const exercise of state.workout) {
    const index = exercise.sets.findIndex((setItem) => setItem.id === setId);
    if (index >= 0) return { exercise, setItem: exercise.sets[index], index };
  }
  return null;
};

const nextIncompleteSet = () => {
  for (const exercise of state.workout) {
    const index = exercise.sets.findIndex((setItem) => !setItem.completed);
    if (index >= 0) return { exercise, setItem: exercise.sets[index], index };
  }
  return null;
};

const startTimerForSet = (exercise: WorkoutExercise, setItem: WorkoutSet, index: number) => {
  const exerciseDefinition = getExercise(exercise.exerciseId, state.customExercises);
  const durationSeconds = setItem.restSeconds ?? exercise.restSeconds ?? state.defaultRestSeconds;
  if (durationSeconds <= 0) {
    commit((draft) => { draft.timer.status = "idle"; draft.timer.targetEndAt = null; draft.timer.remainingSeconds = 0; });
    return;
  }
  commit((draft) => {
    draft.timer = {
      status: "running",
      durationSeconds,
      remainingSeconds: durationSeconds,
      targetEndAt: Date.now() + durationSeconds * 1000,
      exerciseName: exerciseDefinition.name,
      nextSetLabel: index + 1 < exercise.sets.length ? `第 ${index + 2} 组` : "下一个动作",
    };
  });
};

const completeSet = (setId: string) => {
  const match = findSet(setId);
  if (!match) return;
  const willComplete = !match.setItem.completed;
  commit((draft) => {
    const target = draft.workout.flatMap((exercise) => exercise.sets).find((setItem) => setItem.id === setId);
    if (target) target.completed = willComplete;
  });
  if (willComplete) {
    startTimerForSet(match.exercise, match.setItem, match.index);
    const type = state.setTypes.find((item) => item.id === match.setItem.typeId);
    const isPr = state.livePrEnabled && type?.semantic === "work" && match.setItem.weight >= 80 && match.setItem.reps >= 8;
    showToast(isPr ? `🏆 新个人纪录：${getExercise(match.exercise.exerciseId, state.customExercises).name} ${match.setItem.weight} kg × ${match.setItem.reps}` : `第 ${match.index + 1} 组已完成${state.timer.status === "running" ? "，休息计时开始" : ""}`);
  }
};

const selectPage = (page: PageId) => {
  commit((draft) => {
    draft.page = page;
    draft.modal = "none";
    draft.selectedExerciseId = null;
    draft.selectedPlanId = null;
  });
  window.scrollTo({ top: 0, behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
};

const startWorkout = (blank = false) => {
  commit((draft) => {
    draft.workoutStarted = !blank;
    draft.workoutStartedAt = blank ? null : Date.now();
    draft.workoutElapsedSeconds = 0;
    draft.workoutDraft = blank;
    draft.workoutCompleted = false;
    draft.workoutTimerPaused = false;
    draft.page = "train";
    draft.trainView = "workout";
    draft.modal = "none";
    if (blank) {
      draft.workout = [];
      draft.workoutName = "空白训练";
      draft.previousPlanId = null;
      draft.modal = "exercise-library";
    }
  });
};

const startRoutine = (routineId: string) => {
  const routine = state.routines.find((item) => item.id === routineId);
  if (!routine) return;
  commit((draft) => {
    draft.workout = structuredClone(routine.exercises).map((exercise) => ({
      ...exercise,
      id: uid("workout-exercise"),
      collapsed: false,
      sets: exercise.sets.map((setItem) => ({ ...setItem, id: uid("set"), completed: false })),
    }));
    draft.workoutName = routine.name;
    draft.workoutStarted = true;
    draft.workoutStartedAt = Date.now();
    draft.workoutElapsedSeconds = 0;
    draft.workoutDraft = false;
    draft.previousPlanId = routineId;
    draft.workoutTimerPaused = false;
    draft.workoutCompleted = false;
    draft.page = "train";
    draft.trainView = "workout";
    draft.modal = "none";
  });
};

const startPlanSession = (planId: string, sessionIndex = 0) => {
  const plan = officialPlans.find((item) => item.id === planId);
  const session = plan?.sessions[sessionIndex] ?? plan?.sessions[0];
  if (!plan || !session) return;
  commit((draft) => {
    const sourceByExercise = new Map<string, WorkoutExercise>();
    draft.workout.forEach((item) => sourceByExercise.set(item.exerciseId, item));
    draft.routines.forEach((routine) => routine.exercises.forEach((item) => sourceByExercise.set(item.exerciseId, item)));
    draft.workout = session.exerciseIds.map((exerciseId, index) => {
      const source = sourceByExercise.get(exerciseId);
      if (source) {
        const cloned = structuredClone(source);
        return {
          ...cloned,
          id: uid("workout-exercise"),
          collapsed: index !== 0,
          sets: cloned.sets.map((setItem) => ({ ...setItem, id: uid("set"), completed: false })),
        };
      }
      return {
        id: uid("workout-exercise"),
        exerciseId,
        restSeconds: draft.defaultRestSeconds,
        collapsed: index !== 0,
        sets: [1, 2, 3].map(() => ({ id: uid("set"), typeId: "work", weight: 0, reps: 8, targetMin: 6, targetMax: 8, restSeconds: draft.defaultRestSeconds, completed: false })),
      };
    });
    draft.workoutName = session.name;
    draft.workoutStarted = true;
    draft.workoutStartedAt = Date.now();
    draft.workoutElapsedSeconds = 0;
    draft.workoutDraft = false;
    draft.workoutTimerPaused = false;
    draft.workoutCompleted = false;
    draft.previousPlanId = draft.routines.find((routine) => routine.name === session.name)?.id ?? null;
    draft.timer.status = "idle";
    draft.timer.targetEndAt = null;
    draft.timer.remainingSeconds = draft.timer.durationSeconds;
    draft.timer.exerciseName = session.name;
    draft.timer.nextSetLabel = "正式组 1";
    draft.selectedPlanId = null;
    draft.selectedPlanSessionIndex = null;
    draft.page = "train";
    draft.trainView = "workout";
    draft.modal = "none";
  });
};

const closeAllModals = () => commit((draft) => {
  draft.modal = "none";
  draft.selectedExerciseId = null;
  draft.selectedPlanId = null;
  draft.selectedRep = null;
  draft.selectedCitation = null;
  draft.selectedSetTypeId = null;
  draft.selectedPlanSessionIndex = null;
  draft.selectedWorkoutExerciseId = null;
  draft.resourceEditorExerciseId = null;
  draft.selectedRoutineId = null;
  draft.selectedRecordId = null;
  draft.exerciseSelectionMode = "add";
  draft.replaceWorkoutExerciseId = null;
  draft.replaceRoutineExerciseId = null;
  draft.routineBuilderReturn = "none";
});

const simulateAnalysis = () => {
  if (analysisTimer) window.clearInterval(analysisTimer);
  commit((draft) => {
    draft.recognitionStatus = "processing";
    draft.recognitionProgress = 8;
  });
  analysisTimer = window.setInterval(() => {
    const next = Math.min(100, state.recognitionProgress + Math.ceil(Math.random() * 13));
    if (next >= 100) {
      if (analysisTimer) window.clearInterval(analysisTimer);
      analysisTimer = null;
      commit((draft) => {
        draft.recognitionProgress = 100;
        draft.recognitionStatus = "complete";
      });
      showToast(state.scenario === "low-confidence" ? "分析完成，但证据不足" : "分析报告已生成并保存到本地");
      return;
    }
    commit((draft) => { draft.recognitionProgress = next; });
  }, 380);
};

const answerQuestion = (question: string) => {
  const normalized = question.trim();
  if (!normalized) return;
  commit((draft) => {
    draft.chat.push({ id: uid("message"), role: "user", body: normalized });
    draft.aiTyping = true;
  });

  window.setTimeout(() => {
    const body = normalized.includes("80") || normalized.includes("加重")
      ? "你已经在 80 kg 完成全部 3 组 8 次，符合当前双重渐进规则。下一次建议使用 82.5 kg，目标先设为 3 组 6-8 次。如果第一组低于 6 次或动作质量明显下降，退回 80 kg 完成剩余组。"
      : normalized.includes("热身")
        ? "热身组用于建立动作和逐步接近工作重量，不应计入正式训练量或自动加重判断。它仍然应该保存在训练记录中，以便下次快速复用热身路径。"
        : "先保留当前计划结构，再根据最近两节同动作训练调整。优先看有效正式组是否达到目标范围、动作质量是否稳定，以及下降发生在第几组。不要仅凭单次状态重写整个周期。";
    commit((draft) => {
      draft.aiTyping = false;
      draft.chat.push({
        id: uid("message"),
        role: "assistant",
        body,
        citations: [
          { title: "ACSM 阻力训练进展模型", detail: "渐进负荷与训练处方原则" },
          { title: "KILO 知识库：双重渐进", detail: "审核版本 2026.08" },
        ],
      });
    });
  }, 1100);
};

const updatePlateCalculator = () => {
  const targetInput = document.querySelector<HTMLInputElement>('[data-field="plate-target"]');
  const barInput = document.querySelector<HTMLSelectElement>('[data-field="bar-weight"]');
  const result = document.querySelector<HTMLElement>("[data-plate-result]");
  if (!targetInput || !barInput || !result) return;
  const target = Math.max(0, Number(targetInput.value) || 0);
  const bar = Math.max(0, Number(barInput.value) || 0);
  let remaining = Math.max(0, (target - bar) / 2);
  const plates = [25,20,15,10,5,2.5,1.25,0.5];
  const chosen: number[] = [];
  plates.forEach((plate) => {
    while (remaining + 0.001 >= plate) {
      chosen.push(plate);
      remaining -= plate;
    }
  });
  const exact = remaining < 0.01;
  result.innerHTML = `${chosen.map((plate) => `<span class="plate">${plate}</span>`).join("")}<div><small>每侧</small><b>${Math.max(0, (target - bar) / 2).toFixed(2).replace(/\.00$/, "")} kg</b><p>${exact ? chosen.join(" + ") || "无需杠片" : `无法精确组合，还差 ${remaining.toFixed(2)} kg`}</p></div>`;
};

app.addEventListener("click", (event) => {
  const target = event.target as HTMLElement;
  const pageButton = target.closest<HTMLElement>("[data-page]");
  if (pageButton?.dataset.page && validPages.includes(pageButton.dataset.page as PageId)) {
    selectPage(pageButton.dataset.page as PageId);
    return;
  }

  const actionTarget = target.closest<HTMLElement>("[data-action]");
  if (!actionTarget) {
    const planCard = target.closest<HTMLElement>("[data-plan-id]");
    if (planCard?.dataset.planId) commit((draft) => { draft.selectedPlanId = planCard.dataset.planId ?? null; });
    const prompt = target.closest<HTMLElement>("[data-prompt]");
    if (prompt?.dataset.prompt) answerQuestion(prompt.dataset.prompt);
    return;
  }

  const action = actionTarget.dataset.action;
  switch (action) {
    case "start-workout":
    case "resume-workout": startWorkout(); break;
    case "start-blank-workout": startWorkout(true); break;
    case "start-routine": if (actionTarget.dataset.id) startRoutine(actionTarget.dataset.id); break;
    case "start-plan-session": if (actionTarget.dataset.id) startPlanSession(actionTarget.dataset.id, Number(actionTarget.dataset.sessionIndex ?? 0)); break;
    case "new-routine": commit((draft) => { draft.selectedRoutineId = null; draft.routineBuilderReturn = "none"; draft.modal = "routine-builder"; }); break;
    case "new-routine-from-settings": commit((draft) => { draft.selectedRoutineId = null; draft.routineBuilderReturn = "workout-settings"; draft.modal = "routine-builder"; }); break;
    case "new-routine-from-schedule": commit((draft) => { draft.selectedRoutineId = null; draft.routineBuilderReturn = "schedule"; draft.modal = "routine-builder"; }); break;
    case "edit-routine": commit((draft) => { draft.selectedRoutineId = actionTarget.dataset.id ?? null; draft.modal = "routine-builder"; }); break;
    case "manage-routine-folders": commit((draft) => { draft.modal = "routine-folders"; }); break;
    case "routine-folder-filter": commit((draft) => { draft.routineFolderFilter = actionTarget.dataset.id ?? "all"; }); break;
    case "routine-add-exercise": commit((draft) => { draft.exerciseSelectionMode = "routine-add"; draft.replaceRoutineExerciseId = null; draft.modal = "exercise-library"; }); break;
    case "routine-replace-exercise": commit((draft) => { draft.exerciseSelectionMode = "routine-replace"; draft.replaceRoutineExerciseId = actionTarget.dataset.id ?? null; draft.modal = "exercise-library"; }); break;
    case "routine-move-exercise": commit((draft) => {
      const collection = draft.routines.find((routine) => routine.id === draft.selectedRoutineId)?.exercises ?? draft.workout;
      const index = collection.findIndex((item) => item.id === actionTarget.dataset.id);
      const nextIndex = actionTarget.dataset.direction === "up" ? index - 1 : index + 1;
      if (index < 0 || nextIndex < 0 || nextIndex >= collection.length) return;
      [collection[index], collection[nextIndex]] = [collection[nextIndex], collection[index]];
    }); break;
    case "routine-remove-exercise": commit((draft) => {
      const routine = draft.routines.find((item) => item.id === draft.selectedRoutineId);
      if (routine) routine.exercises = routine.exercises.filter((item) => item.id !== actionTarget.dataset.id);
      else draft.workout = draft.workout.filter((item) => item.id !== actionTarget.dataset.id);
    }); showToast("动作已从训练模板移除"); break;
    case "routine-toggle-superset": commit((draft) => {
      const collection = draft.routines.find((routine) => routine.id === draft.selectedRoutineId)?.exercises ?? draft.workout;
      const index = collection.findIndex((item) => item.id === actionTarget.dataset.id);
      const current = collection[index];
      if (!current) return;
      if (current.supersetId) {
        const group = current.supersetId;
        collection.forEach((item) => { if (item.supersetId === group) item.supersetId = null; });
      } else if (collection[index + 1]) {
        const group = String.fromCharCode(65 + collection.filter((item) => item.supersetId).length);
        current.supersetId = group;
        collection[index + 1].supersetId = group;
      }
    }); showToast("训练模板的超级组已更新"); break;
    case "routine-warmup": commit((draft) => {
      const collection = draft.routines.find((routine) => routine.id === draft.selectedRoutineId)?.exercises ?? draft.workout;
      const exercise = collection.find((item) => item.id === actionTarget.dataset.id);
      if (!exercise) return;
      const workSet = exercise.sets.find((setItem) => draft.setTypes.find((type) => type.id === setItem.typeId)?.semantic === "work") ?? exercise.sets[0];
      const targetWeight = workSet?.weight ?? 0;
      const warmups = [0.4, 0.6, 0.8].map((ratio, index) => ({ id: uid("set"), typeId: "warmup", weight: Math.round(targetWeight * ratio / 2.5) * 2.5, reps: [10, 6, 3][index], targetMin: [10, 6, 3][index], targetMax: [10, 6, 3][index], restSeconds: [60, 75, 90][index], completed: false }));
      exercise.sets = [...warmups, ...exercise.sets.filter((setItem) => setItem.typeId !== "warmup")];
    }); showToast("已在训练模板中生成 3 组热身"); break;
    case "train-tab": commit((draft) => {
      const tab = actionTarget.dataset.tab;
      if (tab === "workout" || tab === "plans") draft.trainView = tab;
      draft.selectedExerciseId = null;
      draft.modal = "none";
    }); break;
    case "open-exercise-library": commit((draft) => {
      if (!draft.workoutStarted && !draft.workoutDraft) {
        draft.page = "exercises";
        draft.modal = "none";
      } else {
        draft.modal = "exercise-library";
      }
    }); break;
    case "cancel-blank-workout": commit((draft) => { draft.workout = []; draft.workoutDraft = false; draft.workoutStarted = false; draft.workoutStartedAt = null; draft.workoutElapsedSeconds = 0; draft.modal = "none"; }); break;
    case "workout-settings": commit((draft) => { draft.modal = "workout-settings"; }); break;
    case "toggle-workout-clock": commit((draft) => {
      if (!draft.workoutTimerPaused && draft.workoutStartedAt) {
        draft.workoutElapsedSeconds += Math.max(0, Math.floor((Date.now() - draft.workoutStartedAt) / 1000));
        draft.workoutStartedAt = null;
        draft.workoutTimerPaused = true;
      } else {
        draft.workoutStartedAt = Date.now();
        draft.workoutTimerPaused = false;
      }
    }); showToast(state.workoutTimerPaused ? "训练计时已暂停" : "训练计时已恢复"); break;
    case "open-exercise-actions": commit((draft) => { draft.selectedWorkoutExerciseId = actionTarget.dataset.exerciseId ?? null; draft.modal = "exercise-actions"; }); break;
    case "edit-exercise-note": commit((draft) => {
      draft.resourceEditorExerciseId = actionTarget.dataset.id ?? null;
      draft.resourceEditorScope = (actionTarget.dataset.scope ?? "library") as ExerciseResourceScope;
      draft.selectedExerciseId = null;
      draft.selectedPlanId = null;
      draft.modal = "exercise-note";
    }); break;
    case "close-modal":
      closeAllModals(); break;
    case "backdrop-close": if (event.target === actionTarget) closeAllModals(); break;
    case "open-exercise-detail": if (actionTarget.dataset.id) commit((draft) => { draft.selectedExerciseId = actionTarget.dataset.id ?? null; }); break;
    case "close-exercise-detail": commit((draft) => { draft.selectedExerciseId = null; }); break;
    case "close-plan-detail": commit((draft) => { draft.selectedPlanId = null; }); break;
    case "toggle-device-panel": commit((draft) => { draft.devicePanelOpen = !draft.devicePanelOpen; }); break;
    case "toggle-device-connection": {
      const device = actionTarget.dataset.device;
      if (device === "appleWatch" || device === "liveActivity" || device === "androidNotifications") {
        commit((draft) => { draft.deviceConnections[device] = !draft.deviceConnections[device]; });
        showToast(state.deviceConnections[device] ? "设备连接已开启" : "设备连接已关闭");
      }
      break;
    }
    case "reset-prototype": resetState(); showToast("演示数据已重置"); break;
    case "show-settings": commit((draft) => { draft.page = "profile"; draft.modal = "none"; }); break;
    case "open-calendar": commit((draft) => { draft.modal = "calendar"; }); break;
    case "calendar-day": commit((draft) => { if (actionTarget.dataset.date) draft.selectedCalendarDate = actionTarget.dataset.date; }); break;
    case "open-workout-record": commit((draft) => { draft.selectedRecordId = actionTarget.dataset.id ?? null; draft.modal = "workout-record"; }); break;
    case "open-record-overview": commit((draft) => { draft.modal = "record-overview"; }); break;
    case "open-record-history": commit((draft) => { draft.modal = "record-history"; }); break;
    case "log-past-workout": commit((draft) => { draft.workoutName = "补录训练"; draft.modal = "workout-save"; }); break;
    case "delete-workout-record": {
      const id = actionTarget.dataset.id;
      commit((draft) => { draft.workoutHistory = draft.workoutHistory.filter((record) => record.id !== id); draft.selectedRecordId = null; draft.modal = "none"; });
      showToast("训练记录已删除");
      break;
    }
    case "open-saved-history": commit((draft) => { draft.modal = "none"; draft.workoutStarted = false; draft.workoutStartedAt = null; draft.workoutDraft = false; draft.page = "records"; }); break;
    case "open-plans": commit((draft) => { draft.page = "train"; draft.trainView = "plans"; draft.modal = "none"; }); break;
    case "toggle-exercise": {
      const id = actionTarget.dataset.exerciseId;
      commit((draft) => {
        const item = draft.workout.find((exercise) => exercise.id === id);
        if (item) item.collapsed = !item.collapsed;
      });
      break;
    }
    case "complete-set": if (actionTarget.dataset.setId) completeSet(actionTarget.dataset.setId); break;
    case "external-complete-set": {
      const next = nextIncompleteSet();
      if (next) completeSet(next.setItem.id);
      else showToast("当前训练的所有组已经完成");
      break;
    }
    case "add-set": {
      const exerciseId = actionTarget.dataset.exerciseId;
      commit((draft) => {
        const exercise = draft.workout.find((item) => item.id === exerciseId);
        if (!exercise) return;
        const last = exercise.sets.at(-1);
        exercise.sets.push({ id: uid("set"), typeId: last?.typeId ?? "work", weight: last?.weight ?? 0, reps: last?.reps ?? 8, targetMin: last?.targetMin ?? 6, targetMax: last?.targetMax ?? 8, restSeconds: exercise.restSeconds, completed: false });
      });
      break;
    }
    case "set-exercise-rest": {
      const seconds = Number(actionTarget.dataset.seconds ?? state.defaultRestSeconds);
      commit((draft) => {
        const exercise = draft.workout.find((item) => item.id === draft.selectedWorkoutExerciseId);
        if (!exercise) return;
        exercise.restSeconds = seconds;
        exercise.sets.forEach((setItem) => { if (!setItem.completed) setItem.restSeconds = seconds; });
      });
      showToast(seconds ? `自动休息已设为 ${formatTime(seconds)}` : "已关闭该动作的自动休息");
      break;
    }
    case "warmup-calculator": commit((draft) => {
      const exercise = draft.workout.find((item) => item.id === draft.selectedWorkoutExerciseId);
      if (!exercise) return;
      const workSet = exercise.sets.find((setItem) => draft.setTypes.find((type) => type.id === setItem.typeId)?.semantic === "work") ?? exercise.sets[0];
      const targetWeight = workSet?.weight ?? 0;
      const warmups = [0.4, 0.6, 0.8].map((ratio, index) => ({ id: uid("set"), typeId: "warmup", weight: Math.round(targetWeight * ratio / 2.5) * 2.5, reps: [10, 6, 3][index], targetMin: [10, 6, 3][index], targetMax: [10, 6, 3][index], restSeconds: [60, 75, 90][index], completed: false }));
      exercise.sets = [...warmups, ...exercise.sets.filter((setItem) => setItem.typeId !== "warmup")];
      draft.modal = "none";
      draft.selectedWorkoutExerciseId = null;
    }); showToast("已按工作重量生成 3 组热身"); break;
    case "plate-calculator": commit((draft) => { draft.modal = "plate-calculator"; }); break;
    case "toggle-superset": commit((draft) => {
      const index = draft.workout.findIndex((item) => item.id === draft.selectedWorkoutExerciseId);
      if (index < 0) return;
      const current = draft.workout[index];
      if (current.supersetId) {
        const group = current.supersetId;
        draft.workout.forEach((item) => { if (item.supersetId === group) item.supersetId = null; });
      } else if (draft.workout[index + 1]) {
        const group = String.fromCharCode(65 + draft.workout.filter((item) => item.supersetId).length);
        current.supersetId = group;
        draft.workout[index + 1].supersetId = group;
      }
      draft.modal = "none";
    }); showToast("超级组设置已更新"); break;
    case "replace-workout-exercise": commit((draft) => { draft.exerciseSelectionMode = "replace"; draft.replaceWorkoutExerciseId = draft.selectedWorkoutExerciseId; draft.modal = "exercise-library"; }); break;
    case "move-workout-exercise": commit((draft) => {
      const index = draft.workout.findIndex((item) => item.id === draft.selectedWorkoutExerciseId);
      const nextIndex = actionTarget.dataset.direction === "up" ? index - 1 : index + 1;
      if (index < 0 || nextIndex < 0 || nextIndex >= draft.workout.length) return;
      [draft.workout[index], draft.workout[nextIndex]] = [draft.workout[nextIndex], draft.workout[index]];
      draft.modal = "none";
    }); showToast("动作顺序已更新"); break;
    case "delete-last-set": commit((draft) => {
      const exercise = draft.workout.find((item) => item.id === draft.selectedWorkoutExerciseId);
      if (exercise && exercise.sets.length > 1) exercise.sets.pop();
      draft.modal = "none";
    }); showToast("最后一组已删除"); break;
    case "remove-workout-exercise": commit((draft) => { draft.workout = draft.workout.filter((item) => item.id !== draft.selectedWorkoutExerciseId); draft.modal = "none"; draft.selectedWorkoutExerciseId = null; }); showToast("动作已从本次训练移除"); break;
    case "edit-set-rest": {
      const id = actionTarget.dataset.setId;
      if (!id) break;
      commit((draft) => {
        const match = draft.workout.flatMap((exercise) => exercise.sets).find((setItem) => setItem.id === id);
        if (match) match.restSeconds = match.restSeconds === 120 ? 150 : match.restSeconds === 150 ? 90 : 120;
      });
      showToast("本组休息时间已更新");
      break;
    }
    case "toggle-batch": commit((draft) => { draft.batchMode = !draft.batchMode; draft.selectedSetIds = []; }); break;
    case "select-set": {
      const id = actionTarget.dataset.setId;
      if (!id) break;
      commit((draft) => {
        draft.selectedSetIds = draft.selectedSetIds.includes(id) ? draft.selectedSetIds.filter((item) => item !== id) : [...draft.selectedSetIds, id];
      });
      break;
    }
    case "apply-batch": {
      const weightRange = document.querySelector<HTMLInputElement>("[data-batch-range='weight']");
      const repsRange = document.querySelector<HTMLInputElement>("[data-batch-range='reps']");
      const weightDelta = Number(weightRange?.value ?? 0);
      const repsDelta = Number(repsRange?.value ?? 0);
      commit((draft) => {
        draft.workout.flatMap((exercise) => exercise.sets).forEach((setItem) => {
          if (draft.selectedSetIds.includes(setItem.id) && !setItem.completed) {
            setItem.weight = Math.max(0, setItem.weight + weightDelta);
            setItem.reps = Math.max(0, setItem.reps + repsDelta);
          }
        });
        draft.selectedSetIds = [];
      });
      showToast("批量修改已应用，可在正式端提供撤销");
      break;
    }
    case "manage-set-types": commit((draft) => { draft.modal = "set-types"; }); break;
    case "edit-set-type": commit((draft) => { draft.selectedSetTypeId = actionTarget.dataset.id ?? null; }); break;
    case "toggle-timer": commit((draft) => {
      if (draft.timer.status === "running") {
        draft.timer.status = "paused";
        draft.timer.targetEndAt = null;
      } else if (draft.timer.status === "paused") {
        draft.timer.status = "running";
        draft.timer.targetEndAt = Date.now() + draft.timer.remainingSeconds * 1000;
      }
    }); break;
    case "add-rest": commit((draft) => {
      draft.timer.remainingSeconds += 15;
      draft.timer.durationSeconds += 15;
      if (draft.timer.status === "running") draft.timer.targetEndAt = Date.now() + draft.timer.remainingSeconds * 1000;
    }); break;
    case "skip-rest": commit((draft) => { draft.timer.status = "idle"; draft.timer.targetEndAt = null; draft.timer.remainingSeconds = 0; }); showToast("休息已跳过"); break;
    case "finish-workout": commit((draft) => { draft.modal = "workout-save"; draft.timer.status = "idle"; }); break;
    case "close-completion": commit((draft) => { draft.modal = "none"; draft.page = "today"; draft.workoutStarted = false; draft.workoutStartedAt = null; }); break;
    case "custom-exercise": commit((draft) => { draft.modal = "custom-exercise"; }); break;
    case "add-exercise": {
      const id = actionTarget.dataset.id;
      if (!id) break;
      const definition = getExercise(id, state.customExercises);
      const routineSelection = state.exerciseSelectionMode === "routine-add" || state.exerciseSelectionMode === "routine-replace";
      const replacing = state.exerciseSelectionMode === "replace" || state.exerciseSelectionMode === "routine-replace";
      commit((draft) => {
        if (draft.exerciseSelectionMode === "routine-add" || draft.exerciseSelectionMode === "routine-replace") {
          const collection = draft.routines.find((routine) => routine.id === draft.selectedRoutineId)?.exercises ?? draft.workout;
          if (draft.exerciseSelectionMode === "routine-replace" && draft.replaceRoutineExerciseId) {
            const target = collection.find((item) => item.id === draft.replaceRoutineExerciseId);
            if (target) target.exerciseId = id;
          } else if (!collection.some((item) => item.exerciseId === id)) {
            collection.push({ id: uid("routine-exercise"), exerciseId: id, restSeconds: draft.defaultRestSeconds, collapsed: false, sets: [1,2,3].map(() => ({ id: uid("set"), typeId: "work", weight: 0, reps: 8, targetMin: 6, targetMax: 8, restSeconds: draft.defaultRestSeconds, completed: false })) });
          }
          draft.exerciseSelectionMode = "add";
          draft.replaceRoutineExerciseId = null;
          draft.modal = "routine-builder";
          draft.selectedExerciseId = null;
          return;
        }
        if (draft.exerciseSelectionMode === "replace" && draft.replaceWorkoutExerciseId) {
          const target = draft.workout.find((item) => item.id === draft.replaceWorkoutExerciseId);
          if (target) target.exerciseId = id;
          draft.exerciseSelectionMode = "add";
          draft.replaceWorkoutExerciseId = null;
        } else if (!draft.workout.some((item) => item.exerciseId === id)) {
          draft.workout.push({ id: uid("workout-exercise"), exerciseId: id, restSeconds: draft.defaultRestSeconds, collapsed: false, sets: [1, 2, 3].map(() => ({ id: uid("set"), typeId: "work", weight: 0, reps: 8, targetMin: 6, targetMax: 8, restSeconds: draft.defaultRestSeconds, completed: false })) });
        }
        if (!draft.workoutStarted) draft.workoutElapsedSeconds = 0;
        draft.workoutStarted = true;
        draft.workoutDraft = false;
        draft.workoutStartedAt ??= Date.now();
        draft.page = "train";
        draft.modal = "none";
        draft.selectedExerciseId = null;
      });
      showToast(`${definition.name} 已${replacing ? "替换" : "加入"}${routineSelection ? "训练模板" : "当前训练"}`);
      break;
    }
    case "analyze-exercise": {
      const id = actionTarget.dataset.id;
      if (!id) break;
      commit((draft) => { draft.recognitionExerciseId = id; draft.page = "recognition"; draft.selectedExerciseId = null; draft.recognitionStatus = "idle"; });
      break;
    }
    case "choose-demo-video": commit((draft) => { draft.recognitionStatus = "ready"; }); showToast("演示视频已载入"); break;
    case "start-analysis": if (state.recognitionStatus === "ready") simulateAnalysis(); break;
    case "reset-recognition": commit((draft) => { draft.recognitionStatus = "idle"; draft.recognitionProgress = 0; }); break;
    case "retry-recognition": commit((draft) => { draft.scenario = "normal"; }); showToast("连接已恢复"); break;
    case "attach-analysis": commit((draft) => { draft.analysisAttached = true; }); showToast("识别结果已关联到杠铃卧推"); break;
    case "save-cue": commit((draft) => { draft.savedCue = true; draft.modal = "none"; draft.selectedRep = null; }); showToast("提示已保存到下一组"); break;
    case "rep-detail": commit((draft) => { draft.selectedRep = Number(actionTarget.dataset.rep ?? 1); draft.modal = "rep-detail"; }); break;
    case "open-plan-builder": commit((draft) => { draft.modal = "plan-builder"; }); break;
    case "convert-last": {
      const latest = state.workoutHistory[0];
      const sourceExercises = latest?.exerciseIds ?? state.workout.map((item) => item.exerciseId);
      const routineId = uid("routine");
      commit((draft) => {
        const sourceByExercise = new Map<string, WorkoutExercise>();
        draft.workout.forEach((item) => sourceByExercise.set(item.exerciseId, item));
        draft.routines.forEach((routine) => routine.exercises.forEach((item) => sourceByExercise.set(item.exerciseId, item)));
        const exercises = sourceExercises.map((exerciseId, index) => {
          const source = sourceByExercise.get(exerciseId);
          if (source) {
            const cloned = structuredClone(source);
            return {
              ...cloned,
              id: uid("routine-exercise"),
              collapsed: index !== 0,
              sets: cloned.sets.map((setItem) => ({ ...setItem, id: uid("set"), completed: false })),
            };
          }
          return {
            id: uid("routine-exercise"),
            exerciseId,
            restSeconds: draft.defaultRestSeconds,
            collapsed: index !== 0,
            sets: [1, 2, 3].map(() => ({ id: uid("set"), typeId: "work", weight: 0, reps: 8, targetMin: 6, targetMax: 8, restSeconds: draft.defaultRestSeconds, completed: false })),
          };
        });
        draft.routines.push({ id: routineId, name: `${latest?.name ?? "上次训练"} · 复制`, folderId: draft.routineFolders[0]?.id ?? "folder-strength", updatedAt: "2026-08-03", exercises });
        draft.selectedRoutineId = routineId;
        draft.routineBuilderReturn = "none";
        draft.page = "train";
        draft.trainView = "workout";
        draft.modal = "routine-builder";
      });
      showToast("已把上次训练复制为可编辑计划");
      break;
    }
    case "custom-plan": commit((draft) => { draft.modal = "plan-builder"; }); break;
    case "schedule-session": commit((draft) => { draft.modal = "schedule"; }); break;
    case "reschedule": commit((draft) => { draft.modal = "schedule"; }); break;
    case "remove-schedule": commit((draft) => { delete draft.scheduledWorkouts[draft.selectedCalendarDate]; }); showToast("训练安排已移除"); break;
    case "preview-plan": commit((draft) => { draft.selectedPlanSessionIndex = draft.selectedPlanSessionIndex === null ? 0 : null; }); break;
    case "toggle-plan-session": commit((draft) => { const index = Number(actionTarget.dataset.index ?? 0); draft.selectedPlanSessionIndex = draft.selectedPlanSessionIndex === index ? null : index; }); break;
    case "use-plan": {
      const plan = officialPlans.find((item) => item.id === actionTarget.dataset.id);
      if (plan) {
        commit((draft) => { draft.activePlanId = plan.id; draft.selectedPlanId = null; draft.selectedPlanSessionIndex = null; draft.modal = "none"; draft.page = "train"; draft.trainView = "plans"; });
        showToast(`${plan.title} 已设为当前计划`);
      }
      break;
    }
    case "save-plan-routine": {
      const plan = officialPlans.find((item) => item.id === actionTarget.dataset.id);
      const session = plan?.sessions[0];
      if (!plan || !session) break;
      commit((draft) => {
        draft.routines.push({ id: uid("routine"), name: `${plan.title} · ${session.name}`, folderId: draft.routineFolders[0]?.id ?? "folder-strength", updatedAt: "2026-08-03", exercises: session.exerciseIds.map((exerciseId, index) => ({ id: uid("routine-exercise"), exerciseId, restSeconds: 120, collapsed: index !== 0, sets: [1,2,3].map(() => ({ id: uid("set"), typeId: "work", weight: 0, reps: 8, targetMin: 6, targetMax: 8, restSeconds: 120, completed: false })) })) });
        draft.selectedPlanId = null;
        draft.page = "train";
        draft.trainView = "workout";
      });
      showToast("已保存为我的训练模板");
      break;
    }
    case "toggle-ai-data": commit((draft) => {
      if (!draft.aiConsentSeen && !draft.aiUseTrainingData) draft.modal = "ai-consent";
      else draft.aiUseTrainingData = !draft.aiUseTrainingData;
    }); break;
    case "approve-ai-data": commit((draft) => { draft.aiUseTrainingData = true; draft.aiConsentSeen = true; draft.modal = "none"; }); showToast("训练摘要授权已开启"); break;
    case "new-thread": commit((draft) => { draft.chat = [{ id: uid("message"), role: "assistant", body: "新对话已建立。可以直接描述你的训练问题。" }]; }); break;
    case "open-citation": commit((draft) => { draft.selectedCitation = Number(actionTarget.dataset.index ?? 0); draft.modal = "citation"; }); break;
    case "muscle-method": commit((draft) => { draft.modal = "muscle-method"; }); break;
    case "progress-metric": commit((draft) => { const metric = actionTarget.dataset.metric; if (metric === "best" || metric === "volume" || metric === "e1rm") draft.progressMetric = metric; }); break;
    case "load-thread": {
      const content = actionTarget.dataset.thread === "volume" ? "四日计划的训练量应该怎样分配？" : actionTarget.dataset.thread === "warmup" ? "硬拉正式组前应该怎样热身？" : "卧推停滞时应该调整重量还是训练量？";
      commit((draft) => { draft.chat = [{ id: uid("message"), role: "user", body: content }, { id: uid("message"), role: "assistant", body: "这是保存在本机的历史对话。继续提问时会使用当前知识库版本。" }]; });
      break;
    }
    default: break;
  }
});

app.addEventListener("input", (event) => {
  const target = event.target as HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement;
  if (target.dataset.batchRange === "weight") {
    const output = document.querySelector<HTMLOutputElement>("[data-batch-weight-output]");
    if (output) output.textContent = `${Number(target.value) >= 0 ? "+" : ""}${target.value} kg`;
  }
  if (target.dataset.batchRange === "reps") {
    const output = document.querySelector<HTMLOutputElement>("[data-batch-reps-output]");
    if (output) output.textContent = `${Number(target.value) >= 0 ? "+" : ""}${target.value} 次`;
  }
  if (target.dataset.field === "exercise-query") {
    const cursor = target instanceof HTMLInputElement ? target.selectionStart : null;
    commit((draft) => { draft.exerciseQuery = target.value; });
    requestAnimationFrame(() => {
      const search = document.querySelector<HTMLInputElement>('[data-field="exercise-query"]');
      if (!search) return;
      search.focus();
      if (cursor !== null) search.setSelectionRange(cursor, cursor);
    });
  }
  if (target.dataset.field === "plate-target") updatePlateCalculator();
});

app.addEventListener("change", (event) => {
  const target = event.target as HTMLInputElement | HTMLSelectElement;
  if (target instanceof HTMLInputElement && target.dataset.action === "recognition-file") {
    commit((draft) => { draft.recognitionStatus = target.files?.length ? "ready" : "idle"; });
    return;
  }
  if (target.dataset.field === "scenario") {
    commit((draft) => { draft.scenario = target.value as typeof state.scenario; });
  }
  if (target.dataset.field === "recognition-exercise") commit((draft) => { draft.recognitionExerciseId = target.value; });
  if (target.dataset.field === "recognition-camera") commit((draft) => { draft.recognitionCamera = target.value; });
  if (target.dataset.field === "plan-level") commit((draft) => { draft.planLevelFilter = target.value; });
  if (target.dataset.field === "plan-goal") commit((draft) => { draft.planGoalFilter = target.value; });
  if (target.dataset.field === "plan-equipment") commit((draft) => { draft.planEquipmentFilter = target.value; });
  if (target.dataset.field === "bar-weight") updatePlateCalculator();
  if (target.dataset.setField && target.dataset.setId) {
    if (target.dataset.setField === "typeId") {
      commit((draft) => {
        const match = draft.workout.flatMap((exercise) => exercise.sets).find((setItem) => setItem.id === target.dataset.setId);
        if (match && !match.completed && draft.setTypes.some((type) => type.id === target.value)) match.typeId = target.value;
      });
      return;
    }
    const value = Math.max(0, Number(target.value) || 0);
    commit((draft) => {
      const match = draft.workout.flatMap((exercise) => exercise.sets).find((setItem) => setItem.id === target.dataset.setId);
      if (!match || match.completed) return;
      if (target.dataset.setField === "weight") match.weight = value;
      if (target.dataset.setField === "reps") match.reps = Math.round(value);
      if (target.dataset.setField === "rpe") match.rpe = Math.min(10, Math.max(1, value));
    });
  }
});

app.addEventListener("click", (event) => {
  const target = event.target as HTMLElement;
  const muscle = target.closest<HTMLElement>("[data-muscle]")?.dataset.muscle;
  if (muscle) commit((draft) => { draft.exerciseMuscle = muscle; });
  const equipment = target.closest<HTMLElement>("[data-equipment]")?.dataset.equipment;
  if (equipment) commit((draft) => { draft.exerciseEquipment = equipment; });
});

app.addEventListener("submit", (event) => {
  event.preventDefault();
  const form = event.target as HTMLFormElement;
  if (form.dataset.form === "chat") {
    const data = new FormData(form);
    answerQuestion(String(data.get("question") ?? ""));
  }
  if (form.dataset.form === "set-type") {
    const data = new FormData(form);
    const label = String(data.get("label") ?? "").trim();
    const semantic = String(data.get("semantic") ?? "work") as SetSemantic;
    const typeId = String(data.get("id") ?? "");
    if (!label) return;
    commit((draft) => {
      const editing = draft.setTypes.find((type) => type.id === typeId);
      if (editing) {
        editing.label = label;
        editing.shortLabel = label.slice(0, 1);
        editing.semantic = semantic;
      } else {
        draft.setTypes.push({ id: uid("set-type"), label, shortLabel: label.slice(0, 1), semantic, color: "#72e4ff" });
      }
      draft.selectedSetTypeId = null;
      draft.modal = "none";
    });
    showToast(typeId ? `${label} 已更新` : `${label} 已添加`);
  }
  if (form.dataset.form === "plan-builder") {
    commit((draft) => { draft.modal = "none"; draft.activePlanId = "upper-lower-4"; draft.page = "train"; draft.trainView = "plans"; });
    showToast("12 周四日训练草案已生成，可继续编辑");
  }
  if (form.dataset.form === "exercise-note") {
    const data = new FormData(form);
    const exerciseId = String(data.get("exerciseId") ?? "");
    const scope = String(data.get("scope") ?? "library") as ExerciseResourceScope;
    const note = String(data.get("note") ?? "").trim();
    const link = String(data.get("link") ?? "").trim();
    if (!exerciseId) return;
    const returnToRoutine = state.selectedRoutineId !== null;
    commit((draft) => {
      draft.exerciseResources[exerciseId] ??= {};
      draft.exerciseResources[exerciseId][scope] = { note, link };
      draft.resourceEditorExerciseId = null;
      draft.modal = returnToRoutine ? "routine-builder" : "none";
    });
    showToast("动作备注和链接已保存");
  }
  if (form.dataset.form === "workout-settings") {
    const data = new FormData(form);
    const defaultRest = Number(data.get("defaultRest") ?? state.defaultRestSeconds);
    commit((draft) => {
      draft.workoutName = String(data.get("name") ?? draft.workoutName).trim() || draft.workoutName;
      draft.workoutNote = String(data.get("note") ?? "").trim();
      draft.defaultRestSeconds = defaultRest;
      const previousPlanId = String(data.get("previousPlanId") ?? "").trim();
      draft.previousPlanId = previousPlanId || null;
      draft.previousValueMode = previousPlanId ? "routine" : "exercise";
      draft.rpeTrackingEnabled = data.get("rpe") === "on";
      draft.livePrEnabled = data.get("pr") === "on";
      draft.modal = "none";
    });
    showToast("训练设置已保存");
  }
  if (form.dataset.form === "routine-builder") {
    const data = new FormData(form);
    const id = String(data.get("id") ?? "");
    const name = String(data.get("name") ?? "新训练模板").trim();
    const folderId = String(data.get("folder") ?? state.routineFolders[0]?.id ?? "folder-strength");
      const returnModal = state.routineBuilderReturn;
      commit((draft) => {
        const existing = draft.routines.find((routine) => routine.id === id);
        const savedRoutineId = existing?.id ?? uid("routine");
        const source = existing?.exercises ?? draft.workout;
      const exercises = source.map((item) => {
        const count = Math.min(12, Math.max(1, Number(data.get(`sets-${item.id}`) ?? item.sets.length)));
        const restSeconds = Math.max(0, Number(data.get(`rest-${item.id}`) ?? item.restSeconds));
        const weight = Math.max(0, Number(data.get(`weight-${item.id}`) ?? item.sets[0]?.weight ?? 0));
        const targetMin = Math.max(1, Number(data.get(`min-${item.id}`) ?? item.sets[0]?.targetMin ?? 6));
        const targetMax = Math.max(targetMin, Number(data.get(`max-${item.id}`) ?? item.sets[0]?.targetMax ?? 8));
        const typeId = String(data.get(`type-${item.id}`) ?? "work");
        const sets = Array.from({ length: count }, (_, index) => {
          const current = item.sets[index];
          const keepWarmup = current?.typeId === "warmup";
          return { id: current?.id ?? uid("set"), typeId: keepWarmup ? "warmup" : typeId, weight: keepWarmup ? current.weight : weight, reps: keepWarmup ? current.reps : targetMax, targetMin: keepWarmup ? current.targetMin : targetMin, targetMax: keepWarmup ? current.targetMax : targetMax, restSeconds: keepWarmup ? current.restSeconds : restSeconds, completed: false, rpe: current?.rpe };
        });
        return { ...item, restSeconds, collapsed: false, sets };
      });
        if (existing) {
        existing.name = name;
        existing.folderId = folderId;
        existing.exercises = exercises;
        existing.updatedAt = "2026-08-03";
        } else {
          draft.routines.push({ id: savedRoutineId, name, folderId, updatedAt: "2026-08-03", exercises });
        }
        if (returnModal === "workout-settings") {
          draft.previousPlanId = savedRoutineId;
          draft.previousValueMode = "routine";
        }
        draft.selectedRoutineId = null;
      draft.routineBuilderReturn = "none";
      draft.modal = returnModal === "workout-settings" ? "workout-settings" : returnModal === "schedule" ? "schedule" : "none";
    });
    showToast(id ? "训练模板已更新" : "训练模板已创建");
  }
  if (form.dataset.form === "routine-folder") {
    const data = new FormData(form);
    const name = String(data.get("name") ?? "").trim();
    if (!name) return;
    commit((draft) => { draft.routineFolders.push({ id: uid("folder"), name }); draft.modal = "none"; });
    showToast("模板文件夹已创建");
  }
  if (form.dataset.form === "workout-save") {
    const data = new FormData(form);
    const completedSets = state.workout.flatMap((exercise) => exercise.sets).filter((setItem) => setItem.completed);
    const name = String(data.get("name") ?? state.workoutName).trim() || "未命名训练";
    const date = String(data.get("date") ?? "2026-08-03");
    const time = String(data.get("time") ?? "18:30");
    const durationSeconds = Math.max(60, Number(data.get("duration") ?? 54) * 60);
    commit((draft) => {
      draft.workoutHistory.unshift({ id: uid("history"), name, date, startTime: time, durationSeconds, volume: completedSets.reduce((total, setItem) => total + setItem.weight * setItem.reps, 0), effectiveSets: completedSets.filter((setItem) => draft.setTypes.find((type) => type.id === setItem.typeId)?.semantic === "work").length, note: String(data.get("note") ?? "").trim(), exerciseIds: draft.workout.map((exercise) => exercise.exerciseId), prs: draft.livePrEnabled ? ["本次训练实时 PR"] : [] });
      draft.workoutName = name;
      draft.workoutNote = String(data.get("note") ?? "").trim();
      draft.workoutElapsedSeconds = durationSeconds;
      draft.workoutStartedAt = null;
      draft.workoutTimerPaused = true;
      draft.workoutCompleted = true;
      draft.selectedCalendarDate = date;
      draft.modal = "workout-complete";
    });
    showToast("训练已保存到记录和日历");
  }
  if (form.dataset.form === "workout-record") {
    const data = new FormData(form);
    const id = String(data.get("id") ?? "");
    commit((draft) => {
      const record = draft.workoutHistory.find((item) => item.id === id);
      if (record) {
        record.name = String(data.get("name") ?? record.name).trim() || record.name;
        record.note = String(data.get("note") ?? "").trim();
        record.date = String(data.get("date") ?? record.date);
        record.startTime = String(data.get("time") ?? record.startTime);
        record.durationSeconds = Math.max(60, Number(data.get("duration") ?? Math.round(record.durationSeconds / 60)) * 60);
        draft.selectedCalendarDate = record.date;
      }
      draft.modal = "none";
      draft.selectedRecordId = null;
    });
    showToast("训练记录已更新");
  }
  if (form.dataset.form === "schedule") {
    const data = new FormData(form);
    const date = String(data.get("date") ?? state.selectedCalendarDate);
    const workout = String(data.get("workout") ?? "上肢力量 A");
    commit((draft) => { draft.selectedCalendarDate = date; draft.scheduledWorkouts[date] = workout; draft.modal = "calendar"; });
    showToast(`${date} 已安排 ${workout}`);
  }
  if (form.dataset.form === "custom-exercise") {
    const data = new FormData(form);
    const name = String(data.get("name") ?? "").trim();
    if (!name) return;
    const muscle = String(data.get("muscle") ?? "胸部");
    const equipment = String(data.get("equipment") ?? "杠铃");
    const customExercise: Exercise = {
      id: uid("custom-exercise"),
      name,
      englishName: String(data.get("englishName") ?? "").trim() || name,
      family: muscle.includes("腿") ? "蹲" : muscle.includes("臀") ? "髋铰链" : muscle.includes("背") ? "拉" : muscle.includes("肩") ? "肩部孤立" : muscle.includes("手臂") ? "肘部孤立" : muscle.includes("腹") ? "核心" : "推",
      muscle,
      secondary: "用户定义",
      equipment,
      camera: "需要手动确认机位",
      cue: "自定义动作暂不提供自动技术提示。",
      loadMode: equipment === "自重" ? "bodyweight" : "total",
    };
    const routineSelection = state.exerciseSelectionMode === "routine-add" || state.exerciseSelectionMode === "routine-replace";
    const addingToBlankWorkout = state.workoutDraft;
    commit((draft) => {
      draft.customExercises.push(customExercise);
      const createWorkoutExercise = (): WorkoutExercise => ({ id: uid("workout-exercise"), exerciseId: customExercise.id, restSeconds: draft.defaultRestSeconds, collapsed: false, sets: [1, 2, 3].map(() => ({ id: uid("set"), typeId: "work", weight: 0, reps: 8, targetMin: 6, targetMax: 8, restSeconds: draft.defaultRestSeconds, completed: false })) });
      if (routineSelection) {
        const collection = draft.routines.find((routine) => routine.id === draft.selectedRoutineId)?.exercises ?? draft.workout;
        if (draft.exerciseSelectionMode === "routine-replace" && draft.replaceRoutineExerciseId) {
          const target = collection.find((item) => item.id === draft.replaceRoutineExerciseId);
          if (target) target.exerciseId = customExercise.id;
        } else collection.push(createWorkoutExercise());
        draft.exerciseSelectionMode = "add";
        draft.replaceRoutineExerciseId = null;
        draft.modal = "routine-builder";
        draft.page = "train";
      } else if (addingToBlankWorkout) {
        draft.workout.push(createWorkoutExercise());
        draft.workoutDraft = false;
        draft.workoutStarted = true;
        draft.workoutStartedAt = Date.now();
        draft.workoutElapsedSeconds = 0;
        draft.page = "train";
        draft.modal = "none";
      } else {
        draft.modal = "none";
        draft.page = "exercises";
        draft.exerciseQuery = name;
      }
    });
    showToast(routineSelection ? `${name} 已加入训练计划` : addingToBlankWorkout ? `${name} 已加入训练，计时开始` : `${name} 已创建并加入动作库`);
  }
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") closeAllModals();
});

window.setInterval(() => {
  if (state.timer.status === "running" && state.timer.targetEndAt) {
    const remaining = Math.max(0, Math.ceil((state.timer.targetEndAt - Date.now()) / 1000));
    if (remaining !== state.timer.remainingSeconds) {
      state.timer.remainingSeconds = remaining;
      persist();
      document.querySelectorAll<HTMLElement>("[data-timer-value]").forEach((node) => { node.textContent = formatTime(remaining); });
      const island = document.querySelector<HTMLElement>(".dynamic-island b");
      const lock = document.querySelector<HTMLElement>(".live-card > strong");
      const watch = document.querySelector<HTMLElement>(".watch-frame > span");
      if (island) island.textContent = formatTime(remaining);
      if (lock) lock.textContent = formatTime(remaining);
      if (watch) watch.textContent = formatTime(remaining);
      const ring = document.querySelector<HTMLElement>(".rest-ring");
      ring?.style.setProperty("--rest-progress", String(remaining / Math.max(1, state.timer.durationSeconds)));
    }
    if (remaining <= 0) {
      commit((draft) => { draft.timer.status = "idle"; draft.timer.targetEndAt = null; });
      showToast("休息结束，开始下一组");
    }
  }
  if (state.workoutStarted && !state.workoutTimerPaused) {
    const elapsed = state.workoutElapsedSeconds + (state.workoutStartedAt ? Math.max(0, Math.floor((Date.now() - state.workoutStartedAt) / 1000)) : 0);
    const node = document.querySelector<HTMLElement>("[data-workout-time]");
    if (node) node.textContent = `已训练 ${formatTime(elapsed)}`;
    const shortNode = document.querySelector<HTMLElement>("[data-workout-time-short]");
    if (shortNode) shortNode.textContent = formatTime(elapsed);
  }
}, 250);

if (state.timer.status === "running" && state.timer.targetEndAt && state.timer.targetEndAt <= Date.now()) {
  commit((draft) => { draft.timer.status = "idle"; draft.timer.targetEndAt = null; draft.timer.remainingSeconds = 0; });
}

void exercises.length;
