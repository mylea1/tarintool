import { exercises, getExercise, officialPlans, weekSchedule } from "./data";
import { state } from "./state";
import type { Exercise, ExerciseResourceScope, OfficialPlan, SetType, WorkoutExercise, WorkoutRecord, WorkoutSet } from "./types";

const icon = (name: string, weight: "regular" | "bold" | "fill" = "regular") =>
  `<i class="ph${weight === "regular" ? "" : `-${weight}`} ph-${name}" aria-hidden="true"></i>`;

const escapeHtml = (value: string) => value
  .replaceAll("&", "&amp;")
  .replaceAll("<", "&lt;")
  .replaceAll(">", "&gt;")
  .replaceAll('"', "&quot;")
  .replaceAll("'", "&#039;");

const exerciseCatalog = () => [...exercises, ...state.customExercises];
const resolveExercise = (id: string) => getExercise(id, state.customExercises);
const getExerciseResource = (exerciseId: string, scope: ExerciseResourceScope) => state.exerciseResources[exerciseId]?.[scope] ?? { note: "", link: "" };

export const formatTime = (totalSeconds: number) => {
  const value = Math.max(0, Math.floor(totalSeconds));
  const minutes = Math.floor(value / 60);
  const seconds = value % 60;
  return `${minutes.toString().padStart(2, "0")}:${seconds.toString().padStart(2, "0")}`;
};

const formatDuration = (totalSeconds: number) => {
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  return hours ? `${hours} 小时 ${minutes} 分` : `${minutes} 分钟`;
};

const workoutVolume = () => state.workout.flatMap((item) => item.sets).filter((setItem) => setItem.completed).reduce((total, setItem) => total + setItem.weight * setItem.reps, 0);
const currentWorkoutElapsed = () => state.workoutElapsedSeconds + (state.workoutStartedAt && !state.workoutTimerPaused ? Math.max(0, Math.floor((Date.now() - state.workoutStartedAt) / 1000)) : 0);
const calendarToday = "2026-08-03";
const calendarStatus = (iso: string) => {
  const completed = state.workoutHistory.some((record) => record.date === iso);
  const planned = Boolean(state.scheduledWorkouts[iso]);
  if (completed) return "completed" as const;
  if (planned && iso < calendarToday) return "missed" as const;
  if (planned) return "planned" as const;
  return "empty" as const;
};
const calendarStatusLabel = (status: ReturnType<typeof calendarStatus>) => ({ completed: "已完成", planned: "已安排", missed: "已安排但未完成", empty: "未安排" }[status]);

const monthDays = () => {
  const previousDays = [27, 28, 29, 30, 31].map((day) => ({ day, iso: `2026-07-${day}`, outside: true }));
  const currentDays = Array.from({ length: 31 }, (_, index) => ({ day: index + 1, iso: `2026-08-${String(index + 1).padStart(2, "0")}`, outside: false }));
  const nextDays = [1, 2, 3, 4, 5, 6].map((day) => ({ day, iso: `2026-09-0${day}`, outside: true }));
  return [...previousDays, ...currentDays, ...nextDays];
};

const navItems = [
  { id: "today", label: "主页", icon: "house" },
  { id: "train", label: "训练", icon: "barbell" },
  { id: "records", label: "记录", icon: "calendar-check" },
  { id: "exercises", label: "动作", icon: "books" },
  { id: "recognition", label: "识别", icon: "scan" },
  { id: "ai", label: "AI", icon: "chats-circle" },
  { id: "profile", label: "我的", icon: "user-circle" },
] as const;

const getPageMeta = () => ({
  today: ["主页", "训练、记录和计划概览"],
  train: ["训练", state.workoutStarted ? "保持专注，完成下一组" : state.workoutDraft ? "先选择动作，再开始计时" : "选择计划并开始训练"],
  records: ["记录", "训练日历、完成情况和历史记录"],
  exercises: ["动作库", "动作、机位与识别能力"],
  recognition: ["动作识别", "上传视频并查看可解释报告"],
  plans: ["训练计划", "周期、排程和下一次目标"],
  ai: ["知识库 AI", "有来源的训练问答"],
  progress: ["进步", "肌群分布和动作趋势"],
  profile: ["我的", "训练偏好、设备连接和隐私设置"],
} as const);

const renderNav = () => navItems.map((item) => `
  <button class="nav-item ${state.page === item.id ? "is-active" : ""}" data-page="${item.id}" aria-label="${item.label}" aria-current="${state.page === item.id ? "page" : "false"}">
    ${icon(item.icon, state.page === item.id ? "fill" : "regular")}
    <span>${item.label}</span>
  </button>
`).join("");

const renderTopbar = () => {
  const [title, subtitle] = getPageMeta()[state.page];
  const contextAction = state.page === "train" && state.workoutStarted
    ? null
    : state.page === "exercises"
    ? { action: "custom-exercise", label: "新建自定义动作", glyph: "plus" }
    : state.page === "ai"
      ? { action: "new-thread", label: "新建对话", glyph: "plus" }
      : state.page === "recognition"
        ? state.recognitionStatus !== "idle"
          ? { action: "reset-recognition", label: "重新选择视频", glyph: "arrow-counter-clockwise" }
          : { action: "choose-demo-video", label: "载入演示视频", glyph: "video-camera" }
        : state.page === "progress"
          ? { action: "muscle-method", label: "查看计算方法", glyph: "info" }
          : state.page === "profile"
            ? { action: "reset-prototype", label: "重置演示数据", glyph: "arrow-counter-clockwise" }
          : { action: "open-calendar", label: "打开完整月历", glyph: "calendar-dots" };
  return `
    <header class="topbar">
      <div>
        <h1>${title}</h1>
        <p>${subtitle}</p>
      </div>
      <div class="topbar-actions">
        <label class="scenario-control">
          <span>模拟场景</span>
          <select data-field="scenario" aria-label="切换模拟场景">
            <option value="normal" ${state.scenario === "normal" ? "selected" : ""}>正常</option>
            <option value="low-confidence" ${state.scenario === "low-confidence" ? "selected" : ""}>低置信度</option>
            <option value="offline" ${state.scenario === "offline" ? "selected" : ""}>离线</option>
            <option value="empty" ${state.scenario === "empty" ? "selected" : ""}>空数据</option>
          </select>
        </label>
        ${contextAction ? `<button class="icon-button context-action" data-action="${contextAction.action}" aria-label="${contextAction.label}" title="${contextAction.label}">${icon(contextAction.glyph)}</button>` : ""}
      </div>
    </header>
  `;
};

const completionStats = () => {
  const sets = state.workout.flatMap((item) => item.sets);
  const completed = sets.filter((set) => set.completed).length;
  return { completed, total: sets.length, percentage: sets.length ? Math.round((completed / sets.length) * 100) : 0 };
};

const renderWeek = () => `
  <div class="week-strip" aria-label="本周训练日历">
    ${weekSchedule.map((item) => `
      <button class="week-day is-${item.state}" data-action="calendar-day" data-date="${item.date}">
        <span>${item.day}</span>
        <b>${item.date}</b>
        <small>${item.label}</small>
      </button>
    `).join("")}
  </div>
`;

const renderToday = () => {
  if (state.scenario === "empty") {
    return `
      <section class="empty-state page-enter">
        <div class="empty-visual">${icon("calendar-plus")}</div>
        <h2>还没有安排训练</h2>
        <p>从官方计划选择一节，或直接开始空白训练。</p>
        <div class="button-row"><button class="primary-button" data-page="plans">浏览计划</button><button class="secondary-button" data-action="start-blank-workout">空白训练</button></div>
      </section>
    `;
  }

  const stats = completionStats();
  return `
    <div class="today-layout page-enter">
      <section class="next-session-panel">
        <div class="session-copy">
          <p class="context-label">8 月 1 日 星期六</p>
          <h2>${state.workoutStarted ? "训练进行中" : "上肢力量 A"}</h2>
          <p>${state.workoutStarted ? `已经完成 ${stats.completed}/${stats.total} 组，下一项是杠铃卧推正式组。` : "卧推、胸托划船、侧平举。预计 56 分钟。"}</p>
          <div class="session-actions">
            <button class="primary-button large" data-action="${state.workoutStarted ? "resume-workout" : "start-workout"}">
              ${icon(state.workoutStarted ? "play" : "barbell", "bold")}${state.workoutStarted ? "继续训练" : "开始训练"}
            </button>
            <button class="secondary-button large" data-page="plans">查看计划</button>
          </div>
        </div>
        <div class="target-lift" aria-label="下一次卧推目标">
          <div class="lift-arc" style="--progress: 72%">
            <span>下一次目标</span>
            <strong>82.5<small>kg</small></strong>
            <em>3 × 8</em>
          </div>
          <p>${icon("arrow-up-right", "bold")} 上节 80 kg 全部达到 8 次</p>
        </div>
      </section>

      <section class="week-section">
        <div class="section-heading"><div><h3>训练周</h3><p>点击日期查看或调整安排</p></div><button class="text-button" data-page="plans">打开日历 ${icon("arrow-right")}</button></div>
        ${renderWeek()}
      </section>

      <div class="today-lower-grid">
        <section class="progress-trajectory">
          <div class="section-heading"><div><h3>长期目标仍在推进</h3><p>引体向上重复次数</p></div><button class="icon-button" data-page="progress" aria-label="查看进步">${icon("arrow-up-right")}</button></div>
          <div class="trajectory-chart" aria-label="引体向上从 5 次进步到 8 次，长期目标 12 次">
            <svg viewBox="0 0 680 190" role="img">
              <path class="chart-guide" d="M20 145 C145 115 210 125 320 88 S520 55 660 22" />
              <path class="chart-line" d="M20 150 C135 135 190 142 285 108 S430 80 510 70" />
              <circle class="chart-point" cx="510" cy="70" r="7" />
              <text x="520" y="62">当前 8</text>
              <text x="600" y="20">目标 12</text>
            </svg>
          </div>
          <div class="trajectory-footer"><strong>+3 次</strong><span>过去 6 周</span><span>距离下一里程碑还差 1 次</span></div>
        </section>

        <section class="readiness-panel">
          <h3>今天的训练条件</h3>
          <div class="readiness-number"><strong>良好</strong><span>无需降低计划重量</span></div>
          <dl>
            <div><dt>计划完成率</dt><dd>91%</dd></div>
            <div><dt>最近训练</dt><dd>2 天前</dd></div>
            <div><dt>连续训练</dt><dd>7 周</dd></div>
          </dl>
          <button class="quiet-link" data-page="ai">问 AI 如何安排今天 ${icon("arrow-right")}</button>
        </section>
      </div>

      <section class="recent-lifts">
        <div class="section-heading"><div><h3>最近进步</h3><p>只展示值得注意的变化</p></div><button class="text-button" data-page="progress">全部趋势</button></div>
        <div class="lift-list">
          <button data-page="progress"><span class="lift-icon">${icon("barbell")}</span><span><b>杠铃卧推</b><small>80 kg × 8，重复次数纪录</small></span><strong>+1</strong></button>
          <button data-page="progress"><span class="lift-icon">${icon("trend-up")}</span><span><b>胸托划船</b><small>近四周训练量持续上升</small></span><strong>+8.4%</strong></button>
          <button data-page="recognition"><span class="lift-icon">${icon("scan")}</span><span><b>深蹲轨迹</b><small>最低点稳定性改善</small></span><strong>稳定</strong></button>
        </div>
      </section>
    </div>
  `;
};

