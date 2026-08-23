import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { createServer as createHttpServer } from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { isAcademicKnowledgeSource, parseAiSkills, startServer } from '../src/server.mjs';
import { assertProductionConfiguration } from '../src/config.mjs';
import { loadConfig } from '../src/config.mjs';

let root;
let server;
let base;
let adminToken;
let memberToken;
let userToken;
let user2Token;

async function api(pathname, options = {}) {
  const headers = { ...(options.body !== undefined ? { 'content-type': 'application/json' } : {}), ...(options.headers || {}) };
  const response = await fetch(`${base}${pathname}`, { ...options, headers });
  const text = await response.text();
  let body = null; try { body = text ? JSON.parse(text) : null; } catch { body = text; }
  return { response, body };
}

test.before(async () => {
  root = await fs.mkdtemp(path.join(os.tmpdir(), 'kilo-backend-'));
  const cfg = loadConfig({ ...process.env, NODE_ENV: 'test', KILO_ENABLE_TEST_ADMIN: 'true', KILO_ENABLE_TEST_MEMBER: 'true', KILO_ENABLE_PASSWORD_REGISTRATION: 'true', KILO_GPU_API_KEY: 'gpu-test-key-123456789012345678901234', KILO_SESSION_PEPPER: 'session-test-pepper-12345678901234567890', KILO_DATA_DIR: root, KILO_DATABASE_PATH: path.join(root, 'kilo.sqlite3'), KILO_MEDIA_DIR: path.join(root, 'media'), KILO_ALLOWED_ORIGINS: 'http://allowed.test' });
  server = await startServer({ config: cfg, port: 0 });
  base = `http://127.0.0.1:${server.address().port}`;
  const admin = await api('/v1/auth/phone/login', { method: 'POST', body: JSON.stringify({ identifier: '1234', password: '1234' }) });
  const member = await api('/v1/auth/phone/login', { method: 'POST', body: JSON.stringify({ identifier: '123', password: '123' }) });
  assert.equal(member.response.status, 200);
  assert.equal(member.body.user.role, 'user');
  memberToken = member.body.session.token;
  assert.equal(admin.response.status, 200); adminToken = admin.body.session.token;
  const first = await api('/v1/auth/register', { method: 'POST', body: JSON.stringify({ identifier: 'first-user', password: 'abcd' }) });
  assert.equal(first.response.status, 201); userToken = first.body.session.token;
  const second = await api('/v1/auth/register', { method: 'POST', body: JSON.stringify({ identifier: 'second-user', password: 'abcd' }) });
  assert.equal(second.response.status, 201); user2Token = second.body.session.token;
});

test.after(async () => { await server.closeGracefully(); await fs.rm(root, { recursive: true, force: true }); });

test('visible citations exclude internal, GitHub and Bilibili sources only', () => {
  assert.equal(isAcademicKnowledgeSource({ source: 'https://github.com/example/method', tags_json: '["training"]' }), false);
  assert.equal(isAcademicKnowledgeSource({ source: 'https://www.bilibili.com/video/BV1x', tags_json: '[]' }), false);
  assert.equal(isAcademicKnowledgeSource({ source: 'https://pubmed.ncbi.nlm.nih.gov/12345/', tags_json: '[]' }), true);
  assert.equal(isAcademicKnowledgeSource({ source: 'https://www.who.int/news-room/fact-sheets/detail/physical-activity', tags_json: '[]' }), true);
  assert.equal(isAcademicKnowledgeSource({ source: 'internal', tags_json: '["论文"]' }), false);
});

test('custom AI skills are trimmed, validated and capped at three', () => {
  const result = parseAiSkills([
    { name: ' Skill 1 ', instructions: ' Rule 1 ' },
    { name: 'Skill 2', instructions: 'Rule 2' },
    { name: 'Skill 3', instructions: 'Rule 3' },
    { name: 'Skill 4', instructions: 'Rule 4' },
  ]);
  assert.equal(result.length, 3);
  assert.deepEqual(result[0], { name: 'Skill 1', instructions: 'Rule 1' });
  assert.deepEqual(parseAiSkills([{ name: '', instructions: 'x' }]), []);
});

test('expanded knowledge retrieval reaches public evidence behind repository notes', async () => {
  for (let index = 0; index < 6; index += 1) {
    const internal = await api('/v1/admin/knowledge', {
      method: 'POST',
      headers: { authorization: `Bearer ${adminToken}` },
      body: JSON.stringify({
        title: `组间休息内部方法 ${index}`,
        source: `https://github.com/example/rest-${index}`,
        content: '力量训练组间休息时间安排方法。',
      }),
    });
    assert.equal(internal.response.status, 201);
  }
  const paper = await api('/v1/admin/knowledge', {
    method: 'POST',
    headers: { authorization: `Bearer ${adminToken}` },
    body: JSON.stringify({
      title: '组间休息系统综述',
      source: 'https://pubmed.ncbi.nlm.nih.gov/39205815/',
      content: '力量训练组间休息时间安排的系统综述。',
    }),
  });
  assert.equal(paper.response.status, 201);
  const search = await api(`/v1/knowledge/search?q=${encodeURIComponent('组间休息时间安排')}&limit=20`, {
    headers: { authorization: `Bearer ${adminToken}` },
  });
  assert.equal(search.response.status, 200);
  assert.equal(
    search.body.results.filter(isAcademicKnowledgeSource).some((item) => item.id === paper.body.id),
    true,
  );
});

