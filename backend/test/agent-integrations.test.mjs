import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { startServer } from '../src/server.mjs';
import { loadConfig } from '../src/config.mjs';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
import { searchExercises,exerciseDetail,readReference,integrationStatus } from '../src/agent-integrations.mjs';

let upstream,app,root,url,remoteUrl,localToken,remoteLogin,other;
async function request(base,route,token,body,method){const r=await fetch(base+route,{method:method||(body?'POST':'GET'),headers:{...(token?{authorization:`Bearer ${token}`} :{}),...(body?{'content-type':'application/json'}:{})},...(body?{body:JSON.stringify(body)}:{})});return {status:r.status,value:await r.json()};}
async function connectMcp(token){const client=new Client({name:'integration-test',version:'1'});await client.connect(new StreamableHTTPClientTransport(new URL(url+'/mcp'),{requestInit:{headers:{authorization:`Bearer ${token}`}}}));return client;}
test.before(async()=>{
 root=await fs.mkdtemp(path.join(os.tmpdir(),'kilo-integrations-'));
 const config=(dir,extra={})=>loadConfig({NODE_ENV:'test',KILO_DATA_DIR:path.join(root,dir),KILO_DATABASE_PATH:path.join(root,dir,'db.sqlite3'),KILO_MEDIA_DIR:path.join(root,dir,'media'),KILO_ENABLE_TEST_MEMBER:'true',KILO_ENABLE_PASSWORD_REGISTRATION:'true',...extra});
 upstream=await startServer({port:0,config:config('software')});remoteUrl=`http://127.0.0.1:${upstream.address().port}`;
 app=await startServer({port:0,config:config('agent',{KILO_AGENT_BACKEND_URL:remoteUrl})});url=`http://127.0.0.1:${app.address().port}`;
 remoteLogin=(await request(remoteUrl,'/v1/auth/phone/login',null,{identifier:'123',password:'123'})).value;
 localToken=(await request(url,'/v1/auth/phone/login',null,{identifier:'123',password:'123'})).value.session.token;
 other=(await request(url,'/v1/auth/register',null,{identifier:'isolated-member',password:'pass1234'})).value;
 app.context.db.prepare("UPDATE entitlements SET membership='forever' WHERE user_id=?").run(other.user.id);
 await request(remoteUrl,'/v1/sync',remoteLogin.session.token,{entityType:'workout',entityId:'remote-workout',baseRevision:0,payload:{id:'remote-workout',name:'from-software',date:'2026-10-02',exercises:[]}});
 await request(remoteUrl,'/v1/sync',remoteLogin.session.token,{entityType:'settings',entityId:'mobile_backup_v1',baseRevision:0,payload:{trainingProfile:{profile:{heightCm:181}},weight:[{id:'weight',weightKg:75,recordedAt:'2026-10-02'}],nutrition:[{id:'meal',foodName:'REMOTE_PRIVATE_MEAL',calories:500,recordedAt:'2026-10-02'}]}});
});
test.after(async()=>{await app.closeGracefully();await upstream.closeGracefully();await fs.rm(root,{recursive:true,force:true});});
test('Real wger snapshot and licensed health-coach references are searchable',()=>{
 assert.equal(integrationStatus().wger.exercises,916);
 const result=searchExercises({query:'bench press'});assert.ok(result.total>0);
 const detail=exerciseDetail(result.records[0].id);assert.ok(detail.license.url);assert.ok(detail.translations.some((t)=>t.name.toLowerCase().includes('bench press')));
 assert.ok(!detail.translations.some((t)=>t.description.includes('<p>')));
 assert.ok(readReference('nutrition').markdown.includes('Nutrition'));assert.ok(readReference('weekly-report').markdown.length>200);
 assert.throws(()=>readReference('../../config'));assert.throws(()=>exerciseDetail(-1));
});
test('Connecting the actual software API imports only this member and revokes previous MCP grants',async()=>{
 const old=(await request(url,'/v1/agent/tokens',localToken,{label:'old',scopes:['workouts']})).value;
 const linked=await request(url,'/v1/agent/backend',localToken,{identifier:'123',password:'123'});assert.equal(linked.status,200);assert.equal(linked.value.connected,true);
 const bootstrap=(await request(url,'/v1/agent/bootstrap',localToken)).value;assert.equal(bootstrap.workouts[0].id,'remote-workout');assert.equal(bootstrap.profile.heightCm,181);assert.equal(bootstrap.nutrition[0].foodName,'REMOTE_PRIVATE_MEAL');
 const encrypted=app.context.db.prepare('SELECT token_cipher FROM agent_backend_links').get().token_cipher;assert.ok(!encrypted.includes(remoteLogin.session.token));assert.ok(encrypted.length>50);
 const isolated=(await request(url,'/v1/agent/bootstrap',other.session.token)).value;assert.equal(isolated.workouts.length,0);assert.equal(isolated.backend.connected,false);
 await assert.rejects(connectMcp(old.token));
});
test('External AI can use both upstream knowledge projects and scoped software records',async()=>{
 const grant=(await request(url,'/v1/agent/tokens',localToken,{label:'combined',scopes:['workouts','profile','skills']})).value;
 const client=await connectMcp(grant.token);
 try{
  const names=(await client.listTools()).tools.map((t)=>t.name);assert.ok(names.includes('search_wger_exercises'));assert.ok(names.includes('read_health_reference'));assert.ok(!names.includes('read_nutrition_history'));
  const exercise=JSON.parse((await client.callTool({name:'search_wger_exercises',arguments:{query:'squat',limit:2}})).content[0].text);assert.equal(exercise.records.length,2);
  const history=JSON.parse((await client.callTool({name:'read_workout_history',arguments:{}})).content[0].text);assert.equal(history.records[0].id,'remote-workout');
  const prompts=(await client.listPrompts()).prompts;assert.ok(prompts.some((p)=>p.name==='health-coach'));assert.ok(prompts.some((p)=>p.name==='wger-training-coach'));
  const reference=await client.readResource({uri:'kilo://health-coach/nutrition'});assert.ok(reference.contents[0].text.includes('Nutrition'));
 }finally{await client.close();}
});
test('Remote server conversations are readable only through the owner account and chats scope',async()=>{
 const chat=(await request(remoteUrl,'/v1/ai/conversations',remoteLogin.session.token,{title:'Actual software chat'})).value;
 upstream.context.db.prepare('INSERT INTO conversation_messages(id,conversation_id,role,content,created_at) VALUES(?,?,?,?,?)').run('remote-message',chat.id,'user','remote-chat-secret',new Date().toISOString());
 const grant=(await request(url,'/v1/agent/tokens',localToken,{label:'chat-reader',scopes:['chats']})).value;
 const client=await connectMcp(grant.token);
 try{
  const listing=JSON.parse((await client.callTool({name:'list_conversations',arguments:{}})).content[0].text);
  assert.ok(listing.records.some((c)=>c.id==='backend:'+chat.id));
  const detail=JSON.parse((await client.callTool({name:'read_conversation',arguments:{conversationId:'backend:'+chat.id}})).content[0].text);assert.equal(detail.messages.records[0].content,'remote-chat-secret');
  const stranger=(await request(remoteUrl,'/v1/auth/register',null,{identifier:'stranger',password:'pass1234'})).value;
  const foreign=(await request(remoteUrl,'/v1/ai/conversations',stranger.session.token,{title:'foreign'})).value;
  assert.equal((await client.callTool({name:'read_conversation',arguments:{conversationId:'backend:'+foreign.id}})).isError,true);
 }finally{await client.close();}
});
test('Membership expiry denies cached data, restoration refreshes and disconnect clears grants',async()=>{
 const grant=(await request(url,'/v1/agent/tokens',localToken,{label:'expiry',scopes:['workouts']})).value;
 upstream.context.db.prepare("UPDATE entitlements SET membership='free',trial_expires_at=NULL WHERE user_id=?").run(remoteLogin.user.id);
 assert.equal((await request(url,'/v1/agent/bootstrap',localToken)).status,403);await assert.rejects(connectMcp(grant.token));assert.equal(app.context.db.prepare('SELECT COUNT(*) AS n FROM agent_remote_entities').get().n,0);
 upstream.context.db.prepare("UPDATE entitlements SET membership='forever' WHERE user_id=?").run(remoteLogin.user.id);
 assert.equal((await request(url,'/v1/agent/bootstrap',localToken)).value.workouts[0].id,'remote-workout');
 const disconnected=await request(url,'/v1/agent/backend',localToken,null,'DELETE');assert.equal(disconnected.status,200);assert.equal(disconnected.value.connected,false);assert.equal(app.context.db.prepare('SELECT COUNT(*) AS n FROM agent_remote_entities').get().n,0);
 await assert.rejects(connectMcp(grant.token));assert.equal((await request(url,'/v1/agent/bootstrap',localToken)).value.workouts.length,0);
});
test('Expired remote session is denied and can be disconnected without losing local login',async()=>{
 assert.equal((await request(url,'/v1/agent/backend',localToken,{identifier:'123',password:'123'})).status,200);
 upstream.context.db.prepare('DELETE FROM sessions WHERE user_id=?').run(remoteLogin.user.id);
 const denied=await request(url,'/v1/agent/bootstrap',localToken);assert.equal(denied.status,401);assert.equal(denied.value.error,'backend_session_invalid');
 assert.equal((await request(url,'/v1/agent/backend',localToken,null,'DELETE')).status,200);
 assert.equal((await request(url,'/v1/agent/bootstrap',localToken)).status,200);
});