const renderTodayFocused = () => {
  const stats = completionStats();
  const leadExercises = state.workout.slice(0, 3).map((item) => resolveExercise(item.exerciseId));
  const activePlan = officialPlans.find((plan) => plan.id === state.activePlanId) ?? officialPlans[0];
  return `
    <div class="home-focus page-enter">
      <section class="home-status" aria-label="本周训练状态">
        <span><small>本周</small><b>3 / 4</b><em>节训练</em></span>
        <span><small>连续</small><b>7</b><em>周</em></span>
        <button data-page="progress"><small>最新进步</small><b>+2.5</b><em>kg 卧推 ${icon("caret-right")}</em></button>
      </section>

      <section class="home-workout-card">
        <div class="home-workout-head"><div><p class="context-label">今天 18:30</p><h2>${state.workoutStarted ? "继续上肢力量 A" : "上肢力量 A"}</h2><p>${activePlan.title} / 预计 56 分钟</p></div><button class="icon-button" data-action="open-calendar" aria-label="打开完整月历">${icon("calendar-dots")}</button></div>
        <div class="home-exercise-stack" aria-label="今日动作">
          ${leadExercises.map((exercise) => `<button data-action="open-exercise-detail" data-id="${exercise.id}">${exercise.image ? `<img src="${exercise.image}" alt="${exercise.name}" />` : icon("person-simple-run")}<span>${exercise.name}</span></button>`).join("")}
        </div>
        ${state.workoutStarted ? `<div class="home-live-progress"><span><i style="width:${stats.percentage}%"></i></span><small>${stats.completed} / ${stats.total} 组已完成</small></div>` : ""}
        <button class="primary-button large home-primary-action" data-action="${state.workoutStarted ? "resume-workout" : "start-workout"}">${icon(state.workoutStarted ? "play" : "barbell", "bold")}${state.workoutStarted ? "继续训练" : "开始今天的训练"}</button>
      </section>

      <section class="home-digest" aria-label="训练信息摘要">
        <button data-action="open-plans"><span class="digest-icon">${icon("notebook")}</span><span><small>训练计划</small><b>${activePlan.title}</b><em>第 6 周 / 下一节周一</em></span>${icon("caret-right")}</button>
        <button data-page="progress"><span class="digest-icon">${icon("trend-up")}</span><span><small>下一次建议</small><b>卧推 82.5 kg</b><em>上次全部正式组达到次数上限</em></span>${icon("caret-right")}</button>
        <button data-page="recognition"><span class="digest-icon">${icon("scan")}</span><span><small>最近识别</small><b>${state.analysisAttached ? "已关联到训练" : "深蹲轨迹稳定"}</b><em>${state.savedCue ? "动作提示已保存" : "查看第 6-8 次重复反馈"}</em></span>${icon("caret-right")}</button>
      </section>

      <button class="home-calendar-link" data-action="open-calendar"><span>${icon("calendar-blank")}<b>8 月训练日历</b><small>查看全部日期和未来安排</small></span>${icon("arrow-right")}</button>
    </div>
  `;
};

const getSetType = (id: string): SetType => state.setTypes.find((type) => type.id === id) ?? state.setTypes[0];

const renderExerciseResource = (exerciseId: string, scope: ExerciseResourceScope, compact = false) => {
  const resource = getExerciseResource(exerciseId, scope);
  const hasContent = Boolean(resource.note || resource.link);
  return `
    <section class="exercise-resource ${compact ? "is-compact" : ""} ${hasContent ? "has-content" : "is-empty"}">
      <span class="resource-icon">${icon(resource.link ? "link" : "note-pencil")}</span>
      <span class="resource-copy">
        <b>${resource.note ? escapeHtml(resource.note) : "添加动作备注或教学链接"}</b>
        ${resource.link ? `<a href="${escapeHtml(resource.link)}" target="_blank" rel="noopener noreferrer">${icon("arrow-square-out")}打开教学链接</a>` : `<small>${scope === "library" ? "动作库备注会在详情中保留" : scope === "plan" ? "每次使用计划时都会显示" : "仅保存在本次训练中"}</small>`}
      </span>
      <button class="icon-button" type="button" data-action="edit-exercise-note" data-id="${exerciseId}" data-scope="${scope}" aria-label="${hasContent ? "编辑" : "添加"}动作备注和链接">${icon("pencil-simple")}</button>
    </section>
  `;
};

const renderSetRow = (workoutExercise: WorkoutExercise, setItem: WorkoutSet, index: number) => {
  const type = getSetType(setItem.typeId);
  const selected = state.selectedSetIds.includes(setItem.id);
  const previousRoutine = state.routines.find((routine) => routine.id === state.previousPlanId);
  const previousExercise = previousRoutine?.exercises.find((exercise) => exercise.exerciseId === workoutExercise.exerciseId);
  const previousSet = previousExercise?.sets.find((set) => getSetType(set.typeId).semantic === "work") ?? previousExercise?.sets[0];
  const previousWeight = previousSet?.weight ?? Math.max(0, setItem.weight - (type.semantic === "work" ? 2.5 : 0));
  const previousReps = previousSet?.reps ?? setItem.reps;
  return `
    <div class="set-row ${setItem.completed ? "is-complete" : ""} ${selected ? "is-selected" : ""}" data-set-id="${setItem.id}">
      ${state.batchMode ? `<label class="set-select"><input type="checkbox" data-action="select-set" data-set-id="${setItem.id}" aria-label="选择第 ${index + 1} 组" ${selected ? "checked" : ""} ${setItem.completed ? "disabled" : ""}/><span></span></label>` : ""}
      <select class="set-type-select" style="--set-color:${type.color}" data-set-field="typeId" data-set-id="${setItem.id}" aria-label="第 ${index + 1} 组类型" ${setItem.completed ? "disabled" : ""}>
        ${state.setTypes.map((option) => `<option value="${option.id}" ${option.id === setItem.typeId ? "selected" : ""}>${escapeHtml(option.label)}</option>`).join("")}
      </select>
      <span class="set-index">${index + 1}</span>
      <span class="set-previous" title="${state.previousPlanId ? `上次计划：${previousRoutine?.name ?? "训练计划"}` : "上次训练值"}"><small>${previousWeight}×${previousReps}</small><button data-action="edit-set-rest" data-set-id="${setItem.id}" title="设置本组休息" ${setItem.completed ? "disabled" : ""}>休 ${formatTime(setItem.restSeconds)}</button></span>
      <label><span>重量</span><input inputmode="decimal" value="${setItem.weight}" data-set-field="weight" data-set-id="${setItem.id}" aria-label="第 ${index + 1} 组重量" ${setItem.completed ? "disabled" : ""}/><small>kg</small></label>
      <label><span>次数</span><input inputmode="numeric" value="${setItem.reps}" data-set-field="reps" data-set-id="${setItem.id}" aria-label="第 ${index + 1} 组次数" ${setItem.completed ? "disabled" : ""}/><small>次</small></label>
      ${state.rpeTrackingEnabled ? `<label class="rpe-field"><span>RPE</span><input inputmode="decimal" value="${setItem.rpe ?? ""}" placeholder="-" data-set-field="rpe" data-set-id="${setItem.id}" aria-label="第 ${index + 1} 组 RPE" ${setItem.completed ? "disabled" : ""}/></label>` : ""}
      <button class="complete-set ${setItem.completed ? "is-complete" : ""}" data-action="complete-set" data-exercise-id="${workoutExercise.id}" data-set-id="${setItem.id}" aria-label="${setItem.completed ? "取消完成" : "完成本组"}">${icon(setItem.completed ? "check" : "circle", setItem.completed ? "bold" : "regular")}</button>
    </div>
  `;
};

const renderWorkoutExercise = (item: WorkoutExercise, index: number) => {
  const exercise = resolveExercise(item.exerciseId);
  const done = item.sets.filter((setItem) => setItem.completed).length;
  return `
    <article class="workout-exercise ${item.collapsed ? "is-collapsed" : ""}">
      <button class="exercise-header" data-action="toggle-exercise" data-exercise-id="${item.id}">
        <span class="exercise-order">${String(index + 1).padStart(2, "0")}</span>
        <span class="exercise-title"><b>${exercise.name}</b><small>${done}/${item.sets.length} 组完成，默认休息 ${formatTime(item.restSeconds)}</small></span>
        <span class="exercise-load">${item.sets.find((setItem) => setItem.typeId === "work")?.weight ?? item.sets[0]?.weight ?? 0}<small>kg</small></span>
        ${icon(item.collapsed ? "caret-down" : "caret-up")}
      </button>
      ${item.collapsed ? "" : `
        ${item.supersetId ? `<div class="superset-banner">${icon("arrows-left-right")}超级组 ${item.supersetId}</div>` : ""}
        ${renderExerciseResource(exercise.id, "workout", true)}
        <div class="set-table-header ${state.batchMode ? "has-select" : ""} ${state.rpeTrackingEnabled ? "has-rpe" : ""}"><span></span><span>组</span><span>上次 / 休息</span><span>重量</span><span>次数</span>${state.rpeTrackingEnabled ? "<span>RPE</span>" : ""}<span>完成</span></div>
        <div class="set-list">${item.sets.map((setItem, setIndex) => renderSetRow(item, setItem, setIndex)).join("")}</div>
        <div class="exercise-footer">
          <button class="quiet-link" data-action="add-set" data-exercise-id="${item.id}">${icon("plus")} 添加一组</button>
          <button class="quiet-link" data-action="open-exercise-actions" data-exercise-id="${item.id}">${icon("dots-three")} 更多</button>
          <button class="quiet-link" data-action="open-exercise-detail" data-id="${exercise.id}">${icon("info")} 动作详情</button>
        </div>
      `}
    </article>
  `;
};

const renderRestBanner = () => state.timer.status === "idle" ? "" : `
  <section class="rest-banner ${state.timer.status === "paused" ? "is-paused" : ""}">
    <div class="rest-ring" style="--rest-progress:${Math.max(0, Math.min(1, state.timer.remainingSeconds / Math.max(1, state.timer.durationSeconds)))}">
      <strong data-timer-value>${formatTime(state.timer.remainingSeconds)}</strong>
    </div>
    <div><span>${state.timer.status === "paused" ? "休息已暂停" : "组间休息"}</span><b>${state.timer.exerciseName}</b><small>下一项：${state.timer.nextSetLabel}</small></div>
    <div class="rest-actions">
      <button class="secondary-button" data-action="add-rest">+15 秒</button>
      <button class="secondary-button" data-action="toggle-timer" aria-label="${state.timer.status === "paused" ? "恢复休息计时" : "暂停休息计时"}" title="${state.timer.status === "paused" ? "恢复休息计时" : "暂停休息计时"}">${icon(state.timer.status === "paused" ? "play" : "pause", "bold")}</button>
      <button class="primary-button compact" data-action="skip-rest">跳过</button>
    </div>
  </section>
`;

const renderTrainTabs = () => `
  <div class="train-segments" role="tablist" aria-label="训练内容">
    ${([
      ["workout", "barbell", "训练"],
      ["plans", "notebook", "计划"],
    ] as const).map(([tab, tabIcon, label]) => `
      <button role="tab" aria-selected="${state.trainView === tab}" class="${state.trainView === tab ? "is-active" : ""}" data-action="train-tab" data-tab="${tab}">
        ${icon(tabIcon, state.trainView === tab ? "fill" : "regular")}<span>${label}</span>
      </button>
    `).join("")}
  </div>
`;

const renderMonthCalendar = (label = "2026 年 8 月") => `
  <section class="inline-month-calendar" aria-label="${label}训练日历">
    <header><div><p class="context-label">训练日历</p><h2>${label}</h2></div><button class="text-button" data-action="schedule-session">安排训练 ${icon("plus")}</button></header>
    <div class="month-calendar"><div class="month-weekdays">${["一","二","三","四","五","六","日"].map((day) => `<span>${day}</span>`).join("")}</div><div class="month-days">${monthDays().map((item) => {
      const scheduled = state.scheduledWorkouts[item.iso];
      const record = state.workoutHistory.find((history) => history.date === item.iso);
      const status = calendarStatus(item.iso);
      return `<button class="${item.outside ? "is-outside" : ""} is-${status} ${item.iso === state.selectedCalendarDate ? "is-selected" : ""} ${scheduled ? "has-workout" : ""} ${record ? "has-record" : ""}" data-action="calendar-day" data-date="${item.iso}" aria-label="${item.iso}${record ? ` 已完成 ${record.name}` : scheduled ? ` ${calendarStatusLabel(status)}：${scheduled}` : " 未安排"}"><b>${item.day}</b>${record ? `<i title="已完成"></i>` : scheduled ? `<i title="${calendarStatusLabel(status)}"></i>` : ""}</button>`;
    }).join("")}</div></div>
    <div class="calendar-legend"><span><i class="is-completed"></i>已完成</span><span><i class="is-planned"></i>已安排</span><span><i class="is-missed"></i>已安排但未完成</span></div>
  </section>
`;

