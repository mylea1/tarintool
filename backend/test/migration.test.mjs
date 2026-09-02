import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import Database from 'better-sqlite3';

import { closeDatabase, openDatabase } from '../src/db.mjs';

test('legacy membership tables migrate to yearly plans without losing orders', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'kilo-membership-migration-'));
  const databasePath = path.join(directory, 'legacy.sqlite');
  const legacy = new Database(databasePath);
  legacy.exec(`
    CREATE TABLE users (
      id TEXT PRIMARY KEY,
      identifier TEXT UNIQUE NOT NULL,
      display_name TEXT NOT NULL,
      role TEXT NOT NULL,
      auth_provider TEXT NOT NULL,
      password_salt TEXT,
      password_hash TEXT,
      created_at TEXT NOT NULL
    );
    CREATE TABLE entitlements (
      user_id TEXT PRIMARY KEY,
      membership TEXT NOT NULL DEFAULT 'free'
        CHECK (membership IN ('free', 'oneMonth', 'threeMonths', 'forever')),
      membership_expires_at TEXT,
      ai_day_key TEXT NOT NULL,
      ai_remaining INTEGER NOT NULL DEFAULT 3,
      recognition_remaining INTEGER NOT NULL DEFAULT 5,
      recognition_week_key TEXT NOT NULL,
      recognition_weekly_grant INTEGER NOT NULL DEFAULT 1,
      updated_at TEXT NOT NULL
    );
    CREATE TABLE membership_orders (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      plan TEXT NOT NULL CHECK (plan IN ('oneMonth', 'threeMonths', 'forever')),
      provider TEXT NOT NULL,
      status TEXT NOT NULL,
      amount_minor INTEGER,
      currency TEXT,
      provider_transaction_id TEXT UNIQUE,
      local_order_id TEXT,
      failure_reason TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      paid_at TEXT
    );
    INSERT INTO users VALUES
      ('user-1', 'legacy-user', 'Legacy', 'user', 'password', NULL, NULL, '2026-01-01T00:00:00.000Z');
    INSERT INTO entitlements VALUES
      ('user-1', 'oneMonth', '2027-01-01T00:00:00.000Z', '2026-01-01', 3, 5, '2026-01', 1, '2026-01-01T00:00:00.000Z');
    INSERT INTO membership_orders VALUES
      ('order-1', 'user-1', 'legacy-monthly', 'oneMonth', 'app_store', 'paid', 1800, 'CNY', 'tx-1', NULL, NULL, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z');
  `);
  legacy.close();

  const upgraded = openDatabase(databasePath);
  try {
    const entitlementSql = upgraded
      .prepare("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'entitlements'")
      .get().sql;
    const orderSql = upgraded
      .prepare("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'membership_orders'")
      .get().sql;
    assert.match(entitlementSql, /'yearly'/);
    assert.match(orderSql, /'yearly'/);
    assert.equal(upgraded.prepare('SELECT COUNT(*) AS count FROM membership_orders').get().count, 1);
    const entitlementColumns = upgraded
      .prepare('PRAGMA table_info(entitlements)')
      .all()
      .map((column) => column.name);
    assert.ok(entitlementColumns.includes('trial_started_at'));
    assert.ok(entitlementColumns.includes('trial_expires_at'));
    assert.ok(entitlementColumns.includes('trial_workout_id'));
    assert.doesNotThrow(() => upgraded
      .prepare("UPDATE entitlements SET membership = 'yearly' WHERE user_id = 'user-1'")
      .run());
  } finally {
    closeDatabase(upgraded);
  }

  // Re-opening an already-upgraded database must keep the additive migration idempotent.
  const reopened = openDatabase(databasePath);
  try {
    const columns = reopened
      .prepare('PRAGMA table_info(entitlements)')
      .all()
      .map((column) => column.name);
    assert.ok(columns.includes('trial_started_at'));
    assert.equal(reopened.prepare('SELECT membership FROM entitlements WHERE user_id = ?').get('user-1').membership, 'yearly');
  } finally {
    closeDatabase(reopened);
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('legacy workout posts gain safe cross-device card appearance fields', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'kilo-workout-card-migration-'));
  const databasePath = path.join(directory, 'legacy.sqlite');
  const legacy = new Database(databasePath);
  legacy.exec(`
    CREATE TABLE friend_workout_posts (
      id TEXT PRIMARY KEY,
      owner_user_id TEXT NOT NULL,
      source_workout_id TEXT NOT NULL,
      name TEXT NOT NULL,
      started_at TEXT,
      completed_at TEXT NOT NULL,
      duration_seconds INTEGER NOT NULL DEFAULT 0,
      volume_kg REAL NOT NULL DEFAULT 0,
      effective_sets INTEGER NOT NULL DEFAULT 0,
      completion_rate REAL NOT NULL DEFAULT 0,
      exercises_json TEXT NOT NULL DEFAULT '[]',
      caption TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      UNIQUE(owner_user_id, source_workout_id)
    );
    INSERT INTO friend_workout_posts VALUES
      ('post-1', 'user-1', 'workout-1', '旧训练', NULL,
       '2026-08-31T11:00:00.000Z', 3600, 1200, 10, 1, '[]', NULL,
       '2026-08-31T11:00:00.000Z', '2026-08-31T11:00:00.000Z');
  `);
  legacy.close();

  const upgraded = openDatabase(databasePath);
  try {
    const columns = upgraded
      .prepare('PRAGMA table_info(friend_workout_posts)')
      .all()
      .map((column) => column.name);
    assert.ok(columns.includes('card_style'));
    assert.ok(columns.includes('card_image_key'));
    const post = upgraded
      .prepare('SELECT card_style, card_image_key FROM friend_workout_posts WHERE id = ?')
      .get('post-1');
    assert.deepEqual(post, { card_style: 'coral', card_image_key: 'brand' });
  } finally {
    closeDatabase(upgraded);
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
