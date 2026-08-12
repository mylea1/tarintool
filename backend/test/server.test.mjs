import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { isAcademicKnowledgeSource, startServer } from '../src/server.mjs';
import { assertProductionConfiguration } from '../src/config.mjs';
import { loadConfig } from '../src/config.mjs';

let root;
let server;
let base;
let adminToken;
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
  const done = await api(`/v1/internal/gpu/jobs/${created.body.id}/result`, { method: 'POST', headers: { 'x-kilo-gpu-key': 'gpu-test-key-123456789012345678901234' }, body: JSON.stringify({ result: { status: 'complete', confidence: 0.9, repetitions: 8, summary: 'ok' }, modelVersion: 'test-v1' }) }); assert.equal(done.response.status, 200); assert.equal(done.body.status, 'completed');
  const ownerMedia = await fetch(`${base}/v1/analysis/jobs/${created.body.id}/media/preview`, { headers: { authorization: `Bearer ${user2Token}` } }); assert.equal(ownerMedia.status, 200); assert.equal(ownerMedia.headers.get('content-type'), 'image/png');
  const otherMedia = await fetch(`${base}/v1/analysis/jobs/${created.body.id}/media/preview`, { headers: { authorization: `Bearer ${userToken}` } }); assert.equal(otherMedia.status, 404);
});

test('recognition rejects unsafe or oversized uploads', async () => {
  const before = (await api('/v1/me/entitlements', { headers: { authorization: `Bearer ${user2Token}` } })).body.recognitionRemaining;
  const created = await api('/v1/analysis/jobs', { method: 'POST', headers: { authorization: `Bearer ${user2Token}` }, body: JSON.stringify({ exerciseId: 'barbell_squat', camera: 'side' }) });
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
