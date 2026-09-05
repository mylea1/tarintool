import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { openDatabase, closeDatabase, publicUser, normalizePhone, syncAccountPhoneIdentity } from '../src/db.mjs';

test('public IDs are unique, stable across reopen and preserve phone discovery', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'kilo-public-id-'));
  const filename = path.join(directory, 'db.sqlite');
  let db = openDatabase(filename);
  try {
    for (let i = 0; i < 40; i++) {
      db.prepare(`INSERT INTO users (id, identifier, display_name, role, auth_provider, created_at)
        VALUES (?, ?, '训练者', 'user', 'password', ?)`).run(`user-${i}`, `1380013${String(i).padStart(4, '0')}`, new Date().toISOString());
    }
    const users = db.prepare('SELECT * FROM users ORDER BY id').all();
    const ids = users.map(row => publicUser(row).publicId);
    assert.equal(new Set(ids).size, 40);
    for (const id of ids) assert.match(id, /^[1-9]\d{9}$/);
    syncAccountPhoneIdentity(db, users[0]);
    const found = db.prepare("SELECT user_id FROM user_identities WHERE kind = 'phone' AND normalized_value = ?").get(normalizePhone(users[0].identifier));
    assert.equal(found.user_id, users[0].id);
    closeDatabase(db);
    db = openDatabase(filename);
    assert.deepEqual(db.prepare('SELECT public_id FROM users ORDER BY id').all().map(row => row.public_id), ids);
  } finally {
    closeDatabase(db);
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