test('health, auth and admin role boundaries', async () => {
  assert.equal((await api('/health')).body.ok, true);
  const capabilities = await api('/v1/analysis/capabilities');
  assert.equal(capabilities.response.status, 200);
  assert.equal(capabilities.body.exercises.some((item) => item.exerciseId === 'barbell_squat'), true);
  assert.equal(capabilities.body.exercises.some((item) => item.exerciseId === 'lat_pulldown'), true);
  assert.equal(capabilities.body.exercises.some((item) => item.exerciseId === 'bench_press'), true);
  assert.ok(capabilities.body.exercises.length >= 15);
  assert.equal(capabilities.body.exercises.find((item) => item.exerciseId === 'bench_press').group, '胸部');
  const adminEntitlements = await api('/v1/me/entitlements', { headers: { authorization: `Bearer ${adminToken}` } });
  assert.equal(adminEntitlements.body.membership, 'forever'); assert.equal(adminEntitlements.body.membershipExpiresAt, null); assert.ok(adminEntitlements.body.aiRemaining >= 20); assert.ok(adminEntitlements.body.recognitionRemaining >= 3); assert.ok(adminEntitlements.body.recognitionWeeklyGrant >= 3);
  const memberEntitlements = await api('/v1/me/entitlements', { headers: { authorization: `Bearer ${memberToken}` } });
  assert.equal(memberEntitlements.body.membership, 'forever'); assert.equal(memberEntitlements.body.membershipExpiresAt, null); assert.ok(memberEntitlements.body.aiRemaining >= 20); assert.ok(memberEntitlements.body.recognitionWeeklyGrant >= 3);
  const unauth = await api('/v1/me/entitlements'); assert.equal(unauth.response.status, 401);
  const forbidden = await api('/v1/admin/redemption-codes', { method: 'POST', headers: { authorization: `Bearer ${userToken}` }, body: JSON.stringify({ plan: 'oneMonth' }) });
  assert.equal(forbidden.response.status, 403);
  const code = await api('/v1/admin/redemption-codes', { method: 'POST', headers: { authorization: `Bearer ${adminToken}` }, body: JSON.stringify({ plan: 'oneMonth' }) });
  assert.equal(code.response.status, 201); assert.match(code.body.code, /^KILO-/);
});

test('knowledge search falls back to Chinese substring matching', async () => {
  const created = await api('/v1/admin/knowledge', {
    method: 'POST',
    headers: { authorization: `Bearer ${adminToken}` },
    body: JSON.stringify({
      title: '深蹲组间休息',
      source: 'test-fixture',
      content: '深蹲正式组之间通常需要较充分的组间休息，并根据训练目标和主观恢复调整。',
      tags: ['深蹲', '恢复'],
    }),
  });
  assert.equal(created.response.status, 201);
  const result = await api(`/v1/knowledge/search?q=${encodeURIComponent('如何安排深蹲组间休息')}`, {
    headers: { authorization: `Bearer ${userToken}` },
  });
  assert.equal(result.response.status, 200);
  assert.equal(result.body.results.some((item) => item.id === created.body.id), true);
});

test('redemption is atomic and cannot be reused', async () => {
  const generated = await api('/v1/admin/redemption-codes', { method: 'POST', headers: { authorization: `Bearer ${adminToken}` }, body: JSON.stringify({ plan: 'threeMonths' }) });
  const redeemed = await api('/v1/redemptions/redeem', { method: 'POST', headers: { authorization: `Bearer ${userToken}` }, body: JSON.stringify({ code: generated.body.code }) });
  assert.equal(redeemed.response.status, 200); assert.equal(redeemed.body.entitlement.membership, 'threeMonths');
  const reused = await api('/v1/redemptions/redeem', { method: 'POST', headers: { authorization: `Bearer ${user2Token}` }, body: JSON.stringify({ code: generated.body.code }) });
  assert.equal(reused.response.status, 409); assert.equal(reused.body.error, 'code_already_used');
});

test('quota reserve commit rollback and idempotency', async () => {
  const before = (await api('/v1/me/entitlements', { headers: { authorization: `Bearer ${user2Token}` } })).body;
  const reserved = await api('/v1/usage/consume', { method: 'POST', headers: { authorization: `Bearer ${user2Token}` }, body: JSON.stringify({ kind: 'ai', requestId: 'test-ai-1' }) });
  assert.equal(reserved.response.status, 200); assert.equal(reserved.body.aiRemaining, before.aiRemaining - 1);
  const again = await api('/v1/usage/consume', { method: 'POST', headers: { authorization: `Bearer ${user2Token}` }, body: JSON.stringify({ kind: 'ai', requestId: 'test-ai-1' }) });
  assert.equal(again.body.idempotent, true); assert.equal(again.body.aiRemaining, before.aiRemaining - 1);
  const rolledBack = await api('/v1/usage/consume', { method: 'POST', headers: { authorization: `Bearer ${user2Token}` }, body: JSON.stringify({ kind: 'ai', requestId: 'test-ai-1', action: 'rollback' }) });
  assert.equal(rolledBack.body.aiRemaining, before.aiRemaining);
});

test('membership products are public but orders and verification are protected', async () => {
  const products = await api('/v1/membership/products');
  assert.equal(products.response.status, 200);
  assert.deepEqual(
    products.body.products.map((item) => item.productId),
    [
      'com.kilostrength.pro.monthly',
      'com.kilostrength.pro.yearly',
    ],
  );
  assert.equal((await api('/v1/membership/orders')).response.status, 401);
  const orders = await api('/v1/membership/orders', {
    headers: { authorization: `Bearer ${userToken}` },
  });
  assert.equal(orders.response.status, 200);
  assert.deepEqual(orders.body.orders, []);
  const unverified = await api('/v1/membership/apple/verify', {
    method: 'POST',
    headers: { authorization: `Bearer ${userToken}` },
    body: JSON.stringify({
      productId: 'com.kilostrength.pro.monthly',
      verificationData: 'not-a-receipt',
    }),
  });
  assert.equal(unverified.response.status, 503);
  assert.equal(unverified.body.error, 'apple_iap_not_configured');
});

