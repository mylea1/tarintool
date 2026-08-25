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
  // The original schema only allowed the prototype plans (oneMonth,
  // threeMonths, forever). Keep those values readable while widening the
  // check constraint for the current yearly subscription. SQLite cannot
  // alter a CHECK constraint in place, so rebuild these two small tables
  // additively and copy every historical row before dropping the legacy copy.
  const entitlementSql = db.prepare("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'entitlements'").get()?.sql || '';
  if (!entitlementSql.includes("'yearly'")) {
    db.exec(`
      ALTER TABLE entitlements RENAME TO entitlements_legacy;
      CREATE TABLE entitlements (
        user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        membership TEXT NOT NULL DEFAULT 'free' CHECK (membership IN ('free', 'oneMonth', 'yearly', 'threeMonths', 'forever')),
        membership_expires_at TEXT,
        ai_day_key TEXT NOT NULL,
        ai_remaining INTEGER NOT NULL DEFAULT 3 CHECK (ai_remaining >= 0),
        recognition_remaining INTEGER NOT NULL DEFAULT 5 CHECK (recognition_remaining >= 0),
        recognition_week_key TEXT NOT NULL,
        recognition_weekly_grant INTEGER NOT NULL DEFAULT 1 CHECK (recognition_weekly_grant >= 0),
        updated_at TEXT NOT NULL
      );
      INSERT INTO entitlements (user_id, membership, membership_expires_at, ai_day_key,
        ai_remaining, recognition_remaining, recognition_week_key,
        recognition_weekly_grant, updated_at)
        SELECT user_id, membership, membership_expires_at, ai_day_key,
          ai_remaining, recognition_remaining, recognition_week_key,
          recognition_weekly_grant, updated_at FROM entitlements_legacy;
      DROP TABLE entitlements_legacy;
    `);
  }
  const ordersSql = db.prepare("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'membership_orders'").get()?.sql || '';
  if (!ordersSql.includes("'yearly'")) {
    db.exec(`
      DROP INDEX IF EXISTS idx_membership_orders_pending_product;
      DROP INDEX IF EXISTS idx_membership_orders_user;
      ALTER TABLE membership_orders RENAME TO membership_orders_legacy;
      CREATE TABLE membership_orders (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        product_id TEXT NOT NULL,
        plan TEXT NOT NULL CHECK (plan IN ('oneMonth', 'yearly', 'threeMonths', 'forever')),
        provider TEXT NOT NULL CHECK (provider IN ('app_store', 'google_play', 'redemption')),
        status TEXT NOT NULL CHECK (status IN ('pending', 'paid', 'restored', 'cancelled', 'failed', 'refunded')),
        amount_minor INTEGER,
        currency TEXT,
        provider_transaction_id TEXT UNIQUE,
        local_order_id TEXT,
        failure_reason TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        paid_at TEXT
      );
      INSERT INTO membership_orders (id, user_id, product_id, plan, provider, status,
        amount_minor, currency, provider_transaction_id, local_order_id,
        failure_reason, created_at, updated_at, paid_at)
        SELECT id, user_id, product_id, plan, provider, status,
          amount_minor, currency, provider_transaction_id, local_order_id,
          failure_reason, created_at, updated_at, paid_at
        FROM membership_orders_legacy;
      DROP TABLE membership_orders_legacy;
      CREATE INDEX idx_membership_orders_user
        ON membership_orders(user_id, created_at DESC);
      CREATE UNIQUE INDEX idx_membership_orders_pending_product
        ON membership_orders(user_id, product_id) WHERE status = 'pending';
    `);
  }
  const paymentOrdersSql = db.prepare("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'membership_orders'").get()?.sql || '';
  if (!paymentOrdersSql.includes("'wechat_pay'")) {
    db.exec(`
      DROP INDEX IF EXISTS idx_membership_orders_pending_product;
      DROP INDEX IF EXISTS idx_membership_orders_user;
      ALTER TABLE membership_orders RENAME TO membership_orders_pre_android;
      CREATE TABLE membership_orders (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        product_id TEXT NOT NULL,
        plan TEXT NOT NULL CHECK (plan IN ('oneMonth', 'yearly', 'threeMonths', 'forever')),
        provider TEXT NOT NULL CHECK (provider IN ('app_store', 'google_play', 'wechat_pay', 'alipay', 'redemption')),
        status TEXT NOT NULL CHECK (status IN ('pending', 'paid', 'restored', 'cancelled', 'failed', 'refunded')),
        amount_minor INTEGER,
        currency TEXT,
        provider_transaction_id TEXT UNIQUE,
        local_order_id TEXT,
        failure_reason TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        paid_at TEXT
      );
      INSERT INTO membership_orders SELECT * FROM membership_orders_pre_android;
      DROP TABLE membership_orders_pre_android;
      CREATE INDEX idx_membership_orders_user ON membership_orders(user_id, created_at DESC);
      CREATE UNIQUE INDEX idx_membership_orders_pending_product
        ON membership_orders(user_id, product_id, provider) WHERE status = 'pending';
    `);
  }
  // These tables were added after the first release. CREATE IF NOT EXISTS is
  // deliberately used so existing production databases remain untouched.
  db.exec(`
    CREATE TABLE IF NOT EXISTS daily_checkins (
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      date_key TEXT NOT NULL,
      created_at TEXT NOT NULL,
      PRIMARY KEY (user_id, date_key)
    );
    CREATE INDEX IF NOT EXISTS idx_daily_checkins_user ON daily_checkins(user_id, date_key DESC);
    CREATE TABLE IF NOT EXISTS checkin_state (
      user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      round_days INTEGER NOT NULL DEFAULT 0 CHECK (round_days >= 0 AND round_days < 7),
      total_days INTEGER NOT NULL DEFAULT 0 CHECK (total_days >= 0),
      reward_round INTEGER NOT NULL DEFAULT 0 CHECK (reward_round >= 0),
      last_reward_at TEXT,
      updated_at TEXT NOT NULL
    );
  `);
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

