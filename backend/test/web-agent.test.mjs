import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { createServer } from 'node:http';
import { startServer } from '../src/server.mjs';
import { loadConfig } from '../src/config.mjs';
import { dashboard } from '../src/agent-data.mjs';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { fileURLToPath } from 'node:url';

let app,upstream,root,base,member,free,other,lastModelRequest;
let upstreamFails=false;
async function request(route,token,body,method) {
  const response=await fetch(base+route,{method:method||(body?'POST':'GET'),headers:{...(token?{authorization:`Bearer ${token}`} :{}),...(body?{'content-type':'application/json'}:{})},...(body?{body:JSON.stringify(body)}:{})});
  const value=await response.json();return {status:response.status,value};
}
async function register(name){return (await request('/v1/auth/register',null,{identifier:name,password:'pass1234'})).value;}
async function mcp(token) {
  const client=new Client({name:'kilo-test-client',version:'1.0.0'});
  await client.connect(new StreamableHTTPClientTransport(new URL(base+'/mcp'),{requestInit:{headers:{authorization:`Bearer ${token}`}}}));
  return client;
}
async function createConversation(token,title='新会话'){return (await request('/v1/ai/conversations',token,{title})).value.id;}
async function stream(token,conversationId,question) {
  return fetch(base+'/v1/agent/chat/stream',{method:'POST',headers:{authorization:`Bearer ${token}`,'content-type':'application/json'},body:JSON.stringify({conversationId,question})});
}
test.before(async()=>{
  root=await fs.mkdtemp(path.join(os.tmpdir(),'kilo-web-agent-'));
  upstream=createServer(async(req,res)=>{
    let raw='';for await(const chunk of req)raw+=chunk;
    lastModelRequest=JSON.parse(raw);
    if(upstreamFails){res.writeHead(503);res.end();return;}
    res.writeHead(200,{'content-type':'text/event-stream'});
    res.write('data: '+JSON.stringify({choices:[{delta:{content:'基于你的记录，'}}]})+'\n\n');
    setTimeout(()=>{res.end('data: '+JSON.stringify({choices:[{delta:{content:'建议逐步调整。'}}]})+'\n\ndata: [DONE]\n\n');},30);
  });
  await new Promise((r)=>upstream.listen(0,'127.0.0.1',r));
  app=await startServer({port:0,config:loadConfig({NODE_ENV:'test',KILO_PUBLIC_BASE_URL:'https://api.kilostrength.cn',KILO_AGENT_PUBLIC_BASE_URL:'https://kilostrength.cn',KILO_DATA_DIR:root,KILO_DATABASE_PATH:path.join(root,'db.sqlite3'),KILO_MEDIA_DIR:path.join(root,'media'),KILO_ENABLE_TEST_MEMBER:'true',KILO_ENABLE_PASSWORD_REGISTRATION:'true',DEEPSEEK_API_KEY:'mock-key',DEEPSEEK_BASE_URL:`http://127.0.0.1:${upstream.address().port}`})});
  base=`http://127.0.0.1:${app.address().port}`;
  member=(await request('/v1/auth/phone/login',null,{identifier:'123',password:'123'})).value;
  free=await register('not-a-member');other=await register('other-member');
  app.context.db.prepare("UPDATE entitlements SET membership='free',trial_expires_at=NULL WHERE user_id=?").run(free.user.id);
  app.context.db.prepare("UPDATE entitlements SET membership='forever',trial_expires_at=NULL WHERE user_id=?").run(other.user.id);
  const token=member.session.token;
  const workout={id:'w1',name:'胸部训练',date:new Date(Date.now()-12*3600000).toISOString(),volume:800,effectiveSets:4,exercises:[{exerciseId:'bench_press',sets:[{weight:80,reps:10,completed:true},{weight:80,reps:10,completed:false}]}]};
  assert.equal((await request('/v1/sync',token,{entityType:'workout',entityId:'w1',baseRevision:0,payload:workout})).status,200);
  assert.equal((await request('/v1/sync',token,{entityType:'settings',entityId:'mobile_backup_v1',baseRevision:0,payload:{trainingProfile:{profile:{heightCm:175,weightKg:70,goal:'增肌'}},weight:[{id:'b1',recordedAt:'2026-09-30',weightKg:70}],nutrition:[{id:'n1',recordedAt:'2026-09-30',foodName:'MEMBER_PRIVATE_FOOD_429',calories:200,photoPaths:['/private/on-device.jpg']}],aiConversations:{conversations:[{id:'old',title:'设备聊天',messages:[{role:'user',body:'旧聊天内容'}]}]}}})).status,200);
});
test.after(async()=>{await app.closeGracefully();await new Promise((r)=>upstream.close(r));await fs.rm(root,{recursive:true,force:true});});

