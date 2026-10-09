import { createHash, randomBytes, createCipheriv, createDecipheriv } from 'node:crypto';

const failure=(status,code)=>{throw Object.assign(new Error(code),{status,code});};
const serverUrl=(ctx)=>{
  const u=new URL(ctx.cfg.agentBackendUrl);
  if(u.protocol!=='https:'&&!(u.protocol==='http:'&&['127.0.0.1','localhost','[::1]'].includes(u.hostname)))failure(400,'backend_https_required');
  if(u.username||u.password||u.search||u.hash)failure(400,'invalid_backend_url');
  return u.href.replace(/\/$/,'');
};
function key(ctx){return createHash('sha256').update('kilo-remote-session:'+ctx.cfg.sessionPepper).digest();}
function seal(ctx,token){const iv=randomBytes(12),cipher=createCipheriv('aes-256-gcm',key(ctx),iv);return Buffer.concat([iv,cipher.update(token,'utf8'),cipher.final(),cipher.getAuthTag()]).toString('base64');}
function unseal(ctx,value){try{const b=Buffer.from(value,'base64'),cipher=createDecipheriv('aes-256-gcm',key(ctx),b.subarray(0,12));cipher.setAuthTag(b.subarray(-16));return Buffer.concat([cipher.update(b.subarray(12,-16)),cipher.final()]).toString('utf8');}catch{failure(401,'backend_reconnect_required');}}
export function initializeRemote(db){db.exec(`
 CREATE TABLE IF NOT EXISTS agent_backend_links(user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,remote_user_id TEXT NOT NULL,token_cipher TEXT NOT NULL,updated_at TEXT NOT NULL);
 CREATE TABLE IF NOT EXISTS agent_remote_entities(user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,entity_type TEXT NOT NULL,entity_id TEXT NOT NULL,payload_json TEXT NOT NULL,updated_at TEXT NOT NULL,deleted_at TEXT,PRIMARY KEY(user_id,entity_type,entity_id));
 CREATE TABLE IF NOT EXISTS agent_remote_conversations(user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,id TEXT NOT NULL,title TEXT NOT NULL,created_at TEXT,updated_at TEXT,PRIMARY KEY(user_id,id));
`);}
export function backendStatus(ctx,userId){const link=ctx.db.prepare('SELECT remote_user_id,updated_at FROM agent_backend_links WHERE user_id=?').get(userId);return {url:serverUrl(ctx),connected:!!link,remoteUserId:link?.remote_user_id||null,lastRefresh:link?.updated_at||null};}
async function request(ctx,route,token,body){
  let r;try{r=await fetch(serverUrl(ctx)+route,{method:body?'POST':'GET',redirect:'error',headers:{...(token?{authorization:`Bearer ${token}`} :{}),...(body?{'content-type':'application/json'}:{})},...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(15000)});}catch{failure(502,'backend_unavailable');}
  const chunks=[];let size=0;for await(const part of r.body){size+=part.length;if(size>12*1024*1024)failure(502,'backend_response_too_large');chunks.push(Buffer.from(part));}
  let value;try{value=JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{failure(502,'backend_invalid_response');}
  if(!r.ok)failure([401,403,409].includes(r.status)?r.status:502,r.status===401?'backend_session_invalid':r.status===403?'backend_membership_required':r.status===409?'revision_conflict':'backend_request_failed');
  return value;
}
async function fetchSnapshot(ctx,token){
  const entitlement=await request(ctx,'/v1/me/entitlements',token);
  // Expired memberships can retain cloud-read access in the App. This Agent
  // intentionally requires current membership, not merely retained cloud data.
  if(entitlement.cloudSyncWritable!==true)failure(403,'backend_membership_required');
  const pages=await Promise.all(['workout','plan','settings'].map(async(type)=>({type,...await request(ctx,`/v1/sync?entityType=${type}`,token)})));
  for(const p of pages)if(!Array.isArray(p.entities)||p.entities.some((e)=>e.entityType!==p.type||typeof e.entityId!=='string'||(e.payload!==null&&typeof e.payload!=='object')))failure(502,'backend_invalid_snapshot');
  const chats=await request(ctx,'/v1/ai/conversations',token);
  if(!Array.isArray(chats.conversations))failure(502,'backend_invalid_snapshot');
  return {entities:pages.flatMap((p)=>p.entities),conversations:chats.conversations};
}
function saveSnapshot(ctx,userId,{entities,conversations}){ctx.db.transaction(()=>{
  ctx.db.prepare('DELETE FROM agent_remote_entities WHERE user_id=?').run(userId);
  const insert=ctx.db.prepare('INSERT INTO agent_remote_entities VALUES(?,?,?,?,?,?)');
  for(const e of entities)insert.run(userId,e.entityType,e.entityId,JSON.stringify(e.payload||{}),e.updatedAt||new Date().toISOString(),e.deleted?e.deletedAt||new Date().toISOString():null);
  ctx.db.prepare('DELETE FROM agent_remote_conversations WHERE user_id=?').run(userId);
  const chatInsert=ctx.db.prepare('INSERT INTO agent_remote_conversations VALUES(?,?,?,?,?)');
  for(const c of conversations)if(typeof c.id==='string')chatInsert.run(userId,c.id,String(c.title||'App conversation'),c.createdAt||null,c.updatedAt||null);
  ctx.db.prepare('UPDATE agent_backend_links SET updated_at=? WHERE user_id=?').run(new Date().toISOString(),userId);
})();}
export async function connectBackend(ctx,userId,credentials){
  if(typeof credentials.identifier!=='string'||typeof credentials.password!=='string'||credentials.identifier.length>200||credentials.password.length>1000)failure(400,'backend_credentials_required');
  const login=await request(ctx,'/v1/auth/phone/login',null,{identifier:credentials.identifier,password:credentials.password});
  if(!login.session?.token||!login.user?.id)failure(502,'backend_invalid_login');
  const entities=await fetchSnapshot(ctx,login.session.token);
  ctx.db.transaction(()=>{
    ctx.db.prepare('INSERT INTO agent_backend_links VALUES(?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET remote_user_id=excluded.remote_user_id,token_cipher=excluded.token_cipher,updated_at=excluded.updated_at').run(userId,login.user.id,seal(ctx,login.session.token),new Date().toISOString());
    saveSnapshot(ctx,userId,entities);
    // Changing the upstream account invalidates previously issued external grants.
    ctx.db.prepare('UPDATE agent_tokens SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL').run(new Date().toISOString(),userId);
  })();
  return backendStatus(ctx,userId);
}
export async function refreshBackend(ctx,userId){const link=ctx.db.prepare('SELECT * FROM agent_backend_links WHERE user_id=?').get(userId);if(!link)return;try{saveSnapshot(ctx,userId,await fetchSnapshot(ctx,unseal(ctx,link.token_cipher)));}catch(e){ctx.db.prepare('DELETE FROM agent_remote_entities WHERE user_id=?').run(userId);throw e;}}
export async function remoteConversation(ctx,userId,id){
  if(!id.startsWith('backend:'))return null;
  const link=ctx.db.prepare('SELECT * FROM agent_backend_links WHERE user_id=?').get(userId);
  if(!link)failure(404,'conversation_not_found');
  const detail=await request(ctx,'/v1/ai/conversations/'+encodeURIComponent(id.slice(8)),unseal(ctx,link.token_cipher));
  return {id,title:detail.title,source:'software-backend',messages:detail.messages||[],limitedToRecent:50};
}
export function disconnectBackend(ctx,userId){ctx.db.transaction(()=>{ctx.db.prepare('DELETE FROM agent_remote_entities WHERE user_id=?').run(userId);ctx.db.prepare('DELETE FROM agent_remote_conversations WHERE user_id=?').run(userId);ctx.db.prepare('DELETE FROM agent_backend_links WHERE user_id=?').run(userId);ctx.db.prepare('UPDATE agent_tokens SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL').run(new Date().toISOString(),userId);})();}

// Writes reuse the member's actual App sync API, never an administrator identity.
export async function remoteSyncEntities(ctx,userId,type) {
 const link=ctx.db.prepare('SELECT * FROM agent_backend_links WHERE user_id=?').get(userId);
 if(!link)return null;
 return (await request(ctx,'/v1/sync?entityType='+type,unseal(ctx,link.token_cipher))).entities;
}
export async function writeRemoteEntity(ctx,userId,entity) {
 const link=ctx.db.prepare('SELECT * FROM agent_backend_links WHERE user_id=?').get(userId);
 if(!link)failure(409,'backend_binding_changed');
 return request(ctx,'/v1/sync',unseal(ctx,link.token_cipher),entity);
}
