import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';
import { nowIso, hashPassword, randomId } from './security.mjs';

const migrationPath = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'migrations', '001_init.sql');

export function openDatabase(databasePath) {
  fs.mkdirSync(path.dirname(databasePath), { recursive: true });
  const db = new Database(databasePath);
  db.pragma('foreign_keys = ON');
  db.pragma('busy_timeout = 5000');
  db.exec(fs.readFileSync(migrationPath, 'utf8'));
  // Databases created by the first backend build may not have the upload
  // expiry column. Keep the migration additive so test/prod data can be
  // upgraded in place without dropping recognition jobs.
  const columns = db.prepare('PRAGMA table_info(recognition_jobs)').all();
  if (!columns.some((column) => column.name === 'upload_expires_at')) {
    db.exec('ALTER TABLE recognition_jobs ADD COLUMN upload_expires_at TEXT');
  }
  if (!columns.some((column) => column.name === 'include_overlay')) {
    db.exec(
      'ALTER TABLE recognition_jobs ADD COLUMN include_overlay INTEGER NOT NULL DEFAULT 1',
    );
  }
  return db;
}

export function closeDatabase(db) {
  try { db.close(); } catch { /* already closed */ }
}

export function transaction(db, callback) {
  return db.transaction(callback)();
}

export function ensureEntitlement(db, userId, at = new Date()) {
  const stamp = at.toISOString();
  let row = db.prepare('SELECT * FROM entitlements WHERE user_id = ?').get(userId);
  if (!row) {
    const day = stamp.slice(0, 10);
    const week = isoWeekKey(at);
    db.prepare(`INSERT INTO entitlements
      (user_id, membership, membership_expires_at, ai_day_key, ai_remaining,
       recognition_remaining, recognition_week_key, recognition_weekly_grant, updated_at)
      VALUES (?, 'free', NULL, ?, 3, 5, ?, 1, ?)`).run(userId, day, week, stamp);
    row = db.prepare('SELECT * FROM entitlements WHERE user_id = ?').get(userId);
  }
  return refreshEntitlement(db, row, at);
}

export function isoWeekKey(date = new Date()) {
  const d = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const day = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const week = Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
  return `${d.getUTCFullYear()}-${String(week).padStart(2, '0')}`;
}

export function membershipActive(row, at = new Date()) {
  return row.membership === 'forever' || (row.membership !== 'free' && row.membership_expires_at && new Date(row.membership_expires_at) > at);
}

export function refreshEntitlement(db, row, at = new Date()) {
  const stamp = at.toISOString();
  let membership = row.membership;
  let expires = row.membership_expires_at;
  if (membership !== 'free' && membership !== 'forever' && (!expires || new Date(expires) <= at)) {
    membership = 'free';
    expires = null;
  }
  const day = stamp.slice(0, 10);
  const week = isoWeekKey(at);
  const member = membershipActive({ ...row, membership, membership_expires_at: expires }, at);
  const aiLimit = member ? 20 : 3;
  const recognitionGrant = member ? 3 : 1;
  let aiRemaining = Number(row.ai_remaining);
  let recognitionRemaining = Number(row.recognition_remaining);
  let aiDayKey = row.ai_day_key;
  let recognitionWeekKey = row.recognition_week_key;
  if (aiDayKey !== day) {
    aiDayKey = day;
    aiRemaining = aiLimit;
  } else if (aiRemaining > aiLimit && !member) {
    aiRemaining = aiLimit;
  }
  if (recognitionWeekKey !== week) {
    recognitionWeekKey = week;
    recognitionRemaining += recognitionGrant;
  }
  const changed = membership !== row.membership || expires !== row.membership_expires_at ||
    aiDayKey !== row.ai_day_key || aiRemaining !== row.ai_remaining ||
    recognitionWeekKey !== row.recognition_week_key || recognitionGrant !== row.recognition_weekly_grant;
  if (changed) {
    db.prepare(`UPDATE entitlements SET membership = ?, membership_expires_at = ?, ai_day_key = ?,
      ai_remaining = ?, recognition_week_key = ?, recognition_weekly_grant = ?, updated_at = ? WHERE user_id = ?`)
      .run(membership, expires, aiDayKey, aiRemaining, recognitionWeekKey, recognitionGrant, stamp, row.user_id);
    return db.prepare('SELECT * FROM entitlements WHERE user_id = ?').get(row.user_id);
  }
  return row;
}

export function publicUser(row) {
  if (!row) return null;
  return {
    id: row.id,
    identifier: row.identifier,
    displayName: row.display_name,
    role: row.role,
    authProvider: row.auth_provider,
    createdAt: row.created_at,
  };
}