const renderHistoryCard = (record: WorkoutRecord) => {
  const exercise = resolveExercise(record.exerciseIds[0] ?? "bench_press");
  return `<button class="history-card" data-action="open-workout-record" data-id="${record.id}"><span class="history-thumb">${exercise.image ? `<img src="${exercise.image}" alt="${exercise.name}" />` : icon("barbell")}</span><span><small>${record.date} ${record.startTime}</small><b>${record.name}</b><em>${record.effectiveSets} 有效组 / ${record.volume.toLocaleString()} kg / ${formatDuration(record.durationSeconds)}</em></span>${record.prs.length ? `<strong>${icon("trophy", "fill")}${record.prs.length} PR</strong>` : icon("caret-right")}</button>`;
};

const renderTrainingHistory = () => {
  const selectedRecords = state.workoutHistory.filter((record) => record.date === state.selectedCalendarDate);
  const selectedStatus = calendarStatus(state.selectedCalendarDate);
  const scheduledName = state.scheduledWorkouts[state.selectedCalendarDate];
  return `
    <section class="training-history page-enter">
      ${renderMonthCalendar()}
      <section class="selected-history-day">
        <div><small>${state.selectedCalendarDate}</small><h3>${selectedRecords.length ? `${selectedRecords.length} 次训练记录` : scheduledName ?? "没有训练记录"}</h3><p><span class="calendar-status-chip is-${selectedStatus}">${calendarStatusLabel(selectedStatus)}</span> ${selectedRecords.length ? "点击记录查看动作、训练量、备注和识别结果。" : selectedStatus === "missed" ? "这一天有计划但没有完成，可以补录或重新安排。" : "可以安排未来训练，也可以补录过去的训练。"}</p></div>
        <button class="secondary-button" data-action="log-past-workout">${icon("plus")}补录训练</button>
      </section>
      <div class="section-heading"><div><p class="context-label">全部记录</p><h2>训练历史</h2><p>保存后可继续编辑日期、时长、名称和备注。</p></div></div>
      <div class="history-list">${state.workoutHistory.length ? state.workoutHistory.map(renderHistoryCard).join("") : `<div class="inline-empty"><span>${icon("clock-counter-clockwise")}</span><b>还没有训练记录</b><p>完成训练后会自动保存在这里。</p></div>`}</div>
    </section>
  `;
};

const renderRecords = () => {
  const plannedCount = Object.keys(state.scheduledWorkouts).length;
  const missedCount = Object.keys(state.scheduledWorkouts).filter((date) => calendarStatus(date) === "missed").length;
  const selectedStatus = calendarStatus(state.selectedCalendarDate);
  const selectedWorkout = state.scheduledWorkouts[state.selectedCalendarDate];
  const selectedRecord = state.workoutHistory.find((record) => record.date === state.selectedCalendarDate);
  return `<div class="records-page page-enter"><section class="records-summary"><div><p class="context-label">训练记录中心</p><h2>先选日期，再处理记录</h2><p>月历只保留完成、安排和漏训状态；详细统计按需打开。</p></div><div class="records-summary-actions"><button class="secondary-button" data-action="open-record-overview">概览</button><button class="primary-button" data-action="schedule-session">安排训练</button></div></section>${renderMonthCalendar()}<section class="selected-history-day records-selected-day"><div><small>${state.selectedCalendarDate}</small><h3>${selectedRecord?.name ?? selectedWorkout ?? "今天还没有训练计划"}</h3><p><span class="calendar-status-chip is-${selectedStatus}">${calendarStatusLabel(selectedStatus)}</span> ${selectedRecord ? `${selectedRecord.effectiveSets} 有效组 / ${selectedRecord.volume.toLocaleString()} kg` : selectedStatus === "missed" ? "计划未完成，可以补录或重新安排" : "可以安排训练，或从训练页开始空白训练"}</p></div><div class="selected-day-actions">${selectedRecord ? `<button class="secondary-button" data-action="open-workout-record" data-id="${selectedRecord.id}">查看当天</button>` : `<button class="secondary-button" data-action="log-past-workout">补录训练</button>`}</div></section><details class="record-disclosure"><summary><span><b>本月概览</b><small>统计默认折叠，避免记录页变成看板</small></span>${icon("caret-down")}</summary><div class="records-metrics"><span><small>已完成</small><b>${state.workoutHistory.length}</b><em>次训练</em></span><span><small>已安排</small><b>${plannedCount}</b><em>个日期</em></span><span class="is-missed"><small>未完成计划</small><b>${missedCount}</b><em>需要处理</em></span></div></details><button class="records-history-trigger" data-action="open-record-history"><span>${icon("clock-counter-clockwise")}<span><b>查看全部训练历史</b><small>${state.workoutHistory.length} 次训练记录，点击后在弹窗中编辑</small></span></span>${icon("arrow-up-right")}</button></div>`;
};

const renderRecordOverviewModal = () => {
  const plannedCount = Object.keys(state.scheduledWorkouts).length;
  const missedCount = Object.keys(state.scheduledWorkouts).filter((date) => calendarStatus(date) === "missed").length;
  const totalVolume = state.workoutHistory.reduce((sum, record) => sum + record.volume, 0);
  return `<div class="simple-modal record-overview-modal"><header class="modal-header"><div><p class="context-label">记录概览</p><h2>本月训练状态</h2><p>只显示能帮助你安排下一次训练的数字。</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header><div class="records-metrics"><span><small>已完成</small><b>${state.workoutHistory.length}</b><em>次训练</em></span><span><small>训练量</small><b>${Math.round(totalVolume).toLocaleString()}</b><em>kg</em></span><span class="is-missed"><small>漏训</small><b>${missedCount}</b><em>个日期</em></span></div><div class="record-overview-list"><div><span>${icon("calendar-check", "fill")}</span><b>${plannedCount} 个日期已安排</b><small>点击月历日期可以查看计划是否完成</small></div><div><span>${icon("trend-up", "fill")}</span><b>下一步：保持当前计划</b><small>统计只作为提示，不会替代训练记录</small></div></div><button class="primary-button large" data-action="close-modal">返回记录</button></div>`;
};

const renderRecordHistoryModal = () => {
  return `<div class="simple-modal record-history-modal"><header class="modal-header"><div><p class="context-label">训练历史</p><h2>全部训练记录</h2><p>选择一条记录查看详情、备注和动作表现。</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header><div class="history-list">${state.workoutHistory.length ? state.workoutHistory.map(renderHistoryCard).join("") : `<div class="inline-empty"><span>${icon("clock-counter-clockwise")}</span><b>还没有训练记录</b><p>完成训练后会自动保存到这里。</p></div>`}</div><button class="secondary-button large" data-action="log-past-workout">${icon("plus")}补录一条训练</button></div>`;
};

const renderBlankWorkoutDraft = () => `
  <div class="blank-workout-draft page-enter">
    ${renderTrainTabs()}
    <section class="draft-hero"><div class="draft-icon">${icon("plus-circle", "fill")}</div><div><p class="context-label">空白训练</p><h2>先添加动作</h2><p>当前还没有动作，计时器不会启动。选择动作库中的动作，或创建自定义动作。</p></div></section>
    <div class="draft-actions"><button class="primary-button large" data-action="open-exercise-library">${icon("books")}从动作库选择</button><button class="secondary-button large" data-action="custom-exercise">${icon("plus")}创建自定义动作</button></div>
    <button class="text-button draft-cancel" data-action="cancel-blank-workout">取消空白训练</button>
  </div>
`;

const renderTrain = () => {
  if (state.workoutDraft) return renderBlankWorkoutDraft();
  if (!state.workoutStarted) {
    const visibleRoutines = state.routines.filter((routine) => state.routineFolderFilter === "all" || routine.folderId === state.routineFolderFilter);
    if (state.trainView === "plans") return `<div class="train-hub page-enter">${renderTrainTabs()}${renderPlans()}</div>`;
    if (state.trainView === "history") return renderTrainingHistory();
    return `
      <div class="train-start page-enter">
        ${renderTrainTabs()}
        <section class="empty-workout-cta"><span>${icon("lightning", "fill")}</span><div><p class="context-label">自由训练</p><h2>空白训练</h2><p>从动作库临时组合训练，并自动带入上次重量与次数。</p></div><button class="primary-button" data-action="start-blank-workout">开始</button></section>
        <section class="routine-library">
          <div class="section-heading"><div><p class="context-label">已保存计划</p><h2>我的训练计划</h2><p>点击开始直接训练，点击计划名称可以调整动作和训练变量。</p></div><div><button class="icon-button" data-action="manage-routine-folders" aria-label="管理计划文件夹">${icon("folder-simple")}</button><button class="icon-button" data-action="new-routine" aria-label="新建训练计划">${icon("plus")}</button></div></div>
          <div class="routine-folder-filter"><button class="${state.routineFolderFilter === "all" ? "is-active" : ""}" data-action="routine-folder-filter" data-id="all">全部</button>${state.routineFolders.map((folder) => `<button class="${state.routineFolderFilter === folder.id ? "is-active" : ""}" data-action="routine-folder-filter" data-id="${folder.id}">${folder.name}</button>`).join("")}</div>
          <div class="routine-list">${visibleRoutines.length ? visibleRoutines.map((routine) => {
            const lead = resolveExercise(routine.exercises[0]?.exerciseId ?? "bench_press");
            const setCount = routine.exercises.reduce((total, exercise) => total + exercise.sets.length, 0);
            return `<article class="routine-card"><button class="routine-main" data-action="edit-routine" data-id="${routine.id}"><span>${lead.image ? `<img src="${lead.image}" alt="${lead.name}" />` : icon("barbell")}</span><span><b>${routine.name}</b><small>${routine.exercises.length} 个动作 / ${setCount} 组</small><em>${routine.exercises.slice(0, 3).map((exercise) => resolveExercise(exercise.exerciseId).name).join(" / ")}</em></span>${icon("caret-right")}</button><button class="primary-button compact" data-action="start-routine" data-id="${routine.id}">${icon("play", "fill")}开始</button></article>`;
          }).join("") : `<div class="inline-empty"><span>${icon("notebook")}</span><b>还没有保存的训练计划</b><p>点击右上角加号创建，或从上次训练生成计划。</p></div>`}</div>
        </section>
        <div class="start-options"><button class="secondary-button large" data-action="convert-last">${icon("copy")}上次训练转模板</button><button class="secondary-button large" data-action="open-calendar">${icon("calendar-dots")}训练日历</button></div>
      </div>
    `;
  }

  const stats = completionStats();
  return `
    <div class="active-workout page-enter">
      <div class="workout-toolbar">
        <button class="workout-time-button" data-action="workout-settings"><span class="live-state">训练中</span><strong>${escapeHtml(state.workoutName)}</strong><small data-workout-time>${state.workoutTimerPaused ? `计时已暂停 · ${formatTime(currentWorkoutElapsed())}` : `已训练 ${formatTime(currentWorkoutElapsed())}`}</small></button>
        <div>
          <button class="secondary-button" data-action="manage-set-types">组类型</button>
          <button class="secondary-button" data-action="workout-settings">设置</button>
          <button class="secondary-button ${state.batchMode ? "is-active" : ""}" data-action="toggle-batch">${state.batchMode ? "退出批量" : "批量修改"}</button>
          <button class="danger-button" data-action="finish-workout">结束训练</button>
        </div>
      </div>
      <section class="live-workout-stats"><span><small>时长</small><b data-workout-time-short>${formatTime(currentWorkoutElapsed())}</b></span><span><small>训练量</small><b>${workoutVolume().toLocaleString()} kg</b></span><span><small>完成组</small><b>${stats.completed} / ${stats.total}</b></span></section>
      ${renderRestBanner()}
      <div class="workout-progress" style="--workout-progress:${stats.percentage / 100}"><span></span></div>
      <div class="workout-list">${state.workout.map(renderWorkoutExercise).join("")}</div>
      <button class="add-exercise-button" data-action="open-exercise-library">${icon("plus-circle")}添加动作</button>
      ${state.batchMode ? renderBatchBar() : ""}
    </div>
  `;
};

const renderBatchBar = () => `
  <div class="batch-bar">
    <div><b>已选 ${state.selectedSetIds.length} 组</b><span>拖动增量后应用到所选组</span></div>
    <label><span>重量增量 <output data-batch-weight-output>+2.5 kg</output></span><input type="range" min="-10" max="10" step="0.5" value="2.5" data-batch-range="weight" /></label>
    <label><span>次数增量 <output data-batch-reps-output>+1 次</output></span><input type="range" min="-5" max="5" step="1" value="1" data-batch-range="reps" /></label>
    <button class="primary-button compact" data-action="apply-batch" ${state.selectedSetIds.length === 0 ? "disabled" : ""}>应用</button>
  </div>
`;

