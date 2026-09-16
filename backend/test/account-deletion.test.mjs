import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { openDatabase } from '../src/db.mjs';
import { LocalStorage } from '../src/storage.mjs';
import { deleteAccountData, revokeAppleAuthorization } from '../src/account-deletion.mjs';

test('permanent deletion removes owned data/media/session and keeps other users', async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'kilo-delete-'));
  const db = openDatabase(path.join(dir, 'test.db'));
  const storage = new LocalStorage(path.join(dir, 'media'));
  try {
    for (const id of ['owner', 'other']) db.prepare("INSERT INTO users(id,identifier,display_name,role,created_at) VALUES(?,?,?,'user','now')").run(id,id,id);
    db.prepare("INSERT INTO sessions VALUES('s','owner','secret','2099','now')").run();
    db.prepare("INSERT INTO sync_entities VALUES('owner','plan','p',1,'{}',NULL,'now')").run();
    db.prepare("INSERT INTO sync_entities VALUES('other','plan','q',1,'{}',NULL,'now')").run();
    db.prepare("INSERT INTO audit_log VALUES('a','owner','login','owner','{}','now')").run();
    db.prepare("INSERT INTO redemption_codes(code,plan,created_by,created_at,used_by) VALUES('used','oneMonth','other','now','owner')").run();
    await storage.putBuffer('avatars/owner.png', Buffer.from('avatar'));
    await storage.putBuffer('avatars/other.png', Buffer.from('other'));
    if (!db.prepare('PRAGMA table_info(users)').all().some(c=>c.name==='avatar_key')) db.exec('ALTER TABLE users ADD COLUMN avatar_key TEXT');
    db.prepare("UPDATE users SET avatar_key='avatars/owner.png' WHERE id='owner'").run();
    await deleteAccountData({db, storage}, db.prepare("SELECT * FROM users WHERE id='owner'").get());
    assert.equal(db.prepare("SELECT * FROM users WHERE id='owner'").get(), undefined);
    assert.equal(db.prepare('SELECT count(*) n FROM sessions').get().n, 0);
    assert.equal(db.prepare('SELECT count(*) n FROM audit_log').get().n, 0);
    assert.equal(db.prepare('SELECT count(*) n FROM redemption_codes').get().n, 0);
    assert.equal(db.prepare('SELECT count(*) n FROM sync_entities').get().n, 1);
    assert.equal(storage.exists('avatars/owner.png'), false);
    assert.equal(storage.exists('avatars/other.png'), true);
  } finally { db.close(); await fs.rm(dir,{recursive:true,force:true}); }
});

test('Apple deletion fails closed without revocation configuration', async () => {
  await assert.rejects(revokeAppleAuthorization({}, 'code', 'subject'), /apple_revocation_not_configured/);
});


test('HTTP deletion requires confirmation, invalidates session and accepts actual Apple product IDs', async () => {
  const { startServer } = await import('../src/server.mjs');
  const { loadConfig } = await import('../src/config.mjs');
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'kilo-delete-api-'));
  const cfg = loadConfig({NODE_ENV:'test', KILO_ENABLE_PASSWORD_REGISTRATION:'true',
    KILO_SESSION_PEPPER:'test-session-pepper-with-enough-length',
    KILO_DATA_DIR:dir,KILO_DATABASE_PATH:path.join(dir,'db.sqlite'),KILO_MEDIA_DIR:path.join(dir,'media')});
  const server = await startServer({config:cfg,port:0});
  const base = `http://127.0.0.1:${server.address().port}`;
  const request = (route, token, body) => fetch(base+route,{method:'POST', headers:{'content-type':'application/json', ...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify(body)});
  try {
    const registered = await request('/v1/auth/register', null, {identifier:'deletion-test',password:'abcd'});
    assert.equal(registered.status,201);
    const token = (await registered.json()).session.token;
    for (const productId of ['11','33']) {
      const order = await request('/v1/membership/orders', token, {productId,provider:'app_store'});
      assert.equal(order.status,201);
      assert.equal((await order.json()).order.productId,productId);
    }
    assert.equal((await request('/v1/me/delete-account',null,{confirmation:'DELETE'})).status,401);
    assert.equal((await request('/v1/me/delete-account',token,{})).status,400);
    const removed = await request('/v1/me/delete-account',token,{confirmation:'DELETE'});
    assert.equal(removed.status,200);
    assert.equal((await removed.json()).deleted,true);
    assert.equal((await request('/v1/me/delete-account',token,{confirmation:'DELETE'})).status,401);
  } finally { await server.closeGracefully(); await fs.rm(dir,{recursive:true,force:true}); }
});
