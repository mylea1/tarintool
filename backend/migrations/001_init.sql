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
  avatar_key TEXT,
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

-- Searchable aliases are intentionally separate from the login identifier.
-- Friend relationships always reference users.id, so changing a public
-- username never breaks Android/iOS interoperability or existing friendships.
CREATE TABLE IF NOT EXISTS user_identities (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('username', 'phone', 'email')),
  normalized_value TEXT NOT NULL,
  display_value TEXT NOT NULL,
  source TEXT NOT NULL CHECK (source IN ('user', 'account', 'apple', 'google')),
  verified_at TEXT,
  searchable INTEGER NOT NULL DEFAULT 1 CHECK (searchable IN (0, 1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(kind, normalized_value),
  UNIQUE(user_id, kind)
);
CREATE INDEX IF NOT EXISTS idx_user_identities_user
  ON user_identities(user_id, kind);
CREATE INDEX IF NOT EXISTS idx_user_identities_search
  ON user_identities(kind, normalized_value, searchable);

CREATE TABLE IF NOT EXISTS entitlements (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  membership TEXT NOT NULL DEFAULT 'free' CHECK (membership IN ('free', 'oneMonth', 'yearly', 'threeMonths', 'forever')),
  membership_expires_at TEXT,
  cloud_retention_expires_at TEXT,
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
CREATE INDEX IF NOT EXISTS idx_membership_orders_user
  ON membership_orders(user_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_membership_orders_pending_product
  ON membership_orders(user_id, product_id, provider) WHERE status = 'pending';

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

-- Social data is deliberately opt-in. Friends can only see plan snapshots
-- explicitly shared by their owner; workout notes and private history never
-- enter these tables.
CREATE TABLE IF NOT EXISTS friend_requests (
  id TEXT PRIMARY KEY,
  pair_key TEXT NOT NULL UNIQUE,
  sender_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  CHECK (sender_user_id <> receiver_user_id)
);
CREATE INDEX IF NOT EXISTS idx_friend_requests_receiver
  ON friend_requests(receiver_user_id, status, updated_at DESC);

CREATE TABLE IF NOT EXISTS friend_plan_shares (
  id TEXT PRIMARY KEY,
  owner_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source_plan_id TEXT NOT NULL,
  name TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(owner_user_id, source_plan_id)
);
CREATE INDEX IF NOT EXISTS idx_friend_plan_shares_owner
  ON friend_plan_shares(owner_user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS friend_plan_reactions (
  share_id TEXT NOT NULL REFERENCES friend_plan_shares(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (share_id, user_id)
);

-- A workout post is an immutable, opt-in snapshot created after a workout is
-- completed. It intentionally stores only publish-safe aggregate data rather
-- than the user's private workout notes or full local history.
CREATE TABLE IF NOT EXISTS friend_workout_posts (
  id TEXT PRIMARY KEY,
  owner_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source_workout_id TEXT NOT NULL,
  name TEXT NOT NULL,
  started_at TEXT,
  completed_at TEXT NOT NULL,
  duration_seconds INTEGER CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
  volume_kg REAL CHECK (volume_kg IS NULL OR volume_kg >= 0),
  effective_sets INTEGER CHECK (effective_sets IS NULL OR effective_sets >= 0),
  completion_rate REAL CHECK (completion_rate IS NULL OR (completion_rate >= 0 AND completion_rate <= 1)),
  exercises_json TEXT NOT NULL DEFAULT '[]',
  caption TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(owner_user_id, source_workout_id)
);
CREATE INDEX IF NOT EXISTS idx_friend_workout_posts_owner
  ON friend_workout_posts(owner_user_id, completed_at DESC);

CREATE TABLE IF NOT EXISTS friend_workout_post_likes (
  post_id TEXT NOT NULL REFERENCES friend_workout_posts(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  PRIMARY KEY (post_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_friend_workout_post_likes_post
  ON friend_workout_post_likes(post_id, created_at DESC);

CREATE TABLE IF NOT EXISTS friend_workout_post_comments (
  id TEXT PRIMARY KEY,
  post_id TEXT NOT NULL REFERENCES friend_workout_posts(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_friend_workout_post_comments_post
  ON friend_workout_post_comments(post_id, created_at ASC);

-- Food-photo recognition is separate from exercise/video recognition. The
-- image rows support streamed multi-image uploads, while result_json stores
-- only the validated candidate response returned by the configured vision
-- provider. No local fallback numbers are written when the provider is absent.
CREATE TABLE IF NOT EXISTS nutrition_recognition_jobs (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('created', 'uploading', 'ready', 'processing', 'completed', 'insufficient_image', 'failed', 'cancelled')),
  result_json TEXT,
  error_code TEXT,
  model_version TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  completed_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_nutrition_recognition_jobs_user
  ON nutrition_recognition_jobs(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS nutrition_recognition_images (
  id TEXT PRIMARY KEY,
  job_id TEXT NOT NULL REFERENCES nutrition_recognition_jobs(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK (position >= 0),
  storage_key TEXT NOT NULL DEFAULT '',
  content_type TEXT NOT NULL DEFAULT 'application/octet-stream',
  byte_size INTEGER NOT NULL DEFAULT 0 CHECK (byte_size >= 0),
  created_at TEXT NOT NULL,
  uploaded_at TEXT,
  UNIQUE(job_id, position)
);
CREATE INDEX IF NOT EXISTS idx_nutrition_recognition_images_job
  ON nutrition_recognition_images(job_id, position);

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
  include_overlay INTEGER NOT NULL DEFAULT 0,
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

CREATE TABLE IF NOT EXISTS recognition_artifacts (
  job_id TEXT NOT NULL REFERENCES recognition_jobs(id) ON DELETE CASCADE,
  artifact_id TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('evidence')),
  storage_key TEXT NOT NULL,
  content_type TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (job_id, artifact_id)
);

CREATE INDEX IF NOT EXISTS idx_recognition_artifacts_job
  ON recognition_artifacts(job_id, created_at);

CREATE TABLE IF NOT EXISTS push_tokens (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  token_hash TEXT NOT NULL,
  token TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (user_id, token_hash)
);

CREATE TABLE IF NOT EXISTS audit_log (
  id TEXT PRIMARY KEY,
  actor_user_id TEXT REFERENCES users(id),
  action TEXT NOT NULL,
  target TEXT NOT NULL,
  detail_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL
);