const renderExerciseCard = (exercise: Exercise) => `
  <button class="exercise-card" data-action="open-exercise-detail" data-id="${exercise.id}">
    <span class="exercise-image ${exercise.image ? "has-image" : "is-placeholder"}">
      ${exercise.image ? `<img src="${exercise.image}" alt="${exercise.name}起始姿势插画" loading="lazy" />` : `${icon("person-simple-run")}<small>素材待补</small>`}
    </span>
    <span class="exercise-card-copy"><b>${exercise.name}</b><small>${exercise.englishName}</small><em>${exercise.muscle} / ${exercise.equipment}</em>${(() => { const resource = getExerciseResource(exercise.id, "library"); return resource.note || resource.link ? `<i>${icon(resource.link ? "link" : "note")}${resource.link ? "教学链接" : "私人备注"}</i>` : ""; })()}</span>
    ${icon("caret-right")}
  </button>
`;

const filteredExercises = () => exerciseCatalog().filter((exercise) => {
  const query = state.exerciseQuery.trim().toLocaleLowerCase();
  const matchesQuery = !query || exercise.name.includes(query) || exercise.englishName.toLocaleLowerCase().includes(query);
  const matchesMuscle = state.exerciseMuscle === "全部" || exercise.muscle.includes(state.exerciseMuscle) || exercise.secondary.includes(state.exerciseMuscle);
  const matchesEquipment = state.exerciseEquipment === "全部" || exercise.equipment === state.exerciseEquipment;
  return matchesQuery && matchesMuscle && matchesEquipment;
});

const renderExerciseLibrary = (embedded = false) => {
  const muscles = ["全部", "胸部", "背", "肩", "腿", "臀", "手臂", "腹"];
  const equipment = ["全部", "杠铃", "哑铃", "绳索", "固定器械", "自重"];
  const filtered = filteredExercises();
  return `
    <div class="library-shell ${embedded ? "is-embedded" : ""}">
      <header class="modal-header"><div><p class="context-label">动作素材与识别能力</p><h2>动作库</h2><p>${exerciseCatalog().length} 个动作，32 个支持视频识别，11 组许可起止插图</p></div>${embedded ? `<span class="library-count">${filtered.length}</span>` : `<button class="icon-button" data-action="close-modal" aria-label="关闭动作库">${icon("x")}</button>`}</header>
      <div class="library-search"><label>${icon("magnifying-glass")}<input type="search" value="${escapeHtml(state.exerciseQuery)}" data-field="exercise-query" placeholder="搜索动作" aria-label="搜索动作" /></label><button class="secondary-button" data-action="custom-exercise">${icon("plus")}自定义动作</button></div>
      <div class="equipment-filter">${equipment.map((item) => `<button class="filter-chip ${state.exerciseEquipment === item ? "is-active" : ""}" data-equipment="${item}">${item}</button>`).join("")}</div>
      <div class="library-layout">
        <nav class="muscle-filter" aria-label="按肌群筛选">${muscles.map((item) => `<button class="${state.exerciseMuscle === item ? "is-active" : ""}" data-muscle="${item}">${item}</button>`).join("")}</nav>
        <section class="exercise-grid" aria-live="polite">
          ${filtered.length ? filtered.map(renderExerciseCard).join("") : `<div class="inline-empty"><span>${icon("magnifying-glass")}</span><b>没有匹配动作</b><p>清除搜索词或切换筛选条件。</p></div>`}
        </section>
      </div>
      <footer class="license-note">动作插画：Everkinetic / wger，CC BY-SA 3.0。缺少插画的动作在正式发布前补齐许可素材。</footer>
    </div>
  `;
};

const renderExerciseDetail = (exercise: Exercise) => {
  const imageEnd = exercise.image?.replace("_0.png", "_1.png");
  const selectingForRoutine = state.exerciseSelectionMode === "routine-add" || state.exerciseSelectionMode === "routine-replace";
  const replacing = state.exerciseSelectionMode === "replace" || state.exerciseSelectionMode === "routine-replace";
  return `
    <div class="detail-sheet">
      <header class="modal-header"><div><p class="context-label">${exercise.family} / ${exercise.muscle}</p><h2>${exercise.name}</h2><p>${exercise.englishName}</p></div><button class="icon-button" data-action="close-exercise-detail" aria-label="关闭动作详情">${icon("x")}</button></header>
      <div class="detail-media ${exercise.image ? "" : "is-placeholder"}">
        ${exercise.image ? `<figure><img src="${exercise.image}" alt="${exercise.name}起始姿势"/><figcaption>起始</figcaption></figure><figure><img src="${imageEnd}" alt="${exercise.name}结束姿势"/><figcaption>关键位置</figcaption></figure>` : `<div>${icon("person-simple-run")}<p>正式发布前补齐同风格起止图</p></div>`}
      </div>
      <dl class="exercise-facts"><div><dt>主要肌群</dt><dd>${exercise.muscle}</dd></div><div><dt>辅助肌群</dt><dd>${exercise.secondary}</dd></div><div><dt>器械</dt><dd>${exercise.equipment}</dd></div><div><dt>推荐机位</dt><dd>${exercise.camera}</dd></div></dl>
      <section class="coach-cue"><span>${icon("crosshair")}</span><div><b>识别重点</b><p>${exercise.cue}</p></div></section>
      ${renderExerciseResource(exercise.id, "library")}
      <div class="detail-actions"><button class="secondary-button large" data-action="analyze-exercise" data-id="${exercise.id}">${icon("scan")}分析这个动作</button><button class="primary-button large" data-action="add-exercise" data-id="${exercise.id}">${icon(replacing ? "arrows-clockwise" : "plus")}${replacing ? "替换为这个动作" : selectingForRoutine ? "加入训练模板" : "加入训练"}</button></div>
    </div>
  `;
};

const renderRecognitionReport = () => {
  if (state.scenario === "low-confidence") {
    return `
      <section class="recognition-report low-confidence">
        <div class="report-status">${icon("warning-circle")}<span><b>无法可靠判断</b><small>人物下半身被器械遮挡，且机位偏正面。</small></span></div>
        <div class="retake-guide"><h3>重新拍摄建议</h3><ol><li>手机放在训练凳侧前方约 2.5 米处。</li><li>画面包含头部、髋部、双脚和完整杠铃路径。</li><li>保持镜头固定，不要使用跟拍。</li></ol></div>
        <button class="primary-button" data-action="reset-recognition">重新选择视频</button>
      </section>
    `;
  }
  return `
    <section class="recognition-report">
      <div class="report-lead">
        <div><p class="context-label">杠铃卧推 / 侧前方</p><h2>8 次重复已分段</h2><p>主要动作路径稳定。首先修正第 6-8 次的杠铃回落位置。</p></div>
        <div class="evidence-badge"><strong>高</strong><span>证据质量</span></div>
      </div>
      <div class="score-split">
        <article><span>主要动作</span><strong>87</strong><p>肘部屈伸、触胸深度和推起节奏一致。</p></article>
        <article><span>耦合支撑</span><strong>78</strong><p>上背接触稳定，第 7 次出现轻微肩部前移。</p></article>
        <article><span>稳定性</span><strong>82</strong><p>髋部未明显抬离训练凳，脚部位置稳定。</p></article>
      </div>
      <div class="priority-cue"><span>${icon("target", "fill")}</span><div><small>下一组只关注这一点</small><h3>让杠铃回落到胸骨下段</h3><p>后两次回落位置向头部移动约一个拳头距离。下一组保持前臂垂直，不需要刻意加快速度。</p></div><button class="secondary-button ${state.savedCue ? "is-active" : ""}" data-action="save-cue">${state.savedCue ? "已保存" : "保存提示"}</button></div>
      <div class="rep-timeline"><div class="section-heading"><div><h3>逐次重复</h3><p>点击异常重复可查看时间点</p></div><span>00:04 - 00:31</span></div><div>${[91,89,90,88,86,81,76,74].map((value, index) => `<button class="${value < 80 ? "needs-attention" : ""}" data-action="rep-detail" data-rep="${index + 1}"><span>${index + 1}</span><i style="height:${value}%"></i><small>${value}</small></button>`).join("")}</div></div>
      <div class="report-actions"><button class="secondary-button" data-action="reset-recognition">分析另一个视频</button><button class="primary-button" data-action="attach-analysis">${state.analysisAttached ? "已关联训练" : "关联到本次训练"}</button></div>
    </section>
  `;
};

const renderRecognition = () => {
  if (state.scenario === "offline") {
    return `<section class="error-state page-enter"><span>${icon("cloud-slash")}</span><h2>识别服务暂时不可用</h2><p>训练记录仍可离线使用。恢复网络后再上传视频。</p><button class="secondary-button" data-action="retry-recognition">重试连接</button></section>`;
  }
  const selected = resolveExercise(state.recognitionExerciseId);
  return `
    <div class="recognition-page page-enter">
      ${state.recognitionStatus === "complete" ? renderRecognitionReport() : `
        <section class="capture-workspace">
          <div class="camera-stage ${state.recognitionStatus === "processing" ? "is-processing" : ""}">
            <div class="camera-frame">
              <span class="frame-corner top-left"></span><span class="frame-corner top-right"></span><span class="frame-corner bottom-left"></span><span class="frame-corner bottom-right"></span>
              ${state.recognitionStatus === "processing" ? `<div class="scan-line"></div><div class="processing-copy"><strong>${state.recognitionProgress}%</strong><span>正在分段重复并检查证据</span></div>` : `${icon("video-camera")}<strong>${state.recognitionStatus === "ready" ? "视频已就绪" : "拖入或选择一段训练视频"}</strong><p>建议 10-45 秒，保持镜头固定和全身可见。</p>`}
            </div>
          </div>
          <div class="capture-controls">
            <div class="field-group"><label for="recognition-exercise">动作</label><select id="recognition-exercise" data-field="recognition-exercise">${exerciseCatalog().map((exercise) => `<option value="${exercise.id}" ${exercise.id === state.recognitionExerciseId ? "selected" : ""}>${exercise.name}</option>`).join("")}</select><small>请选择实际拍摄的动作，自动识别不确定时会拒绝评分。</small></div>
            <div class="field-group"><label for="recognition-camera">拍摄机位</label><select id="recognition-camera" data-field="recognition-camera"><option ${state.recognitionCamera === "侧前方 30-45°" ? "selected" : ""}>侧前方 30-45°</option><option ${state.recognitionCamera === "正侧面" ? "selected" : ""}>正侧面</option><option ${state.recognitionCamera === "正前方" ? "selected" : ""}>正前方</option><option ${state.recognitionCamera === "侧后方 30-45°" ? "selected" : ""}>侧后方 30-45°</option></select><small>${selected.camera} 最适合判断这个动作。</small></div>
            <div class="privacy-note">${icon("shield-check")}<span><b>临时云端分析</b><small>结果确认下载后删除原视频，异常任务最长保留 24 小时。</small></span></div>
            <input class="sr-only" type="file" accept="video/*" id="video-file" data-action="recognition-file" />
            <div class="capture-buttons"><label class="secondary-button large" for="video-file">${icon("upload-simple")}选择视频</label><button class="secondary-button large" data-action="choose-demo-video">使用演示视频</button><button class="primary-button large" data-action="start-analysis" ${state.recognitionStatus !== "ready" ? "disabled" : ""}>${icon("scan", "bold")}开始分析</button></div>
          </div>
        </section>
        <section class="recognition-capabilities"><div><b>主要动作</b><span>目标关节、负重路径、有效幅度</span></div><div><b>耦合支撑</b><span>肩胛、胸廓、骨盆和器械接触</span></div><div><b>证据质量</b><span>机位、遮挡、关键点可信度</span></div></section>
      `}
    </div>
  `;
};

const renderPlanCard = (plan: OfficialPlan, featured = false) => `
  <button class="plan-card ${featured ? "is-featured" : ""}" data-plan-id="${plan.id}">
    ${(() => { const exercise = resolveExercise(plan.sessions[0]?.exerciseIds[0] ?? "bench_press"); return `<span class="plan-cover">${exercise.image ? `<img src="${exercise.image}" alt="${exercise.name}" />` : icon("barbell")}</span>`; })()}
    <span class="plan-meta"><b>${plan.level}</b><small>${plan.days} 天/周</small><small>${plan.weeks} 周</small></span>
    <span class="plan-title"><strong>${plan.title}</strong><small>${plan.subtitle}</small></span>
    <span class="plan-focus">${plan.focus}</span>
    ${icon("arrow-up-right")}
  </button>
`;