test('membership orders are server-owned, idempotent and cancellable only while pending', async () => {
  const first = await api('/v1/membership/orders', {
    method: 'POST',
    headers: { authorization: `Bearer ${user2Token}` },
    body: JSON.stringify({
      productId: 'com.kilostrength.pro.monthly',
      provider: 'app_store',
      amountMinor: 1800,
      currency: 'CNY',
    }),
  });
  assert.equal(first.response.status, 201);
  assert.equal(first.body.order.status, 'pending');
  assert.equal(first.body.order.plan, 'oneMonth');
  assert.equal(first.body.reused, false);

  const repeated = await api('/v1/membership/orders', {
    method: 'POST',
    headers: { authorization: `Bearer ${user2Token}` },
    body: JSON.stringify({ productId: 'com.kilostrength.pro.monthly', provider: 'app_store' }),
  });
  assert.equal(repeated.response.status, 200);
  assert.equal(repeated.body.reused, true);
  assert.equal(repeated.body.order.id, first.body.order.id);

  const yearly = await api('/v1/membership/orders', {
    method: 'POST',
    headers: { authorization: `Bearer ${user2Token}` },
    body: JSON.stringify({ productId: 'com.kilostrength.pro.yearly', provider: 'app_store' }),
  });
  assert.equal(yearly.response.status, 201);
  assert.equal(yearly.body.order.plan, 'yearly');

  const otherUser = await api(`/v1/membership/orders/${encodeURIComponent(first.body.order.id)}/cancel`, {
    method: 'POST',
    headers: { authorization: `Bearer ${userToken}` },
    body: '{}',
  });
  assert.equal(otherUser.response.status, 404);

  const cancelled = await api(`/v1/membership/orders/${encodeURIComponent(first.body.order.id)}/cancel`, {
    method: 'POST',
    headers: { authorization: `Bearer ${user2Token}` },
    body: '{}',
  });
  assert.equal(cancelled.response.status, 200);
  assert.equal(cancelled.body.order.status, 'cancelled');

  const repeatedCancel = await api(`/v1/membership/orders/${encodeURIComponent(first.body.order.id)}/cancel`, {
    method: 'POST',
    headers: { authorization: `Bearer ${user2Token}` },
    body: '{}',
  });
  assert.equal(repeatedCancel.response.status, 409);
  assert.equal(repeatedCancel.body.error, 'membership_order_not_cancellable');
});

test('daily check-in is once per Shanghai day and rewards after seven distinct days', async () => {
  const isolated = await fs.mkdtemp(path.join(os.tmpdir(), 'kilo-checkin-'));
  const cfg = loadConfig({
    ...process.env,
    NODE_ENV: 'test',
    KILO_ENABLE_TEST_ADMIN: 'true',
    KILO_ENABLE_TEST_MEMBER: 'true',
    KILO_ENABLE_PASSWORD_REGISTRATION: 'true',
    KILO_GPU_API_KEY: 'checkin-gpu-key-123456789012345678901234',
    KILO_SESSION_PEPPER: 'checkin-session-pepper-12345678901234567890',
    KILO_DATA_DIR: isolated,
    KILO_DATABASE_PATH: path.join(isolated, 'kilo.sqlite3'),
    KILO_MEDIA_DIR: path.join(isolated, 'media'),
  });
  const isolatedServer = await startServer({ config: cfg, port: 0 });
  const isolatedBase = `http://127.0.0.1:${isolatedServer.address().port}`;
  const localApi = async (pathname, options = {}) => {
    const headers = { ...(options.body !== undefined ? { 'content-type': 'application/json' } : {}), ...(options.headers || {}) };
    const response = await fetch(`${isolatedBase}${pathname}`, { ...options, headers });
    const text = await response.text();
    return { response, body: text ? JSON.parse(text) : null };
  };
  try {
    const registration = await localApi('/v1/auth/register', {
      method: 'POST',
      body: JSON.stringify({ identifier: `checkin-${Date.now()}`, password: 'abcd' }),
    });
    assert.equal(registration.response.status, 201);
    const token = registration.body.session.token;
    const user = isolatedServer.context.db.prepare('SELECT id FROM users WHERE identifier = ?').get(registration.body.user.identifier);
    const now = new Date();
    const day = (offset) => {
      const value = new Date(now.getTime() - offset * 24 * 60 * 60 * 1000);
      return new Date(value.getTime() + 8 * 60 * 60 * 1000).toISOString().slice(0, 10);
    };
    const stamp = now.toISOString();
    const insert = isolatedServer.context.db.prepare('INSERT INTO daily_checkins (user_id, date_key, created_at) VALUES (?, ?, ?)');
    for (let offset = 1; offset <= 6; offset += 1) insert.run(user.id, day(offset), stamp);
    isolatedServer.context.db.prepare(`INSERT INTO checkin_state (user_id, round_days, total_days, reward_round, updated_at)
      VALUES (?, 6, 6, 0, ?)`)
      .run(user.id, stamp);

    const status = await localApi('/v1/checkin/status', { headers: { authorization: `Bearer ${token}` } });
    assert.equal(status.response.status, 200);
    assert.equal(status.body.roundDays, 6);
    assert.equal(status.body.todayCheckedIn, false);
    const checkin = await localApi('/v1/checkin', { method: 'POST', headers: { authorization: `Bearer ${token}` }, body: '{}' });
    assert.equal(checkin.response.status, 200);
    assert.equal(checkin.body.awarded, true);
    assert.equal(checkin.body.rewardDays, 15);
    assert.equal(checkin.body.roundDays, 0);
    assert.equal(checkin.body.entitlement.membership, 'oneMonth');
    const duplicate = await localApi('/v1/checkin', { method: 'POST', headers: { authorization: `Bearer ${token}` }, body: '{}' });
    assert.equal(duplicate.response.status, 200);
    assert.equal(duplicate.body.alreadyCheckedIn, true);
    assert.equal(duplicate.body.awarded, false);
  } finally {
    await isolatedServer.closeGracefully();
    await fs.rm(isolated, { recursive: true, force: true });
  }
});

