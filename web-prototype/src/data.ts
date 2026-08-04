import type { Exercise, OfficialPlan, SetType, WorkoutExercise } from "./types";

export const setTypes: SetType[] = [
  { id: "warmup", label: "热身组", shortLabel: "热", semantic: "warmup", color: "#78908a" },
  { id: "work", label: "正式组", shortLabel: "正", semantic: "work", color: "#72e4ff" },
  { id: "backoff", label: "退阶组", shortLabel: "退", semantic: "work", color: "#e3bc5d" },
  { id: "drop", label: "递减组", shortLabel: "递", semantic: "work", color: "#d98656" },
  { id: "failure", label: "力竭组", shortLabel: "竭", semantic: "work", color: "#e06a62" },
  { id: "technique", label: "技术练习", shortLabel: "技", semantic: "excluded", color: "#8292a6" },
];

const image = (name: string) => `/assets/exercises/${name}`;

export const exercises: Exercise[] = [
  { id: "machine_chest_press", name: "器械推胸", englishName: "Machine chest press", family: "推", muscle: "胸部", secondary: "肱三头肌", equipment: "固定器械", camera: "侧前方 30-45°", cue: "让手柄轨迹与前臂方向保持一致", image: image("bench_press_0.png"), loadMode: "total" },
  { id: "machine_crunch", name: "器械卷腹", englishName: "Machine crunch", family: "核心", muscle: "腹部", secondary: "腹斜肌", equipment: "固定器械", camera: "正侧面", cue: "由胸廓向骨盆卷曲，不要只低头", image: image("crunch_0.png"), loadMode: "total" },
  { id: "standing_hip_abduction", name: "站姿髋外展", englishName: "Standing hip abduction", family: "髋部孤立", muscle: "臀中肌", secondary: "臀小肌", equipment: "绳索", camera: "正面", cue: "骨盆保持水平，腿向侧方展开" , loadMode: "perSide" },
  { id: "seated_hip_abduction", name: "坐姿髋外展", englishName: "Seated hip abduction", family: "髋部孤立", muscle: "臀部", secondary: "臀中肌", equipment: "固定器械", camera: "正前方", cue: "保持躯干稳定，控制回程", image: image("hip_bridge_0.png"), loadMode: "total" },
  { id: "chest_supported_row", name: "胸托划船", englishName: "Chest-supported row", family: "拉", muscle: "上背部", secondary: "肱二头肌", equipment: "固定器械", camera: "正侧方", cue: "胸口保持支撑，肘部向后拉", image: image("seated_row_0.png"), loadMode: "total" },
  { id: "t_bar_row", name: "T 杠划船", englishName: "T-bar row", family: "拉", muscle: "背部", secondary: "后束", equipment: "杠铃", camera: "侧后方", cue: "保持躯干角度，不用髋部甩动", image: image("seated_row_1.png"), loadMode: "total" },
  { id: "plate_loaded_pulldown", name: "片装高位下拉", englishName: "Plate-loaded pulldown", family: "拉", muscle: "背阔肌", secondary: "肱二头肌", equipment: "固定器械", camera: "正侧方", cue: "肘部向髋部方向下拉", image: image("lat_pulldown_0.png"), loadMode: "total" },
  { id: "plate_loaded_romanian_deadlift", name: "片装罗马尼亚硬拉", englishName: "Plate-loaded RDL", family: "髋铰链", muscle: "腘绳肌", secondary: "臀部", equipment: "固定器械", camera: "正侧面", cue: "髋部后移，负重路径贴近身体", image: image("romanian_deadlift_0.png"), loadMode: "total" },
  { id: "single_arm_pulldown", name: "单臂高位下拉", englishName: "Single-arm pulldown", family: "拉", muscle: "背阔肌", secondary: "肱二头肌", equipment: "绳索", camera: "工作侧前方", cue: "先稳定肩胛，再让肘部向下", image: image("lat_pulldown_1.png"), loadMode: "perSide" },
  { id: "hack_squat", name: "哈克深蹲", englishName: "Hack squat", family: "蹲", muscle: "股四头肌", secondary: "臀部", equipment: "固定器械", camera: "侧后方", cue: "膝盖跟随脚尖方向，控制下放", image: image("squat_1.png"), loadMode: "total" },
  { id: "hip_thrust", name: "杠铃臀推", englishName: "Hip thrust", family: "髋铰链", muscle: "臀部", secondary: "腘绳肌", equipment: "杠铃", camera: "正侧面", cue: "顶端保持肋骨和骨盆稳定", image: image("hip_bridge_1.png"), loadMode: "total" },
  { id: "back_extension", name: "山羊挺身", englishName: "Back extension", family: "髋铰链", muscle: "后侧链", secondary: "下背部", equipment: "自重", camera: "正侧面", cue: "从髋部折叠，不要过度伸展腰椎", image: image("romanian_deadlift_1.png"), loadMode: "bodyweight" },
  { id: "preacher_curl", name: "牧师凳弯举", englishName: "Preacher curl", family: "肘部孤立", muscle: "肱二头肌", secondary: "前臂", equipment: "哑铃", camera: "工作侧", cue: "上臂贴稳支撑面，完整控制下放", image: image("biceps_curl_1.png"), loadMode: "perSide" },
  { id: "barbell_squat", name: "杠铃深蹲", englishName: "Barbell squat", family: "蹲", muscle: "腿部", secondary: "臀部", equipment: "杠铃", camera: "侧后方 30-45°", cue: "中足稳定，髋膝同步下降", image: image("squat_0.png"), loadMode: "total" },
  { id: "goblet_squat", name: "高脚杯深蹲", englishName: "Goblet squat", family: "蹲", muscle: "腿部", secondary: "核心", equipment: "哑铃", camera: "侧前方", cue: "负重贴近胸口，保持足底稳定", image: image("squat_1.png"), loadMode: "total" },
  { id: "deadlift", name: "传统硬拉", englishName: "Deadlift", family: "髋铰链", muscle: "后侧链", secondary: "背部", equipment: "杠铃", camera: "正侧面", cue: "杠铃从中足上方垂直移动", image: image("romanian_deadlift_1.png"), loadMode: "total" },
  { id: "romanian_deadlift", name: "罗马尼亚硬拉", englishName: "Romanian deadlift", family: "髋铰链", muscle: "腘绳肌", secondary: "臀部", equipment: "杠铃", camera: "正侧面", cue: "膝角稳定，髋部持续后移", image: image("romanian_deadlift_0.png"), loadMode: "total" },
  { id: "bench_press", name: "杠铃卧推", englishName: "Bench press", family: "推", muscle: "胸部", secondary: "肱三头肌", equipment: "杠铃", camera: "侧前方 30-45°", cue: "前臂垂直，杠铃稳定触胸", image: image("bench_press_0.png"), loadMode: "total" },
  { id: "dumbbell_press", name: "上斜哑铃卧推", englishName: "Dumbbell press", family: "推", muscle: "上胸", secondary: "肱三头肌", equipment: "哑铃", camera: "侧前方", cue: "两侧同步下降，避免肩部前移", image: image("incline_dumbbell_press_0.png"), loadMode: "perSide" },
  { id: "shoulder_press", name: "哑铃推举", englishName: "Shoulder press", family: "推", muscle: "肩部", secondary: "肱三头肌", equipment: "哑铃", camera: "正侧方", cue: "保持肋骨下沉，手腕叠在肘部上方", image: image("shoulder_press_0.png"), loadMode: "perSide" },
  { id: "push_up", name: "俯卧撑", englishName: "Push-up", family: "推", muscle: "胸部", secondary: "核心", equipment: "自重", camera: "正侧面", cue: "头肩髋保持一条直线", image: image("bench_press_1.png"), loadMode: "bodyweight" },
  { id: "dip", name: "双杠臂屈伸", englishName: "Dip", family: "推", muscle: "胸部", secondary: "肱三头肌", equipment: "自重", camera: "正侧面", cue: "肩胛稳定，下降深度由控制决定", loadMode: "bodyweight" },
  { id: "row", name: "坐姿绳索划船", englishName: "Seated row", family: "拉", muscle: "背部", secondary: "肱二头肌", equipment: "绳索", camera: "正侧方", cue: "躯干保持稳定，肘部贴近身体", image: image("seated_row_0.png"), loadMode: "total" },
  { id: "lat_pulldown", name: "高位下拉", englishName: "Lat pulldown", family: "拉", muscle: "背阔肌", secondary: "肱二头肌", equipment: "绳索", camera: "正前方", cue: "下拉到上胸，避免明显后仰", image: image("lat_pulldown_0.png"), loadMode: "total" },
  { id: "pull_up", name: "引体向上", englishName: "Pull-up", family: "拉", muscle: "背部", secondary: "肱二头肌", equipment: "自重", camera: "正前方", cue: "从稳定悬垂开始，胸口向上", image: image("lat_pulldown_1.png"), loadMode: "bodyweight" },
  { id: "face_pull", name: "绳索面拉", englishName: "Face pull", family: "拉", muscle: "肩后束", secondary: "上背部", equipment: "绳索", camera: "正前方", cue: "向面部拉开绳索，避免耸肩", image: image("seated_row_1.png"), loadMode: "total" },
  { id: "lateral_raise", name: "哑铃侧平举", englishName: "Lateral raise", family: "肩部孤立", muscle: "肩中束", secondary: "斜方肌", equipment: "哑铃", camera: "正前方", cue: "以肘部带动手臂向侧上方", image: image("lateral_raise_0.png"), loadMode: "perSide" },
  { id: "y_raise", name: "绳索 Y 举", englishName: "Cable Y raise", family: "肩部孤立", muscle: "肩部", secondary: "下斜方肌", equipment: "绳索", camera: "正前方", cue: "手腕沿对角线上升到 Y 字顶端", image: image("lateral_raise_1.png"), loadMode: "perSide" },
  { id: "biceps_curl", name: "杠铃弯举", englishName: "Biceps curl", family: "肘部孤立", muscle: "肱二头肌", secondary: "前臂", equipment: "杠铃", camera: "正侧方", cue: "上臂稳定，避免躯干借力", image: image("biceps_curl_0.png"), loadMode: "total" },
  { id: "triceps_extension", name: "绳索臂屈伸", englishName: "Triceps extension", family: "肘部孤立", muscle: "肱三头肌", secondary: "前臂", equipment: "绳索", camera: "正侧方", cue: "肘部位置稳定，完成伸展", loadMode: "total" },
  { id: "leg_extension", name: "腿屈伸", englishName: "Leg extension", family: "膝部孤立", muscle: "股四头肌", secondary: "无", equipment: "固定器械", camera: "正侧面", cue: "控制膝关节伸展和下放", loadMode: "total" },
  { id: "leg_curl", name: "腿弯举", englishName: "Leg curl", family: "膝部孤立", muscle: "腘绳肌", secondary: "小腿", equipment: "固定器械", camera: "正侧面", cue: "骨盆稳定，控制回程", loadMode: "total" },
];