const renderPlans = () => {
  const filteredPlans = officialPlans.filter((plan) => {
    const matchesLevel = state.planLevelFilter === "全部" || plan.level.includes(state.planLevelFilter);
    const matchesGoal = state.planGoalFilter === "全部" || plan.focus.includes(state.planGoalFilter);
    const equipment = plan.sessions.flatMap((session) => session.exerciseIds).map((id) => resolveExercise(id).equipment);
    const matchesEquipment = state.planEquipmentFilter === "全部" || equipment.includes(state.planEquipmentFilter);
    return matchesLevel && matchesGoal && matchesEquipment;
  });
  return `
  <div class="plans-page plans-focused page-enter">
    <section class="active-plan-summary">
      <div><p class="context-label">当前计划 / 第 6 周</p><h2>${(officialPlans.find((plan) => plan.id === state.activePlanId) ?? officialPlans[0]).title}</h2><p>本周完成 3 / 4 节，下一节安排在周一。</p></div>
      <button class="icon-button" data-plan-id="${state.activePlanId}" aria-label="查看当前计划">${icon("caret-right")}</button>
      <div class="active-plan-actions"><button class="primary-button" data-action="start-plan-session" data-id="${state.activePlanId}" data-session-index="0">${icon("play", "bold")}开始下一节</button><button class="secondary-button" data-action="open-calendar">${icon("calendar-dots")}月历</button></div>
    </section>
    <section class="plan-quick-actions" aria-label="计划操作">
      <button data-action="open-plan-builder">${icon("sparkle")}<span><b>生成计划</b><small>规则校验的 AI 草案</small></span></button>
      <button data-action="custom-plan">${icon("pencil-simple")}<span><b>手动创建</b><small>自定义周期和训练日</small></span></button>
      <button data-action="convert-last">${icon("copy")}<span><b>复制上次训练</b><small>自动应用重量建议</small></span></button>
    </section>
    <section class="official-plans compact-plan-library"><div class="section-heading"><div><h3>官方计划库</h3><p>可保存完整计划，也可只保存其中一节训练</p></div></div><div class="plan-library-filters"><label><span>经验</span><select data-field="plan-level">${["全部","中级","中高级"].map((value) => `<option ${state.planLevelFilter === value ? "selected" : ""}>${value}</option>`).join("")}</select></label><label><span>目标</span><select data-field="plan-goal">${["全部","力量","肌肥大","增肌"].map((value) => `<option ${state.planGoalFilter === value ? "selected" : ""}>${value}</option>`).join("")}</select></label><label><span>器械</span><select data-field="plan-equipment">${["全部","杠铃","哑铃","固定器械"].map((value) => `<option ${state.planEquipmentFilter === value ? "selected" : ""}>${value}</option>`).join("")}</select></label></div><div class="plan-scroll">${filteredPlans.length ? filteredPlans.map((plan) => renderPlanCard(plan)).join("") : `<div class="inline-empty"><span>${icon("funnel")}</span><b>没有匹配计划</b><p>调整经验、目标或器械筛选。</p></div>`}</div></section>
  </div>
  `;
};

const renderPlanDetail = (plan: OfficialPlan) => `
  <div class="detail-sheet plan-detail">
    <header class="modal-header"><div><p class="context-label">${plan.level} / ${plan.focus}</p><h2>${plan.title}</h2><p>${plan.subtitle}</p></div><button class="icon-button" data-action="close-plan-detail" aria-label="关闭计划详情">${icon("x")}</button></header>
    <div class="plan-stats"><div><strong>${plan.days}</strong><span>每周训练</span></div><div><strong>${plan.weeks}</strong><span>周期周数</span></div><div><strong>双重</strong><span>默认渐进</span></div></div>
    <section class="plan-sessions"><h3>首周结构</h3>${plan.sessions.map((session, index) => { const sessionExercises = session.exerciseIds.map(resolveExercise); const lead = sessionExercises[0]; const expanded = state.selectedPlanSessionIndex === index; return `<div class="${expanded ? "is-expanded" : ""}"><span class="session-thumb">${lead?.image ? `<img src="${lead.image}" alt="${lead.name}" />` : icon("barbell")}</span><span class="session-copy"><small>${session.day}</small><b>${session.name}</b><em>${sessionExercises.slice(0, 3).map((exercise) => exercise.name).join(" / ")}</em><small>${session.exercises} 个动作 / ${session.duration}</small></span><button class="icon-button" data-action="toggle-plan-session" data-index="${index}" aria-label="${expanded ? "收起" : "查看"}训练内容">${icon(expanded ? "caret-up" : "caret-down")}</button>${expanded ? `<div class="session-exercise-list">${sessionExercises.map((exercise) => `<article><button class="session-exercise-main" data-action="open-exercise-detail" data-id="${exercise.id}">${exercise.image ? `<img src="${exercise.image}" alt="${exercise.name}" />` : icon("person-simple-run")}<span><b>${exercise.name}</b><small>${exercise.muscle} / ${exercise.equipment}</small></span>${icon("caret-right")}</button>${renderExerciseResource(exercise.id, "plan", true)}</article>`).join("")}</div>` : ""}</div>`; }).join("")}</section>
    <section class="progression-rule"><span>${icon("trend-up")}</span><div><b>默认加重规则</b><p>全部正式组达到次数上限时，下一次按器械最小增量加重。每次建议都会说明原因。</p></div></section>
    <div class="detail-actions plan-detail-actions"><button class="primary-button large" data-action="start-plan-session" data-id="${plan.id}" data-session-index="${state.selectedPlanSessionIndex ?? 0}">${icon("play", "bold")}开始${plan.sessions[state.selectedPlanSessionIndex ?? 0]?.name ?? "这一节"}</button><div class="plan-secondary-actions"><button class="secondary-button large" data-action="save-plan-routine" data-id="${plan.id}">保存单节模板</button><button class="secondary-button large" data-action="use-plan" data-id="${plan.id}">设为当前计划</button></div></div>
  </div>
`;

const renderAi = () => `
  <div class="ai-layout page-enter">
    <aside class="thread-list"><button class="new-thread" data-action="new-thread">${icon("plus")}新对话</button><div><button class="is-active" data-action="load-thread" data-thread="bench"><b>卧推停滞怎么调整</b><small>今天</small></button><button data-action="load-thread" data-thread="volume"><b>四日计划的训练量</b><small>昨天</small></button><button data-action="load-thread" data-thread="warmup"><b>硬拉前的热身安排</b><small>7 月 28 日</small></button></div><p>对话只保存在当前设备</p></aside>
    <section class="chat-panel">
      <header class="chat-header"><div><h2>训练知识库</h2><p>回答附带来源，无法证实时会明确说明。</p></div><button class="data-toggle ${state.aiUseTrainingData ? "is-on" : ""}" data-action="toggle-ai-data" role="switch" aria-checked="${state.aiUseTrainingData}"><span></span><b>基于我的训练数据</b></button></header>
      ${state.scenario === "offline" ? `<div class="inline-status is-warning">${icon("wifi-slash")}当前离线。可以查看本地对话，但无法请求新的知识库回答。</div>` : ""}
      <div class="chat-messages" aria-live="polite">
        ${state.chat.map((message) => `<article class="message is-${message.role}"><span class="message-avatar">${message.role === "assistant" ? "K" : "梁"}</span><div><p>${escapeHtml(message.body)}</p>${message.citations?.length ? `<div class="citations"><span>依据</span>${message.citations.map((citation, index) => `<button data-action="open-citation" data-index="${index}"><b>${citation.title}</b><small>${citation.detail}</small>${icon("arrow-square-out")}</button>`).join("")}</div>` : ""}</div></article>`).join("")}
        ${state.aiTyping ? `<article class="message is-assistant"><span class="message-avatar">K</span><div class="answer-skeleton"><i></i><i></i><i></i></div></article>` : ""}
      </div>
      ${state.chat.length === 1 ? `<div class="suggested-prompts"><button data-prompt="我卧推 80 kg 做到了 3 组 8 次，下一次应该怎么加重？">卧推达到次数上限，如何加重？</button><button data-prompt="中长期计划没完成时，应该怎样调整而不是直接放弃？">长期目标落后时怎样调整？</button><button data-prompt="热身组是否应该计算训练量？">热身组是否计入训练量？</button></div>` : ""}
      <form class="chat-composer" data-form="chat"><textarea name="question" rows="1" placeholder="${state.scenario === "offline" ? "离线时无法提问" : "输入训练问题"}" aria-label="输入训练问题" ${state.scenario === "offline" ? "disabled" : ""}></textarea><button class="primary-button" type="submit" ${state.aiTyping || state.scenario === "offline" ? "disabled" : ""} aria-label="发送问题">${icon("arrow-up", "bold")}</button></form>
      <p class="ai-disclaimer">不是医疗诊断。疼痛或伤病问题请咨询合格专业人员。</p>
    </section>
  </div>
`;

const muscleFigure = (side: "front" | "back", muscles: string[]) => `
  <div class="muscle-figure" aria-label="${side === "front" ? "正面" : "背面"}肌群训练分布">
    <img src="/assets/muscles/male-${side}-base.svg" alt="" />
    ${muscles.map((muscle, index) => `<img class="muscle-overlay intensity-${Math.min(3, index + 1)}" src="/assets/muscles/male-${side}-${muscle}.svg" alt="" />`).join("")}
    <span>${side === "front" ? "正面" : "背面"}</span>
  </div>
`;

const renderProgress = () => {
  if (state.scenario === "empty") {
    return `<section class="empty-state page-enter"><div class="empty-visual">${icon("chart-line-up")}</div><h2>完成两次训练后生成趋势</h2><p>我们会自动为有有效数据的动作创建图表。</p><button class="primary-button" data-action="start-workout">开始第一次训练</button></section>`;
  }
  return `
    <div class="progress-page page-enter">
      <section class="progress-hero">
        <div><p class="context-label">过去 6 周</p><h2>没有达到 12 次，但你已经从 5 次做到 8 次。</h2><p>计划落后 1 周。下一里程碑是稳定完成 9 次，而不是重置目标。</p><div class="milestone-row"><span><b>+3</b> 重复次数</span><span><b>+6.8%</b> 估算力量</span><span><b>7</b> 连续训练周</span></div></div>
        <div class="goal-orbit"><span>当前</span><strong>8</strong><small>/ 12 次</small><i></i></div>
      </section>
      <div class="progress-grid">
        <section class="muscle-distribution"><div class="section-heading"><div><h3>本周肌群分布</h3><p>基于有效正式组的估算</p></div><button class="text-button" data-action="muscle-method">查看算法</button></div><div class="body-pair">${muscleFigure("front", ["chest", "deltoids", "quadriceps"])}${muscleFigure("back", ["upper-back", "triceps", "gluteal"])}</div><div class="muscle-legend"><span><i></i>主要刺激</span><span><i></i>辅助刺激</span></div></section>
        <section class="weekly-heatmap"><div class="section-heading"><div><h3>每周训练热力</h3><p>硬组数，不代表精确生理刺激</p></div><span>8 月 1 日</span></div><div class="heatmap-grid"><span></span>${["一","二","三","四","五","六","日"].map((day) => `<b>${day}</b>`).join("")}${["胸部","背部","肩部","股四头","臀部","手臂"].map((muscle, row) => `<span>${muscle}</span>${[0,1,2,3,4,5,6].map((column) => `<i style="--heat:${((row * 2 + column * 3) % 5) / 4}" title="${muscle} ${column + 1}"></i>`).join("")}`).join("")}</div></section>
      </div>
      <section class="exercise-trend"><div class="section-heading"><div><h3>杠铃卧推</h3><p>自动创建于第 2 次有效训练</p></div><div class="metric-switch"><button class="${state.progressMetric === "best" ? "is-active" : ""}" data-action="progress-metric" data-metric="best">最佳组</button><button class="${state.progressMetric === "volume" ? "is-active" : ""}" data-action="progress-metric" data-metric="volume">训练量</button><button class="${state.progressMetric === "e1rm" ? "is-active" : ""}" data-action="progress-metric" data-metric="e1rm">估算 1RM</button></div></div><div class="trend-chart"><svg viewBox="0 0 920 260" role="img" aria-label="卧推趋势"><line x1="30" y1="220" x2="890" y2="220"/><line x1="30" y1="150" x2="890" y2="150"/><line x1="30" y1="80" x2="890" y2="80"/><path d="${state.progressMetric === "volume" ? "M40 212 C170 180 240 198 350 142 S610 130 875 68" : state.progressMetric === "e1rm" ? "M40 200 C180 196 270 168 390 155 S650 104 875 74" : "M40 205 C150 198 190 182 280 188 S440 145 540 152 S700 104 875 78"}"/><circle cx="875" cy="${state.progressMetric === "volume" ? "68" : state.progressMetric === "e1rm" ? "74" : "78"}" r="7"/><text x="790" y="52">${state.progressMetric === "volume" ? "6,842 kg" : state.progressMetric === "e1rm" ? "101.3 kg" : "80 kg × 8"}</text></svg></div><div class="trend-stats"><span><small>周期起点</small><b>${state.progressMetric === "volume" ? "5,120 kg" : state.progressMetric === "e1rm" ? "91.8 kg" : "72.5 kg × 8"}</b></span><span><small>当前最佳</small><b>${state.progressMetric === "volume" ? "6,842 kg" : state.progressMetric === "e1rm" ? "101.3 kg" : "80 kg × 8"}</b></span><span><small>下一次建议</small><b>82.5 kg × 6-8</b></span></div></section>
      <section class="distribution-trend"><div class="section-heading"><div><h3>肌群训练量趋势</h3><p>最近四周硬组数</p></div><button class="text-button" data-action="muscle-method">计算方法</button></div><div class="stacked-bars">${[19,23,21,27].map((value, index) => `<div><span>第 ${index + 3} 周</span><i><b style="--bar:${value / 30}"></b><em style="--bar:${(value - 5) / 30}"></em></i><strong>${value} 组</strong></div>`).join("")}</div></section>
    </div>
  `;
};