test('administrator remains quota-exempt when recognition balance is zero', async () => {
  const admin = server.context.db.prepare("SELECT id FROM users WHERE identifier = '1234'").get();
  server.context.db.prepare('UPDATE entitlements SET recognition_remaining = 0 WHERE user_id = ?').run(admin.id);
  const created = await api('/v1/analysis/jobs', {
    method: 'POST',
    headers: { authorization: `Bearer ${adminToken}` },
    body: JSON.stringify({ exerciseId: 'barbell_squat', camera: 'side', includeOverlay: false }),
  });
  assert.equal(created.response.status, 202);
  assert.equal((await api('/v1/me/entitlements', { headers: { authorization: `Bearer ${adminToken}` } })).body.recognitionRemaining, 0);
  const issuedUpload = new URL(created.body.upload.url);
  const rejected = await fetch(new URL(`${issuedUpload.pathname}${issuedUpload.search}`, base), {
    method: 'PUT',
    headers: { 'content-type': 'text/plain' },
    body: 'invalid',
  });
  assert.equal(rejected.status, 415);
  assert.equal((await api('/v1/me/entitlements', { headers: { authorization: `Bearer ${adminToken}` } })).body.recognitionRemaining, 0);
});

test('sync is user-scoped and stale revisions conflict', async () => {
  const first = await api('/v1/sync/workout/w1', { method: 'PUT', headers: { authorization: `Bearer ${userToken}` }, body: JSON.stringify({ revision: 1, payload: { sets: 3 } }) });
  assert.equal(first.response.status, 200);
  const stale = await api('/v1/sync/workout/w1', { method: 'PUT', headers: { authorization: `Bearer ${userToken}` }, body: JSON.stringify({ revision: 1, payload: { sets: 4 } }) });
  assert.equal(stale.response.status, 409);
  const hidden = await api('/v1/sync/workout', { headers: { authorization: `Bearer ${user2Token}` } });
  assert.equal(hidden.body.entities.some((item) => item.entityId === 'w1'), false);
  const deleted = await api('/v1/sync/workout/w1?revision=1', { method: 'DELETE', headers: { authorization: `Bearer ${userToken}` } });
  assert.equal(deleted.response.status, 200); assert.equal(deleted.body.deleted, true);
});

test('AI missing configuration rolls quota back and does not persist a fake answer', async () => {
  const before = (await api('/v1/me/entitlements', { headers: { authorization: `Bearer ${user2Token}` } })).body.aiRemaining;
  const answer = await api('/v1/coach/answer', { method: 'POST', headers: { authorization: `Bearer ${user2Token}` }, body: JSON.stringify({ question: 'hello', requestId: 'missing-ai-1' }) });
  assert.equal(answer.response.status, 503); assert.equal(answer.body.error, 'deepseek_not_configured');
  const after = (await api('/v1/me/entitlements', { headers: { authorization: `Bearer ${user2Token}` } })).body.aiRemaining;
  assert.equal(after, before);
});

test('AI streaming uses the configured request timeout instead of aborting immediately', async () => {
  const upstream = createHttpServer((_req, res) => {
    res.writeHead(200, { 'content-type': 'text/event-stream; charset=utf-8' });
    res.write('data: {"choices":[{"delta":{"content":"流式"}}]}\n\n');
    setTimeout(() => {
      res.end('data: {"choices":[{"delta":{"content":"通路正常"}}]}\n\ndata: [DONE]\n\n');
    }, 25);
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  const isolatedRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'kilo-stream-'));
  const cfg = loadConfig({
    ...process.env,
    NODE_ENV: 'test',
    KILO_ENABLE_TEST_ADMIN: 'true',
    KILO_SESSION_PEPPER: 'stream-test-pepper-12345678901234567890',
    KILO_GPU_API_KEY: 'stream-gpu-key-123456789012345678901234',
    KILO_DATA_DIR: isolatedRoot,
    KILO_DATABASE_PATH: path.join(isolatedRoot, 'kilo.sqlite3'),
    KILO_MEDIA_DIR: path.join(isolatedRoot, 'media'),
    DEEPSEEK_API_KEY: 'stream-test-key',
    DEEPSEEK_BASE_URL: `http://127.0.0.1:${upstream.address().port}`,
    KILO_AI_REQUEST_TIMEOUT_SECONDS: '2',
  });
  const isolatedServer = await startServer({ config: cfg, port: 0 });
  const isolatedBase = `http://127.0.0.1:${isolatedServer.address().port}`;
  try {
    const login = await fetch(`${isolatedBase}/v1/auth/phone/login`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ identifier: '1234', password: '1234' }),
    });
    const token = (await login.json()).session.token;
    const response = await fetch(`${isolatedBase}/v1/coach/stream`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
      body: JSON.stringify({ question: '测试流式回答' }),
    });
    const stream = await response.text();
    assert.equal(response.status, 200);
    assert.match(stream, /event: delta/u);
    assert.match(stream, /流式/u);
    assert.match(stream, /通路正常/u);
    assert.match(stream, /event: done/u);
    assert.doesNotMatch(stream, /deepseek_timeout/u);
  } finally {
    await isolatedServer.closeGracefully();
    await new Promise((resolve) => upstream.close(resolve));
    await fs.rm(isolatedRoot, { recursive: true, force: true });
  }
});

