import { SignJWT, importPKCS8, decodeJwt } from 'jose';

// Re-authorize Apple accounts at deletion time; never store the authorization code.
export async function revokeAppleAuthorization(cfg, code, expectedSubject, request = fetch) {
  if (!cfg.appleTeamId || !cfg.appleKeyId || !cfg.applePrivateKey || !cfg.appleClientId) {
    throw Object.assign(new Error('apple_revocation_not_configured'), { status: 503 });
  }
  const key = await importPKCS8(cfg.applePrivateKey.replace(/\\n/g, '\n'), 'ES256');
  const secret = await new SignJWT({}).setProtectedHeader({ alg: 'ES256', kid: cfg.appleKeyId })
    .setIssuer(cfg.appleTeamId).setSubject(cfg.appleClientId)
    .setAudience('https://appleid.apple.com').setIssuedAt().setExpirationTime('5m').sign(key);
  const exchange = await request('https://appleid.apple.com/auth/token', {
    method: 'POST', signal: AbortSignal.timeout(15000),
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ client_id: cfg.appleClientId, client_secret: secret, code, grant_type: 'authorization_code' }),
  });
  const tokens = await exchange.json();
  if (!exchange.ok || !tokens.refresh_token) throw Object.assign(new Error('apple_reauthorization_required'), { status: 422 });
  if (!tokens.id_token || decodeJwt(tokens.id_token).sub !== expectedSubject) {
    throw Object.assign(new Error('apple_account_mismatch'), { status: 403 });
  }
  const response = await request('https://appleid.apple.com/auth/revoke', {
    method: 'POST', signal: AbortSignal.timeout(15000),
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ client_id: cfg.appleClientId, client_secret: secret, token: tokens.refresh_token, token_type_hint: 'refresh_token' }),
  });
  if (!response.ok) throw Object.assign(new Error('apple_revocation_failed'), { status: 502 });
}

export async function deleteAccountData(ctx, user) {
  const { db, storage } = ctx;
  const keys = new Set([user.avatar_key]);
  for (const row of db.prepare('SELECT input_key, overlay_key, preview_key FROM recognition_jobs WHERE user_id = ?').all(user.id)) {
    keys.add(row.input_key); keys.add(row.overlay_key); keys.add(row.preview_key);
  }
  for (const row of db.prepare('SELECT a.storage_key FROM recognition_artifacts a JOIN recognition_jobs j ON j.id=a.job_id WHERE j.user_id=?').all(user.id)) keys.add(row.storage_key);
  for (const row of db.prepare('SELECT i.storage_key FROM nutrition_recognition_images i JOIN nutrition_recognition_jobs j ON j.id=i.job_id WHERE j.user_id=?').all(user.id)) keys.add(row.storage_key);
  // Remove owned media before returning success. Missing files are idempotent.
  for (const key of keys) if (key) await storage.remove(key);
  db.transaction(() => {
    db.prepare('DELETE FROM audit_log WHERE actor_user_id = ? OR target = ?').run(user.id, user.id);
    db.prepare('DELETE FROM redemption_codes WHERE created_by = ? OR used_by = ?').run(user.id, user.id);
    db.prepare('DELETE FROM sms_challenges WHERE normalized_phone = ?').run(user.identifier);
    db.prepare("DELETE FROM sms_rate_events WHERE scope='phone' AND scope_value=?").run(user.identifier);
    db.prepare("DELETE FROM password_login_failures WHERE scope='identifier' AND scope_value=?").run(user.identifier);
    // All owned records, sessions, identities and social references cascade.
    db.prepare('DELETE FROM users WHERE id = ?').run(user.id);
  })();
}
