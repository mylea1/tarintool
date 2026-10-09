import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const backend=path.join(root,'backend'),runtime=path.join(root,'.agent-local');
fs.mkdirSync(runtime,{recursive:true,mode:0o700});
const envFile=path.join(root,'.agent.env');
if(fs.existsSync(envFile))process.loadEnvFile(envFile);
if(!process.env.KILO_SESSION_PEPPER){
  const secretFile=path.join(runtime,'session-pepper');
  if(!fs.existsSync(secretFile))fs.writeFileSync(secretFile,randomBytes(32).toString('hex'),{mode:0o600});
  process.env.KILO_SESSION_PEPPER=fs.readFileSync(secretFile,'utf8').trim();
}
// Local trial environment is isolated from the existing mobile backend.
process.env.KILO_HOST??='127.0.0.1';process.env.KILO_PORT??='8792';
process.env.KILO_PUBLIC_BASE_URL??=`http://127.0.0.1:${process.env.KILO_PORT}`;
process.env.KILO_DATA_DIR??=runtime;process.env.KILO_DATABASE_PATH??=path.join(runtime,'kilo.sqlite3');process.env.KILO_MEDIA_DIR??=path.join(runtime,'media');
process.env.NODE_ENV??='development';
process.env.KILO_ENABLE_TEST_MEMBER??='true';process.env.KILO_ENABLE_TEST_ADMIN??='false';
const url=`http://${process.env.KILO_HOST}:${process.env.KILO_PORT}`;
const pidFile=path.join(runtime,'agent.pid');
const [major,minor]=process.versions.node.split('.').map(Number);
if(major<22||(major===22&&minor<13))throw new Error('请安装 Node.js 22.13 或更新版本。');
const health=async()=>{try{const r=await fetch(url+'/health',{signal:AbortSignal.timeout(2000)});return r.ok?await r.json():null;}catch{return null;}};
if(process.argv.includes('--stop')) {
  if(fs.existsSync(pidFile)){
    const pid=Number(fs.readFileSync(pidFile,'utf8'));
    const command=process.platform==='win32'?(spawnSync('powershell',['-NoProfile','-Command',`(Get-CimInstance Win32_Process -Filter "ProcessId = ${pid}").CommandLine`],{encoding:'utf8'}).stdout||''):(spawnSync('ps',['-p',String(pid),'-o','command='],{encoding:'utf8'}).stdout||'');
    // Never kill a recycled PID or a separately running mobile backend.
    if(command.includes(path.join(backend,'src/server.mjs'))){try{process.kill(pid,'SIGTERM');console.log('本地 TrainTool Web 已停止。');}catch{console.log('服务已停止。');}}
    else console.log('没有找到此启动器启动的 Agent 进程。');
    fs.rmSync(pidFile,{force:true});
  }else console.log('本地 TrainTool Web 未运行。');
  process.exit(0);
}
const existing=await health();
if(existing?.agent?.version==='2.0.0'){console.log(`TrainTool Web 已运行：${url}/agent/`);}
else {
  if(existing)throw new Error(`${process.env.KILO_PORT} 端口上已有其他服务，请修改 .agent.env 中的 KILO_PORT。`);
  const lock=fs.readFileSync(path.join(backend,'package-lock.json'),'utf8'),stamp=path.join(runtime,'dependencies.lock');
  if(!fs.existsSync(path.join(backend,'node_modules/@modelcontextprotocol/sdk'))||!fs.existsSync(stamp)||fs.readFileSync(stamp,'utf8')!==lock){
    console.log('安装 Web 与 MCP 依赖…');
    const installed=spawnSync(process.platform==='win32'?'npm.cmd':'npm',['ci','--no-audit','--no-fund'],{cwd:backend,stdio:'inherit',shell:process.platform==='win32'});
    if(installed.status!==0)throw new Error('依赖安装失败。');fs.writeFileSync(stamp,lock);
  }
  console.log('启动本地 TrainTool Web…');
  const log=fs.openSync(path.join(runtime,'agent.log'),'a',0o600);
  const child=spawn(process.execPath,[path.join(backend,'src/server.mjs')],{cwd:backend,env:process.env,detached:true,stdio:['ignore',log,log]});
  fs.writeFileSync(pidFile,String(child.pid));child.unref();fs.closeSync(log);
  let ready=false;
  for(let i=0;i<30;i++){if((await health())?.agent?.version){ready=true;break;}await new Promise((r)=>setTimeout(r,500));}
  if(!ready)throw new Error('Web 启动失败，请查看项目 .agent-local/agent.log。');
  console.log(`启动成功：${url}/agent/`);
}
console.log(`MCP：${url}/mcp`);
if(process.env.KILO_ENABLE_TEST_MEMBER==='true')console.log('本地体验会员已启用（默认账号及密码见使用说明）。');
console.log('照片识别与建议由你的外部 AI 完成；网页无需模型密钥。');
if(!process.argv.includes('--no-browser')) {
  const target=url+'/agent/';
  if(process.platform==='darwin')spawnSync('open',[target]);
  else if(process.platform==='win32')spawnSync('cmd',['/c','start','',target]);
  else spawnSync('xdg-open',[target]);
}