export function publicEntitlement(row) {
  return {
    membership: row.membership,
    membershipExpiresAt: row.membership_expires_at,
    aiRemaining: Number(row.ai_remaining),
    aiDailyLimit: row.membership === 'free' ? 3 : 20,
    recognitionRemaining: Number(row.recognition_remaining),
    recognitionWeeklyGrant: Number(row.recognition_weekly_grant),
    aiDayKey: row.ai_day_key,
    aiPeriodKey: row.ai_day_key,
    recognitionWeekKey: row.recognition_week_key,
    updatedAt: row.updated_at,
  };
}

export function seedTestAdmin(db, cfg) {
  if (!cfg.enableTestAdmin) return null;
  const existing = db.prepare('SELECT * FROM users WHERE identifier = ?').get(cfg.testAdminIdentifier);
  if (existing) {
    if (existing.role !== 'admin') db.prepare("UPDATE users SET role = 'admin' WHERE id = ?").run(existing.id);
    ensureEntitlement(db, existing.id);
    db.prepare(`UPDATE entitlements SET membership = 'forever', membership_expires_at = NULL,
      ai_remaining = CASE WHEN ai_remaining < 20 THEN 20 ELSE ai_remaining END,
      recognition_remaining = CASE WHEN recognition_remaining < 3 THEN 3 ELSE recognition_remaining END,
      recognition_weekly_grant = CASE WHEN recognition_weekly_grant < 3 THEN 3 ELSE recognition_weekly_grant END,
      updated_at = ? WHERE user_id = ?`).run(nowIso(), existing.id);
    return db.prepare('SELECT * FROM users WHERE id = ?').get(existing.id);
  }
  const password = hashPassword(cfg.testAdminPassword);
  const user = {
    id: randomId('usr_'),
    identifier: cfg.testAdminIdentifier,
    display_name: 'KILO Test Admin',
    role: 'admin',
    auth_provider: 'password',
    created_at: nowIso(),
  };
  db.prepare(`INSERT INTO users (id, identifier, display_name, role, auth_provider, password_salt, password_hash, created_at)
    VALUES (@id, @identifier, @display_name, @role, @auth_provider, @salt, @hash, @created_at)`)
    .run({ ...user, salt: password.salt, hash: password.hash });
  ensureEntitlement(db, user.id);
  db.prepare(`UPDATE entitlements SET membership = 'forever', membership_expires_at = NULL,
    ai_remaining = CASE WHEN ai_remaining < 20 THEN 20 ELSE ai_remaining END,
    recognition_remaining = CASE WHEN recognition_remaining < 3 THEN 3 ELSE recognition_remaining END,
    recognition_weekly_grant = CASE WHEN recognition_weekly_grant < 3 THEN 3 ELSE recognition_weekly_grant END,
    updated_at = ? WHERE user_id = ?`).run(nowIso(), user.id);
  return db.prepare('SELECT * FROM users WHERE id = ?').get(user.id);
}

export function seedTestMember(db, cfg) {
  if (!cfg.enableTestMember) return null;
  const upsertMember = ({ identifier, rawPassword, displayName, forever = false }) => {
    let user = db.prepare('SELECT * FROM users WHERE identifier = ?').get(identifier);
    if (!user) {
      const password = hashPassword(rawPassword, undefined, 3);
      user = {
        id: randomId('usr_'),
        identifier,
        display_name: displayName,
        role: 'user',
        auth_provider: 'password',
        created_at: nowIso(),
      };
      db.prepare(`INSERT INTO users (id, identifier, display_name, role, auth_provider, password_salt, password_hash, created_at)
        VALUES (@id, @identifier, @display_name, @role, @auth_provider, @salt, @hash, @created_at)`)
        .run({ ...user, salt: password.salt, hash: password.hash });
    }
    if (user.role !== 'user') {
      db.prepare("UPDATE users SET role = 'user' WHERE id = ?").run(user.id);
      user = db.prepare('SELECT * FROM users WHERE id = ?').get(user.id);
    }
    ensureEntitlement(db, user.id);
    if (forever) {
      db.prepare(`UPDATE entitlements SET membership = 'forever', membership_expires_at = NULL,
        ai_remaining = CASE WHEN ai_remaining < 20 THEN 20 ELSE ai_remaining END,
        recognition_remaining = CASE WHEN recognition_remaining < 3 THEN 3 ELSE recognition_remaining END,
        recognition_weekly_grant = CASE WHEN recognition_weekly_grant < 3 THEN 3 ELSE recognition_weekly_grant END,
        updated_at = ? WHERE user_id = ?`).run(nowIso(), user.id);
    }
    return db.prepare('SELECT * FROM users WHERE id = ?').get(user.id);
  };
  const member = upsertMember({
    identifier: cfg.testMemberIdentifier,
    rawPassword: cfg.testMemberPassword,
    displayName: 'EMBER Test Member',
  });
  upsertMember({
    identifier: cfg.testAdminIdentifier,
    rawPassword: cfg.testAdminPassword,
    displayName: 'EMBER Test Operator',
    forever: true,
  });
  return member;
}