test('AI agent continuation preserves tool message order, consent and one quota charge', async () => {
  const upstreamBodies = [];
  const upstream = createHttpServer(async (req, res) => {
    let text = '';
    for await (const chunk of req) text += chunk;
    upstreamBodies.push(JSON.parse(text));
    res.writeHead(200, { 'content-type': 'application/json' });
    if (upstreamBodies.length === 1) {
      res.end(JSON.stringify({
        choices: [{
          message: {
            content: null,
            tool_calls: [{
              id: 'call_read_plans',
              type: 'function',
              function: { name: 'read_training_plans', arguments: '{}' },
            }],
          },
        }],
      }));
      return;
    }
    res.end(JSON.stringify({ choices: [{ message: { content: '已读取你的训练计划。' } }] }));
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  const isolatedRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'kilo-agent-'));
  const cfg = loadConfig({
    ...process.env,
    NODE_ENV: 'test',
    KILO_ENABLE_TEST_ADMIN: 'false',
    KILO_ENABLE_TEST_MEMBER: 'true',
    KILO_ENABLE_PASSWORD_REGISTRATION: 'true',
    KILO_SESSION_PEPPER: 'agent-test-pepper-12345678901234567890',
    KILO_GPU_API_KEY: 'agent-gpu-key-123456789012345678901234',
    KILO_DATA_DIR: isolatedRoot,
    KILO_DATABASE_PATH: path.join(isolatedRoot, 'kilo.sqlite3'),
    KILO_MEDIA_DIR: path.join(isolatedRoot, 'media'),
    DEEPSEEK_API_KEY: 'agent-test-key',
    DEEPSEEK_BASE_URL: `http://127.0.0.1:${upstream.address().port}`,
    KILO_AI_REQUEST_TIMEOUT_SECONDS: '2',
  });
  const isolatedServer = await startServer({ config: cfg, port: 0 });
  const isolatedBase = `http://127.0.0.1:${isolatedServer.address().port}`;
  try {
    const login = await fetch(`${isolatedBase}/v1/auth/phone/login`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ identifier: '123', password: '123' }),
    });
    assert.equal(login.status, 200);
    const token = (await login.json()).session.token;
    const auth = { authorization: `Bearer ${token}` };
    const before = (await fetch(`${isolatedBase}/v1/me/entitlements`, { headers: auth })).json();
    const beforeQuota = (await before).aiRemaining;
    const availableTools = [{
      type: 'function',
      function: { name: 'read_training_plans' },
    }];
    const first = await fetch(`${isolatedBase}/v1/coach/answer`, {
      method: 'POST',
      headers: { ...auth, 'content-type': 'application/json' },
      body: JSON.stringify({
        question: '读取我的训练计划',
        requestId: 'agent-order-1',
        useTrainingData: true,
        availableTools,
      }),
    });
    const firstBody = await first.json();
    assert.equal(first.status, 200);
    assert.equal(firstBody.toolCalls[0].name, 'read_training_plans');
    const afterReserve = (await fetch(`${isolatedBase}/v1/me/entitlements`, { headers: auth })).json();
    assert.equal((await afterReserve).aiRemaining, beforeQuota - 1);

    const second = await fetch(`${isolatedBase}/v1/coach/answer`, {
      method: 'POST',
      headers: { ...auth, 'content-type': 'application/json' },
      body: JSON.stringify({
        question: '读取我的训练计划',
        requestId: 'agent-order-1',
        useTrainingData: true,
        toolResults: [{
          id: 'call_read_plans',
          name: 'read_training_plans',
          arguments: {},
          result: { tool: 'read_training_plans', plans: [], count: 0 },
        }],
      }),
    });
    const secondBody = await second.json();
    assert.equal(second.status, 200);
    assert.equal(secondBody.answer, '已读取你的训练计划。');
    const continuation = upstreamBodies[1].messages;
    const userIndex = continuation.findIndex((item) => item.role === 'user' && item.content === '读取我的训练计划');
    const assistantIndex = continuation.findIndex((item) => item.role === 'assistant' && Array.isArray(item.tool_calls));
    const toolIndex = continuation.findIndex((item) => item.role === 'tool' && item.tool_call_id === 'call_read_plans');
    assert.ok(userIndex >= 0 && userIndex < assistantIndex && assistantIndex < toolIndex);
    assert.deepEqual(
      continuation.slice(assistantIndex, toolIndex + 1).map((item) => item.role),
      ['assistant', 'tool'],
    );
    const afterCommit = (await fetch(`${isolatedBase}/v1/me/entitlements`, { headers: auth })).json();
    assert.equal((await afterCommit).aiRemaining, beforeQuota - 1);

    const consentOff = await fetch(`${isolatedBase}/v1/coach/answer`, {
      method: 'POST',
      headers: { ...auth, 'content-type': 'application/json' },
      body: JSON.stringify({
        question: '普通问题，不读取训练资料',
        requestId: 'agent-consent-off',
        useTrainingData: false,
        availableTools,
      }),
    });
    assert.equal(consentOff.status, 200);
    assert.equal(upstreamBodies[2].tools, undefined);

    const unknownTools = await fetch(`${isolatedBase}/v1/coach/answer`, {
      method: 'POST',
      headers: { ...auth, 'content-type': 'application/json' },
      body: JSON.stringify({
        question: '不应启用未知工具',
        requestId: 'agent-unknown-tool',
        useTrainingData: true,
        availableTools: [{ type: 'function', function: { name: 'delete_all_data' } }],
      }),
    });
    assert.equal(unknownTools.status, 400);
    assert.equal((await unknownTools.json()).error, 'invalid_ai_tools');
    const consentResults = await fetch(`${isolatedBase}/v1/coach/answer`, {
      method: 'POST',
      headers: { ...auth, 'content-type': 'application/json' },
      body: JSON.stringify({
        question: '未授权时不应读取训练资料',
        requestId: 'agent-consent-result-off',
        useTrainingData: false,
        toolResults: [{
          id: 'call_plans',
          name: 'read_training_plans',
          arguments: {},
          result: { tool: 'read_training_plans', plans: [], count: 0 },
        }],
      }),
    });
    assert.equal(consentResults.status, 400);
    assert.equal((await consentResults.json()).error, 'ai_tools_consent_required');
    const afterUnknown = (await fetch(`${isolatedBase}/v1/me/entitlements`, { headers: auth })).json();
    assert.equal((await afterUnknown).aiRemaining, beforeQuota - 2);
  } finally {
    await isolatedServer.closeGracefully();
    await new Promise((resolve) => upstream.close(resolve));
    await fs.rm(isolatedRoot, { recursive: true, force: true });
  }
});

