import { createHash } from 'node:crypto';
import { randomId, nowIso } from './security.mjs';
import { BUILTIN_SKILLS } from './agent-data.mjs';
const fail=(status,code)=>{throw Object.assign(new Error(code),{status,code});};
export function initializeManagement(db){db.exec(`CREATE TABLE IF NOT EXISTS agent_management_writes(user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,request_key TEXT NOT NULL,input_hash TEXT NOT NULL,result_json TEXT NOT NULL,created_at TEXT NOT NULL,PRIMARY KEY(user_id,request_key));`);}
export function manageAgent(ctx,userId,kind,args){
 const hash=createHash('sha256').update(JSON.stringify({kind,args})).digest('hex');
 return ctx.db.transaction(()=>{
  const prior=ctx.db.prepare('SELECT * FROM agent_management_writes WHERE user_id=? AND request_key=?').get(userId,args.idempotencyKey);
  if(prior){if(prior.input_hash!==hash)fail(409,'idempotency_key_reused');return JSON.parse(prior.result_json);}
  const stamp=nowIso();let result;
  if(kind==='skill'){
   const id=args.skillId||randomId('skill_');
   const existing=ctx.db.prepare('SELECT * FROM agent_skills WHERE user_id=? AND id=?').get(userId,id);
   const builtin=BUILTIN_SKILLS.find(s=>s.id===id);
   if(args.action==='delete'){
    if(!existing&&!builtin)fail(404,'skill_not_found');
    if(builtin){const s=existing||builtin;ctx.db.prepare('INSERT INTO agent_skills VALUES(?,?,?,?,?,0,0,?) ON CONFLICT(user_id,id) DO UPDATE SET enabled=0,external=0,updated_at=excluded.updated_at').run(id,userId,s.name,s.description,s.instructions,stamp);}
    else ctx.db.prepare('DELETE FROM agent_skills WHERE user_id=? AND id=?').run(userId,id);
    result={id,deleted:true};
   }else{
    const r=args.record;if(!r)fail(400,'skill_record_required');
    if(!existing&&ctx.db.prepare('SELECT COUNT(*) AS n FROM agent_skills WHERE user_id=?').get(userId).n>=50)fail(400,'skill_limit_reached');
    ctx.db.prepare('INSERT INTO agent_skills VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(user_id,id) DO UPDATE SET name=excluded.name,description=excluded.description,instructions=excluded.instructions,enabled=excluded.enabled,external=excluded.external,updated_at=excluded.updated_at').run(id,userId,r.name,r.description||'',r.instructions,Number(r.enabled!==false),Number(r.external===true),stamp);
    result={id,saved:true,storage:'server'};
   }
  }else{
   const id=args.conversationId||randomId('conv_');
   if(id.startsWith('mobile:'))fail(400,'mobile_backup_conversation_read_only');
   const existing=ctx.db.prepare('SELECT * FROM conversations WHERE id=?').get(id);
   if(existing&&existing.user_id!==userId)fail(404,'conversation_not_found');
   if(args.action==='delete'){
    if(!existing)fail(404,'conversation_not_found');
    ctx.db.prepare('DELETE FROM conversations WHERE id=? AND user_id=?').run(id,userId);result={id,deleted:true};
   }else{
    if(!existing)ctx.db.prepare("INSERT INTO conversations(id,user_id,title,memory_summary,created_at,updated_at) VALUES(?,?,?,'',?,?)").run(id,userId,args.title||'外部 AI 会话',stamp,stamp);
    else ctx.db.prepare('UPDATE conversations SET title=?,updated_at=? WHERE id=? AND user_id=?').run(args.title||existing.title,stamp,id,userId);
    for(const message of args.messages||[])ctx.db.prepare('INSERT INTO conversation_messages(id,conversation_id,role,content,created_at) VALUES(?,?,?,?,?)').run(randomId('msg_'),id,message.role,message.content,stamp);
    result={id,title:args.title||existing?.title||'外部 AI 会话',appendedMessages:(args.messages||[]).length,storage:'server'};
   }
  }
  ctx.db.prepare('INSERT INTO agent_management_writes VALUES(?,?,?,?,?)').run(userId,args.idempotencyKey,hash,JSON.stringify(result),stamp);return result;
 })();
}