test('Web bootstrap is membership gated and reads existing mobile schemas without leaking local paths',async()=>{
  assert.equal((await request('/v1/agent/bootstrap')).status,401);
  assert.equal((await request('/v1/agent/bootstrap',free.session.token)).status,403);
  const {value}=await request('/v1/agent/bootstrap',member.session.token);
  assert.equal(value.profile.heightCm,175);assert.equal(value.workouts[0].id,'w1');assert.equal(value.weight[0].weightKg,70);
  assert.equal(value.nutrition[0].photoPaths,undefined);
  assert.equal(value.dashboard.muscles.find((m)=>m.id==='chest').weeklySets,1);
  assert.equal(value.dashboard.muscles.find((m)=>m.id==='hamstring').recoveryPercent,null);
  assert.equal(value.preferences.shareMemory,false);assert.equal(value.preferences.useCloudData,false);
  const isolated=(await request('/v1/agent/bootstrap',other.session.token)).value;
  assert.equal(isolated.workouts.length,0);assert.equal(isolated.weight.length,0);
});
test('Recovery excludes future workouts and unfinished sets',()=>{
  const d=dashboard({workouts:[{date:'2099-01-01',exercises:[{exerciseId:'bench_press',sets:[{completed:true}]}]},{date:'2026-09-30',exercises:[{exerciseId:'bench_press',sets:[{completed:false}]}]}]},new Date('2026-10-01'));
  assert.equal(d.muscles.find((m)=>m.id==='chest').recoveryPercent,null);
  assert.equal(d.weekly.sessions,1);
});
test('MCP SDK interoperates, lists only authorized tools and isolates user data',async()=>{
  const {value:grant}=await request('/v1/agent/tokens',member.session.token,{label:'test-client',scopes:['workouts','skills'],days:7});
  const client=await mcp(grant.token);
  try{
    const names=(await client.listTools()).tools.map((t)=>t.name);
    assert.ok(names.includes('read_workout_history'));assert.ok(!names.includes('read_conversation'));assert.ok(!names.includes('read_body_profile'));
    const history=await client.callTool({name:'read_workout_history',arguments:{limit:1}});
    assert.equal(JSON.parse(history.content[0].text).records[0].id,'w1');
    assert.ok((await client.listPrompts()).prompts.some((p)=>p.name==='weekly-review'));
    assert.ok((await client.getPrompt({name:'weekly-review',arguments:{request:'复盘'}})).messages[0].content.text.includes('复盘'));
    const skill=await client.readResource({uri:'kilo://skills/weekly-review'});assert.ok(skill.contents[0].text.includes('数据访问'));
    assert.equal((await client.callTool({name:'read_conversation',arguments:{conversationId:'x'}})).isError,true);
    const logged=(await request('/v1/agent/access-log',member.session.token)).value.events;
    assert.ok(logged.some((e)=>e.target==='read_workout_history'));
    await request('/v1/agent/tokens/'+grant.id,member.session.token,null,'DELETE');
    await assert.rejects(client.listTools());
  }finally{await client.close();}
});
test('Skill sharing is opt-in, exports Markdown and updates MCP prompt visibility',async()=>{
  const token=member.session.token;
  const saved=await request('/v1/agent/skills',token,{id:'my-coach',name:'自定义教练',description:'我的技能',instructions:'只按记录分析',enabled:true,external:false});
  assert.equal(saved.status,200);
  const {value:grant}=await request('/v1/agent/tokens',token,{label:'skills-client',scopes:['skills']});
  const client=await mcp(grant.token);
  try{
    assert.ok(!(await client.listPrompts()).prompts.some((p)=>p.name==='my-coach'));
    await request('/v1/agent/skills',token,{id:'my-coach',name:'自定义教练',description:'我的技能',instructions:'只按记录分析',enabled:true,external:true});
    assert.ok((await client.listPrompts()).prompts.some((p)=>p.name==='my-coach'));
    const result=await client.callTool({name:'get_skill',arguments:{skillId:'my-coach'}});
    assert.match(JSON.parse(result.content[0].text).markdown,/只按记录分析/);
    const exported=await fetch(base+'/v1/agent/skills/my-coach/export',{headers:{authorization:`Bearer ${token}`}});assert.equal(exported.status,200);
    const markdown=await exported.text();assert.match(markdown,/name: my-coach/);assert.match(markdown,/# 自定义教练/);
    assert.equal((await request('/v1/agent/skills/my-coach',other.session.token,null,'DELETE')).status,404);
    await request('/v1/agent/skills/my-coach',token,null,'DELETE');
    assert.ok(!(await client.listPrompts()).prompts.some((p)=>p.name==='my-coach'));
  }finally{await client.close();}
});
test('MCP chat permission reads only owned conversations, member expiry and token expiry deny access',async()=>{
  const token=member.session.token,id=await createConversation(token,'私有对话');
  const {value:grant}=await request('/v1/agent/tokens',other.session.token,{label:'chat-reader',scopes:['chats']});
  const client=await mcp(grant.token);
  try{
    const denied=await client.callTool({name:'read_conversation',arguments:{conversationId:id}});assert.equal(denied.isError,true);
    app.context.db.prepare("UPDATE entitlements SET membership='free',trial_expires_at=NULL WHERE user_id=?").run(other.user.id);
    await assert.rejects(client.listTools());
    app.context.db.prepare("UPDATE entitlements SET membership='forever' WHERE user_id=?").run(other.user.id);
    app.context.db.prepare("UPDATE agent_tokens SET expires_at='2020-01-01' WHERE id=?").run(grant.id);
    await assert.rejects(client.listTools());
  }finally{await client.close();}
});



test('MCP rejects untrusted Origin and session tokens are not accepted as MCP credentials',async()=>{
  const r=await fetch(base+'/mcp',{method:'POST',headers:{origin:'https://untrusted.example',authorization:`Bearer ${member.session.token}`,'content-type':'application/json'},body:'{}'});assert.equal(r.status,403);
  const denied=await fetch(base+'/mcp',{method:'POST',headers:{authorization:`Bearer ${member.session.token}`,'content-type':'application/json'},body:'{}'});assert.equal(denied.status,401);
});
test('Stdio bridge serves external local AI clients through the same scoped HTTP connection',async()=>{
  const {value:grant}=await request('/v1/agent/tokens',member.session.token,{label:'stdio-client',scopes:['profile','skills']});
  const client=new Client({name:'stdio-test',version:'1.0.0'});
  const transport=new StdioClientTransport({command:process.execPath,args:[fileURLToPath(new URL('../scripts/mcp-stdio.mjs',import.meta.url))],env:{...process.env,KILO_MCP_URL:base+'/mcp',KILO_MCP_TOKEN:grant.token},stderr:'pipe'});
  try{
    await client.connect(transport);
    const tools=(await client.listTools()).tools.map((t)=>t.name);
    assert.ok(tools.includes('read_body_profile'));assert.ok(!tools.includes('read_workout_history'));
    const profile=await client.callTool({name:'read_body_profile',arguments:{}});assert.equal(JSON.parse(profile.content[0].text).profile.heightCm,175);
    assert.ok((await client.listPrompts()).prompts.some((p)=>p.name==='weekly-review'));
  }finally{await client.close();}
});

test('Previous embedded AI chat is retired while existing App conversations remain readable',async()=>{assert.equal((await request('/v1/agent/chat/stream',member.session.token,{question:'hi'})).status,410);});

test('Separate Web domain advertises its MCP URL and accepts only configured origins',async()=>{
  const {value:grant}=await request('/v1/agent/tokens',member.session.token,{label:'web-domain',scopes:['workouts'],days:1});
  try {
    assert.equal(grant.url,'https://kilostrength.cn/mcp');
    const accepted=await fetch(base+'/mcp',{method:'POST',headers:{host:'kilostrength.cn',origin:'https://kilostrength.cn','content-type':'application/json'},body:'{}'});
    assert.equal(accepted.status,401);
    const denied=await fetch(base+'/mcp',{method:'POST',headers:{host:'kilostrength.cn',origin:'https://kilostrength.cn.evil.example','content-type':'application/json'},body:'{}'});
    assert.equal(denied.status,403);
    const client=await mcp(grant.token);
    try {
      const catalog=JSON.parse((await client.callTool({name:'search_app_exercises',arguments:{}})).content[0].text);
      const detail=JSON.parse((await client.callTool({name:'get_app_exercise',arguments:{exerciseId:catalog.records[0].id}})).content[0].text);
      assert.ok(detail.imageUrl.startsWith('https://kilostrength.cn/agent/exercise-media/'));
    } finally { await client.close(); }
  } finally {await request('/v1/agent/tokens/'+grant.id,member.session.token,null,'DELETE');}
});
