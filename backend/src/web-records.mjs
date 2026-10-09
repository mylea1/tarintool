import { initializeBrowserStorage, isBrowserStorage, browserRequest } from './browser-bridge.mjs';
import fs from 'node:fs';
import { createHash } from 'node:crypto';
import { z } from 'zod';
import { cloudData, exerciseInfo } from './agent-data.mjs';
import { remoteSyncEntities, writeRemoteEntity, refreshBackend } from './agent-remote.mjs';
const catalog=JSON.parse(fs.readFileSync(new URL('../knowledge/agent-exercises.json',import.meta.url),'utf8'));
const fail=(status,code)=>{throw Object.assign(new Error(code),{status,code});};
const text=z.string().max(4000),number=(max=100000)=>z.number().finite().min(0).max(max),integer=(max=100000)=>number(max).int();
const date=z.string().max(40).refine(v=>/^\d{4}-\d{2}-\d{2}T/.test(v)&&Number.isFinite(Date.parse(v)), 'ISO timestamp required');
const id=z.string().regex(/^[a-zA-Z0-9_-]{1,120}$/);
const optionalNumber=(max)=>number(max).nullable().optional();
export const setSchema=z.object({id:id.optional(),type:z.enum(['work','warmup','drop','failure']).default('work'),weight:number(2000).default(0),plannedWeight:optionalNumber(2000),reps:integer(10000).default(0),targetMin:integer(10000).default(0),targetMax:integer(10000).default(0),restSeconds:integer(7200).default(0),completed:z.boolean().default(true),failed:z.boolean().default(false),rpe:z.number().min(1).max(10).nullable().optional(),rir:optionalNumber(5),note:text.default(''),feeling:text.optional(),state:text.optional(),additionalNotes:text.optional(),durationSeconds:integer(86400).nullable().optional(),weightText:z.string().max(100).default(''),speedKph:optionalNumber(100),inclinePercent:optionalNumber(100)}).strict();
export const exerciseSchema=z.object({id:id.optional(),exerciseId:id,restSeconds:integer(7200).default(0),note:text.default(''),supersetId:id.nullable().optional(),collapsed:z.boolean().default(false),sets:z.array(setSchema).min(1).max(100)}).strict();
export const workoutSchema=z.object({name:z.string().trim().min(1).max(200),date,durationSeconds:integer(86400).default(0),startTime:z.string().max(40).optional(),note:text.default(''),gymId:id.nullable().optional(),exercises:z.array(exerciseSchema).min(1).max(100)}).strict();
export const planSchema=z.object({name:z.string().trim().min(1).max(200),folder:z.string().max(100).default('我的计划'),note:text.default(''),exercises:z.array(exerciseSchema).min(1).max(100)}).strict();
export const nutritionSchema=z.object({recordedAt:date,mealType:z.enum(['早餐','午餐','晚餐','加餐','其他','饮水']),foodName:z.string().trim().min(1).max(300),amount:z.string().max(300).default(''),calories:number(20000),proteinGrams:number(2000).default(0),carbsGrams:number(4000).default(0),fatGrams:number(2000).default(0),waterMl:number(20000).default(0),recognitionWarnings:z.array(z.string().max(1000)).max(20).default([]),recognitionReviewed:z.boolean().default(false),estimated:z.boolean().default(false),note:text.default('')}).strict();
export const weightSchema=z.object({recordedAt:date,weightKg:z.number().min(1).max(700),bodyFatPercent:z.number().min(1).max(80).nullable().optional(),note:text.default('')}).strict();
export const profileSchema=z.object({gender:z.string().max(40).optional(),age:integer(120).optional(),trainingYears:number(100).optional(),goal:z.string().max(100).optional(),heightCm:z.number().min(50).max(260).optional(),weightKg:z.number().min(1).max(700).optional(),weeklyTrainingDays:integer(7).optional(),preferredWeekdays:z.array(z.number().int().min(1).max(7)).max(7).optional(),activityLevel:z.enum(['low','moderate','high']).optional(),sessionMinutes:integer(600).optional(),planStyle:z.string().max(50).optional(),preferredRepRange:z.string().max(50).optional(),needsWarmupSets:z.boolean().optional(),focusMuscles:z.array(z.string().max(50)).max(30).optional(),reducedMuscles:z.array(z.string().max(50)).max(30).optional(),excludedMuscles:z.array(z.string().max(50)).max(30).optional(),dislikedExerciseIds:z.array(id).max(300).optional(),unavailableExerciseIds:z.array(id).max(300).optional()}).strict();
export const goalSchema=z.object({date:z.string().regex(/^\d{4}-\d{2}-\d{2}$/),calories:z.number().min(100).max(20000),proteinGrams:number(2000).optional(),carbsGrams:number(4000).optional(),fatGrams:number(2000).optional(),goalType:z.enum(['减脂','维持','增肌','其他']),basis:text.default(''),source:z.enum(['user','external-ai']).default('user')}).strict();
export const recordSchemas={workout:workoutSchema,plan:planSchema,nutrition:nutritionSchema,weight:weightSchema,profile:profileSchema,nutritionGoals:goalSchema,activeWorkout:workoutSchema};
export const mutationSchema=z.object({idempotencyKey:z.string().min(8).max(150),recordId:id.optional(),action:z.enum(['create','update','delete','append']).default('create'),expectedVersion:z.string().max(100).optional(),record:z.record(z.string(),z.unknown()).optional(),exercise:exerciseSchema.optional()}).strict();
const hash=v=>createHash('sha256').update(typeof v==='string'?v:JSON.stringify(v)).digest('hex');
function canonical(value){return Array.isArray(value)?value.map(canonical):value&&typeof value==='object'?Object.fromEntries(Object.keys(value).sort().map(k=>[k,canonical(value[k])])):value;}
export function initializeRecords(db){initializeBrowserStorage(db);db.exec(`CREATE TABLE IF NOT EXISTS web_mutations(user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,binding TEXT NOT NULL,key TEXT NOT NULL,input_hash TEXT NOT NULL,record_id TEXT NOT NULL,created_at TEXT NOT NULL,result_json TEXT,PRIMARY KEY(user_id,binding,key));`);}
export function appExercises(query='',muscle='',equipment='') { const q=query.trim().toLowerCase(); const records=Object.entries(catalog).filter(([key,v])=>(!q||[key,v.name,v.englishName].some(s=>s?.toLowerCase().includes(q)))&&(!muscle||v.muscle.includes(muscle))&&(!equipment||v.equipment.includes(equipment))).map(([id,v])=>({id,...v}));return {records:records.slice(0,150),total:records.length,muscles:[...new Set(Object.values(catalog).map(v=>v.muscle))],equipment:[...new Set(Object.values(catalog).map(v=>v.equipment))]};}
export function exerciseProgress(data,exerciseId){return {exercise:exerciseInfo({exerciseId}),sessions:data.workouts.filter(w=>w.exercises?.some(e=>e.exerciseId===exerciseId)).slice().sort((a,b)=>a.date.localeCompare(b.date)).map(w=>{const sets=w.exercises.filter(e=>e.exerciseId===exerciseId).flatMap((e,ei)=>e.sets.map((s,i)=>({...s,exerciseInstanceNumber:ei+1,setNumber:i+1,exerciseNote:e.note,exerciseInstanceId:e.id})));const completed=sets.filter(s=>s.completed&&s.type!=='warmup');return {recordId:w.id,date:w.date,name:w.name,note:w.note,sets,maxWeight:completed.length?Math.max(...completed.map(s=>s.weight)):null,maxReps:completed.length?Math.max(...completed.map(s=>s.reps)):null};})};}
function normalizeExercises(exercises,recordId,plan=false){return exercises.map((e,i)=>{if(!catalog[e.exerciseId])fail(422,'unknown_exercise_id_use_catalog');return {...e,id:e.id||`${recordId}_e${i}`,sets:e.sets.map((s,j)=>({...s,id:s.id||`${recordId}_s${i}_${j}`,note:[s.note,s.state&&`状态：${s.state}`,s.feeling&&`感受：${s.feeling}`,s.additionalNotes&&`补充：${s.additionalNotes}`].filter(Boolean).join('\n'),...(plan?{completed:false,plannedWeight:s.plannedWeight??s.weight}:{})})).map(({state,feeling,additionalNotes,...s})=>s)};});}
function normalize(kind,raw,recordId,stamp){const parsed=recordSchemas[kind].safeParse(raw);if(!parsed.success)fail(400,'invalid_record:'+parsed.error.issues.map(i=>i.path.join('.')).join(','));let record={...parsed.data,id:recordId,updatedAt:stamp};if(['workout','plan','activeWorkout'].includes(kind)){record.exercises=normalizeExercises(record.exercises,recordId,kind==='plan');if(kind==='workout'){const sets=record.exercises.flatMap(e=>e.sets).filter(s=>s.completed&&s.type!=='warmup');record={...record,startTime:record.startTime||record.date.slice(11,16),exerciseIds:record.exercises.map(e=>e.exerciseId),volume:sets.reduce((n,s)=>n+s.weight*s.reps,0),effectiveSets:sets.length,prs:[],prDetails:[]};}}if(kind==='nutrition'&&record.estimated)record.recognitionWarnings=[...new Set([...record.recognitionWarnings,'热量与营养素为估算，可根据实际份量调整。'])];if(kind==='profile'&&record.preferredWeekdays)record.weeklyTrainingDays=new Set(record.preferredWeekdays).size;return record;}
function rowPublic(row){return row?{entityType:row.entity_type,entityId:row.entity_id,revision:row.revision,payload:JSON.parse(row.payload_json),deleted:!!row.deleted_at}:null;}
function localEntities(ctx,userId,type){return ctx.db.prepare('SELECT * FROM sync_entities WHERE user_id=? AND entity_type=?').all(userId,type).map(rowPublic);}
function saveLocal(ctx,userId,entity){const current=ctx.db.prepare('SELECT revision FROM sync_entities WHERE user_id=? AND entity_type=? AND entity_id=?').get(userId,entity.entityType,entity.entityId);if((current?.revision||0)!==entity.baseRevision)fail(409,'revision_conflict');const revision=entity.baseRevision+1,stamp=new Date().toISOString();ctx.db.prepare('INSERT INTO sync_entities VALUES(?,?,?,?,?,?,?) ON CONFLICT(user_id,entity_type,entity_id) DO UPDATE SET revision=excluded.revision,payload_json=excluded.payload_json,deleted_at=excluded.deleted_at,updated_at=excluded.updated_at').run(userId,entity.entityType,entity.entityId,revision,JSON.stringify(entity.payload),entity.deleted?stamp:null,stamp);return {revision};}
const ownerLocks=new Map();
export async function mutateRecord(ctx,userId,kind,input){
 if(!recordSchemas[kind])fail(404,'record_kind_invalid');const p=mutationSchema.safeParse(input);if(!p.success)fail(400,'invalid_mutation');const body=p.data;
 if(body.action==='append'&&(!['plan','activeWorkout'].includes(kind)||!body.exercise))fail(400,'append_exercise_required');
 if(kind==='profile'&&body.action==='delete')fail(400,'profile_cannot_be_deleted');
 if(body.action!=='create'&&!body.recordId&&!['profile','activeWorkout'].includes(kind))fail(400,'record_id_required');
 if(isBrowserStorage(ctx,userId)){const key=hash(body.idempotencyKey),recordId=kind==='profile'?'profile':kind==='activeWorkout'?'active-workout':body.action==='create'?`${kind}_${hash(userId+key).slice(0,24)}`:body.recordId,stamp=new Date().toISOString();const record=body.action==='delete'?null:body.action==='append'?normalizeExercises([body.exercise],recordId+'_a'+key.slice(0,10),kind==='plan')[0]:normalize(kind,body.record,recordId,stamp);return browserRequest(ctx,userId,{type:'mutate',kind,body,record,recordId,key,inputHash:hash(canonical({kind,...body})),stamp});}
 const binding=ctx.db.prepare('SELECT remote_user_id FROM agent_backend_links WHERE user_id=?').get(userId)?.remote_user_id||'local';
 const lockKey=userId+':'+binding,prior=ownerLocks.get(lockKey)||Promise.resolve();let release;const next=new Promise(r=>release=r);ownerLocks.set(lockKey,next);await prior;
 try {
  const key=hash(body.idempotencyKey),inputHash=hash(canonical({kind,...body})),recordId=kind==='profile'?'profile':kind==='activeWorkout'?'active-workout':body.action==='create'?`${kind}_${hash(userId+binding+key).slice(0,24)}`:body.recordId;
  let journal=ctx.db.prepare('SELECT * FROM web_mutations WHERE user_id=? AND binding=? AND key=?').get(userId,binding,key);
  if(journal&&journal.input_hash!==inputHash)fail(409,'idempotency_key_reused');
  if(journal?.result_json)return {...JSON.parse(journal.result_json),replayed:true};
  const stamp=journal?.created_at||new Date().toISOString();const record=body.action==='delete'?null:body.action==='append'?normalizeExercises([body.exercise],recordId+'_a'+key.slice(0,10),kind==='plan')[0]:normalize(kind,body.record,recordId,stamp);
  if(!journal)ctx.db.prepare('INSERT INTO web_mutations VALUES(?,?,?,?,?,?,NULL)').run(userId,binding,key,inputHash,recordId,stamp);
  const remote=binding!=='local',type=['workout','plan'].includes(kind)?kind:'settings',entityId=type==='settings'?'mobile_backup_v1':recordId;
  const perform=async()=>{
   for(let attempt=0;attempt<5;attempt++){
    const entities=remote?await remoteSyncEntities(ctx,userId,type):localEntities(ctx,userId,type);
    const current=entities.find(e=>e.entityId===entityId);const payload=current?.payload||{};
    const applied=type==='settings'?payload._webMutations?.[key]:payload._webMutation;
    if(applied?.key===key){if(applied.inputHash!==inputHash)fail(409,'idempotency_key_reused');return {...applied.result,replayed:true};}
    let updated,existing;
    if(type==='settings'){
     existing=kind==='profile'?payload.trainingProfile?.profile:kind==='activeWorkout'?payload.activeWorkout:(payload[kind]||[]).find(r=>r.id===recordId);
    }else existing=current&&!current.deleted?payload:null;
    if(body.action!=='create'&&!['profile','activeWorkout'].includes(kind)&&!existing)fail(404,'record_not_found');
    if(existing&&body.action==='create'&&!['profile','activeWorkout'].includes(kind))fail(409,'record_exists');
    if(body.expectedVersion&&existing?.updatedAt!==body.expectedVersion)fail(409,'record_changed_refresh');
    if(body.action==='append'&&!existing)fail(404,'record_not_found');
    const finalRecord=body.action==='append'?{...existing,updatedAt:stamp,exercises:[...existing.exercises,record]}:record;
    const result={kind,recordId,record:kind==='profile'?{...existing,...finalRecord}:finalRecord,deleted:body.action==='delete',savedAt:stamp,destination:remote?'software-backend':'local-backend'};
    const marker={key,inputHash,result};
    if(type==='settings'){
     updated={...payload,schemaVersion:payload.schemaVersion||1,updatedAt:stamp};
     if(kind==='profile')updated.trainingProfile={...payload.trainingProfile,profile:{...existing,...record}};
     else if(kind==='activeWorkout')updated.activeWorkout=finalRecord;
     else {const list=payload[kind]||[];if(!Array.isArray(list))fail(409,'invalid_existing_backup');updated[kind]=[...list.filter(r=>r.id!==recordId),...(record?[record]:[])];if(body.action==='delete')updated.webTombstones={...payload.webTombstones,[kind]:{...payload.webTombstones?.[kind],[recordId]:stamp}};}
     // Durable replay markers also recover a lost upstream response. Limit metadata growth.
     updated._webMutations=Object.fromEntries([...Object.entries(payload._webMutations||{}).slice(-127),[key,marker]]);
    }else updated={...(finalRecord||payload),_webMutation:marker};
    try {const entity={entityType:type,entityId,baseRevision:current?.revision||0,payload:updated,deleted:type!=='settings'&&body.action==='delete'};if(remote)await writeRemoteEntity(ctx,userId,entity);else saveLocal(ctx,userId,entity);return result;}catch(e){if(e.code!=='revision_conflict'||attempt===4)throw e;}
   }
  };
  let result;
  if(remote){result=await perform();ctx.db.prepare('UPDATE web_mutations SET result_json=? WHERE user_id=? AND binding=? AND key=?').run(JSON.stringify(result),userId,binding,key);await refreshBackend(ctx,userId);}
  else { // No awaits inside the SQLite transaction: data and replay result commit together.
   // perform only needs async for remote I/O; local execution is handled synchronously below.
   result=mutateLocal(ctx,userId,kind,body,record,recordId,stamp,key,inputHash,type,entityId);
   ctx.db.transaction(()=>{saveLocal(ctx,userId,result.entity);ctx.db.prepare('UPDATE web_mutations SET result_json=? WHERE user_id=? AND binding=? AND key=?').run(JSON.stringify(result.result),userId,binding,key);})();result=result.result;
  }
  ctx.db.prepare('INSERT OR IGNORE INTO audit_log VALUES(?,?,?,?,?,?)').run('audit_web_'+hash(userId+key+stamp).slice(0,24),userId,'mcp_write',kind,JSON.stringify({recordId,action:body.action,destination:result.destination}),stamp);
  return result;
 } finally {release();if(ownerLocks.get(lockKey)===next)ownerLocks.delete(lockKey);}
}
function mutateLocal(ctx,userId,kind,body,record,recordId,stamp,key,inputHash,type,entityId){
 const current=localEntities(ctx,userId,type).find(e=>e.entityId===entityId),payload=current?.payload||{};
 const existing=type==='settings'?(kind==='profile'?payload.trainingProfile?.profile:kind==='activeWorkout'?payload.activeWorkout:(payload[kind]||[]).find(r=>r.id===recordId)):current&&!current.deleted?payload:null;
 if(body.action!=='create'&&!['profile','activeWorkout'].includes(kind)&&!existing)fail(404,'record_not_found');
 if(existing&&body.action==='create'&&!['profile','activeWorkout'].includes(kind))fail(409,'record_exists');
 if(body.expectedVersion&&existing?.updatedAt!==body.expectedVersion)fail(409,'record_changed_refresh');
 if(body.action==='append'&&!existing)fail(404,'record_not_found');
    const finalRecord=body.action==='append'?{...existing,updatedAt:stamp,exercises:[...existing.exercises,record]}:record;
    const result={kind,recordId,record:kind==='profile'?{...existing,...finalRecord}:finalRecord,deleted:body.action==='delete',savedAt:stamp,destination:'local-backend'};
 let updated;
 if(type==='settings'){updated={...payload,schemaVersion:payload.schemaVersion||1,updatedAt:stamp};if(kind==='profile')updated.trainingProfile={...payload.trainingProfile,profile:{...existing,...record}};else if(kind==='activeWorkout')updated.activeWorkout=finalRecord;else {if(payload[kind]&&!Array.isArray(payload[kind]))fail(409,'invalid_existing_backup');updated[kind]=[...(payload[kind]||[]).filter(r=>r.id!==recordId),...(record?[record]:[])];if(body.action==='delete')updated.webTombstones={...payload.webTombstones,[kind]:{...payload.webTombstones?.[kind],[recordId]:stamp}};}}
 else updated=finalRecord||payload;
 return {result,entity:{entityType:type,entityId,baseRevision:current?.revision||0,payload:updated,deleted:type!=='settings'&&body.action==='delete'}};
}