test('AI agent follow-up failure rolls back its pending quota reservation', async () => {
  let callCount = 0;
  const upstream = createHttpServer(async (req, res) => {
    for await (const _chunk of req) { /* consume request */ }
    callCount += 1;
    if (callCount === 1) {
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify({
        choices: [{
          message: {
            content: null,
            tool_calls: [{
              id: 'call_history',
              type: 'function',
              function: { name: 'read_workout_history', arguments: '{}' },
            }],
          },
        }],
      }));
      return;
    }
    res.writeHead(500, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ error: 'upstream unavailable' }));
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  const isolatedRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'kilo-agent-failure-'));
  const cfg = loadConfig({
    ...process.env,
    NODE_ENV: 'test',
    KILO_ENABLE_TEST_ADMIN: 'false',
    KILO_ENABLE_TEST_MEMBER: 'true',
    KILO_SESSION_PEPPER: 'agent-failure-pepper-12345678901234567890',
    KILO_GPU_API_KEY: 'agent-failure-gpu-key-12345678901234567890',
    KILO_DATA_DIR: isolatedRoot,
    KILO_DATABASE_PATH: path.join(isolatedRoot, 'kilo.sqlite3'),
    KILO_MEDIA_DIR: path.join(isolatedRoot, 'media'),
    DEEPSEEK_API_KEY: 'agent-failure-key',
    DEEPSEEK_BASE_URL: `http://127.0.0.1:${upstream.address().port}`,
    KILO_AI_REQUEST_TIMEOUT_SECONDS: '2',
  });
  const isolatedServer = await startServer({ config: cfg, port: 0 });
  const isolatedBase = `http://127.0.0.1:${isolatedServer.address().port}`;
  try {
    const login = await fetch(`${isolatedBase}/v1/auth/phone/login`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ identifier: '123', password: '123' }),
    });
    assert.equal(login.status, 200);
    const token = (await login.json()).session.token;
    const auth = { authorization: `Bearer ${token}` };
    const before = (await fetch(`${isolatedBase}/v1/me/entitlements`, { headers: auth })).json();
    const beforeQuota = (await before).aiRemaining;
    const availableTools = [{
      type: 'function',
      function: { name: 'read_workout_history' },
    }];
    const first = await fetch(`${isolatedBase}/v1/coach/answer`, {
      method: 'POST',
      headers: { ...auth, 'content-type': 'application/json' },
      body: JSON.stringify({
        question: '读取我的训练记录',
        requestId: 'agent-failure-1',
        useTrainingData: true,
        availableTools,
      }),
    });
    assert.equal(first.status, 200);
    assert.equal((await first.json()).toolCalls[0].name, 'read_workout_history');
    const afterReserve = (await fetch(`${isolatedBase}/v1/me/entitlements`, { headers: auth })).json();
    assert.equal((await afterReserve).aiRemaining, beforeQuota - 1);

    const second = await fetch(`${isolatedBase}/v1/coach/answer`, {
      method: 'POST',
      headers: { ...auth, 'content-type': 'application/json' },
      body: JSON.stringify({
        question: '读取我的训练记录',
        requestId: 'agent-failure-1',
        useTrainingData: true,
        toolResults: [{
          id: 'call_history',
          name: 'read_workout_history',
          arguments: {},
          result: { tool: 'read_workout_history', records: [], count: 0 },
        }],
      }),
    });
    assert.equal(second.status, 502);
    const afterRollback = (await fetch(`${isolatedBase}/v1/me/entitlements`, { headers: auth })).json();
    assert.equal((await afterRollback).aiRemaining, beforeQuota);
  } finally {
    await isolatedServer.closeGracefully();
    await new Promise((resolve) => upstream.close(resolve));
    await fs.rm(isolatedRoot, { recursive: true, force: true });
  }
});

test('recognition upload, GPU protocol, media authorization and result', async () => {
  const created = await api('/v1/analysis/jobs', { method: 'POST', headers: { authorization: `Bearer ${user2Token}` }, body: JSON.stringify({ exerciseId: 'barbell_squat', camera: 'side', includeOverlay: false }) });
  assert.equal(created.body.includeOverlay, false);
  assert.equal(created.response.status, 202); const issuedUpload = new URL(created.body.upload.url); const upload = new URL(`${issuedUpload.pathname}${issuedUpload.search}`, base);
  const uploadResponse = await fetch(upload, { method: 'PUT', headers: { 'content-type': 'video/mp4', 'content-length': '4' }, body: Buffer.from('test') });
  assert.equal(uploadResponse.status, 200);
  const claim = await api('/v1/internal/gpu/jobs/claim', { method: 'POST', headers: { 'x-kilo-gpu-key': 'gpu-test-key-123456789012345678901234', 'content-type': 'application/json' }, body: '{}' });
  assert.equal(claim.response.status, 200); assert.equal(claim.body.job.id, created.body.id); assert.equal(claim.body.job.includeOverlay, false);
  const heartbeat = await api(`/v1/internal/gpu/jobs/${created.body.id}/heartbeat`, { method: 'POST', headers: { 'x-kilo-gpu-key': 'gpu-test-key-123456789012345678901234', 'content-type': 'application/json' }, body: '{}' });
  assert.equal(heartbeat.response.status, 200); assert.equal(heartbeat.body.status, 'processing');
  const input = await fetch(`${base}/v1/internal/gpu/jobs/${created.body.id}/input`, { headers: { 'x-kilo-gpu-key': 'gpu-test-key-123456789012345678901234' } }); assert.equal(input.status, 200); assert.equal(input.headers.get('content-type'), 'video/mp4'); assert.equal(await input.text(), 'test');
  const artifact = await api(`/v1/internal/gpu/jobs/${created.body.id}/artifact`, { method: 'POST', headers: { 'x-kilo-gpu-key': 'gpu-test-key-123456789012345678901234' }, body: JSON.stringify({ kind: 'preview', contentType: 'image/png', dataBase64: Buffer.from('png').toString('base64') }) }); assert.equal(artifact.response.status, 200);
  const evidenceArtifact = await fetch(`${base}/v1/internal/gpu/jobs/${created.body.id}/artifact`, { method: 'PUT', headers: { 'x-kilo-gpu-key': 'gpu-test-key-123456789012345678901234', 'x-artifact-kind': 'evidence', 'x-artifact-id': 'event-001', 'content-type': 'image/jpeg', 'content-length': '4' }, body: Buffer.from('jpeg') });
  assert.equal(evidenceArtifact.status, 200);
  const done = await api(`/v1/internal/gpu/jobs/${created.body.id}/result`, {
    method: 'POST',
    headers: { 'x-kilo-gpu-key': 'gpu-test-key-123456789012345678901234' },
    body: JSON.stringify({
      result: {
        status: 'complete',
        confidence: 0.9,
        summary: '在视频中的 1 个时间点发现需要注意的动作现象。',
        metrics: { completeMotionCycles: 1, durationSeconds: 12.4 },
        events: [{
          id: 'event-001',
          evidenceId: 'event-001',
          code: 'SQUAT_DEPTH_LIMITED',
          label: '下蹲深度可能不足',
          startMs: 11800,
          peakMs: 12400,
          endMs: 13000,
          displayTime: '00:12.4',
          explanation: '最低位置可见侧膝角约 126.0°，高于当前参考线。',
          measurements: { kneeAngleDeg: 126, referenceLimitDeg: 118 },
        }],
      },
      modelVersion: 'test-v2-time-evidence',
    }),
  });
  assert.equal(done.response.status, 200); assert.equal(done.body.status, 'completed');
  assert.equal(done.body.result.events[0].displayTime, '00:12.4');
  assert.match(done.body.result.events[0].evidenceImageUrl, /\/media\/evidence\/event-001$/);
  assert.equal('repetitions' in done.body.result, false);
  const ownerMedia = await fetch(`${base}/v1/analysis/jobs/${created.body.id}/media/preview`, { headers: { authorization: `Bearer ${user2Token}` } }); assert.equal(ownerMedia.status, 200); assert.equal(ownerMedia.headers.get('content-type'), 'image/png');
  const otherMedia = await fetch(`${base}/v1/analysis/jobs/${created.body.id}/media/preview`, { headers: { authorization: `Bearer ${userToken}` } }); assert.equal(otherMedia.status, 404);
  const ownerEvidence = await fetch(`${base}/v1/analysis/jobs/${created.body.id}/media/evidence/event-001`, { headers: { authorization: `Bearer ${user2Token}` } }); assert.equal(ownerEvidence.status, 200); assert.equal(ownerEvidence.headers.get('content-type'), 'image/jpeg'); assert.equal(await ownerEvidence.text(), 'jpeg');
  const otherEvidence = await fetch(`${base}/v1/analysis/jobs/${created.body.id}/media/evidence/event-001`, { headers: { authorization: `Bearer ${userToken}` } }); assert.equal(otherEvidence.status, 404);
});

