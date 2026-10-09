import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=(name)=>fs.readFileSync(path.join(root,name),'utf8');
const decode=(s)=>s.replace(/\\(['\\nr])/g,(_,c)=>c==='n'?'\n':c==='r'?'\r':c);
const field=(source,key)=>decode(source.match(new RegExp(`\\b${key}:\\s*'((?:\\\\.|[^'])*)'`))?.[1]||'');
const exactSection=read('mobile/lib/exercise_name_zh.dart').split('const exact = <String, String>{')[1]?.split('};')[0]||'';
const names=Object.fromEntries([...exactSection.matchAll(/'((?:\\.|[^'])*)': '((?:\\.|[^'])*)'/g)].map((m)=>[decode(m[1]),decode(m[2])]));
const catalogue={};
const media={};
for(const m of read('mobile/lib/exercise_media.dart').matchAll(/'([^']+)': ExerciseMedia\(([\s\S]*?)\n  \),/g)) media[m[1]]={...Object.fromEntries(['summary','imageAsset','gifAsset'].map(k=>[k,field(m[2],k)])),steps:[...(m[2].match(/steps: <String>\[([\s\S]*?)\]/)?.[1]||'').matchAll(/'((?:\\.|[^'])*)'/g)].map(m=>decode(m[1]))};
for(const m of read('mobile/lib/exercise_dataset.generated.dart').matchAll(/'(dataset_\d+)': DatasetExerciseEntry\(([\s\S]*?)\n  \),/g)){
  const englishName=field(m[2],'name');
  catalogue[m[1]]={name:names[englishName]||englishName,englishName,...Object.fromEntries(['muscle','secondary','family','equipment'].map((k)=>[k,field(m[2],k)])),...Object.fromEntries(['summary','imageAsset','gifAsset','attribution','loadMode'].map(k=>[k,field(m[2],k)])),steps:[...(m[2].match(/steps: <String>\[([\s\S]*?)\]/)?.[1]||'').matchAll(/'((?:\\.|[^'])*)'/g)].map(m=>decode(m[1]))};
}
for(const m of read('mobile/lib/models.dart').matchAll(/\bExercise\(\s*id: '([^']+)',([\s\S]*?)\n  \),/g)){
  catalogue[m[1]]={...media[m[1]],...Object.fromEntries(['name','muscle','secondary','family','equipment'].map((k)=>[k,field(m[2],k)])),attribution:'© Gym visual — https://gymvisual.com/'};
}
fs.writeFileSync(path.join(root,'backend/knowledge/agent-exercises.json'),JSON.stringify(catalogue,null,2)+'\n');
console.log(`Generated ${Object.keys(catalogue).length} exercise mappings from existing mobile sources.`);