// Calendar days for rewards follow the product's advertised Asia/Shanghai
// timezone, regardless of the host machine's timezone.
export function shanghaiDayKey(date = new Date()) {
  return new Date(date.getTime() + 8 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

export function ensureCheckinState(db, userId, at = new Date()) {
  const stamp = at.toISOString();
  let row = db.prepare('SELECT * FROM checkin_state WHERE user_id = ?').get(userId);
  if (!row) {
    db.prepare(`INSERT INTO checkin_state
      (user_id, round_days, total_days, reward_round, last_reward_at, updated_at)
      VALUES (?, 0, 0, 0, NULL, ?)`).run(userId, stamp);
    row = db.prepare('SELECT * FROM checkin_state WHERE user_id = ?').get(userId);
  }
  return row;
}

export function publicCheckinState(db, userId, at = new Date()) {
  const state = ensureCheckinState(db, userId, at);
  const today = shanghaiDayKey(at);
  return {
    todayCheckedIn: Boolean(db.prepare('SELECT 1 FROM daily_checkins WHERE user_id = ? AND date_key = ?').get(userId, today)),
    roundDays: Number(state.round_days),
    roundSize: 7,
    totalDays: Number(state.total_days),
    rewardRound: Number(state.reward_round),
    lastRewardAt: state.last_reward_at,
    timezone: 'Asia/Shanghai',
  };
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
  let existing = db.prepare('SELECT * FROM users WHERE identifier = ?').get(cfg.testAdminIdentifier);
  const legacy = cfg.testAdminIdentifier !== '1234'
    ? db.prepare("SELECT * FROM users WHERE identifier = '1234' AND role = 'admin'").get()
    : null;
  if (!existing && legacy) {
    db.prepare('UPDATE users SET identifier = ?, display_name = ? WHERE id = ?')
      .run(cfg.testAdminIdentifier, '形域测试管理员', legacy.id);
    existing = db.prepare('SELECT * FROM users WHERE id = ?').get(legacy.id);
  }
  if (existing) {
    const password = hashPassword(cfg.testAdminPassword);
    db.prepare(`UPDATE users SET role = 'admin', display_name = ?, auth_provider = 'password',
      password_salt = ?, password_hash = ? WHERE id = ?`)
      .run('形域测试管理员', password.salt, password.hash, existing.id);
    ensureEntitlement(db, existing.id);
    db.prepare(`UPDATE entitlements SET membership = 'forever', membership_expires_at = NULL,
      ai_remaining = CASE WHEN ai_remaining < 20 THEN 20 ELSE ai_remaining END,
      recognition_remaining = CASE WHEN recognition_remaining < 3 THEN 3 ELSE recognition_remaining END,
      recognition_weekly_grant = CASE WHEN recognition_weekly_grant < 3 THEN 3 ELSE recognition_weekly_grant END,
      updated_at = ? WHERE user_id = ?`).run(nowIso(), existing.id);
    const admin = db.prepare('SELECT * FROM users WHERE id = ?').get(existing.id);
    seedSocialDemoData(db, admin, cfg.testAdminPassword);
    return admin;
  }
  const password = hashPassword(cfg.testAdminPassword);
  const user = {
    id: randomId('usr_'),
    identifier: cfg.testAdminIdentifier,
    display_name: '形域测试管理员',
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
  const admin = db.prepare('SELECT * FROM users WHERE id = ?').get(user.id);
  seedSocialDemoData(db, admin, cfg.testAdminPassword);
  return admin;
}

function seedSocialDemoData(db, admin, rawPassword) {
  const stamp = nowIso();
  const demos = [
    {
      identifier: '13800001001',
      name: '晨练小周',
      sourcePlanId: 'demo-upper-strength',
      planName: '上肢力量进阶',
      exercises: [
        ['bench_press', 82.5, 6, 150],
        ['chest_supported_row', 60, 10, 120],
        ['shoulder_press', 22.5, 8, 120],
      ],
    },
    {
      identifier: '13800001002',
      name: '背部玩家',
      sourcePlanId: 'demo-back-volume',
      planName: '背部容量日',
      exercises: [
        ['lat_pulldown', 65, 10, 120],
        ['chest_supported_row', 55, 12, 120],
        ['deadlift', 100, 5, 180],
      ],
    },
    {
      identifier: '13800001003',
      name: '力量新手阿泽',
      sourcePlanId: 'demo-lower-foundation',
      planName: '下肢基础训练',
      exercises: [
        ['barbell_squat', 60, 8, 180],
        ['deadlift', 70, 6, 180],
      ],
    },
  ];
  for (const demo of demos) {
    let user = db.prepare('SELECT * FROM users WHERE identifier = ?').get(demo.identifier);
    if (!user) {
      const password = hashPassword(rawPassword, undefined, 3);
      const id = randomId('usr_');
      db.prepare(`INSERT INTO users (id, identifier, display_name, role, auth_provider,
        password_salt, password_hash, created_at) VALUES (?, ?, ?, 'user', 'password', ?, ?, ?)`)
        .run(id, demo.identifier, demo.name, password.salt, password.hash, stamp);
      user = db.prepare('SELECT * FROM users WHERE id = ?').get(id);
      ensureEntitlement(db, id);
    }
    const pair = [admin.id, user.id].sort().join(':');
    db.prepare(`INSERT INTO friend_requests
      (id, pair_key, sender_user_id, receiver_user_id, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, 'accepted', ?, ?)
      ON CONFLICT(pair_key) DO UPDATE SET status='accepted', updated_at=excluded.updated_at`)
      .run(`demo-friend-${user.id}`, pair, user.id, admin.id, stamp, stamp);
    const payload = {
      exercises: demo.exercises.map(([exerciseId, weight, reps, restSeconds]) => ({
        exerciseId,
        restSeconds,
        sets: Array.from({ length: 3 }, () => ({ type: 'work', weight, reps, restSeconds })),
      })),
    };
    db.prepare(`INSERT INTO friend_plan_shares
      (id, owner_user_id, source_plan_id, name, payload_json, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(owner_user_id, source_plan_id)
      DO UPDATE SET name=excluded.name, payload_json=excluded.payload_json, updated_at=excluded.updated_at`)
      .run(`demo-plan-${user.id}`, user.id, demo.sourcePlanId, demo.planName, JSON.stringify(payload), stamp, stamp);
  }
  if (cfgLegacyAdmin(db, admin.id)) {
    const disabled = hashPassword(randomId('disabled_'), undefined, 3);
    db.prepare(`UPDATE users SET identifier = ?, role = 'user', password_salt = ?, password_hash = ?
      WHERE identifier = '1234' AND id <> ?`)
      .run(`disabled-${randomId('legacy_')}`, disabled.salt, disabled.hash, admin.id);
  }
}

function cfgLegacyAdmin(db, adminId) {
  return db.prepare("SELECT 1 FROM users WHERE identifier = '1234' AND id <> ?").get(adminId);
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
    forever: true,
  });
  return member;
}
