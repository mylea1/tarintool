import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { config } from '../src/config.mjs';
import { openDatabase, closeDatabase, transaction } from '../src/db.mjs';
import { nowIso } from '../src/security.mjs';

const backendRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sourcePath = path.join(backendRoot, 'knowledge', 'core.zh-CN.json');
const chunks = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
const db = openDatabase(config.databasePath);

try {
  transaction(db, () => {
    const upsert = db.prepare(`INSERT INTO knowledge_chunks
      (id, title, source, content, tags_json, updated_at)
      VALUES (@id, @title, @source, @content, @tags_json, @updated_at)
      ON CONFLICT(id) DO UPDATE SET title=excluded.title, source=excluded.source,
        content=excluded.content, tags_json=excluded.tags_json, updated_at=excluded.updated_at`);
    const removeFts = db.prepare('DELETE FROM knowledge_fts WHERE id = ?');
    const insertFts = db.prepare('INSERT INTO knowledge_fts (id, title, content) VALUES (?, ?, ?)');
    for (const chunk of chunks) {
      const record = {
        ...chunk,
        tags_json: JSON.stringify(Array.isArray(chunk.tags) ? chunk.tags : []),
        updated_at: nowIso(),
      };
      upsert.run(record);
      removeFts.run(chunk.id);
      insertFts.run(chunk.id, chunk.title, chunk.content);
    }
  });
  console.log(JSON.stringify({ seeded: chunks.length, databasePath: config.databasePath }));
} finally {
  closeDatabase(db);
}