test('recognition refuses to invent coaching feedback without a complete motion cycle', async () => {
  const created = await api('/v1/analysis/jobs', { method: 'POST', headers: { authorization: `Bearer ${adminToken}` }, body: JSON.stringify({ exerciseId: 'barbell_squat', camera: 'side', includeOverlay: false }) });
  assert.equal(created.response.status, 202);
  const issuedUpload = new URL(created.body.upload.url);
  const upload = new URL(`${issuedUpload.pathname}${issuedUpload.search}`, base);
  const uploadResponse = await fetch(upload, { method: 'PUT', headers: { 'content-type': 'video/mp4', 'content-length': '4' }, body: Buffer.from('test') });
  assert.equal(uploadResponse.status, 200);
  const claim = await api('/v1/internal/gpu/jobs/claim', { method: 'POST', headers: { 'x-kilo-gpu-key': 'gpu-test-key-123456789012345678901234', 'content-type': 'application/json' }, body: '{}' });
  assert.equal(claim.response.status, 200);
  const done = await api(`/v1/internal/gpu/jobs/${created.body.id}/result`, {
    method: 'POST',
    headers: { 'x-kilo-gpu-key': 'gpu-test-key-123456789012345678901234' },
    body: JSON.stringify({
      result: {
        status: 'complete',
        confidence: 0.0988,
        summary: '本次动作已经分析完成',
        metrics: { completeMotionCycles: 0, detectedFrames: 29, inferenceFrames: 29, detectionRate: 1, durationSeconds: 3.01 },
      },
      modelVersion: 'test-v1',
    }),
  });

  assert.equal(done.response.status, 200);
  assert.equal(done.body.result.assessment, 'insufficient_evidence');
  assert.deepEqual(done.body.result.aiReview.strengths, []);
  assert.deepEqual(done.body.result.aiReview.risks, []);
  assert.equal(done.body.result.aiReviewError, null);
  assert.match(done.body.result.summary, /不足以评价/);
});

test('recognition rejects unsafe or oversized uploads', async () => {
  const before = (await api('/v1/me/entitlements', { headers: { authorization: `Bearer ${user2Token}` } })).body.recognitionRemaining;
  const created = await api('/v1/analysis/jobs', { method: 'POST', headers: { authorization: `Bearer ${user2Token}` }, body: JSON.stringify({ exerciseId: 'barbell_squat', camera: 'side' }) });
  assert.equal(created.body.includeOverlay, false);
  const issuedUpload = new URL(created.body.upload.url); const upload = new URL(`${issuedUpload.pathname}${issuedUpload.search}`, base); const badType = await fetch(upload, { method: 'PUT', headers: { 'content-type': 'text/plain' }, body: 'x' }); assert.equal(badType.status, 415);
  const after = (await api('/v1/me/entitlements', { headers: { authorization: `Bearer ${user2Token}` } })).body.recognitionRemaining; assert.equal(after, before);
});

test('upload token expires after fifteen minutes and rolls back quota', async () => {
  const before = (await api('/v1/me/entitlements', { headers: { authorization: `Bearer ${user2Token}` } })).body.recognitionRemaining;
  const created = await api('/v1/analysis/jobs', { method: 'POST', headers: { authorization: `Bearer ${user2Token}` }, body: JSON.stringify({ exerciseId: 'hip_thrust', camera: 'side' }) });
  const issuedUpload = new URL(created.body.upload.url); const upload = new URL(`${issuedUpload.pathname}${issuedUpload.search}`, base);
  server.context.db.prepare('UPDATE recognition_jobs SET upload_expires_at = ? WHERE id = ?').run(new Date(Date.now() - 1000).toISOString(), created.body.id);
  const expired = await fetch(upload, { method: 'PUT', headers: { 'content-type': 'video/mp4' }, body: Buffer.from('expired') });
  assert.equal(expired.status, 410); assert.equal((await api(`/v1/analysis/jobs/${created.body.id}`, { headers: { authorization: `Bearer ${user2Token}` } })).body.status, 'expired');
  const after = (await api('/v1/me/entitlements', { headers: { authorization: `Bearer ${user2Token}` } })).body.recognitionRemaining;
  assert.equal(after, before);
});

