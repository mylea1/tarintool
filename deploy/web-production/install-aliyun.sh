#!/usr/bin/env bash
# Run as root on the existing, inspected KILO ECS server after extracting the release.
set -Eeuo pipefail
umask 077
release=$(cd "$(dirname "$0")/../.." && pwd)
[[ $EUID == 0 && "$release" == /opt/kilo/releases/* ]] || { echo 'Extract under /opt/kilo/releases and run as root.'; exit 1; }
[[ -L /opt/kilo/current && -f /etc/kilo/kilo.env && -f /var/lib/kilo/kilo.sqlite3 ]] || exit 1
old=$(readlink -f /opt/kilo/current)
[[ "$old" != "$release" ]] || { echo 'Already active; no changes made.'; exit 1; }
node -e 'if(Number(process.versions.node.split(".")[0])<22)process.exit(1)'
nginx -t
(cd "$release/backend" && npm ci --omit=dev --no-audit --no-fund)
stamp=$(date -u +%Y%m%dT%H%M%SZ)
backup="/opt/kilo/backups/web-mcp-$stamp"
mkdir -m 700 "$backup"
cp -a /etc/kilo/kilo.env "$backup/kilo.env"
cp -a /etc/nginx/conf.d/kilo-website.conf "$backup/kilo-website.conf"
printf '%s\n' "$old" > "$backup/previous-release"
node --input-type=module - "$release" "$backup" <<'JS'
import { createRequire } from 'node:module';
const require = createRequire(process.argv[2] + '/backend/package.json');
const Database = require('better-sqlite3');
const db = new Database('/var/lib/kilo/kilo.sqlite3', { readonly: true, fileMustExist: true });
await db.backup(process.argv[3] + '/kilo.sqlite3');
db.close();
JS
chown -R root:kilo "$release"
chmod -R u=rwX,g=rX,o= "$release"
# Preserve the existing worker directory if deployed alongside the backend.
if [[ -d "$old/backend/media-worker" && ! -d "$release/backend/media-worker" ]]; then
 cp -a "$old/backend/media-worker" "$release/backend/media-worker"
fi
# Parse the inspected static /agent/ block. Abort rather than change an unexpected layout.
python3 - "$release" "$backup" <<'PY'
import re,sys
from pathlib import Path
r=Path(sys.argv[1]);b=Path(sys.argv[2])
p=Path('/etc/nginx/conf.d/kilo-website.conf')
s=p.read_text()
pattern=r'(?ms)^[ \t]*location\s+/agent/\s*\{.*?^[ \t]*\}'
assert len(re.findall(pattern,s))==1, 'Unexpected existing /agent/ configuration'
assert not re.search(r'location\s+(?:=\s+)?/mcp',s), 'Existing MCP routing requires review'
s=re.sub(pattern,(r/'deploy/web-production/nginx-locations.conf').read_text().strip(),s,count=1)
(b/'new-kilo-website.conf').write_text(s)
p=Path('/etc/kilo/kilo.env');s=p.read_text()
s=re.sub(r'(?m)^KILO_AGENT_PUBLIC_BASE_URL=.*\n?', '', s)
s += '\nKILO_AGENT_PUBLIC_BASE_URL=https://kilostrength.cn\n'
(b/'new-kilo.env').write_text(s)
PY
changed=0
rollback() {
 code=$?
 if [[ $changed == 1 ]]; then
  cp -a "$backup/kilo.env" /etc/kilo/kilo.env
  cp -a "$backup/kilo-website.conf" /etc/nginx/conf.d/kilo-website.conf
  ln -s "$old" /opt/kilo/current.rollback
  mv -Tf /opt/kilo/current.rollback /opt/kilo/current
  systemctl restart kilo-api
  nginx -t && systemctl reload nginx
  echo "Rolled back application/configuration. Backup: $backup"
 fi
 exit "$code"
}
trap rollback ERR
changed=1
cat "$backup/new-kilo.env" > /etc/kilo/kilo.env
cat "$backup/new-kilo-website.conf" > /etc/nginx/conf.d/kilo-website.conf
nginx -t
ln -s "$release" /opt/kilo/current.next
mv -Tf /opt/kilo/current.next /opt/kilo/current
systemctl restart kilo-api
systemctl reload nginx
trap - ERR
printf 'DEPLOY_OK\nRelease: %s\nBackup: %s\nWeb: https://kilostrength.cn/agent/\nMCP: https://kilostrength.cn/mcp\n' "$release" "$backup"