let sequence = 0;
const set = (typeId: string, weight: number, reps: number, completed = false, restSeconds = 120) => ({
  id: `set-${++sequence}`,
  typeId,
  weight,
  reps,
  targetMin: typeId === "warmup" ? 8 : 6,
  targetMax: typeId === "warmup" ? 10 : 8,
  restSeconds,
  completed,
});

export const initialWorkout: WorkoutExercise[] = [
  {
    id: "we-bench",
    exerciseId: "bench_press",
    restSeconds: 150,
    collapsed: false,
    sets: [set("warmup", 20, 10, true, 60), set("warmup", 50, 8, true, 90), set("work", 80, 8), set("work", 80, 8), set("work", 80, 8)],
  },
  {
    id: "we-row",
    exerciseId: "chest_supported_row",
    restSeconds: 120,
    collapsed: true,
    sets: [set("warmup", 35, 10, false, 60), set("work", 62.5, 10), set("work", 62.5, 10), set("backoff", 55, 12)],
  },
  {
    id: "we-lateral",
    exerciseId: "lateral_raise",
    restSeconds: 75,
    collapsed: true,
    sets: [set("work", 10, 12, false, 75), set("work", 10, 12, false, 75), set("drop", 8, 15, false, 60)],
  },
];

export const officialPlans: OfficialPlan[] = [
  { id: "upper-lower-4", title: "上下肢力量", subtitle: "力量与肌肥大并重，围绕主项双重渐进", days: 4, weeks: 12, level: "中级", focus: "力量 + 增肌", sessions: [
    { day: "周一", name: "上肢力量", exercises: 6, duration: "65 分钟", exerciseIds: ["bench_press", "chest_supported_row", "shoulder_press"] },
    { day: "周二", name: "下肢力量", exercises: 5, duration: "70 分钟", exerciseIds: ["barbell_squat", "romanian_deadlift", "leg_curl"] },
    { day: "周四", name: "上肢容量", exercises: 7, duration: "60 分钟", exerciseIds: ["dumbbell_press", "lat_pulldown", "lateral_raise"] },
    { day: "周六", name: "下肢容量", exercises: 6, duration: "65 分钟", exerciseIds: ["hack_squat", "hip_thrust", "leg_extension"] },
  ] },
  { id: "ppl-6", title: "推拉腿进阶", subtitle: "高频分化，适合恢复能力较好的训练者", days: 6, weeks: 8, level: "中高级", focus: "肌肥大", sessions: [
    { day: "周一", name: "推 A", exercises: 6, duration: "58 分钟", exerciseIds: ["bench_press", "shoulder_press", "triceps_extension"] },
    { day: "周二", name: "拉 A", exercises: 6, duration: "60 分钟", exerciseIds: ["pull_up", "row", "biceps_curl"] },
    { day: "周三", name: "腿 A", exercises: 5, duration: "68 分钟", exerciseIds: ["barbell_squat", "romanian_deadlift", "leg_extension"] },
  ] },
  { id: "full-body-3", title: "全身三日", subtitle: "低频率限制下保持每周肌群刺激", days: 3, weeks: 10, level: "中级", focus: "均衡增肌", sessions: [
    { day: "周一", name: "全身 A", exercises: 6, duration: "62 分钟", exerciseIds: ["barbell_squat", "bench_press", "row"] },
    { day: "周三", name: "全身 B", exercises: 6, duration: "60 分钟", exerciseIds: ["deadlift", "shoulder_press", "lat_pulldown"] },
    { day: "周五", name: "全身 C", exercises: 7, duration: "66 分钟", exerciseIds: ["hack_squat", "dumbbell_press", "chest_supported_row"] },
  ] },
  { id: "strength-5", title: "基础力量五日", subtitle: "主项技术频率与可解释的周进阶", days: 5, weeks: 16, level: "中高级", focus: "最大力量", sessions: [
    { day: "周一", name: "深蹲主项", exercises: 5, duration: "70 分钟", exerciseIds: ["barbell_squat", "romanian_deadlift", "leg_extension"] },
    { day: "周二", name: "卧推主项", exercises: 6, duration: "65 分钟", exerciseIds: ["bench_press", "chest_supported_row", "triceps_extension"] },
    { day: "周四", name: "硬拉主项", exercises: 5, duration: "72 分钟", exerciseIds: ["deadlift", "lat_pulldown", "back_extension"] },
  ] },
];

export const weekSchedule = [
  { day: "一", date: "27", state: "done", label: "下肢" },
  { day: "二", date: "28", state: "rest", label: "恢复" },
  { day: "三", date: "29", state: "done", label: "拉" },
  { day: "四", date: "30", state: "rest", label: "休息" },
  { day: "五", date: "31", state: "done", label: "腿" },
  { day: "六", date: "01", state: "today", label: "上肢" },
  { day: "日", date: "02", state: "planned", label: "休息" },
];

export const getExercise = (id: string, customExercises: Exercise[] = []) => [...exercises, ...customExercises].find((exercise) => exercise.id === id) ?? exercises[0];
