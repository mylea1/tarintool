#!/usr/bin/env python3
"""Package only application code and exercise assets; never local data or credentials."""
from pathlib import Path
import hashlib, json, sys, tarfile
repo=Path(__file__).resolve().parents[2]
out=Path(sys.argv[1]).resolve()
out.parent.mkdir(parents=True,exist_ok=True)
files=[]
for item in ['backend/src','backend/migrations','backend/knowledge','backend/agent-web','backend/scripts','mobile/assets/exercises/reference','deploy/web-production']:
 files.extend(p for p in (repo/item).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
files.extend(repo/name for name in ['backend/package.json','backend/package-lock.json'])
with tarfile.open(out,'w:gz') as archive:
 for p in sorted(set(files)):
  archive.add(p,arcname=str(p.relative_to(repo)),recursive=False)
digest=hashlib.sha256(out.read_bytes()).hexdigest()
Path(str(out)+'.sha256').write_text(digest+'  '+out.name+'\n')
print(json.dumps({'archive':str(out),'files':len(files),'bytes':out.stat().st_size,'sha256':digest}))
