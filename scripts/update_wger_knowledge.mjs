import fs from 'node:fs/promises';

// Uses only public exercise data. Never send KILO tokens or member records.
const endpoint=new URL('api/v2/exerciseinfo/?limit=1000',process.env.WGER_PUBLIC_URL||'https://wger.de/');
const origin=endpoint.origin,results=[];
let next=endpoint.href;
while(next){
 const url=new URL(next);if(url.origin!==origin)throw new Error('unexpected_wger_pagination_origin');
 const r=await fetch(url,{signal:AbortSignal.timeout(30000),redirect:'error'});
 if(!r.ok)throw new Error(`wger_http_${r.status}`);
 const page=await r.json();if(!Array.isArray(page.results))throw new Error('invalid_wger_response');
 results.push(...page.results);next=page.next;
 if(results.length>20000)throw new Error('wger_catalog_too_large');
}
if(!results.length||results.some((e)=>!e.license||!e.translations))throw new Error('incomplete_wger_license_data');
await fs.writeFile(new URL('../backend/knowledge/wger-exercises.json',import.meta.url),JSON.stringify({count:results.length,next:null,previous:null,snapshotAt:new Date().toISOString().slice(0,10),results})+'\n');
console.log(`Updated ${results.length} wger exercises, preserving attribution and licenses. Restart Agent to load the snapshot.`);