const renderDevicePanel = () => {
  if (!state.devicePanelOpen) return "";
  const active = state.timer.status !== "idle";
  return `
    <aside class="device-panel is-open" aria-label="系统界面模拟">
      <header><div><h2>系统界面模拟</h2><p>用于验证信息密度，不代表 Web 原生能力。</p></div><button class="icon-button" data-action="toggle-device-panel" aria-label="关闭设备预览">${icon("x")}</button></header>
      <section><h3>iPhone 灵动岛</h3><div class="dynamic-island ${active ? "is-live" : ""}"><span class="island-mark">K</span><b>${active ? formatTime(state.timer.remainingSeconds) : "休息未开始"}</b><small>${active ? state.timer.exerciseName : "完成一组后自动出现"}</small></div></section>
      <section><h3>锁屏实时活动</h3><div class="lock-screen"><div class="lock-time">18:42</div><div class="live-card"><header><span>KILO</span><small>组间休息</small></header><strong>${active ? formatTime(state.timer.remainingSeconds) : "02:30"}</strong><p>${active ? `${state.timer.exerciseName} / ${state.timer.nextSetLabel}` : "杠铃卧推 / 正式组 2"}</p><div><button data-action="toggle-timer">${icon(active && state.timer.status === "running" ? "pause" : "play")}</button><button data-action="external-complete-set">完成本组</button><button data-action="skip-rest">跳过</button></div><footer>iOS 17+ 可直接操作，iOS 16.1-16.x 只读</footer></div></div></section>
      <section><h3>Apple Watch</h3><div class="watch-frame"><span>${active ? formatTime(state.timer.remainingSeconds) : "02:30"}</span><b>${active ? state.timer.exerciseName : "杠铃卧推"}</b><small>${active ? state.timer.nextSetLabel : "正式组 2 / 80 kg × 8"}</small><button data-action="external-complete-set">${icon("check", "bold")}完成</button></div></section>
      <section><h3>Android 通知</h3><div class="android-notification"><span>${icon("timer")}</span><div><b>${active ? `${formatTime(state.timer.remainingSeconds)} 后开始下一组` : "训练休息计时"}</b><small>KILO / ${active ? state.timer.exerciseName : "等待完成一组"}</small><button data-action="external-complete-set">完成本组</button><button data-action="skip-rest">跳过</button></div></div></section>
    </aside>
  `;
};

const renderProfile = () => {
  const connections = state.deviceConnections;
  const connectionRow = (id: keyof typeof connections, iconName: string, title: string, detail: string) => `<button class="profile-setting-row" data-action="toggle-device-connection" data-device="${id}"><span class="profile-row-icon">${icon(iconName)}</span><span><b>${title}</b><small>${detail}</small></span><strong class="connection-status ${connections[id] ? "is-connected" : ""}">${connections[id] ? "已连接" : "连接"}</strong></button>`;
  return `<div class="profile-page page-enter"><section class="profile-hero"><div class="profile-avatar">K</div><div><p class="context-label">本地训练档案</p><h2>KILO Athlete</h2><p>数据保存在当前设备，训练记录不会自动上传。</p></div><span class="profile-local-badge">本地模式</span></section><section class="profile-section"><header><div><p class="context-label">训练偏好</p><h2>让记录页只留下你需要的设置</h2></div></header><button class="profile-setting-row" data-action="workout-settings"><span class="profile-row-icon">${icon("timer")}</span><span><b>训练设置</b><small>默认休息 ${formatTime(state.defaultRestSeconds)} · ${state.rpeTrackingEnabled ? "显示 RPE" : "隐藏 RPE"}</small></span>${icon("caret-right")}</button><button class="profile-setting-row" data-action="manage-set-types"><span class="profile-row-icon">${icon("list-bullets")}</span><span><b>组类型</b><small>${state.setTypes.length} 个类型，使用选择器切换</small></span>${icon("caret-right")}</button><button class="profile-setting-row" data-action="toggle-ai-data"><span class="profile-row-icon">${icon("brain")}</span><span><b>AI 读取训练摘要</b><small>${state.aiUseTrainingData ? "已允许，回答会先展示发送字段" : "默认关闭，不读取本地训练数据"}</small></span><strong class="connection-status ${state.aiUseTrainingData ? "is-connected" : ""}">${state.aiUseTrainingData ? "已开启" : "关闭"}</strong></button></section><section class="profile-section"><header><div><p class="context-label">设备连接</p><h2>锁屏、手表和通知</h2><p>连接状态只影响原生端能力，Web 端使用模拟预览。</p></div><button class="secondary-button compact" data-action="toggle-device-panel">预览</button></header>${connectionRow("appleWatch", "watch", "Apple Watch", "双向同步训练组完成和休息计时")}${connectionRow("liveActivity", "broadcast", "iPhone 灵动岛", "显示当前动作和休息倒计时")}${connectionRow("androidNotifications", "bell", "Android 通知", "锁屏完成组、暂停和跳过休息")}</section><section class="profile-section profile-danger-zone"><header><div><p class="context-label">数据与隐私</p><h2>可恢复、可重置</h2><p>当前是 Web 原型，重置只会清除本机模拟数据。</p></div></header><div class="profile-action-row"><button class="secondary-button" data-action="reset-prototype">${icon("arrow-counter-clockwise")}重置演示数据</button><button class="secondary-button" data-action="show-settings">查看隐私说明</button></div></section></div>`;
};

const renderSetTypesModal = () => {
  const editing = state.setTypes.find((type) => type.id === state.selectedSetTypeId);
  return `
    <div class="simple-modal set-types-modal"><header class="modal-header"><div><h2>组类型</h2><p>名称可以修改，统计语义保持明确。</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header><div class="set-type-list">${state.setTypes.map((type) => `<div class="${editing?.id === type.id ? "is-editing" : ""}"><span style="--set-color:${type.color}">${type.shortLabel}</span><b>${type.label}</b><small>${type.semantic === "warmup" ? "热身，不参与自动加重" : type.semantic === "work" ? "参与进步和自动建议" : "不进入统计"}</small><button class="icon-button" data-action="edit-set-type" data-id="${type.id}" aria-label="编辑 ${type.label}">${icon("pencil-simple")}</button></div>`).join("")}</div><form data-form="set-type" class="inline-form"><input type="hidden" name="id" value="${editing?.id ?? ""}"/><label><span>${editing ? "修改名称" : "新类型名称"}</span><input name="label" maxlength="8" value="${escapeHtml(editing?.label ?? "")}" placeholder="例如：顶组" required /></label><label><span>统计语义</span><select name="semantic"><option value="work" ${editing?.semantic === "work" ? "selected" : ""}>正式有效组</option><option value="warmup" ${editing?.semantic === "warmup" ? "selected" : ""}>热身组</option><option value="excluded" ${editing?.semantic === "excluded" ? "selected" : ""}>不计入统计</option></select></label><button class="primary-button" type="submit">${editing ? "保存修改" : "添加类型"}</button></form></div>
  `;
};

const renderAiConsent = () => `
  <div class="simple-modal consent-modal"><header class="modal-header"><div><h2>授权最小训练摘要</h2><p>只在本次提问中发送以下字段，云端不保存。</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header><div class="consent-data"><div>${icon("check-circle")}最近 4 周动作、重量、次数和有效组</div><div>${icon("check-circle")}当前计划目标与采纳的重量建议</div><div>${icon("x-circle")}不发送视频、完整数据库、姓名或设备标识</div></div><div class="detail-actions"><button class="secondary-button large" data-action="close-modal">暂不授权</button><button class="primary-button large" data-action="approve-ai-data">允许本次及后续提问</button></div></div>
`;

const renderPlanBuilder = () => `
  <div class="simple-modal plan-builder"><header class="modal-header"><div><h2>生成训练计划</h2><p>规则引擎先确定边界，AI 只生成可编辑草案。</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header><form data-form="plan-builder"><div class="form-grid"><label><span>训练目标</span><select name="goal"><option>增肌与力量</option><option>最大力量</option><option>肌肥大</option></select></label><label><span>每周训练</span><select name="days"><option>4 天</option><option>3 天</option><option>5 天</option><option>6 天</option></select></label><label><span>周期长度</span><select name="weeks"><option>12 周</option><option>8 周</option><option>16 周</option><option>24 周</option></select></label><label><span>单次时长</span><select name="duration"><option>60 分钟</option><option>45 分钟</option><option>75 分钟</option></select></label></div><fieldset><legend>可用器械</legend><label><input type="checkbox" checked />杠铃</label><label><input type="checkbox" checked />哑铃</label><label><input type="checkbox" checked />绳索</label><label><input type="checkbox" checked />固定器械</label></fieldset><div class="validation-note">${icon("shield-check")}生成结果会在本地检查动作、组数、次数、休息和排程冲突。</div><button class="primary-button large" type="submit">生成可编辑草案</button></form></div>
`;

const renderWorkoutComplete = () => `
  <div class="completion-modal"><button class="icon-button completion-close" data-action="close-completion" aria-label="关闭训练总结">${icon("x")}</button><div class="pr-burst"><span>训练已保存</span><strong>${state.workoutHistory.length}</strong><small>累计训练</small><i></i></div><h2>记录已写入训练历史和完整月历。</h2><p>本次总训练量 ${workoutVolume().toLocaleString()} kg，动作图表和肌群分布已经更新。</p><div class="completion-metrics"><span><small>训练时长</small><b>${formatDuration(Math.max(60, currentWorkoutElapsed()))}</b></span><span><small>个人纪录</small><b>1 项</b></span><span><small>连续训练</small><b>7 周</b></span><span><small>近 7 天</small><b>4 / 4</b></span></div><div class="detail-actions"><button class="secondary-button large" data-action="close-completion">返回主页</button><button class="primary-button large" data-action="open-saved-history">查看训练记录</button></div></div>
`;

