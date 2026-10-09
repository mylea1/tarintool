import fs from 'node:fs';
import { INTEGRATION_SKILLS } from './agent-integrations.mjs';

const catalog = JSON.parse(fs.readFileSync(new URL('../knowledge/agent-exercises.json', import.meta.url), 'utf8'));
export const MUSCLES = [
  { id: 'chest', name: '胸部', terms: /胸|卧推|俯卧撑|chest|pectoral|bench|push.up/i, exercises: ['杠铃卧推', '哑铃卧推', '俯卧撑'] },
  { id: 'upper-back', name: '上背部', terms: /上背|背阔|背部|lat|row|pull.up|upper.back/i, exercises: ['高位下拉', '坐姿划船', '引体向上'] },
  { id: 'lower-back', name: '下背部', terms: /下背|竖脊|lower.back|erector/i, exercises: ['罗马尼亚硬拉', '背部伸展'] },
  { id: 'deltoids', name: '肩部', terms: /肩|三角|deltoid|shoulder|lateral.raise/i, exercises: ['哑铃侧平举', '哑铃推举', '反向飞鸟'] },
  { id: 'biceps', name: '肱二头肌', terms: /二头|bicep|curl/i, exercises: ['哑铃弯举', '绳索弯举'] },
  { id: 'triceps', name: '肱三头肌', terms: /三头|tricep/i, exercises: ['绳索下压', '哑铃臂屈伸'] },
  { id: 'forearm', name: '前臂', terms: /前臂|forearm/i, exercises: ['腕弯举', '农夫行走'] },
  { id: 'abs', name: '腹部', terms: /腹|核心|abs|core|sit.up|crunch|plank/i, exercises: ['卷腹', '悬垂举腿', '平板支撑'] },
  { id: 'obliques', name: '腹斜肌', terms: /腹斜|oblique/i, exercises: ['绳索伐木', '侧平板支撑'] },
  { id: 'gluteal', name: '臀部', terms: /臀|glute|hip.thrust/i, exercises: ['臀推', '保加利亚分腿蹲'] },
  { id: 'quadriceps', name: '股四头肌', terms: /股四|大腿前|腿部|quadricep|quad|squat|leg.press/i, exercises: ['深蹲', '腿举', '腿屈伸'] },
  { id: 'hamstring', name: '腘绳肌', terms: /腘|大腿后|hamstring|romanian|leg.curl/i, exercises: ['罗马尼亚硬拉', '腿弯举'] },
  { id: 'calves', name: '小腿', terms: /小腿|腓肠|比目鱼|calf|calves/i, exercises: ['站姿提踵', '坐姿提踵'] },
  { id: 'trapezius', name: '斜方肌', terms: /斜方|trap|shrug/i, exercises: ['耸肩', '面拉'] },
];

const list = (v) => Array.isArray(v) ? v : [];
const parse = (v) => { try { return JSON.parse(v); } catch { return {}; } };
const clean = (v) => {
  if (Array.isArray(v)) return v.map(clean);
  if (v && typeof v === 'object') return Object.fromEntries(Object.entries(v).filter(([k]) => !/photoPaths|avatar|token|password|secret|apiKey/i.test(k)).map(([k, x]) => [k, clean(x)]));
  return v;
};
export function cloudData(db, userId) {
  const remote = db.prepare('SELECT user_id FROM agent_backend_links WHERE user_id=?').get(userId);
  const table = remote ? 'agent_remote_entities' : 'sync_entities';
  const rows = db.prepare(`SELECT entity_type, entity_id, payload_json, updated_at FROM ${table} WHERE user_id=? AND deleted_at IS NULL ORDER BY updated_at DESC`).all(userId);
  const backupRow = rows.find((r) => r.entity_type === 'settings' && r.entity_id === 'mobile_backup_v1');
  const backup = parse(backupRow?.payload_json || '{}');
  const records = (type, fallback) => {
    const typed = rows.filter((r) => r.entity_type === type).map((r) => parse(r.payload_json));
    const tombstones=backup.webTombstones?.[type==='workout'?'workoutHistory':type]||{};const deleted=new Set([...Object.keys(tombstones),...db.prepare(`SELECT entity_id FROM ${table} WHERE user_id=? AND entity_type=? AND deleted_at IS NOT NULL`).all(userId,type).map(r=>r.entity_id)]);return [...new Map([...list(fallback),...typed].filter(r=>!deleted.has(r.id)).map(r=>[r.id,r])).values()];
  };
  const enrich = (records) => clean(records).map((w)=>({ ...w, exercises:list(w.exercises).map((e)=>{
    const info=exerciseInfo(e);return {...e,name:info.name,muscle:info.muscle};
  }) }));
  return {
    workouts: enrich(records('workout', backup.workoutHistory)).sort((a,b) => String(b.date || '').localeCompare(String(a.date || ''))),
    plans: enrich(records('plan', backup.trainingLibrary?.routines)),
    activeWorkout: clean(backup.activeWorkout||null),
    profile: clean(backup.trainingProfile?.profile || {}),
    weight: clean(list(backup.weight)).sort((a,b) => String(b.recordedAt).localeCompare(String(a.recordedAt))),
    nutritionGoals: clean(list(backup.nutritionGoals)),
    nutrition: clean(list(backup.nutrition)).sort((a,b) => String(b.recordedAt).localeCompare(String(a.recordedAt))),
    mobileConversations: clean(list(backup.aiConversations?.conversations)),
    syncedAt: backupRow?.updated_at || rows[0]?.updated_at || null,
  };
}

