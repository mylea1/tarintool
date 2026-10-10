import {initializeEquipment,readEquipment,saveEquipment,equipmentSchema} from './exercise-equipment.mjs';
import { initializeManagement, manageAgent } from './agent-management.mjs';
import { storageStatus, selectStorage, isBrowserStorage, broker } from './browser-bridge.mjs';
import { initializeRecords, appExercises, exerciseHistory, mutateRecord, mutationSchema, nutritionDay, recordData, recordSchemas, exerciseSchema } from './web-records.mjs';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { z } from 'zod';
import { registerIntegrationMcp, integrationStatus, readReference, searchExercises, exerciseDetail, coachExerciseContext } from './agent-integrations.mjs';
import { initializeRemote, backendStatus, connectBackend, refreshBackend, disconnectBackend, remoteConversation } from './agent-remote.mjs';
import { randomId, randomToken, sha256, nowIso } from './security.mjs';
import { cloudData, dashboard, pageRecords, conversationList, conversationDetail, BUILTIN_SKILLS } from './agent-data.mjs';

const root = fileURLToPath(new URL('../agent-web/', import.meta.url));
const SCOPES = ['workouts','profile','nutrition','chats','skills','workouts.write','profile.write','nutrition.write','skills.write','chats.write'];
const fail = (status, code) => { throw Object.assign(new Error(code),{status,code}); };
const bounded = (v,n=200) => typeof v==='string' ? v.trim().slice(0,n) : '';
const json = (v) => JSON.parse(v);
const textResult = (data) => ({ content:[{type:'text',text:JSON.stringify(data)}] });
const pagination = { limit:z.number().int().min(1).max(100).default(20),offset:z.number().int().min(0).max(100000).default(0),startDate:z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),endDate:z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional() };
export function initializeAgent(db) {
  initializeManagement(db);
  initializeEquipment(db);
  initializeRemote(db);
  initializeRecords(db);
  db.exec(`
    CREATE TABLE IF NOT EXISTS agent_preferences (
      user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      share_memory INTEGER NOT NULL DEFAULT 0,
      use_cloud_data INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS agent_skills (
      id TEXT NOT NULL, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name TEXT NOT NULL, description TEXT NOT NULL, instructions TEXT NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1, external INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL, PRIMARY KEY(user_id,id)
    );
    CREATE TABLE IF NOT EXISTS agent_tokens (
      id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      label TEXT NOT NULL, token_hash TEXT NOT NULL UNIQUE, scopes_json TEXT NOT NULL,
      created_at TEXT NOT NULL, expires_at TEXT NOT NULL, revoked_at TEXT, last_used_at TEXT
    );
  `);
}
export function preferences(db,userId) {
  const p=db.prepare('SELECT * FROM agent_preferences WHERE user_id=?').get(userId);
  return { shareMemory:p?.share_memory===1,useCloudData:p?.use_cloud_data===1 };
}
export function skillsFor(db,userId) {
  const saved=db.prepare('SELECT * FROM agent_skills WHERE user_id=? ORDER BY updated_at DESC').all(userId).map((s)=>({id:s.id,name:s.name,description:s.description,instructions:s.instructions,enabled:!!s.enabled,external:!!s.external,builtin:BUILTIN_SKILLS.some((b)=>b.id===s.id)}));
  return [...saved,...BUILTIN_SKILLS.filter((s)=>!saved.some((x)=>x.id===s.id))];
}
function member(ctx,userId,api) { api.requireActiveMembership(ctx.db,userId); }
function ownedConversation(ctx,userId,id) {
  const c=ctx.db.prepare('SELECT * FROM conversations WHERE id=? AND user_id=?').get(id,userId);
  if (!c) fail(404,'conversation_not_found');
  return c;
}
function audit(ctx,userId,action,target,detail={}) {
  ctx.db.prepare('INSERT INTO audit_log(id,actor_user_id,action,target,detail_json,created_at) VALUES(?,?,?,?,?,?)').run(randomId('audit_'),userId,action,target,JSON.stringify(detail),nowIso());
}
function authorizeMcp(req,ctx,api) {
  const raw=String(req.headers.authorization||'').match(/^Bearer (.+)$/i)?.[1];
  if (!raw) fail(401,'mcp_token_required');
  const token=ctx.db.prepare('SELECT * FROM agent_tokens WHERE token_hash=? AND revoked_at IS NULL AND expires_at>?').get(sha256(raw,ctx.cfg.sessionPepper),nowIso());
  if (!token) fail(401,'mcp_token_invalid');
  member(ctx,token.user_id,api);
  return token;
}
function createMemberMcp(ctx,token,api) {
  const scopes=json(token.scopes_json), userId=token.user_id;
  const check=async(scope,operation)=>{
    const fresh=ctx.db.prepare('SELECT id FROM agent_tokens WHERE id=? AND revoked_at IS NULL AND expires_at>?').get(token.id,nowIso());
    if (!fresh) fail(401,'mcp_token_invalid');
    member(ctx,userId,api);
    if(isBrowserStorage(ctx,userId)&&scope==='chats')fail(403,'chats_unavailable_in_browser_mode');
    if (!scopes.includes(scope)) fail(403,'mcp_scope_required');
    if(!isBrowserStorage(ctx,userId))await refreshBackend(ctx,userId);
    ctx.db.prepare('UPDATE agent_tokens SET last_used_at=? WHERE id=?').run(nowIso(),token.id);
    audit(ctx,userId,scope.endsWith('.write')?'mcp_write':'mcp_read',operation,{tokenId:token.id,scope});
  };
  const server=new McpServer({name:'traintool',version:'2.0.0'});
  const writeTool=(name,scope,description,kind)=>{if(!scopes.includes(scope))return;server.registerTool(name,{description,inputSchema:{...mutationSchema.shape,record:recordSchemas[kind].optional()},annotations:{readOnlyHint:false,destructiveHint:true,idempotentHint:true,openWorldHint:false}},async(args)=>{try{await check(scope,name);return textResult(await mutateRecord(ctx,userId,kind,args));}catch(e){return {isError:true,content:[{type:'text',text:e.code||'write_failed'}]};}});};
  writeTool('save_workout','workouts.write','保存、修改或删除本人训练。record 必须有 name、ISO date、exercises，每个动作使用 search_app_exercises 的稳定 exerciseId，sets 数组含 weight/reps/restSeconds/completed/type/note，可加 state/feeling/additionalNotes 保存状态感受。支持动作和整次训练 note。每个独立请求提供唯一 idempotencyKey；网络重试重复使用同一 key 和参数。update/delete 提供 recordId，建议 expectedVersion 防止覆盖。','workout');
  writeTool('save_active_workout','workouts.write','保存或修改当前进行中的训练，record 含 name/date/exercises，保留每组 completed、重量次数休息与感受备注。网页可继续此训练。幂等键必填。','activeWorkout');
  writeTool('save_training_plan','workouts.write','保存本人 App 格式计划，record 含 name/folder/exercises（每组重量次数休息备注）。幂等键必填。','plan');
  writeTool('save_nutrition_entry','nutrition.write','将用户描述或外部 AI 照片估算真实保存到 App 饮食云备份。record: recordedAt(ISO含时区),mealType(早餐/午餐/晚餐/加餐/其他/饮水),foodName,amount,calories,proteinGrams,carbsGrams,fatGrams,waterMl,note,estimated。照片推测必须 estimated=true，保留不确定性至 recognitionWarnings，不声称精确识别。支持 update/delete + recordId，幂等键必填。','nutrition');
  writeTool('save_body_weight','profile.write','记录体重：record 含 recordedAt、weightKg、可选 bodyFatPercent 和 note。支持修改与删除。','weight');
  writeTool('save_body_profile','profile.write','合并维护本人身体与训练资料：heightCm/weightKg/gender/age/goal/trainingYears/preferredWeekdays/focusMuscles 等。保留未提供字段。','profile');
  writeTool('save_nutrition_goal','nutrition.write','保存用户或外部 AI 计算的某日热量目标。record 含 date(YYYY-MM-DD)、calories、goalType(减脂/维持/增肌/其他)、basis计算依据、source(user/external-ai)，可选营养素目标。先询问缺失资料；目标和建议由外部 AI 计算，服务不伪造计算结果。','nutritionGoals');
  const managementTool=(name,scope,kind,inputSchema)=>{if(!scopes.includes(scope))return;server.registerTool(name,{description:kind==='skill'?'创建、更新或删除本人的共享技能，保存到服务器。external=true 才向外部 AI 共享；幂等键必填。':'创建或追加本人服务器聊天记录，更新标题或删除会话。messages 含 user/assistant role 和 content；不覆盖 App 同步的 mobile: 历史。幂等键必填。',inputSchema,annotations:{readOnlyHint:false,destructiveHint:true,idempotentHint:true}},async(args)=>{try{await check(scope,name);if(isBrowserStorage(ctx,userId))fail(409,'server_storage_required');return textResult(manageAgent(ctx,userId,kind,args));}catch(e){return {isError:true,content:[{type:'text',text:e.code||'write_failed'}]};}});};
  managementTool('save_skill','skills.write','skill',{idempotencyKey:z.string().min(8).max(150),action:z.enum(['save','delete']).default('save'),skillId:z.string().regex(/^[a-zA-Z0-9_-]{1,100}$/).optional(),record:z.object({name:z.string().trim().min(1).max(100),description:z.string().max(500).default(''),instructions:z.string().trim().min(1).max(12000),enabled:z.boolean().default(true),external:z.boolean().default(true)}).optional()});
  managementTool('save_conversation','chats.write','conversation',{idempotencyKey:z.string().min(8).max(150),action:z.enum(['save','delete']).default('save'),conversationId:z.string().regex(/^[a-zA-Z0-9_-]{1,120}$/).optional(),title:z.string().trim().min(1).max(200).optional(),messages:z.array(z.object({role:z.enum(['user','assistant']),content:z.string().min(1).max(20000)})).max(100).default([])});
  if(scopes.includes('workouts.write'))server.registerTool('save_exercise_equipment',{description:'给本人动作保存器械名称与照片，或修改、删除。photo 为 JPEG/PNG/WebP base64 data URL，图片最大1MB，保存到服务器；equipmentId 用于修改删除。',inputSchema:equipmentSchema.shape,annotations:{readOnlyHint:false,destructiveHint:true}},async(a)=>{try{await check('workouts.write','save_exercise_equipment');return textResult(saveEquipment(ctx,userId,a,id=>appExercises(id).records.some(e=>e.id===id)));}catch(e){return {isError:true,content:[{type:'text',text:e.code||e.message}]};}});
  const register=(name,scope,description,inputSchema,fn)=>{
    if (!scopes.includes(scope)) return;
    server.registerTool(name,{description,inputSchema,annotations:{readOnlyHint:true,destructiveHint:false,openWorldHint:false}},async(args)=>{
      try { await check(scope,name); return textResult(await fn(args)); }
      catch(e) { return {isError:true,content:[{type:'text',text:e.code||'read_failed'}]}; }
    });
  };
  for(const [name,kind] of [['append_plan_exercise','plan'],['append_current_workout_exercise','activeWorkout']]){if(scopes.includes('workouts.write'))server.registerTool(name,{description:'将 App 动作库动作追加到指定计划或当前训练，保留原动作及备注。exercise 含稳定 exerciseId、sets（每组重量次数休息备注），idempotencyKey 必填，重试使用相同参数；expectedVersion 可防止覆盖。',inputSchema:{idempotencyKey:z.string().min(8).max(150),planId:z.string().optional(),expectedVersion:z.string().optional(),exercise:exerciseSchema},annotations:{readOnlyHint:false,destructiveHint:false,idempotentHint:true}},async(a)=>{try{await check('workouts.write',name);return textResult(await mutateRecord(ctx,userId,kind,{idempotencyKey:a.idempotencyKey,action:'append',recordId:kind==='plan'?a.planId:'active-workout',...(a.expectedVersion?{expectedVersion:a.expectedVersion}:{}),exercise:a.exercise}));}catch(e){return {isError:true,content:[{type:'text',text:e.code||'write_failed'}]};}});}
  register('read_exercise_equipment','workouts','读取本人给动作添加的器械名称和照片，照片为 data URL。',{exerciseId:z.string().max(120)},a=>readEquipment(ctx,userId,a.exerciseId));
  register('read_current_workout','workouts','读取正在进行中的训练草稿及每组数据，未开始时返回 null。',{},async()=>({workout:(await recordData(ctx,userId)).activeWorkout||null}));
  register('get_app_exercise','workouts','读取 App 动作详情、教学步骤、图像路径、肌群与器械，使用稳定 ID。',{exerciseId:z.string().max(120)},a=>{const e=appExercises(a.exerciseId).records.find(e=>e.id===a.exerciseId);if(!e)fail(404,'exercise_not_found');return {...e,imageUrl:e.imageAsset?ctx.cfg.agentPublicBaseUrl+'/agent/exercise-media/'+e.imageAsset:null,gifUrl:e.gifAsset?ctx.cfg.agentPublicBaseUrl+'/agent/exercise-media/'+e.gifAsset:null};});
  register('search_app_exercises','workouts','查找本 App 动作库，返回用于训练保存的稳定动作 ID、中文名和器械。',{query:z.string().max(100).default(''),muscle:z.string().max(50).default(''),equipment:z.string().max(50).default('')},a=>appExercises(a.query,a.muscle,a.equipment));
  register('read_exercise_progress','workouts','按稳定动作 ID 返回每次训练的逐组重量、次数、休息和备注，以及各次完成工作组最大重量与最大次数。最大值可能来自不同组，不等同于同一组表现。',{exerciseId:z.string().max(120)},a=>exerciseHistory(ctx,userId,a.exerciseId));
  register('read_nutrition_day','nutrition','读取指定日期的热量目标、依据、已记录摄入及剩余额度、营养素、饮水和个人资料，时区 Asia/Shanghai。缺少目标返回 null；未记录不能视为全天实际摄入。',{date:z.string().regex(/^\d{4}-\d{2}-\d{2}$/)},a=>nutritionDay(ctx,userId,a.date));
  register('read_workout_history','workouts','读取本人已同步训练记录，支持日期与分页。',pagination,async(a)=>pageRecords((await recordData(ctx,userId)).workouts,a));
  register('read_training_plans','workouts','读取本人已同步的训练计划。',pagination,async(a)=>pageRecords((await recordData(ctx,userId)).plans,a));
  register('read_recovery','workouts','读取肌群训练量与恢复估算，未知肌群不能视为完全恢复。',{},async()=>dashboard(await recordData(ctx,userId)));
  register('read_body_profile','profile','读取本人身高、体重、目标及体重记录。',pagination,async(a)=>{const d=await recordData(ctx,userId);return {profile:d.profile,weight:pageRecords(d.weight,a),syncedAt:d.syncedAt};});
  register('read_nutrition_history','nutrition','读取本人实际饮食记录，未记录不等于没有摄入。',pagination,async(a)=>pageRecords((await recordData(ctx,userId)).nutrition,a));
  register('list_conversations','chats','列出本人聊天会话，不读取正文。',{limit:pagination.limit,offset:pagination.offset},(a)=>pageRecords(conversationList(ctx.db,userId),a));
  register('read_conversation','chats','读取指定本人会话，按消息分页。',{conversationId:z.string().min(1).max(200),limit:pagination.limit,offset:pagination.offset},(async(a)=>{const c=await remoteConversation(ctx,userId,a.conversationId)||conversationDetail(ctx.db,userId,a.conversationId);if(!c)fail(404,'conversation_not_found');return {...c,messages:pageRecords(c.messages,a)};}));
  register('list_skills','skills','列出本人允许外部 AI 使用的技能。',{},()=>({skills:skillsFor(ctx.db,userId).filter((s)=>s.enabled&&s.external).map(({instructions,...s})=>s)}));
  register('get_skill','skills','获取本人共享的 SKILL.md 指令，由调用方 AI 执行。不会执行任意代码。',{skillId:z.string().min(1).max(100)},(a)=>{const s=skillsFor(ctx.db,userId).find((s)=>s.id===a.skillId&&s.enabled&&s.external);if(!s)fail(404,'skill_not_found');return {id:s.id,name:s.name,markdown:skillMarkdown(s)};});
  if (scopes.includes('skills')) {
    registerIntegrationMcp(server,check);
    for (const skill of skillsFor(ctx.db,userId).filter((s)=>s.enabled&&s.external)) {
      server.registerPrompt(skill.id,{title:skill.name,description:skill.description,argsSchema:{request:z.string().optional()}},async({request})=>{
        await check('skills',`prompt:${skill.id}`);
        const fresh=skillsFor(ctx.db,userId).find((s)=>s.id===skill.id&&s.enabled&&s.external);
        if(!fresh)fail(404,'skill_not_found');
        return {description:fresh.description,messages:[{role:'user',content:{type:'text',text:`${fresh.instructions}\n\n用户请求：${request||'请按此技能开展分析。'}\n只读取本连接中获授权的工具。缺少权限时请向用户说明。`}}]};
      });
      server.registerResource(skill.id,`kilo://skills/${skill.id}`,{mimeType:'text/markdown',description:skill.description},async(uri)=>{
        await check('skills',`resource:${skill.id}`);
        const fresh=skillsFor(ctx.db,userId).find((s)=>s.id===skill.id&&s.enabled&&s.external);
        if(!fresh)fail(404,'skill_not_found');
        return {contents:[{uri:uri.href,mimeType:'text/markdown',text:skillMarkdown(fresh)}]};
      });
    }
  }
  return server;
}
export function skillMarkdown(s) {
  const portableName=s.id.toLowerCase().replace(/[^a-z0-9-]/g,'-').replace(/-+/g,'-').replace(/^-|-$/g,'').slice(0,64)||'kilo-coach';
  return `---\nname: ${portableName}\ndescription: ${JSON.stringify(s.description||s.name)}\n---\n\n# ${s.name}\n\n${s.instructions}\n\n## 数据访问\n使用 KILO MCP 中获授权的工具；写入需单独权限和幂等键。仅工具返回保存成功后才说明已写入，估算需明确标注。\n`;
}
async function mcpRequest(req,res,ctx,api) {
  // Reject untrusted browser origins and hosts before token processing.
  const host=String(req.headers.host||'').split(':')[0];
  const publicHost=new URL(ctx.cfg.publicBaseUrl).hostname;
  const webOrigin=new URL(ctx.cfg.agentPublicBaseUrl||ctx.cfg.publicBaseUrl);
  if (![ctx.cfg.host,'127.0.0.1','localhost',publicHost,webOrigin.hostname].includes(host)) fail(403,'mcp_host_forbidden');
  if (req.headers.origin && !ctx.cfg.allowedOrigins.has(req.headers.origin) && req.headers.origin!==new URL(ctx.cfg.publicBaseUrl).origin && req.headers.origin!==webOrigin.origin) fail(403,'mcp_origin_forbidden');
  const token=authorizeMcp(req,ctx,api);
  if(!isBrowserStorage(ctx,token.user_id))await refreshBackend(ctx,token.user_id);
  if (req.method!=='POST') { res.writeHead(405,{allow:'POST'});res.end();return; }
  const body=await api.readBody(req,ctx.cfg.maxJsonBytes);
  const server=createMemberMcp(ctx,token,api);
  const transport=new StreamableHTTPServerTransport({sessionIdGenerator:undefined,enableJsonResponse:true});
  res.on('close',()=>{void transport.close();void server.close();});
  await server.connect(transport);
  await transport.handleRequest(req,res,body);
}