const renderCalendarModal = () => {
  const selectedWorkout = state.scheduledWorkouts[state.selectedCalendarDate];
  const selectedRecord = state.workoutHistory.find((record) => record.date === state.selectedCalendarDate);
  const selectedStatus = calendarStatus(state.selectedCalendarDate);
  return `
    <div class="simple-modal calendar-modal"><header class="modal-header"><div><p class="context-label">训练日历</p><h2>2026 年 8 月</h2><p>圆点区分已完成记录和未来安排。</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭月历">${icon("x")}</button></header>
      <div class="calendar-legend"><span><i class="is-completed"></i>已完成</span><span><i class="is-planned"></i>已安排</span><span><i class="is-missed"></i>已安排但未完成</span></div>
      <div class="month-calendar"><div class="month-weekdays">${["一","二","三","四","五","六","日"].map((day) => `<span>${day}</span>`).join("")}</div><div class="month-days">${monthDays().map((item) => { const workout = state.scheduledWorkouts[item.iso]; const record = state.workoutHistory.find((history) => history.date === item.iso); const status = calendarStatus(item.iso); return `<button class="${item.outside ? "is-outside" : ""} is-${status} ${item.iso === state.selectedCalendarDate ? "is-selected" : ""} ${workout ? "has-workout" : ""} ${record ? "has-record" : ""}" data-action="calendar-day" data-date="${item.iso}" aria-label="${item.iso}${record ? ` 已完成 ${record.name}` : workout ? ` ${calendarStatusLabel(status)}：${workout}` : " 未安排"}"><b>${item.day}</b>${record || workout ? `<i></i>` : ""}</button>`; }).join("")}</div></div>
      <section class="calendar-selection"><div><small>${state.selectedCalendarDate}</small><h3>${selectedRecord?.name ?? selectedWorkout ?? "休息或未安排"}</h3><p><span class="calendar-status-chip is-${selectedStatus}">${calendarStatusLabel(selectedStatus)}</span> ${selectedRecord ? `${selectedRecord.effectiveSets} 有效组 / ${selectedRecord.volume.toLocaleString()} kg` : selectedWorkout ? "18:30 / 点击可以改期或移除" : "可以安排计划训练或补录过去训练。"}</p></div><div>${selectedRecord ? `<button class="primary-button" data-action="open-workout-record" data-id="${selectedRecord.id}">查看记录</button>` : selectedWorkout ? `<button class="secondary-button" data-action="reschedule">改期</button><button class="danger-button" data-action="remove-schedule">移除</button>` : `<button class="primary-button" data-action="schedule-session">安排训练</button>`}</div></section>
    </div>
  `;
};

const renderScheduleModal = () => `
  <div class="simple-modal schedule-modal"><header class="modal-header"><div><h2>安排训练</h2><p>选择日期、时间和训练计划。</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header><form data-form="schedule"><label><span>日期</span><input type="date" name="date" value="${state.selectedCalendarDate}" required /></label><label><span>时间</span><input type="time" name="time" value="18:30" required /></label><label><span>训练计划</span><select name="workout">${state.routines.map((routine) => `<option>${escapeHtml(routine.name)}</option>`).join("")}<option>空白训练</option></select></label><button class="text-button form-inline-action" type="button" data-action="new-routine-from-schedule">${icon("plus")}新建训练计划</button><button class="primary-button large" type="submit">保存安排</button></form></div>
`;

const renderExerciseActionsModal = () => {
  const workoutExercise = state.workout.find((item) => item.id === state.selectedWorkoutExerciseId);
  if (!workoutExercise) return "";
  const exercise = resolveExercise(workoutExercise.exerciseId);
  const index = state.workout.findIndex((item) => item.id === workoutExercise.id);
  return `
    <div class="simple-modal exercise-actions-modal"><header class="modal-header"><div><p class="context-label">训练动作设置</p><h2>${exercise.name}</h2><p>调整动作变量不会修改历史记录。</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header>
      ${renderExerciseResource(exercise.id, "workout")}
      <section class="rest-options"><h3>自动休息</h3><div>${[0,60,90,120,150,180,240].map((seconds) => `<button class="${workoutExercise.restSeconds === seconds ? "is-active" : ""}" data-action="set-exercise-rest" data-seconds="${seconds}">${seconds ? formatTime(seconds) : "关闭"}</button>`).join("")}</div></section>
      <div class="action-menu-list">
        <button data-action="warmup-calculator">${icon("thermometer-hot")}<span><b>批量添加热身组</b><small>按第一个正式组重量生成 40%、60%、80%</small></span>${icon("caret-right")}</button>
        ${exercise.equipment.includes("杠铃") ? `<button data-action="plate-calculator">${icon("calculator")}<span><b>杠片计算器</b><small>按目标重量和可用杠片计算每侧装片</small></span>${icon("caret-right")}</button>` : ""}
        <button data-action="toggle-superset">${icon("arrows-left-right")}<span><b>${workoutExercise.supersetId ? "取消超级组" : "与下一动作组成超级组"}</b><small>支持两个以上动作连续组合</small></span>${icon("caret-right")}</button>
        <button data-action="replace-workout-exercise">${icon("arrows-clockwise")}<span><b>替换动作</b><small>保留组数并从动作库选择替代动作</small></span>${icon("caret-right")}</button>
        <button data-action="move-workout-exercise" data-direction="up" ${index <= 0 ? "disabled" : ""}>${icon("arrow-up")}<span><b>上移</b><small>调整训练顺序</small></span></button>
        <button data-action="move-workout-exercise" data-direction="down" ${index >= state.workout.length - 1 ? "disabled" : ""}>${icon("arrow-down")}<span><b>下移</b><small>调整训练顺序</small></span></button>
        <button data-action="delete-last-set" ${workoutExercise.sets.length <= 1 ? "disabled" : ""}>${icon("minus-circle")}<span><b>删除最后一组</b><small>至少保留一组</small></span></button>
        <button class="is-danger" data-action="remove-workout-exercise">${icon("trash")}<span><b>从本次训练移除</b><small>不会删除动作库定义</small></span></button>
      </div>
    </div>
  `;
};

const renderExerciseNoteModal = () => {
  const exercise = resolveExercise(state.resourceEditorExerciseId ?? "bench_press");
  const resource = getExerciseResource(exercise.id, state.resourceEditorScope);
  const scopeLabel = state.resourceEditorScope === "library" ? "动作库" : state.resourceEditorScope === "plan" ? "训练计划" : "本次训练";
  return `
    <div class="simple-modal exercise-note-modal"><header class="modal-header"><div><p class="context-label">${scopeLabel}</p><h2>${exercise.name}</h2><p>备注和链接仅保存在当前设备。</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header>
      <form data-form="exercise-note"><input type="hidden" name="exerciseId" value="${exercise.id}"/><input type="hidden" name="scope" value="${state.resourceEditorScope}"/><label><span>动作备注</span><textarea name="note" rows="3" maxlength="180" placeholder="例如：下放 3 秒，底部停顿 1 秒">${escapeHtml(resource.note)}</textarea></label><label><span>教学链接</span><input type="url" name="link" value="${escapeHtml(resource.link)}" placeholder="https://youtube.com/..."/><small>查看计划、动作详情或训练时可以直接打开。</small></label><button class="primary-button large" type="submit">保存备注与链接</button></form>
    </div>
  `;
};

const renderWorkoutSettingsModal = () => {
  const previousPlanOptions = state.routines.map((routine) => `<option value="${routine.id}" ${state.previousPlanId === routine.id ? "selected" : ""}>${escapeHtml(routine.name)}</option>`).join("");
  return `
  <div class="simple-modal workout-settings-modal"><header class="modal-header"><div><p class="context-label">训练设置</p><h2>${escapeHtml(state.workoutName)}</h2><p>计时、历史值、RPE 和默认休息。</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header>
    <form data-form="workout-settings"><label><span>训练名称</span><input name="name" maxlength="32" value="${escapeHtml(state.workoutName)}" required/></label><label><span>训练备注</span><textarea name="note" rows="2" maxlength="240" placeholder="本次训练的整体备注">${escapeHtml(state.workoutNote)}</textarea></label><div class="form-grid"><label><span>开始日期</span><input type="date" name="date" value="2026-08-03"/></label><label><span>开始时间</span><input type="time" name="time" value="18:30"/></label><label><span>默认休息</span><select name="defaultRest">${[60, 90, 120, 150, 180].map((seconds) => `<option value="${seconds}" ${state.defaultRestSeconds === seconds ? "selected" : ""}>${formatTime(seconds)}</option>`).join("")}</select></label><label><span>上次数据来源</span><select name="previousPlanId"><option value="" ${state.previousPlanId === null ? "selected" : ""}>不指定计划</option>${previousPlanOptions}</select><button class="text-button form-inline-action" type="button" data-action="new-routine-from-settings">${icon("plus")}新建训练计划</button></label></div><p class="form-help">训练页会显示所选训练计划的上一组重量和次数。</p><label class="toggle-row"><input type="checkbox" name="rpe" ${state.rpeTrackingEnabled ? "checked" : ""}/><span><b>显示 RPE</b><small>每组记录主观用力程度</small></span></label><label class="toggle-row"><input type="checkbox" name="pr" ${state.livePrEnabled ? "checked" : ""}/><span><b>实时 PR 通知</b><small>完成组后立即显示重量、次数或估算 1RM 纪录</small></span></label><div class="detail-actions"><button class="secondary-button" type="button" data-action="toggle-workout-clock">${icon(state.workoutTimerPaused ? "play" : "pause")} ${state.workoutTimerPaused ? "恢复训练计时" : "暂停训练计时"}</button><button class="primary-button" type="submit">保存设置</button></div></form>
  </div>
`;
};

const renderPlateCalculatorModal = () => `
  <div class="simple-modal plate-calculator-modal"><header class="modal-header"><div><p class="context-label">杠片计算器</p><h2>目标 82.5 kg</h2><p>结果为杠铃两侧各自需要的杠片。</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header><div class="plate-inputs"><label><span>目标重量</span><input type="number" min="20" step="0.5" value="82.5" data-field="plate-target"/></label><label><span>杠铃重量</span><select data-field="bar-weight"><option value="20">20 kg</option><option value="15">15 kg</option><option value="10">10 kg</option></select></label></div><div class="plate-result" data-plate-result><span class="plate plate-20">20</span><span class="plate plate-10">10</span><span class="plate plate-125">1.25</span><div><small>每侧</small><b>31.25 kg</b><p>20 + 10 + 1.25</p></div></div><p class="validation-note">${icon("check-circle")}按可用杠片 25 / 20 / 15 / 10 / 5 / 2.5 / 1.25 / 0.5 kg 计算。</p></div>
`;

const renderRoutineBuilderModal = () => {
  const routine = state.routines.find((item) => item.id === state.selectedRoutineId);
  const exercisesForRoutine = routine?.exercises ?? state.workout;
  return `<div class="simple-modal routine-builder-modal"><header class="modal-header"><div><p class="context-label">训练模板</p><h2>${routine ? "编辑模板" : "新建模板"}</h2><p>动作、组数、组类型、重量、次数范围和休息均可编辑。</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header><form data-form="routine-builder"><input type="hidden" name="id" value="${routine?.id ?? ""}"/><label><span>模板名称</span><input name="name" value="${escapeHtml(routine?.name ?? "新训练模板")}" maxlength="32" required/></label><label><span>文件夹</span><select name="folder">${state.routineFolders.map((folder) => `<option value="${folder.id}" ${folder.id === routine?.folderId ? "selected" : ""}>${folder.name}</option>`).join("")}</select></label><section class="routine-exercise-preview"><div class="routine-preview-heading"><h3>动作与训练变量</h3><button class="text-button" type="button" data-action="routine-add-exercise">${icon("plus")}添加动作</button></div>${exercisesForRoutine.map((item, index) => { const exercise = resolveExercise(item.exerciseId); const firstSet = item.sets.find((setItem) => setItem.typeId === "work") ?? item.sets[0]; return `<article class="routine-edit-card"><div class="routine-exercise-head"><span>${exercise.image ? `<img src="${exercise.image}" alt="${exercise.name}"/>` : icon("barbell")}</span><div><b>${exercise.name}</b><small>${item.supersetId ? `超级组 ${item.supersetId} / ` : ""}${exercise.muscle} / ${exercise.equipment}</small></div></div>${renderExerciseResource(exercise.id, "plan", true)}<div class="routine-variable-grid"><label><span>组数</span><input type="number" min="1" max="12" name="sets-${item.id}" value="${item.sets.length}"/></label><label><span>组类型</span><select name="type-${item.id}">${state.setTypes.map((type) => `<option value="${type.id}" ${firstSet?.typeId === type.id ? "selected" : ""}>${type.label}</option>`).join("")}</select></label><label><span>重量 kg</span><input type="number" min="0" step="0.5" name="weight-${item.id}" value="${firstSet?.weight ?? 0}"/></label><label><span>次数范围</span><span class="range-inputs"><input type="number" min="1" max="100" name="min-${item.id}" value="${firstSet?.targetMin ?? 6}"/><i>–</i><input type="number" min="1" max="100" name="max-${item.id}" value="${firstSet?.targetMax ?? 8}"/></span></label><label><span>动作休息</span><select name="rest-${item.id}">${[0,60,90,120,150,180,240].map((seconds) => `<option value="${seconds}" ${item.restSeconds === seconds ? "selected" : ""}>${seconds ? formatTime(seconds) : "关闭"}</option>`).join("")}</select></label></div><div class="routine-edit-actions"><button type="button" data-action="routine-warmup" data-id="${item.id}">${icon("thermometer-hot")}热身</button><button type="button" data-action="routine-toggle-superset" data-id="${item.id}">${icon("arrows-left-right")}超级组</button><button type="button" data-action="routine-move-exercise" data-id="${item.id}" data-direction="up" ${index === 0 ? "disabled" : ""} aria-label="上移 ${exercise.name}">${icon("arrow-up")}</button><button type="button" data-action="routine-move-exercise" data-id="${item.id}" data-direction="down" ${index === exercisesForRoutine.length - 1 ? "disabled" : ""} aria-label="下移 ${exercise.name}">${icon("arrow-down")}</button><button type="button" data-action="routine-replace-exercise" data-id="${item.id}">${icon("arrows-clockwise")}替换</button><button class="is-danger" type="button" data-action="routine-remove-exercise" data-id="${item.id}">${icon("trash")}移除</button></div></article>`; }).join("")}</section><button class="primary-button large" type="submit">${routine ? "保存模板" : "创建模板"}</button></form></div>`;
};

