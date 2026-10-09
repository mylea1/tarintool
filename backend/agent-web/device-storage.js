// Personal records are kept in this browser. No background upload or server copy.
export const deviceId=localStorage.getItem('traintool-device-id')||crypto.randomUUID();
localStorage.setItem('traintool-device-id',deviceId);
let database;
export async function openDeviceDatabase(){if(database)return database;database=await new Promise((resolve,reject)=>{const req=indexedDB.open('traintool-device-v2',1);req.onupgradeneeded=()=>{req.result.createObjectStore('records',{keyPath:['userId','kind','id']});req.result.createObjectStore('mutations',{keyPath:['userId','key']});};req.onsuccess=()=>resolve(req.result);req.onerror=()=>reject(req.error);});return database;}
const get=req=>new Promise((resolve,reject)=>{req.onsuccess=()=>resolve(req.result);req.onerror=()=>reject(req.error);});
export async function executeDeviceOperation(userId,operation){const db=await openDeviceDatabase();if(operation.type==='read'){const entries=await get(db.transaction('records').objectStore('records').getAll());const records=entries.filter(e=>e.userId===userId),of=kind=>records.filter(e=>e.kind===kind).map(e=>e.record);return {workouts:of('workout').sort((a,b)=>b.date.localeCompare(a.date)),plans:of('plan'),nutrition:of('nutrition').sort((a,b)=>b.recordedAt.localeCompare(a.recordedAt)),weight:of('weight').sort((a,b)=>b.recordedAt.localeCompare(a.recordedAt)),profile:of('profile')[0]||{},nutritionGoals:of('nutritionGoals'),activeWorkout:of('activeWorkout')[0]||null,mobileConversations:[],syncedAt:null};}
 if(operation.type!=='mutate')throw new Error('invalid_device_operation');
 return new Promise((resolve,reject)=>{const tx=db.transaction(['records','mutations'],'readwrite'),store=tx.objectStore('records'),journal=tx.objectStore('mutations');let result,failure;
 const abort=code=>{failure=code;tx.abort();};
 tx.oncomplete=()=>resolve(result);tx.onabort=()=>reject(new Error(failure||'device_save_failed'));tx.onerror=()=>{failure||='device_save_failed';};
 const previous=journal.get([userId,operation.key]);previous.onsuccess=()=>{if(previous.result){if(previous.result.inputHash!==operation.inputHash)return abort('idempotency_key_reused');result={...previous.result.result,replayed:true};return;}
 const current=store.get([userId,operation.kind,operation.recordId]);current.onsuccess=()=>{const existing=current.result?.record,{kind,body,recordId,stamp}=operation;
 if(body.action!=='create'&&!['profile','activeWorkout'].includes(kind)&&!existing)return abort('record_not_found');
 if(body.action==='create'&&existing&&!['profile','activeWorkout'].includes(kind))return abort('record_exists');
 if(body.expectedVersion&&existing?.updatedAt!==body.expectedVersion)return abort('record_conflict_refresh');
 if(body.action==='append'&&!existing)return abort('record_not_found');
 const record=body.action==='append'?{...existing,updatedAt:stamp,exercises:[...existing.exercises,operation.record]}:kind==='profile'?{...existing,...operation.record}:operation.record;
 if(body.action==='delete')store.delete([userId,kind,recordId]);else store.put({userId,kind,id:recordId,record});
 result={kind,recordId,record,deleted:body.action==='delete',savedAt:stamp,destination:'user-browser'};
 journal.put({userId,key:operation.key,inputHash:operation.inputHash,result});};};
 });
}
export async function importDeviceData(userId,data){const db=await openDeviceDatabase();return new Promise((resolve,reject)=>{const tx=db.transaction('records','readwrite'),s=tx.objectStore('records');for(const [kind,list] of Object.entries(data))for(const record of list)s.put({userId,kind,id:record.id,record});tx.oncomplete=resolve;tx.onabort=()=>reject(tx.error);});}
export function startDeviceBridge(userId,api){let stopped=false,controller;const stop=()=>{stopped=true;controller?.abort();};(async()=>{while(!stopped){try{controller=new AbortController();const {jobs}=await api('/device/poll?deviceId='+deviceId,undefined,'GET',controller.signal);for(const job of jobs){let result,error;try{result=await executeDeviceOperation(userId,job.operation);}catch(e){error=e.message||'device_save_failed';}await api('/device/result?deviceId='+deviceId,{id:job.id,result,error});}}catch(e){if(stopped)return;if(['device_not_bound','unauthorized','session_invalid','membership_required'].includes(e.message)){stop();return;}await new Promise(r=>setTimeout(r,1500));}}})();return stop;}
export function closeDeviceDatabase(){database?.close();database=null;}
