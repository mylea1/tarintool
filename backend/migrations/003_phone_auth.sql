-- SMS challenges never store the clear-text verification code.  The code hash
-- is keyed with the server-only SMS pepper and each challenge is single-use.
CREATE TABLE IF NOT EXISTS sms_challenges (
  id TEXT PRIMARY KEY,
  normalized_phone TEXT NOT NULL,
  purpose TEXT NOT NULL CHECK (purpose IN ('register', 'login')),
  code_hash TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0 AND attempts <= 5),
  delivery_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (delivery_status IN ('pending', 'sent', 'failed', 'replaced')),
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  consumed_at TEXT,
  request_ip TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sms_challenges_lookup
  ON sms_challenges(normalized_phone, purpose, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sms_challenges_expiry
  ON sms_challenges(expires_at, delivery_status);

-- Request events make phone/IP throttles durable across process restarts.  The
-- server prunes events older than the longest configured window on each write.
CREATE TABLE IF NOT EXISTS sms_rate_events (
  id TEXT PRIMARY KEY,
  scope TEXT NOT NULL CHECK (scope IN ('phone', 'ip')),
  scope_value TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sms_rate_events_lookup
  ON sms_rate_events(scope, scope_value, created_at);

-- Password failures use a separate event stream so a password attack cannot
-- consume the SMS request budget and vice versa.
CREATE TABLE IF NOT EXISTS password_login_failures (
  id TEXT PRIMARY KEY,
  scope TEXT NOT NULL CHECK (scope IN ('identifier', 'ip')),
  scope_value TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_password_login_failures_lookup
  ON password_login_failures(scope, scope_value, created_at);
