import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

import { buildAcs3Request, buildAliyunSmsVerifyCodeRequest } from '../src/sms.mjs';
import { loadConfig, assertProductionConfiguration } from '../src/config.mjs';
import { startServer } from '../src/server.mjs';

const TEST_GPU_KEY = 'phone-test-gpu-key-12345678901234567890';
const TEST_SESSION_PEPPER = 'phone-test-session-pepper-12345678901234567890';
const TEST_SMS_PEPPER = 'phone-test-sms-pepper-12345678901234567890';

async function fixture({ sender, trustedProxyIps = '', passwordRegistration = false } = {}) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'kilo-phone-auth-'));
  const cfg = loadConfig({
    ...process.env,
    NODE_ENV: 'test',
    KILO_ENABLE_TEST_ADMIN: 'false',
    KILO_ENABLE_TEST_MEMBER: 'false',
    KILO_ENABLE_PASSWORD_REGISTRATION: passwordRegistration ? 'true' : 'false',
    KILO_GPU_API_KEY: TEST_GPU_KEY,
    KILO_SESSION_PEPPER: TEST_SESSION_PEPPER,
    KILO_SMS_OTP_PEPPER: TEST_SMS_PEPPER,
    KILO_TRUSTED_PROXY_IPS: trustedProxyIps,
    ALIYUN_ACCESS_KEY_ID: '',
    ALIYUN_ACCESS_KEY_SECRET: '',
    ALIYUN_SMS_SIGN_NAME: '',
    ALIYUN_SMS_TEMPLATE_CODE: '',
    ALIYUN_SMS_CODE_PARAM: 'code',
    KILO_DATA_DIR: root,
    KILO_DATABASE_PATH: path.join(root, 'kilo.sqlite3'),
    KILO_MEDIA_DIR: path.join(root, 'media'),
  });
  const server = await startServer({ config: cfg, port: 0, ...(sender ? { smsSender: sender } : {}) });
  const base = `http://127.0.0.1:${server.address().port}`;
  const call = async (pathname, body, options = {}) => {
    const headers = {
      ...(body !== undefined ? { 'content-type': 'application/json' } : {}),
      ...(options.headers || {}),
    };
    const response = await fetch(`${base}${pathname}`, {
      ...options,
      method: options.method || (body === undefined ? 'GET' : 'POST'),
      headers,
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    const text = await response.text();
    let parsed = null;
    try { parsed = text ? JSON.parse(text) : null; } catch { parsed = text; }
    return { response, body: parsed };
  };
  return {
    cfg,
    server,
    db: server.context.db,
    call,
    async close() {
      await server.closeGracefully();
      await fs.rm(root, { recursive: true, force: true });
    },
  };
}

test('PNVS ACS3 builder matches the documented V3 signature vector', () => {
  const request = buildAcs3Request({
    host: 'ecs.cn-shanghai.aliyuncs.com',
    accessKeyId: 'YourAccessKeyId',
    accessKeySecret: 'YourAccessKeySecret',
    action: 'RunInstances',
    version: '2014-05-26',
    method: 'POST',
    canonicalUri: '/',
    query: {
      ImageId: 'win2019_1809_x64_dtc_zh-cn_40G_alibase_20230811.vhd',
      RegionId: 'cn-shanghai',
    },
    body: '',
    date: '2023-10-26T10:22:32Z',
    nonce: '3156853299f313e23d1673dc12e1703d',
  });
  assert.equal(request.signature, '06563a9e1b43f5dfe96b81484da74bceab24a1d853912eee15083a6f0f3283c0');
  assert.equal(request.options.hostname, 'ecs.cn-shanghai.aliyuncs.com');
  assert.equal(request.options.path, '/?ImageId=win2019_1809_x64_dtc_zh-cn_40G_alibase_20230811.vhd&RegionId=cn-shanghai');
});

test('PNVS request uses the fixed domestic verification-code parameters', () => {
  const request = buildAliyunSmsVerifyCodeRequest({
    phone: '+8613812345678',
    config: {
      aliyunAccessKeyId: 'test-ak',
      aliyunAccessKeySecret: 'test-sk',
      aliyunSmsSignName: '恒创联众',
      aliyunSmsTemplateCode: '100001',
      aliyunSmsCodeParam: 'code',
    },
    now: new Date('2026-01-02T03:04:05.000Z'),
    nonce: 'fixed-test-nonce',
  });
  const query = new URLSearchParams(request.canonicalQuery);
  assert.equal(request.options.hostname, 'dypnsapi.aliyuncs.com');
  assert.equal(request.options.path.startsWith('/?'), true);
  assert.equal(query.get('PhoneNumber'), '13812345678');
  assert.equal(query.get('CountryCode'), '86');
  assert.equal(query.get('SignName'), '恒创联众');
  assert.equal(query.get('TemplateCode'), '100001');
  assert.deepEqual(JSON.parse(query.get('TemplateParam')), { code: '##code##', min: '5' });
  assert.equal(query.get('CodeLength'), '6');
  assert.equal(query.get('CodeType'), '1');
  assert.equal(query.get('ValidTime'), '300');
  assert.equal(query.get('Interval'), '60');
  assert.equal(query.get('DuplicatePolicy'), '1');
  assert.equal(query.get('AutoRetry'), '0');
  assert.equal(query.get('ReturnVerifyCode'), 'true');
  assert.equal(query.get('Action'), null);
});

test('phone registration normalizes 11-digit/+86 forms and returns a session', async () => {
  const sent = [];
  const app = await fixture({ sender: async (request) => {
    sent.push(request);
    return { sent: true, verifyCode: '123456' };
  } });
  try {
    const requested = await app.call('/v1/auth/phone/request', { identifier: '13812345678', purpose: 'register' });
    assert.equal(requested.response.status, 200);
    assert.deepEqual({
      sent: requested.body.sent,
      retryAfterSeconds: requested.body.retryAfterSeconds,
      expiresInSeconds: requested.body.expiresInSeconds,
    }, { sent: true, retryAfterSeconds: 60, expiresInSeconds: 300 });
    assert.match(requested.body.challengeId, /^sms_/u);
    assert.equal(sent[0].phone, '+8613812345678');
    assert.equal(sent[0].purpose, 'register');

    const registered = await app.call('/v1/auth/phone/register', {
      identifier: '+8613812345678',
      password: 'password8',
      code: '123456',
    });
    assert.equal(registered.response.status, 201);
    assert.equal(registered.body.user.identifier, '+8613812345678');
    assert.ok(registered.body.session.token);
    const identity = app.db.prepare("SELECT normalized_value, verified_at, source FROM user_identities WHERE kind = 'phone'").get();
    assert.equal(identity.normalized_value, '+8613812345678');
    assert.ok(identity.verified_at);
    assert.equal(identity.source, 'user');
    const challenge = app.db.prepare('SELECT code_hash, attempts, delivery_status, consumed_at FROM sms_challenges').get();
    assert.match(challenge.code_hash, /^[a-f0-9]{64}$/u);
    assert.equal(challenge.delivery_status, 'sent');
    assert.equal(challenge.attempts, 1);
    assert.ok(challenge.consumed_at);
  } finally {
    await app.close();
  }
});

test('OTP purpose isolation and one-time consumption hold across replays', async () => {
  let nextCode = '246810';
  const app = await fixture({ sender: async () => ({ sent: true, verifyCode: nextCode }) });
  try {
    const requested = await app.call('/v1/auth/phone/request', { identifier: '13912345678', purpose: 'register' });
    assert.equal(requested.response.status, 200);
    const wrongPurpose = await app.call('/v1/auth/phone/verify', { identifier: '13912345678', code: nextCode });
    assert.equal(wrongPurpose.response.status, 401);
    assert.equal(wrongPurpose.body.error, 'invalid_sms_code');
    assert.equal(app.db.prepare('SELECT attempts FROM sms_challenges WHERE id = ?').get(requested.body.challengeId).attempts, 0);

    const registered = await app.call('/v1/auth/phone/register', {
      identifier: '13912345678', password: 'password8', code: nextCode,
    });
    assert.equal(registered.response.status, 201);
    const replay = await app.call('/v1/auth/phone/register', {
      identifier: '13912345678', password: 'password8', code: nextCode,
    });
    assert.equal(replay.response.status, 401);
    assert.equal(replay.body.error, 'invalid_sms_code');

    // Move the durable request events outside all windows before asking for
    // the login-purpose code; this does not disable or bypass rate limiting.
    app.db.prepare('UPDATE sms_rate_events SET created_at = ?').run(Date.now() - 25 * 60 * 60 * 1000);
    nextCode = '135790';
    const loginRequest = await app.call('/v1/auth/phone/request', { identifier: '+8613912345678', purpose: 'login' });
    assert.equal(loginRequest.response.status, 200);
    const login = await app.call('/v1/auth/phone/verify', { identifier: '13912345678', code: nextCode });
    assert.equal(login.response.status, 200);
    assert.equal(login.body.user.id, registered.body.user.id);
    const loginReplay = await app.call('/v1/auth/phone/verify', { identifier: '13912345678', code: nextCode });
    assert.equal(loginReplay.response.status, 401);
  } finally {
    await app.close();
  }
});

test('concurrent verification consumes one challenge at most once', async () => {
  const app = await fixture({ sender: async () => ({ sent: true, verifyCode: '313131' }) });
  try {
    await app.call('/v1/auth/phone/request', { identifier: '13712345678', purpose: 'register' });
    const results = await Promise.all([
      app.call('/v1/auth/phone/register', { identifier: '13712345678', password: 'password8', code: '313131' }),
      app.call('/v1/auth/phone/register', { identifier: '13712345678', password: 'password8', code: '313131' }),
    ]);
    assert.deepEqual(results.map((item) => item.response.status).sort((a, b) => a - b), [201, 401]);
    assert.equal(app.db.prepare('SELECT COUNT(*) AS count FROM users').get().count, 1);
    assert.equal(app.db.prepare('SELECT COUNT(*) AS count FROM sessions').get().count, 1);
    assert.equal(app.db.prepare('SELECT attempts, consumed_at FROM sms_challenges').get().attempts, 1);
  } finally {
    await app.close();
  }
});

test('resending replaces the previous challenge and only the new code works', async () => {
  let code = '111111';
  const app = await fixture({ sender: async () => ({ sent: true, verifyCode: code }) });
  try {
    const first = await app.call('/v1/auth/phone/request', { identifier: '13612345678', purpose: 'register' });
    code = '222222';
    app.db.prepare('UPDATE sms_rate_events SET created_at = ?').run(Date.now() - 25 * 60 * 60 * 1000);
    const second = await app.call('/v1/auth/phone/request', { identifier: '+8613612345678', purpose: 'register' });
    assert.equal(second.response.status, 200);
    assert.equal(app.db.prepare("SELECT delivery_status FROM sms_challenges WHERE id = ?").get(first.body.challengeId).delivery_status, 'replaced');
    const oldCode = await app.call('/v1/auth/phone/register', { identifier: '13612345678', password: 'password8', code: '111111' });
    assert.equal(oldCode.response.status, 401);
    const newCode = await app.call('/v1/auth/phone/register', { identifier: '13612345678', password: 'password8', code: '222222' });
    assert.equal(newCode.response.status, 201);
  } finally {
    await app.close();
  }
});

test('wrong SMS guesses persist attempts, then lock and consume the challenge', async () => {
  const app = await fixture({ sender: async () => ({ sent: true, verifyCode: '654321' }) });
  try {
    const requested = await app.call('/v1/auth/phone/request', { identifier: '15012345678', purpose: 'register' });
    for (let attempt = 1; attempt <= 4; attempt += 1) {
      const wrong = await app.call('/v1/auth/phone/register', {
        identifier: '15012345678', password: 'password8', code: '000000',
      });
      assert.equal(wrong.response.status, 401);
      assert.equal(wrong.body.error, 'invalid_sms_code');
      assert.equal(app.db.prepare('SELECT attempts FROM sms_challenges WHERE id = ?').get(requested.body.challengeId).attempts, attempt);
    }
    const fifth = await app.call('/v1/auth/phone/register', {
      identifier: '15012345678', password: 'password8', code: '000000',
    });
    assert.equal(fifth.response.status, 429);
    assert.equal(fifth.body.error, 'sms_code_attempts_exceeded');
    const locked = app.db.prepare('SELECT attempts, consumed_at FROM sms_challenges WHERE id = ?').get(requested.body.challengeId);
    assert.equal(locked.attempts, 5);
    assert.ok(locked.consumed_at);
    const correct = await app.call('/v1/auth/phone/register', {
      identifier: '15012345678', password: 'password8', code: '654321',
    });
    assert.equal(correct.response.status, 401);
  } finally {
    await app.close();
  }
});

test('expired codes are consumed and cannot be replayed', async () => {
  const app = await fixture({ sender: async () => ({ sent: true, verifyCode: '111222' }) });
  try {
    const requested = await app.call('/v1/auth/phone/request', { identifier: '15112345678', purpose: 'register' });
    app.db.prepare('UPDATE sms_challenges SET expires_at = ? WHERE id = ?')
      .run(new Date(Date.now() - 1_000).toISOString(), requested.body.challengeId);
    const expired = await app.call('/v1/auth/phone/register', {
      identifier: '15112345678', password: 'password8', code: '111222',
    });
    assert.equal(expired.response.status, 401);
    assert.equal(expired.body.error, 'sms_code_expired');
    assert.ok(app.db.prepare('SELECT consumed_at FROM sms_challenges WHERE id = ?').get(requested.body.challengeId).consumed_at);
    const replay = await app.call('/v1/auth/phone/register', {
      identifier: '15112345678', password: 'password8', code: '111222',
    });
    assert.equal(replay.response.status, 401);
    assert.equal(replay.body.error, 'invalid_sms_code');
  } finally {
    await app.close();
  }
});

test('failed delivery is fail-closed and never marks a challenge sent', async () => {
  const app = await fixture({ sender: async () => { throw new Error('provider diagnostic must stay private'); } });
  try {
    const failed = await app.call('/v1/auth/phone/request', { identifier: '15212345678', purpose: 'register' });
    assert.equal(failed.response.status, 502);
    assert.equal(failed.body.error, 'sms_send_failed');
    assert.equal(JSON.stringify(failed.body).includes('provider diagnostic'), false);
    const challenge = app.db.prepare('SELECT delivery_status, consumed_at, code_hash FROM sms_challenges').get();
    assert.equal(challenge.delivery_status, 'failed');
    assert.ok(challenge.consumed_at);
    assert.match(challenge.code_hash, /^[a-f0-9]{64}$/u);
    const verify = await app.call('/v1/auth/phone/register', {
      identifier: '15212345678', password: 'password8', code: '123456',
    });
    assert.equal(verify.response.status, 401);
  } finally {
    await app.close();
  }
});

test('phone/IP request limits are durable and do not trust spoofed X-Forwarded-For', async () => {
  const app = await fixture({ sender: async () => ({ sent: true, verifyCode: '123456' }) });
  try {
    for (let index = 0; index < 5; index += 1) {
      const phone = `13${String(index + 1).padStart(1, '0')}12345678`;
      const requested = await app.call('/v1/auth/phone/request', { identifier: phone, purpose: 'register' }, {
        headers: { 'x-forwarded-for': `198.51.100.${index + 1}` },
      });
      assert.equal(requested.response.status, 200);
    }
    const blocked = await app.call('/v1/auth/phone/request', { identifier: '13612345678', purpose: 'register' }, {
      headers: { 'x-forwarded-for': '203.0.113.99' },
    });
    assert.equal(blocked.response.status, 429);
    assert.equal(blocked.body.error, 'sms_rate_limited');
    assert.ok(Number(blocked.body.detail.retryAfterSeconds) >= 1);
    assert.equal(app.db.prepare('SELECT COUNT(*) AS count FROM sms_rate_events').get().count, 10);
  } finally {
    await app.close();
  }
});

test('explicit trusted proxy may supply one valid X-Real-IP, while invalid values fall back to peer', async () => {
  const app = await fixture({ sender: async () => ({ sent: true, verifyCode: '123456' }), trustedProxyIps: '127.0.0.1,::1' });
  try {
    for (let index = 0; index < 5; index += 1) {
      const phone = `14${String(index + 1)}12345678`;
      const requested = await app.call('/v1/auth/phone/request', { identifier: phone, purpose: 'register' }, {
        headers: { 'x-real-ip': `10.0.0.${index + 1}` },
      });
      assert.equal(requested.response.status, 200);
    }
    // The six requests have distinct trusted client IPs, so the shared peer
    // bucket remains below its limit and this request is accepted.
    const accepted = await app.call('/v1/auth/phone/request', { identifier: '14612345678', purpose: 'register' }, {
      headers: { 'x-real-ip': '10.0.0.6' },
    });
    assert.equal(accepted.response.status, 200);
    // A comma-separated or malformed X-Real-IP is not accepted as a client
    // address. Five such requests fill the shared peer bucket, regardless of
    // their spoofed values; the sixth is rejected.
    for (let index = 0; index < 5; index += 1) {
      const phone = `15${index + 1}12345678`;
      const invalidForwarded = await app.call('/v1/auth/phone/request', { identifier: phone, purpose: 'register' }, {
        headers: { 'x-real-ip': `10.0.1.${index + 1}, 10.0.1.99` },
      });
      assert.equal(invalidForwarded.response.status, 200);
    }
    const blockedInvalidForwarded = await app.call('/v1/auth/phone/request', { identifier: '15612345678', purpose: 'register' }, {
      headers: { 'x-real-ip': '10.0.1.6, 10.0.1.99' },
    });
    assert.equal(blockedInvalidForwarded.response.status, 429);
  } finally {
    await app.close();
  }
});

test('password login keeps short seeded compatibility and rate-limits failed guesses', async () => {
  const app = await fixture({ passwordRegistration: true });
  try {
    const created = await app.call('/v1/auth/register', { identifier: 'password-user', password: 'short' });
    assert.equal(created.response.status, 201);
    const withSpaces = await app.call('/v1/auth/phone/login', { identifier: 'password-user', password: ' short ' });
    assert.equal(withSpaces.response.status, 401);
    for (let index = 0; index < 4; index += 1) {
      const wrong = await app.call('/v1/auth/phone/login', { identifier: 'password-user', password: `wrong-${index}` });
      assert.equal(wrong.response.status, 401);
    }
    const limited = await app.call('/v1/auth/phone/login', { identifier: 'password-user', password: 'wrong-final' });
    assert.equal(limited.response.status, 429);
    assert.equal(limited.body.error, 'login_rate_limited');
    const tooLong = await app.call('/v1/auth/phone/login', { identifier: 'password-user', password: 'x'.repeat(257) });
    assert.equal(tooLong.response.status, 400);
  } finally {
    await app.close();
  }
});

test('legacy phone identifier can be SMS-verified without binding an arbitrary profile alias', async () => {
  const app = await fixture({
    passwordRegistration: true,
    sender: async () => ({ sent: true, verifyCode: '222333' }),
  });
  try {
    const legacy = await app.call('/v1/auth/register', { identifier: '13876543210', password: 'legacy-pass' });
    assert.equal(legacy.response.status, 201);
    app.db.prepare('UPDATE sms_rate_events SET created_at = ?').run(Date.now() - 25 * 60 * 60 * 1000);
    const requested = await app.call('/v1/auth/phone/request', { identifier: '+8613876543210', purpose: 'login' });
    assert.equal(requested.response.status, 200);
    const verified = await app.call('/v1/auth/phone/verify', { identifier: '13876543210', code: '222333' });
    assert.equal(verified.response.status, 200);
    assert.equal(verified.body.user.id, legacy.body.user.id);
    assert.ok(app.db.prepare("SELECT verified_at FROM user_identities WHERE user_id = ? AND kind = 'phone'").get(legacy.body.user.id).verified_at);

    // A phone alias owned by another legacy account must not be used to
    // silently attach a newly verified phone to that account.
    const alias = await app.call('/v1/auth/register', { identifier: 'alias-owner', password: 'legacy-pass' });
    assert.equal(alias.response.status, 201);
    app.db.prepare(`INSERT INTO user_identities
      (id, user_id, kind, normalized_value, display_value, source, verified_at, searchable, created_at, updated_at)
      VALUES (?, ?, 'phone', ?, ?, 'account', NULL, 1, ?, ?)`)
      .run('unverified-phone-alias', alias.body.user.id, '+8613812345678', '+8613812345678', new Date().toISOString(), new Date().toISOString());
    const beforeUsers = app.db.prepare('SELECT COUNT(*) AS count FROM users').get().count;
    app.db.prepare('UPDATE sms_rate_events SET created_at = ?').run(Date.now() - 25 * 60 * 60 * 1000);
    const registerRequest = await app.call('/v1/auth/phone/request', { identifier: '13812345678', purpose: 'register' });
    assert.equal(registerRequest.response.status, 200);
    const duplicate = await app.call('/v1/auth/phone/register', { identifier: '13812345678', password: 'password8', code: '222333' });
    assert.equal(duplicate.response.status, 409);
    assert.equal(duplicate.body.error, 'identifier_taken');
    assert.equal(app.db.prepare('SELECT COUNT(*) AS count FROM users').get().count, beforeUsers);
  } finally {
    await app.close();
  }
});

test('unconfigured production SMS remains optional, while unsafe password registration is rejected', () => {
  assert.doesNotThrow(() => assertProductionConfiguration({
    nodeEnv: 'production',
    sessionPepper: 'a'.repeat(40),
    gpuApiKey: 'b'.repeat(40),
    enableTestAdmin: false,
    enableTestMember: false,
    enablePasswordRegistration: false,
  }, { NODE_ENV: 'production' }));
  assert.throws(() => assertProductionConfiguration({
    nodeEnv: 'production',
    sessionPepper: 'a'.repeat(40),
    gpuApiKey: 'b'.repeat(40),
    enableTestAdmin: false,
    enableTestMember: false,
    enablePasswordRegistration: true,
  }, { NODE_ENV: 'production' }), /unsafe_production_configuration/);
});

test('phone endpoints reject non-China identifiers before reserving an SMS request', async () => {
  const app = await fixture({ sender: async () => ({ sent: true, verifyCode: '123456' }) });
  try {
    for (const pathname of ['/v1/auth/phone/request', '/v1/auth/phone/register', '/v1/auth/phone/verify']) {
      const body = pathname.endsWith('/request')
        ? { identifier: '+14155552671', purpose: 'register' }
        : { identifier: '+14155552671', password: 'password8', code: '123456' };
      const result = await app.call(pathname, body);
      assert.equal(result.response.status, 400);
      assert.equal(result.body.error, 'invalid_phone_identifier');
    }
    assert.equal(app.db.prepare('SELECT COUNT(*) AS count FROM sms_challenges').get().count, 0);
    assert.equal(app.db.prepare('SELECT COUNT(*) AS count FROM sms_rate_events').get().count, 0);
  } finally {
    await app.close();
  }
});

test('request without injected sender fails closed when PNVS env is absent', async () => {
  const app = await fixture();
  try {
    const response = await app.call('/v1/auth/phone/request', { identifier: '13812345678', purpose: 'register' });
    assert.equal(response.response.status, 503);
    assert.equal(response.body.error, 'provider_not_configured');
    assert.equal(response.body.detail.provider, 'sms');
    assert.equal(app.db.prepare('SELECT COUNT(*) AS count FROM sms_challenges').get().count, 0);
  } finally {
    await app.close();
  }
});
