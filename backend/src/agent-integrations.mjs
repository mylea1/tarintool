import fs from 'node:fs';
import { z } from 'zod';

const knowledge = new URL('../knowledge/health-coach/', import.meta.url);
const wger = JSON.parse(fs.readFileSync(new URL('../knowledge/wger-exercises.json', import.meta.url),'utf8'));
export const REFERENCE_IDS = ['nutrition','cn-brands','exercise','apple-health','wearables','medical-markers','supplements','medications','weekly-report','monthly-report','daily-log'];
export function readReference(id) {
  if (!REFERENCE_IDS.includes(id)) throw new Error('reference_not_found');
  const folder=id.endsWith('report')||id==='daily-log'?'templates':'references';
  return {id,source:'https://github.com/H1an1/health-coach',license:'MIT',markdown:fs.readFileSync(new URL(`${folder}/${id}.md`,knowledge),'utf8'),notice:'上游资料，仅供参考；产品标签和当前专业指南优先。医疗与药物内容不用于自行诊断或处方。个人数据来源为获授权的 KILO 后端，原项目“仅本地”约定不适用于本集成。'};
}
const plain=(value)=>String(value||'').replace(/<[^>]*>/g,' ').replace(/&nbsp;/g,' ').trim();
export function searchExercises({query='',limit=10,offset=0,muscle='',equipment=''}={}) {
  const terms=query.toLowerCase().split(/\s+/).filter(Boolean);
  const results=wger.results.filter((e)=>{
    const text=e.translations.map((t)=>t.name).join(' ').toLowerCase();
    return terms.every((t)=>text.includes(t))&&(!muscle||e.muscles.concat(e.muscles_secondary).some((m)=>(m.name+' '+m.name_en).toLowerCase().includes(muscle.toLowerCase())))&&(!equipment||e.equipment.some((m)=>m.name.toLowerCase().includes(equipment.toLowerCase())));
  });
  return {source:'https://wger.de/api/v2/exerciseinfo/',snapshotAt:wger.snapshotAt,total:results.length,nextOffset:offset+limit<results.length?offset+limit:null,records:results.slice(offset,offset+limit).map((e)=>({id:e.id,names:e.translations.map((t)=>({name:t.name,language:t.language})),category:e.category,muscles:e.muscles,equipment:e.equipment,license:e.license,author:e.license_author}))};
}
export function exerciseDetail(id) {
  const e=wger.results.find((e)=>e.id===id);if(!e)throw new Error('exercise_not_found');
  return {...e,translations:e.translations.map((t)=>({...t,description:plain(t.description)})),source:`https://wger.de/api/v2/exerciseinfo/${id}/`,snapshotAt:wger.snapshotAt};
}
export function coachExerciseContext(question) {
  const mapping=[[/卧推|bench\s*press/i,'bench press'],[/深蹲|squat/i,'squat'],[/硬拉|deadlift/i,'deadlift'],[/引体|pull.?up/i,'pull up'],[/俯卧撑|push.?up/i,'push up'],[/划船|row/i,'row']];
  const requested=mapping.filter(([pattern])=>pattern.test(question)).map(([,name])=>name);
  const queries=requested.length?requested:/训练|健身|计划|workout|train|exercise/i.test(question)?['squat','bench press','row']:[];
  return queries.flatMap((query)=>searchExercises({query,limit:2}).records).map((record)=>{
    const detail=exerciseDetail(record.id),translation=detail.translations.find((t)=>t.language===2)||detail.translations[0];
    return {id:detail.id,name:translation?.name,instructions:translation?.description.slice(0,1500),muscles:detail.muscles.map((m)=>m.name_en),equipment:detail.equipment.map((m)=>m.name),source:detail.source,license:detail.license,author:detail.license_author};
  });
}
export const INTEGRATION_SKILLS = [
  {id:'health-coach',name:'Health Coach · 身体与饮食',description:'接入 H1an1/health-coach，结合会员的饮食和身体记录做趋势分析。',instructions:'先读取 read_body_profile 和 read_nutrition_history，确认目标和记录完整性。通过 read_health_reference 读取 nutrition 或 cn-brands；需要时读取 weekly-report 模板。计算记录天数与实际记录摄入，缺失不能视为零；比较近期体重趋势。食品数值是参考估计，包装标签优先。需要年龄、性别或活动水平时先询问，不猜测。医疗与药物问题不做处方。数据来源是用户授权的 KILO 后端，不宣称仅本地或已写入记录。',enabled:true,external:true,builtin:true},
  {id:'wger-training-coach',name:'wger × Health Coach · 训练教练',description:'结合 wger 的真实动作库和 health-coach 的训练原则，分析记录并生成计划草案。',instructions:'读取 read_training_plans、read_workout_history、read_recovery 和 read_body_profile。先确认经验、目标、时间、器械和伤病。使用 search_wger_exercises（建议英文动作名）、get_wger_exercise 和 read_health_reference exercise 查动作资料。列出动作、组数、次数、休息、RPE和渐进规则，注明动作资料出处及许可。恢复仅估算，缺失不表示已恢复；若伤病信息缺失先询问。只生成草案，不声称已保存到 App，不自动上传个人数据到 wger。',enabled:true,external:true,builtin:true},
];
export function registerIntegrationMcp(server,check) {
  const tool=(name,description,inputSchema,fn)=>server.registerTool(name,{description,inputSchema,annotations:{readOnlyHint:true,destructiveHint:false,openWorldHint:false}},async(args)=>{
    try {await check('skills',name);return {content:[{type:'text',text:JSON.stringify(fn(args))}]};}
    catch(e){return {isError:true,content:[{type:'text',text:e.code||e.message||'reference_failed'}]};}
  });
  tool('search_wger_exercises','搜索本地缓存的 wger 真实动作库，返回来源和许可；推荐英文关键词，不向 wger 上传会员数据。',{query:z.string().max(100).default(''),muscle:z.string().max(80).default(''),equipment:z.string().max(80).default(''),limit:z.number().int().min(1).max(30).default(10),offset:z.number().int().min(0).max(10000).default(0)},searchExercises);
  tool('get_wger_exercise','读取 wger 动作详情、教学文字、肌群、器械与素材许可。',{id:z.number().int().positive()},({id})=>exerciseDetail(id));
  tool('read_health_reference','读取 health-coach 上游知识库或报告模板；数值需核实，不是医疗处方。',{id:z.enum(REFERENCE_IDS)},({id})=>readReference(id));
  for(const id of REFERENCE_IDS)server.registerResource(`health-coach-${id}`,`kilo://health-coach/${id}`,{mimeType:'text/markdown',description:'health-coach 原始资料（MIT）'},async(uri)=>{await check('skills',`reference:${id}`);return {contents:[{uri:uri.href,mimeType:'text/markdown',text:readReference(id).markdown}]};});
}
export function integrationStatus(){return {wger:{source:'https://github.com/wger-project/wger',exercises:wger.results.length,snapshotAt:wger.snapshotAt},healthCoach:{source:'https://github.com/H1an1/health-coach',revision:'9c2da9483eb826d0ff4b42cb96f79e1218071215',references:REFERENCE_IDS}};}