export function conversationList(db, userId, data = cloudData(db, userId)) {
  const server = db.prepare('SELECT id, title, created_at, updated_at FROM conversations WHERE user_id=? ORDER BY updated_at DESC LIMIT 200').all(userId);
  const remote=db.prepare('SELECT id,title,created_at,updated_at FROM agent_remote_conversations WHERE user_id=? ORDER BY updated_at DESC').all(userId);
  const seen = new Set([...server,...remote].map((c) => c.id));
  return [
    ...remote.map((c)=>({id:`backend:${c.id}`,title:c.title,source:'software-backend',createdAt:c.created_at,updatedAt:c.updated_at})),
    ...server.map((c) => ({ id:c.id, title:c.title, source:'server', createdAt:c.created_at, updatedAt:c.updated_at })),
    ...data.mobileConversations.filter((c) => !seen.has(c.serverConversationId)).map((c) => ({ id:`mobile:${c.id}`, title:c.title, source:'mobile-backup' })),
  ];
}
export function conversationDetail(db, userId, id) {
  if (id.startsWith('mobile:')) {
    const c = cloudData(db,userId).mobileConversations.find((x) => `mobile:${x.id}` === id);
    if (!c) return null;
    return { id, title:c.title, source:'mobile-backup', messages:list(c.messages).map((m) => ({ id:m.id, role:m.role, content:m.body || m.content || '' })) };
  }
  const c = db.prepare('SELECT * FROM conversations WHERE id=? AND user_id=?').get(id,userId);
  if (!c) return null;
  return { id:c.id, title:c.title, source:'server', messages: db.prepare('SELECT id,role,content,created_at AS createdAt FROM conversation_messages WHERE conversation_id=? ORDER BY created_at,rowid').all(id) };
}

export function pageRecords(records, args = {}) {
  let selected = records;
  if (args.startDate) selected = selected.filter((r) => String(r.date || r.recordedAt || '').slice(0,10) >= args.startDate);
  if (args.endDate) selected = selected.filter((r) => String(r.date || r.recordedAt || '').slice(0,10) <= args.endDate);
  const offset = args.offset || 0, limit = args.limit || 20;
  return { records:selected.slice(offset, offset+limit), total:selected.length, nextOffset:offset+limit < selected.length ? offset+limit : null };
}
export function exerciseInfo(exercise) {
  const id = exercise.exerciseId || exercise.id || '';
  const info = catalog[id] || {};
  return { ...info, name:exercise.name || info.name || id, muscle:exercise.muscle || info.muscle || '', id };
}
export function dashboard(data, at = new Date()) {
  const now = at.getTime(), days = 86400000;
  const muscles = MUSCLES.map((m) => ({ id:m.id, name:m.name, exercises:m.exercises, weeklySets:0, lastTrainedAt:null, recoveryPercent:null, estimated:true }));
  let unmappedExercises=0;
  for (const w of data.workouts) {
    const date = Date.parse(w.date || w.completedAt || '');
    if (!Number.isFinite(date) || date > now) continue;
    const exercises = list(w.exercises).length ? w.exercises : list(w.exerciseIds).map((exerciseId) => ({ exerciseId }));
    for (const e of exercises) {
      const info = exerciseInfo(e), primary = String(info.muscle || '');
      // Known catalogue muscle labels take priority over broad name heuristics.
      const matches = MUSCLES.filter((m) => m.terms.test(primary || info.name || info.id))
        .filter((m)=>!(primary && m.id==='upper-back' && /下背|竖脊|lower.back|erector/i.test(primary)))
        .filter((m)=>!(primary && m.id==='abs' && /腹斜|oblique/i.test(primary)));
      if (!matches.length) { unmappedExercises++; continue; }
      const sets = list(e.sets).filter((s) => s.completed === true && s.type !== 'warmup');
      for (const m of matches) {
        const state = muscles.find((x) => x.id === m.id);
        if (list(e.sets).length && !sets.length) continue;
        if (now-date <= 7*days) state.weeklySets += sets.length;
        if (!state.lastTrainedAt || date > Date.parse(state.lastTrainedAt)) state.lastTrainedAt = new Date(date).toISOString();
        const hours = (now-date)/3600000;
        const recoveryHours = 48 + Math.min(24, sets.length*2);
        const estimated = Math.round(Math.min(100, hours/recoveryHours*100));
        state.recoveryPercent = state.recoveryPercent === null ? estimated : Math.min(state.recoveryPercent,estimated);
      }
    }
  }
  const recent = data.workouts.filter((w) => { const d=Date.parse(w.date); return Number.isFinite(d)&&d<=now&&now-d<=7*days; });
  const trend = data.workouts.filter((w) => { const d=Date.parse(w.date); return Number.isFinite(d)&&d<=now&&now-d<=28*days; }).slice().reverse().map((w) => ({ date:w.date, volume:Number(w.volume)||0, sets:Number(w.effectiveSets)||0 }));
  const prs = data.workouts.flatMap((w) => list(w.prDetails).map((p) => ({ ...p,date:w.date,name:exerciseInfo({exerciseId:p.exerciseId}).name }))).slice(0,10);
  return { muscles, appRecovery:appRecovery(data,at), appRecoveryMethod:'沿用 Flutter App 的指数疲劳模型：38 小时衰减，计入主肌群、辅助肌群与 RPE/RIR。恢复为估算，不是生理检测；暂无近期记录按 App 口径显示 100%。预计时间表示不再新增训练时达到 95% 的模型时间。', unmappedExercises, weekly:{ sessions:recent.length, sets:recent.reduce((s,w)=>s+(Number(w.effectiveSets)||0),0), volume:recent.reduce((s,w)=>s+(Number(w.volume)||0),0) }, trend, prs, syncedAt:data.syncedAt, recoveryMethod:'按已记录动作、完成组数与距上次训练时间估算（48–72 小时线性模型），不代表实际生理恢复；未记录的肌群显示未知。' };
}