test('stream artifact accepts payload above JSON limit and preserves media type', async () => {
  const created = await api('/v1/analysis/jobs', { method: 'POST', headers: { authorization: `Bearer ${user2Token}` }, body: JSON.stringify({ exerciseId: 'lat_pulldown', camera: 'rear' }) });
  const issuedUpload = new URL(created.body.upload.url); const upload = new URL(`${issuedUpload.pathname}${issuedUpload.search}`, base);
  const uploadResponse = await fetch(upload, { method: 'PUT', headers: { 'content-type': 'video/mp4' }, body: Buffer.from('input') }); assert.equal(uploadResponse.status, 200);
  const claim = await api('/v1/internal/gpu/jobs/claim', { method: 'POST', headers: { 'x-kilo-gpu-key': 'gpu-test-key-123456789012345678901234', 'content-type': 'application/json' }, body: '{}' }); assert.equal(claim.response.status, 200);
  const large = Buffer.alloc(2 * 1024 * 1024 + 128, 0x61); // larger than KILO_MAX_JSON_BYTES, below upload cap
  const artifact = await fetch(`${base}/v1/internal/gpu/jobs/${created.body.id}/artifact`, { method: 'PUT', headers: { 'x-kilo-gpu-key': 'gpu-test-key-123456789012345678901234', 'x-artifact-kind': 'overlay', 'content-type': 'video/mp4', 'content-length': String(large.length) }, body: large });
  assert.equal(artifact.status, 200);
  const media = await fetch(`${base}/v1/analysis/jobs/${created.body.id}/media/overlay`, { headers: { authorization: `Bearer ${user2Token}` } }); assert.equal(media.status, 200); assert.equal(media.headers.get('content-type'), 'video/mp4'); assert.equal(Number(media.headers.get('content-length')), large.length);
});

test('logout revokes a session; registration can be disabled; production rejects unsafe flags', async () => {
  const login = await api('/v1/auth/phone/login', { method: 'POST', body: JSON.stringify({ identifier: 'second-user', password: 'abcd' }) }); assert.equal(login.response.status, 200);
  const loggedOut = await api('/v1/auth/logout', { method: 'POST', headers: { authorization: `Bearer ${login.body.session.token}` }, body: '{}' }); assert.equal(loggedOut.response.status, 200);
  assert.equal((await api('/v1/me/entitlements', { headers: { authorization: `Bearer ${login.body.session.token}` } })).response.status, 401);
  assert.throws(() => assertProductionConfiguration({ nodeEnv: 'production', sessionPepper: 'short', gpuApiKey: 'short', enableTestAdmin: true, enablePasswordRegistration: true }, { NODE_ENV: 'production' }), /unsafe_production_configuration/);
  const isolated = await fs.mkdtemp(path.join(os.tmpdir(), 'kilo-register-disabled-')); const cfg = loadConfig({ ...process.env, NODE_ENV: 'test', KILO_ENABLE_TEST_ADMIN: 'false', KILO_ENABLE_PASSWORD_REGISTRATION: 'false', KILO_DATA_DIR: isolated, KILO_DATABASE_PATH: path.join(isolated, 'kilo.sqlite3'), KILO_MEDIA_DIR: path.join(isolated, 'media') }); const disabledServer = await startServer({ config: cfg, port: 0 }); const disabledBase = `http://127.0.0.1:${disabledServer.address().port}`; const disabled = await fetch(`${disabledBase}/v1/auth/register`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ identifier: 'blocked', password: 'abcd' }) }); assert.equal(disabled.status, 404); await disabledServer.closeGracefully(); await fs.rm(isolated, { recursive: true, force: true });
});

test('conversation reads remain isolated across users', async () => {
  const created = await api('/v1/ai/conversations', { method: 'POST', headers: { authorization: `Bearer ${user2Token}` }, body: JSON.stringify({ title: 'private' }) }); assert.equal(created.response.status, 201);
  const denied = await api(`/v1/ai/conversations/${created.body.id}`, { headers: { authorization: `Bearer ${userToken}` } }); assert.equal(denied.response.status, 404);
});

test('TestFlight operator credentials never gain server admin rights', async () => {
  const isolated = await fs.mkdtemp(path.join(os.tmpdir(), 'kilo-testflight-users-'));
  const cfg = loadConfig({
    ...process.env,
    NODE_ENV: 'test',
    KILO_ENABLE_TEST_ADMIN: 'false',
    KILO_ENABLE_TEST_MEMBER: 'true',
    KILO_GPU_API_KEY: 'gpu-test-key-123456789012345678901234',
    KILO_SESSION_PEPPER: 'session-test-pepper-12345678901234567890',
    KILO_DATA_DIR: isolated,
    KILO_DATABASE_PATH: path.join(isolated, 'kilo.sqlite3'),
    KILO_MEDIA_DIR: path.join(isolated, 'media'),
  });
  const isolatedServer = await startServer({ config: cfg, port: 0 });
  const isolatedBase = `http://127.0.0.1:${isolatedServer.address().port}`;
  try {
    const login = await fetch(`${isolatedBase}/v1/auth/phone/login`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ identifier: '1234', password: '1234' }),
    });
    const payload = await login.json();
    assert.equal(login.status, 200);
    assert.equal(payload.user.role, 'user');
    const adminCall = await fetch(`${isolatedBase}/v1/admin/redemption-codes`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${payload.session.token}`,
      },
      body: JSON.stringify({ plan: 'oneMonth' }),
    });
    assert.equal(adminCall.status, 403);
  } finally {
    await isolatedServer.closeGracefully();
    await fs.rm(isolated, { recursive: true, force: true });
  }
});