function staticFile(req,res,pathname) {
  let file;
  if (['/','/web','/web/','/agent','/agent/','/agent/index.html'].includes(pathname)) file='index.html';
  else if (/^\/agent\/(app\.js|device-storage\.js|styles\.css|assets\/[a-z-]+\.png|muscles\/[a-z-]+\.(svg|md|json))$/i.test(pathname)) file=pathname.slice(7);
  else return false;
  if (req.method!=='GET' && req.method!=='HEAD') return false;
  const full=path.join(root,file);
  if (!fs.existsSync(full)) return false;
  const type=file.endsWith('.html')?'text/html':file.endsWith('.js')?'text/javascript':file.endsWith('.css')?'text/css':file.endsWith('.svg')?'image/svg+xml':file.endsWith('.png')?'image/png':file.endsWith('.json')?'application/json':'text/plain';
  res.writeHead(200,{'content-type':`${type}; charset=utf-8`,'cache-control':'no-cache','x-content-type-options':'nosniff','content-security-policy':"default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'",'referrer-policy':'no-referrer'});
  res.end(req.method==='HEAD'?undefined:fs.readFileSync(full));return true;
}
export async function handleAgentRequest(req,res,ctx,api) {
  const url=new URL(req.url,'http://localhost');
  if(['/zh-hans/dashboard','/kilo/'].includes(url.pathname)){res.writeHead(302,{location:'/agent/'});res.end();return true;}
  if (staticFile(req,res,url.pathname)) return true;
  const media=url.pathname.match(/^\/agent\/exercise-media\/(\d{4}\.(?:jpg|gif))$/);
  if(media&&['GET','HEAD'].includes(req.method)){const full=fileURLToPath(new URL('../../mobile/assets/exercises/reference/'+media[1],import.meta.url));if(!fs.existsSync(full))fail(404,'exercise_media_missing');res.writeHead(200,{'content-type':media[1].endsWith('.gif')?'image/gif':'image/jpeg','cache-control':'public, max-age=86400'});res.end(req.method==='HEAD'?undefined:fs.readFileSync(full));return true;}
  if (url.pathname==='/mcp') {await mcpRequest(req,res,ctx,api);return true;}
  if (!url.pathname.startsWith('/v1/agent/')) return false;
  const user=api.authenticate(req,ctx);
  member(ctx,user.id,api);
  const write=(status,data)=>api.writeJson(res,status,data,req,ctx.cfg);
  const data=()=>recordData(ctx,user.id);
  if(url.pathname==='/v1/agent/storage'&&req.method==='GET'){write(200,storageStatus(ctx,user.id));return true;}
  if(url.pathname==='/v1/agent/storage'&&req.method==='POST'){write(200,selectStorage(ctx,user.id,await api.readBody(req,ctx.cfg.maxJsonBytes)));return true;}
  if(url.pathname.startsWith('/v1/agent/device/')){
   const status=storageStatus(ctx,user.id),deviceId=url.searchParams.get('deviceId');
   if(status.mode!=='browser'||status.deviceId!==deviceId)fail(403,'device_not_bound');
   if(url.pathname==='/v1/agent/device/poll'&&req.method==='GET'){const cancel=new AbortController();res.on('close',()=>cancel.abort());write(200,{jobs:await broker(ctx).poll(user.id,deviceId,cancel.signal)});return true;}
   if(url.pathname==='/v1/agent/device/result'&&req.method==='POST'){const b=await api.readBody(req,12*1024*1024);broker(ctx).complete(user.id,deviceId,b.id,b.result,b.error);write(200,{ok:true});return true;}
   fail(404,'device_route_not_found');
  }
  if(url.pathname==='/v1/agent/backend'&&req.method==='POST') {write(200,await connectBackend(ctx,user.id,await api.readBody(req,ctx.cfg.maxJsonBytes)));return true;}
  if(url.pathname==='/v1/agent/backend'&&req.method==='DELETE') {disconnectBackend(ctx,user.id);write(200,backendStatus(ctx,user.id));return true;}
  // Disconnect remains available even when an upstream session is expired.
  if(!isBrowserStorage(ctx,user.id))await refreshBackend(ctx,user.id);
  if(url.pathname==='/v1/agent/knowledge'&&req.method==='GET') {write(200,readReference(url.searchParams.get('id')));return true;}
  if(url.pathname==='/v1/agent/exercises'&&req.method==='GET') {write(200,searchExercises({query:(url.searchParams.get('query')||'').slice(0,100),limit:20}));return true;}
  if(url.pathname==='/v1/agent/app-exercises'&&req.method==='GET'){write(200,appExercises(url.searchParams.get('query')||'',url.searchParams.get('muscle')||'',url.searchParams.get('equipment')||''));return true;}
  if(url.pathname==='/v1/agent/exercise-progress'&&req.method==='GET'){write(200,await exerciseHistory(ctx,user.id,url.searchParams.get('exerciseId')||''));return true;}
  if(url.pathname==='/v1/agent/nutrition-day'&&req.method==='GET'){const day=url.searchParams.get('date')||'';if(!/^\d{4}-\d{2}-\d{2}$/.test(day))fail(400,'invalid_date');write(200,await nutritionDay(ctx,user.id,day));return true;}
  if(url.pathname==='/v1/agent/exercise-equipment'&&req.method==='GET'){write(200,readEquipment(ctx,user.id,url.searchParams.get('exerciseId')||''));return true;}
  if(url.pathname==='/v1/agent/exercise-equipment'&&req.method==='POST'){write(200,saveEquipment(ctx,user.id,await api.readBody(req,ctx.cfg.maxJsonBytes),id=>appExercises(id).records.some(e=>e.id===id)));return true;}
  const recordMatch=url.pathname.match(/^\/v1\/agent\/records\/(workout|plan|nutrition|weight|profile|nutritionGoals|activeWorkout)$/);
  if(recordMatch&&req.method==='POST'){const result=await mutateRecord(ctx,user.id,recordMatch[1],await api.readBody(req,ctx.cfg.maxJsonBytes));write(200,result);return true;}
  const exerciseMatch=url.pathname.match(/^\/v1\/agent\/exercises\/(\d+)$/);
  if(exerciseMatch&&req.method==='GET') {write(200,exerciseDetail(Number(exerciseMatch[1])));return true;}
  if (url.pathname==='/v1/agent/bootstrap'&&req.method==='GET') {
    const cloud=await data();write(200,{storage:storageStatus(ctx,user.id),integrations:integrationStatus(),backend:backendStatus(ctx,user.id),user:{id:user.id,displayName:user.display_name},aiConfigured:!!ctx.cfg.deepSeekApiKey,model:ctx.cfg.deepSeekModel,preferences:preferences(ctx.db,user.id),dashboard:dashboard(cloud),activeWorkout:cloud.activeWorkout,profile:cloud.profile,weight:cloud.weight,nutritionGoals:cloud.nutritionGoals,nutrition:cloud.nutrition,workouts:cloud.workouts,plans:cloud.plans,conversations:isBrowserStorage(ctx,user.id)?[]:conversationList(ctx.db,user.id,cloud),skills:skillsFor(ctx.db,user.id),scopes:SCOPES});return true;
  }
  if (url.pathname==='/v1/agent/preferences'&&req.method==='PUT') {
    const b=await api.readBody(req,ctx.cfg.maxJsonBytes);
    if (typeof b.shareMemory!=='boolean'||typeof b.useCloudData!=='boolean')fail(400,'invalid_preferences');
    ctx.db.prepare('INSERT INTO agent_preferences VALUES(?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET share_memory=excluded.share_memory,use_cloud_data=excluded.use_cloud_data,updated_at=excluded.updated_at').run(user.id,Number(b.shareMemory),Number(b.useCloudData),nowIso());
    write(200,preferences(ctx.db,user.id));return true;
  }
  if (url.pathname==='/v1/agent/skills'&&req.method==='POST') {
    const b=await api.readBody(req,ctx.cfg.maxJsonBytes),id=bounded(b.id,100)||randomId('skill_');
    if(!/^[a-zA-Z0-9_-]{1,100}$/.test(id))fail(400,'invalid_skill_id');
    const name=bounded(b.name,100),description=bounded(b.description,500),instructions=bounded(b.instructions,12000);
    if(!name||!instructions)fail(400,'skill_name_and_instructions_required');
    if(ctx.db.prepare('SELECT COUNT(*) AS n FROM agent_skills WHERE user_id=?').get(user.id).n>=50&&!ctx.db.prepare('SELECT id FROM agent_skills WHERE user_id=? AND id=?').get(user.id,id))fail(400,'skill_limit_reached');
    ctx.db.prepare('INSERT INTO agent_skills VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(user_id,id) DO UPDATE SET name=excluded.name,description=excluded.description,instructions=excluded.instructions,enabled=excluded.enabled,external=excluded.external,updated_at=excluded.updated_at').run(id,user.id,name,description,instructions,Number(b.enabled!==false),Number(b.external===true),nowIso());
    write(200,{skills:skillsFor(ctx.db,user.id)});return true;
  }
  const skillMatch=url.pathname.match(/^\/v1\/agent\/skills\/([a-zA-Z0-9_-]+)(\/export)?$/);
  if (skillMatch&&req.method==='GET'&&skillMatch[2]) {
    const s=skillsFor(ctx.db,user.id).find((s)=>s.id===skillMatch[1]);if(!s)fail(404,'skill_not_found');
    res.writeHead(200,{'content-type':'text/markdown; charset=utf-8','content-disposition':`attachment; filename="${s.id}-SKILL.md"`});res.end(skillMarkdown(s));return true;
  }
  if (skillMatch&&req.method==='DELETE') {
    const s=skillsFor(ctx.db,user.id).find((s)=>s.id===skillMatch[1]);if(!s)fail(404,'skill_not_found');
    // Retain disabled overrides for built-ins so deleting never re-enables them.
    if(s.builtin)ctx.db.prepare('INSERT INTO agent_skills VALUES(?,?,?,?,?,0,0,?) ON CONFLICT(user_id,id) DO UPDATE SET enabled=0,external=0,updated_at=excluded.updated_at').run(s.id,user.id,s.name,s.description,s.instructions,nowIso());
    else ctx.db.prepare('DELETE FROM agent_skills WHERE user_id=? AND id=?').run(user.id,s.id);
    write(200,{skills:skillsFor(ctx.db,user.id)});return true;
  }
  if (url.pathname==='/v1/agent/tokens'&&req.method==='GET') {
    const tokens=ctx.db.prepare('SELECT id,label,scopes_json,created_at,expires_at,revoked_at,last_used_at FROM agent_tokens WHERE user_id=? ORDER BY created_at DESC').all(user.id).map(({scopes_json,...t})=>({...t,scopes:json(scopes_json)}));
    write(200,{tokens});return true;
  }
  if (url.pathname==='/v1/agent/tokens'&&req.method==='POST') {
    const b=await api.readBody(req,ctx.cfg.maxJsonBytes),label=bounded(b.label,100);
    const full=b.access==='full'||(Array.isArray(b.scopes)&&b.scopes.length===1&&b.scopes[0]==='*')||b.scopes===undefined||(Array.isArray(b.scopes)&&SCOPES.every(scope=>b.scopes.includes(scope)));
    if(full){if(isBrowserStorage(ctx,user.id))fail(409,'server_storage_required');b.scopes=[...SCOPES];}
    if(!label||!Array.isArray(b.scopes)||!b.scopes.length||b.scopes.some((s)=>!SCOPES.includes(s)))fail(400,'invalid_mcp_scopes');
    const days=b.days===undefined?30:Number(b.days);if(!Number.isInteger(days)||days<1||days>90)fail(400,'invalid_token_expiry');
    if(ctx.db.prepare('SELECT COUNT(*) AS n FROM agent_tokens WHERE user_id=? AND revoked_at IS NULL AND expires_at>?').get(user.id,nowIso()).n>=20)fail(400,'token_limit_reached');
    const raw=randomToken(),id=randomId('mcp_'),expiresAt=new Date(Date.now()+days*86400000).toISOString();
    ctx.db.prepare('INSERT INTO agent_tokens(id,user_id,label,token_hash,scopes_json,created_at,expires_at) VALUES(?,?,?,?,?,?,?)').run(id,user.id,label,sha256(raw,ctx.cfg.sessionPepper),JSON.stringify([...new Set(b.scopes)]),nowIso(),expiresAt);
    audit(ctx,user.id,'mcp_token_created',id,{scopes:b.scopes});
    write(201,{id,token:raw,expiresAt,url:`${ctx.cfg.agentPublicBaseUrl||ctx.cfg.publicBaseUrl}/mcp`});return true;
  }
  const tokenMatch=url.pathname.match(/^\/v1\/agent\/tokens\/([^/]+)$/);
  if (tokenMatch&&req.method==='DELETE') {
    const changed=ctx.db.prepare('UPDATE agent_tokens SET revoked_at=? WHERE id=? AND user_id=?').run(nowIso(),tokenMatch[1],user.id);
    if(!changed.changes)fail(404,'mcp_token_not_found');
    audit(ctx,user.id,'mcp_token_revoked',tokenMatch[1]);write(200,{revoked:true});return true;
  }
  if (url.pathname==='/v1/agent/access-log'&&req.method==='GET') {
    write(200,{events:ctx.db.prepare("SELECT action,target,detail_json,created_at FROM audit_log WHERE actor_user_id=? AND action LIKE 'mcp_%' ORDER BY created_at DESC LIMIT 50").all(user.id).map(({detail_json,...e})=>({...e,detail:json(detail_json)}))});return true;
  }
  if(url.pathname==='/v1/agent/chat/stream'||url.pathname.startsWith('/v1/agent/conversations'))fail(410,'web_agent_retired_use_external_ai');
  if (url.pathname==='/v1/agent/export'&&req.method==='GET') {
    const d=await data();write(200,{exportedAt:nowIso(),...d,conversations:isBrowserStorage(ctx,user.id)?[]:conversationList(ctx.db,user.id,d).map((c)=>conversationDetail(ctx.db,user.id,c.id)),skills:skillsFor(ctx.db,user.id)});return true;
  }
  fail(404,'agent_route_not_found');
}