export function daySummary(data,day) {
 const tz=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Shanghai',year:'numeric',month:'2-digit',day:'2-digit'});
 const records=data.nutrition.filter(r=>{const d=new Date(r.recordedAt);return !isNaN(d)&&tz.format(d)===day;});
 const goals=data.nutritionGoals||[],goal=goals.filter(g=>g.date===day).sort((a,b)=>(b.updatedAt||'').localeCompare(a.updatedAt||''))[0]||null;
 const intake=records.reduce((s,r)=>({calories:s.calories+(Number(r.calories)||0),proteinGrams:s.proteinGrams+(Number(r.proteinGrams)||0),carbsGrams:s.carbsGrams+(Number(r.carbsGrams)||0),fatGrams:s.fatGrams+(Number(r.fatGrams)||0),waterMl:s.waterMl+(Number(r.waterMl)||0)}),{calories:0,proteinGrams:0,carbsGrams:0,fatGrams:0,waterMl:0});
 return {date:day,timeZone:'Asia/Shanghai',goal,intake,remainingCalories:goal?goal.calories-intake.calories:null,records,recordCount:records.length,containsEstimates:records.some(r=>r.estimated),profile:data.profile};
}

export async function recordData(ctx,userId){
 if(!isBrowserStorage(ctx,userId))return cloudData(ctx.db,userId);
 const data=await browserRequest(ctx,userId,{type:'read'});
 if(!data||!Array.isArray(data.workouts)||!Array.isArray(data.nutrition)||!Array.isArray(data.plans)||!Array.isArray(data.weight)||!Array.isArray(data.nutritionGoals)||!data.profile)fail(502,'invalid_browser_data');
 const enrich=r=>r?{...r,exercises:r.exercises?.map(e=>{const info=exerciseInfo(e);return {...e,name:info.name,muscle:info.muscle};})}:r;
 return {...data,workouts:data.workouts.map(enrich),plans:data.plans.map(enrich),activeWorkout:enrich(data.activeWorkout)};
}
export async function exerciseHistory(ctx,userId,exerciseId){return exerciseProgress(await recordData(ctx,userId),exerciseId);}
export async function nutritionDay(ctx,userId,day){return daySummary(await recordData(ctx,userId),day);}