export const BUILTIN_SKILLS = [
  ...INTEGRATION_SKILLS,
  { id:'weekly-review',name:'每周训练复盘',description:'比较训练负荷、频率和进步，给出下一周的调整建议。',instructions:'先用 read_workout_history 读取最近两周记录，用 read_recovery 查看肌群分布。比较训练次数、有效组、负荷和有证据的 PR；区分事实和推测。给出三项可执行建议，缺数据时明确说明，不编造睡眠或疲劳。',enabled:true,external:true,builtin:true },
  { id:'workout-planner',name:'训练计划教练',description:'按目标、可用器械和恢复状态安排训练。',instructions:'读取 read_body_profile、read_training_plans、read_recovery 与 read_workout_history。确认目标、经验、每周天数和器械后制定计划。列出动作、组数、次数范围、休息、进退阶规则。先给可审阅草案，不宣称已经修改或保存计划。',enabled:true,external:true,builtin:true },
  { id:'nutrition-review',name:'饮食与体重复盘',description:'结合记录分析摄入与体重趋势。',instructions:'读取 read_nutrition_history 和 read_body_profile。区分用户实际记录与估计，不将缺失记录视为零摄入。不进行医疗诊断，不提供极端节食建议。总结最近饮食与体重变化，先确认目标和记录完整性，再给实际可执行的调整建议。',enabled:true,external:true,builtin:true },
];

// Ported from mobile/lib/training_intelligence.dart: calculateRecovery and _muscleFactor.
export function appRecovery(data,at=new Date()){
 const groups=[['chest','胸',['胸','chest','pectoral']],['upper-back','背',['背','lat','back','row']],['deltoids','肩',['肩','deltoid','shoulder']],['biceps','二头',['二头','biceps']],['triceps','三头',['三头','triceps']],['quadriceps','股四头',['股四','quadriceps','quads']],['hamstring','腘绳肌',['腘绳','hamstring']],['gluteal','臀',['臀','glute']],['calves','小腿',['小腿','calf','calves']],['abs','核心',['核心','腹','core','abs']]];
 return groups.map(([id,name,keys])=>{let fatigue=0,last=null,weeklySets=0;const sessions=new Set();for(const w of data.workouts){const date=Date.parse(w.date),age=(at-date)/3600000;if(!Number.isFinite(age)||age<0||age>168)continue;for(const e of list(w.exercises)){const info=catalog[e.exerciseId];if(!info)continue;const primary=[e.exerciseId,info.name,info.englishName,info.muscle,info.family].join('|').toLowerCase(),secondary=(info.secondary||'').toLowerCase(),factor=keys.some(k=>primary.includes(k))?1:keys.some(k=>secondary.includes(k))?.45:0;if(!factor)continue;for(const set of list(e.sets).filter(s=>s.completed)){const effort=set.rir!=null?Math.max(.72,Math.min(1.3,1.25-set.rir*.09)):set.rpe!=null?Math.max(.7,Math.min(1.3,.55+set.rpe*.075)):1;fatigue+=factor*effort*Math.exp(-age/38);weeklySets+=factor;sessions.add(w.id);last=last===null?date:Math.max(last,date);}}}
 const percent=Math.max(0,Math.min(100,Math.round(100-fatigue*9.2))),hoursTo95=fatigue*9.2>5?38*Math.log(fatigue*9.2/5):0;return {id,name,recoveryPercent:percent,weeklySets:Math.round(weeklySets*10)/10,trainingCount:sessions.size,lastTrainedAt:last===null?null:new Date(last).toISOString(),hoursSinceLast:last===null?null:(at-last)/3600000,hoursTo95:last===null?null:Math.min(hoursTo95,Math.max(0,168-(at-last)/3600000)),exercises:MUSCLES.find(m=>m.id===id)?.exercises||[],estimated:true};});
}