const renderRoutineFoldersModal = () => `
  <div class="simple-modal routine-folders-modal"><header class="modal-header"><div><h2>模板文件夹</h2><p>把力量、增肌或不同周期分开管理。</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header><div class="folder-list">${state.routineFolders.map((folder) => `<div>${icon("folder-simple")}<span><b>${folder.name}</b><small>${state.routines.filter((routine) => routine.folderId === folder.id).length} 个模板</small></span></div>`).join("")}</div><form data-form="routine-folder" class="inline-form"><label><span>新文件夹</span><input name="name" maxlength="18" placeholder="例如：比赛备赛" required/></label><button class="primary-button" type="submit">添加</button></form></div>
`;

const renderWorkoutSaveModal = () => {
  const stats = completionStats();
  const elapsed = Math.max(60, currentWorkoutElapsed());
  return `<div class="simple-modal workout-save-modal"><header class="modal-header"><div><p class="context-label">保存训练</p><h2>确认训练详情</h2><p>保存后会进入训练记录和日历。</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header><div class="save-workout-stats"><span><small>训练量</small><b>${workoutVolume().toLocaleString()} kg</b></span><span><small>完成组</small><b>${stats.completed}</b></span><span><small>时长</small><b>${formatDuration(elapsed)}</b></span></div><form data-form="workout-save"><label><span>训练名称</span><input name="name" value="${escapeHtml(state.workoutName)}" required/></label><div class="form-grid"><label><span>日期</span><input type="date" name="date" value="2026-08-03" required/></label><label><span>开始时间</span><input type="time" name="time" value="18:30" required/></label><label><span>时长（分钟）</span><input type="number" name="duration" min="1" value="${Math.max(1, Math.round(elapsed / 60))}" required/></label></div><label><span>训练备注</span><textarea name="note" rows="3" maxlength="240">${escapeHtml(state.workoutNote)}</textarea></label><button class="primary-button large" type="submit">保存到训练记录</button></form></div>`;
};

const renderWorkoutRecordModal = () => {
  const record = state.workoutHistory.find((item) => item.id === state.selectedRecordId);
  if (!record) return "";
  return `<div class="simple-modal workout-record-modal"><header class="modal-header"><div><p class="context-label">训练记录</p><h2>${escapeHtml(record.name)}</h2><p>${record.date} ${record.startTime}</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header><div class="save-workout-stats"><span><small>训练量</small><b>${record.volume.toLocaleString()} kg</b></span><span><small>有效组</small><b>${record.effectiveSets}</b></span><span><small>时长</small><b>${formatDuration(record.durationSeconds)}</b></span></div>${record.prs.length ? `<div class="record-pr">${icon("trophy", "fill")}<div><b>${record.prs.join("、")}</b><small>训练中实时识别并保存</small></div></div>` : ""}<div class="record-exercises">${record.exerciseIds.map((id) => { const exercise = resolveExercise(id); return `<button data-action="open-exercise-detail" data-id="${exercise.id}">${exercise.image ? `<img src="${exercise.image}" alt="${exercise.name}"/>` : icon("barbell")}<span><b>${exercise.name}</b><small>查看动作历史与趋势</small></span>${icon("caret-right")}</button>`; }).join("")}</div><form data-form="workout-record"><input type="hidden" name="id" value="${record.id}"/><label><span>训练名称</span><input name="name" value="${escapeHtml(record.name)}" required/></label><div class="form-grid"><label><span>日期</span><input type="date" name="date" value="${record.date}" required/></label><label><span>开始时间</span><input type="time" name="time" value="${record.startTime}" required/></label><label><span>时长（分钟）</span><input type="number" name="duration" min="1" value="${Math.max(1, Math.round(record.durationSeconds / 60))}" required/></label></div><label><span>训练备注</span><textarea name="note" rows="2">${escapeHtml(record.note)}</textarea></label><div class="detail-actions"><button class="danger-button" type="button" data-action="delete-workout-record" data-id="${record.id}">删除记录</button><button class="primary-button" type="submit">保存修改</button></div></form></div>`;
};

const renderCustomExerciseModal = () => `
  <div class="simple-modal custom-exercise-modal"><header class="modal-header"><div><h2>自定义动作</h2><p>创建后会立即出现在动作库和训练选择中。</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header><form data-form="custom-exercise"><label><span>动作名称</span><input name="name" maxlength="24" placeholder="例如：窄握地板卧推" required /></label><label><span>英文名称</span><input name="englishName" maxlength="40" placeholder="Close-grip floor press" /></label><label><span>主要肌群</span><select name="muscle"><option>胸部</option><option>背部</option><option>肩部</option><option>腿部</option><option>臀部</option><option>手臂</option><option>腹部</option></select></label><label><span>器械</span><select name="equipment"><option>杠铃</option><option>哑铃</option><option>绳索</option><option>固定器械</option><option>自重</option></select></label><button class="primary-button large" type="submit">创建动作</button></form></div>
`;

const renderRepDetailModal = () => `
  <div class="simple-modal rep-detail-modal"><header class="modal-header"><div><p class="context-label">逐次重复</p><h2>第 ${state.selectedRep ?? 1} 次</h2><p>00:${String(3 + (state.selectedRep ?? 1) * 3).padStart(2, "0")} / 证据质量高</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header><div class="rep-detail-body"><span>${icon("crosshair")}</span><h3>${(state.selectedRep ?? 1) >= 6 ? "回落位置偏向头部" : "轨迹稳定"}</h3><p>${(state.selectedRep ?? 1) >= 6 ? "杠铃回落点比前五次高约一个拳头距离。下一组保持前臂垂直。" : "本次重复的幅度、节奏和触胸位置均处于稳定范围。"}</p><button class="primary-button" data-action="save-cue">保存为下一组提示</button></div></div>
`;

const renderCitationModal = () => {
  const citations = state.chat.flatMap((message) => message.citations ?? []);
  const citation = citations[state.selectedCitation ?? 0] ?? { title: "ACSM 阻力训练进展模型", detail: "渐进负荷与训练处方原则" };
  return `<div class="simple-modal citation-modal"><header class="modal-header"><div><p class="context-label">知识库来源</p><h2>${citation.title}</h2><p>${citation.detail}</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header><div class="citation-body"><span>${icon("seal-check", "fill")}</span><div><b>已审核来源</b><p>当前知识库版本 2026.08。回答只引用与问题直接相关的训练原则，无法证实时会明确说明。</p></div></div><button class="secondary-button large" data-action="close-modal">返回回答</button></div>`;
};

const renderMuscleMethodModal = () => `
  <div class="simple-modal method-modal"><header class="modal-header"><div><h2>肌群计算方法</h2><p>同时显示硬组数和估算贡献，避免伪精确。</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon("x")}</button></header><div class="method-list"><div><b>主要肌群</b><span>每个有效正式组计 1.0 组贡献</span></div><div><b>辅助肌群</b><span>按动作定义计 0.25-0.5 组贡献</span></div><div><b>排除内容</b><span>热身组、技术组和用户排除组不参与</span></div></div><button class="primary-button large" data-action="close-modal">我知道了</button></div>
`;

const renderModal = () => {
  if (state.selectedExerciseId) return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel wide">${renderExerciseDetail(resolveExercise(state.selectedExerciseId))}</div></div>`;
  if (state.selectedPlanId) {
    const plan = officialPlans.find((item) => item.id === state.selectedPlanId);
    if (plan) return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderPlanDetail(plan)}</div></div>`;
  }
  if (state.modal === "exercise-library") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel library-modal">${renderExerciseLibrary()}</div></div>`;
  if (state.modal === "exercise-actions") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderExerciseActionsModal()}</div></div>`;
  if (state.modal === "exercise-note") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderExerciseNoteModal()}</div></div>`;
  if (state.modal === "workout-settings") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderWorkoutSettingsModal()}</div></div>`;
  if (state.modal === "plate-calculator") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderPlateCalculatorModal()}</div></div>`;
  if (state.modal === "routine-builder") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderRoutineBuilderModal()}</div></div>`;
  if (state.modal === "routine-folders") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderRoutineFoldersModal()}</div></div>`;
  if (state.modal === "workout-save") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderWorkoutSaveModal()}</div></div>`;
  if (state.modal === "workout-record") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderWorkoutRecordModal()}</div></div>`;
  if (state.modal === "record-overview") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderRecordOverviewModal()}</div></div>`;
  if (state.modal === "record-history") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel wide">${renderRecordHistoryModal()}</div></div>`;
  if (state.modal === "set-types") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderSetTypesModal()}</div></div>`;
  if (state.modal === "ai-consent") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderAiConsent()}</div></div>`;
  if (state.modal === "plan-builder") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderPlanBuilder()}</div></div>`;
  if (state.modal === "calendar") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderCalendarModal()}</div></div>`;
  if (state.modal === "schedule") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderScheduleModal()}</div></div>`;
  if (state.modal === "custom-exercise") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderCustomExerciseModal()}</div></div>`;
  if (state.modal === "rep-detail") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderRepDetailModal()}</div></div>`;
  if (state.modal === "citation") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderCitationModal()}</div></div>`;
  if (state.modal === "muscle-method") return `<div class="modal-backdrop" data-action="backdrop-close"><div class="modal-panel">${renderMuscleMethodModal()}</div></div>`;
  if (state.modal === "workout-complete") return `<div class="modal-backdrop celebration" data-action="backdrop-close"><div class="modal-panel">${renderWorkoutComplete()}</div></div>`;
  return "";
};

const renderPage = () => {
  switch (state.page) {
    case "today": return state.scenario === "empty" ? renderToday() : renderTodayFocused();
    case "train": return renderTrain();
    case "records": return renderRecords();
    case "exercises": return `<div class="exercise-page page-enter">${renderExerciseLibrary(true)}</div>`;
    case "recognition": return renderRecognition();
    case "plans": return renderPlans();
    case "ai": return renderAi();
    case "progress": return renderProgress();
    case "profile": return renderProfile();
  }
};

export const renderApp = () => `
  <div class="app-shell kilo-redesign" data-visual-world="performance-bay">
    <main class="main-shell">
      ${renderTopbar()}
      <div class="page-content">${renderPage()}</div>
    </main>
    <nav class="mobile-nav" aria-label="移动端主导航">${renderNav()}</nav>
    ${renderDevicePanel()}
    ${state.devicePanelOpen ? `<button class="device-scrim" data-action="toggle-device-panel" aria-label="关闭设备预览"></button>` : ""}
    ${renderModal()}
    ${state.toast ? `<div class="toast" role="status">${icon("check-circle", "fill")}<span>${escapeHtml(state.toast)}</span></div>` : ""}
  </div>
`;
