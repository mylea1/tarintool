PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 5000;

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  identifier TEXT UNIQUE,
  display_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('user', 'admin')) DEFAULT 'user',
  auth_provider TEXT NOT NULL DEFAULT 'password',
  provider_subject TEXT,
  password_salt TEXT,
  password_hash TEXT,
  created_at TEXT NOT NULL,
  UNIQUE(auth_provider, provider_subject)
);

CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);

CREATE TABLE IF NOT EXISTS entitlements (
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

CREATE TABLE IF NOT EXISTS redemption_codes (
  code TEXT PRIMARY KEY,
  plan TEXT NOT NULL CHECK (plan IN ('oneMonth', 'threeMonths', 'forever')),
  created_by TEXT NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL,
  used_by TEXT REFERENCES users(id),
  used_at TEXT
);

CREATE TABLE IF NOT EXISTS membership_orders (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL,
  -- yearly is the current public plan. The legacy values remain readable so
  -- old orders and redemption records can be migrated without data loss.
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
CREATE INDEX IF NOT EXISTS idx_membership_orders_user
  ON membership_orders(user_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_membership_orders_pending_product
  ON membership_orders(user_id, product_id) WHERE status = 'pending';

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

CREATE TABLE IF NOT EXISTS usage_reservations (
  request_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('ai', 'recognition')),
  state TEXT NOT NULL CHECK (state IN ('reserved', 'committed', 'rolled_back')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS workout_rewards (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  workout_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (user_id, workout_id)
);

CREATE TABLE IF NOT EXISTS sync_entities (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL CHECK (entity_type IN ('workout', 'plan', 'template', 'settings')),
  entity_id TEXT NOT NULL,
  revision INTEGER NOT NULL,
  payload_json TEXT NOT NULL,
  deleted_at TEXT,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (user_id, entity_type, entity_id)
);
CREATE INDEX IF NOT EXISTS idx_sync_updated ON sync_entities(user_id, updated_at);

CREATE TABLE IF NOT EXISTS conversations (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  memory_summary TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_conversations_user ON conversations(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS conversation_messages (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON conversation_messages(conversation_id, created_at);

CREATE TABLE IF NOT EXISTS knowledge_chunks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  source TEXT NOT NULL,
  content TEXT NOT NULL,
  tags_json TEXT NOT NULL DEFAULT '[]',
  updated_at TEXT NOT NULL
);
CREATE VIRTUAL TABLE IF NOT EXISTS knowledge_fts USING fts5(id UNINDEXED, title, content, tokenize='unicode61');

CREATE TABLE IF NOT EXISTS recognition_jobs (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  exercise_id TEXT NOT NULL,
  camera TEXT NOT NULL,
  include_overlay INTEGER NOT NULL DEFAULT 1,
  status TEXT NOT NULL CHECK (status IN ('created', 'uploading', 'queued', 'processing', 'completed', 'failed', 'cancelled', 'expired')),
  upload_token_hash TEXT NOT NULL,
  upload_expires_at TEXT,
  input_key TEXT NOT NULL,
  result_json TEXT,
  overlay_key TEXT,
  preview_key TEXT,
  error_code TEXT,
  model_version TEXT,
  quota_request_id TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_recognition_queue ON recognition_jobs(status, created_at);

CREATE TABLE IF NOT EXISTS push_tokens (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  token_hash TEXT NOT NULL,
  token TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (user_id, token_hash)
);

CREATE TABLE IF NOT EXISTS world_presences (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  venue_code TEXT NOT NULL,
  anonymous_name TEXT NOT NULL,
  training_focus TEXT NOT NULL,
  training_level INTEGER NOT NULL DEFAULT 1,
  training_started_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  allow_fist_bump INTEGER NOT NULL DEFAULT 1,
  allow_cheer INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_world_presences_venue
  ON world_presences(venue_code, expires_at);

CREATE TABLE IF NOT EXISTS world_echoes (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  venue_code TEXT NOT NULL,
  day_key TEXT NOT NULL,
  anonymous_name TEXT NOT NULL,
  training_focus TEXT NOT NULL,
  training_level INTEGER NOT NULL DEFAULT 1,
  duration_minutes INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (user_id, venue_code, day_key)
);
CREATE INDEX IF NOT EXISTS idx_world_echoes_venue
  ON world_echoes(venue_code, day_key, updated_at DESC);

CREATE TABLE IF NOT EXISTS world_interactions (
  id TEXT PRIMARY KEY,
  sender_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  venue_code TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('fist_bump', 'cheer', 'challenge')),
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_world_interactions_target
  ON world_interactions(target_user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS audit_log (
  id TEXT PRIMARY KEY,
  actor_user_id TEXT REFERENCES users(id),
  action TEXT NOT NULL,
  target TEXT NOT NULL,
  detail_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL
);
