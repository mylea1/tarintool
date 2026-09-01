import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import fs from 'node:fs/promises';
import { createServer as createHttpServer } from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { isAcademicKnowledgeSource, parseAiSkills, recognitionEvidenceAssessment, startServer } from '../src/server.mjs';
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
  const admin = await api('/v1/auth/phone/login', { method: 'POST', body: JSON.stringify({ identifier: '13023097571', password: '1234' }) });
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
  assert.equal(capabilities.body.exercises.some((item) => item.exerciseId === 'leg_press'), true);
  assert.equal(capabilities.body.exercises.some((item) => item.exerciseId === 'prone_y_raise'), true);
  assert.equal(capabilities.body.exercises.length, 66);
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
  const legacyAdmin = await api('/v1/auth/phone/login', { method: 'POST', body: JSON.stringify({ identifier: '1234', password: '1234' }) });
  assert.equal(legacyAdmin.response.status, 401);
  const seededFriends = await api('/v1/friends', { headers: { authorization: `Bearer ${adminToken}` } });
  assert.equal(seededFriends.response.status, 200);
  assert.ok(seededFriends.body.friends.length >= 3);
  const seededFeed = await api('/v1/friends/feed', { headers: { authorization: `Bearer ${adminToken}` } });
  assert.ok(seededFeed.body.plans.some((item) => item.name === '上肢力量进阶'));
});

test('admin can create a phone account and optionally grant membership', async () => {
  const forbidden = await api('/v1/admin/users', {
    method: 'POST',
    headers: { authorization: `Bearer ${userToken}` },
    body: JSON.stringify({ identifier: '17880160001', password: '1234' }),
  });
  assert.equal(forbidden.response.status, 403);
  const invalid = await api('/v1/admin/users', {
    method: 'POST',
    headers: { authorization: `Bearer ${adminToken}` },
    body: JSON.stringify({ identifier: 'not-a-phone', password: '1234' }),
  });
  assert.equal(invalid.response.status, 400);
  assert.equal(invalid.body.error, 'invalid_phone_identifier');
  const created = await api('/v1/admin/users', {
    method: 'POST',
    headers: { authorization: `Bearer ${adminToken}` },
    body: JSON.stringify({
      identifier: '17880160001',
      password: '1234',
      displayName: '会员测试用户',
      membershipPlan: 'oneMonth',
    }),
  });
  assert.equal(created.response.status, 201);
  assert.equal(created.body.user.identifier, '17880160001');
  assert.equal(created.body.user.role, 'user');
  assert.equal(created.body.entitlement.membership, 'oneMonth');
  const duplicate = await api('/v1/admin/users', {
    method: 'POST',
    headers: { authorization: `Bearer ${adminToken}` },
    body: JSON.stringify({ identifier: '17880160001', password: '1234' }),
  });
  assert.equal(duplicate.response.status, 409);
  assert.equal(duplicate.body.error, 'identifier_taken');
  const login = await api('/v1/auth/phone/login', {
    method: 'POST',
    body: JSON.stringify({ identifier: '17880160001', password: '1234' }),
  });
  assert.equal(login.response.status, 200);
});

test('friends can accept requests, react and copy only explicitly shared plan snapshots', async () => {
  const request = await api('/v1/friends/requests', {
    method: 'POST',
    headers: { authorization: `Bearer ${userToken}` },
    body: JSON.stringify({ identifier: 'second-user' }),
  });
  assert.equal(request.response.status, 201);
  const pending = await api('/v1/friends', { headers: { authorization: `Bearer ${user2Token}` } });
  assert.equal(pending.response.status, 200);
  assert.equal(pending.body.pending.length, 1);
  const accepted = await api(`/v1/friends/requests/${request.body.request.id}/accept`, {
    method: 'POST', headers: { authorization: `Bearer ${user2Token}` },
  });
  assert.equal(accepted.response.status, 200);
  const shared = await api('/v1/friends/plans', {
    method: 'POST',
    headers: { authorization: `Bearer ${userToken}` },
    body: JSON.stringify({
      sourcePlanId: 'routine-chest-a',
      name: '胸部力量 A',
      plan: { exercises: [{ exerciseId: 'bench_press', restSeconds: 120, sets: [{ type: 'work', weight: 80, reps: 8, restSeconds: 120 }] }] },
    }),
  });
  assert.equal(shared.response.status, 201);
  const feed = await api('/v1/friends/feed', { headers: { authorization: `Bearer ${user2Token}` } });
  assert.equal(feed.response.status, 200);
  assert.equal(feed.body.plans.length, 1);
  assert.equal(feed.body.plans[0].plan.exercises[0].exerciseId, 'bench_press');
  assert.equal('note' in feed.body.plans[0].plan, false);
  const reaction = await api(`/v1/friends/plans/${shared.body.share.id}/reactions`, {
    method: 'POST', headers: { authorization: `Bearer ${user2Token}` }, body: JSON.stringify({ emoji: '🔥' }),
  });
  assert.equal(reaction.response.status, 200);
  assert.equal(reaction.body.reactionCount, 1);
});

test('friend identity search is cross-platform, masked and supports stable user IDs', async () => {
  const username = await api('/v1/me/username', {
    method: 'PUT',
    headers: { authorization: `Bearer ${userToken}` },
    body: JSON.stringify({ username: 'Lifting_小林' }),
  });
  assert.equal(username.response.status, 200);
  assert.equal(username.body.identity.value, 'Lifting_小林');

  const identities = await api('/v1/me/identities', {
    headers: { authorization: `Bearer ${userToken}` },
  });
  assert.equal(identities.response.status, 200);
  assert.equal(identities.body.identities.some((item) => item.kind === 'username'), true);
  assert.equal(identities.body.identities.some((item) => item.normalizedValue), false);

  const usernameSearch = await api('/v1/friends/search', {
    method: 'POST',
    headers: { authorization: `Bearer ${user2Token}` },
    body: JSON.stringify({ query: 'lifting_' }),
  });
  assert.equal(usernameSearch.response.status, 200);
  assert.equal(usernameSearch.body.results[0].username, 'Lifting_小林');
  assert.equal(usernameSearch.body.results[0].relationshipStatus, 'friends');
  assert.equal('identifier' in usernameSearch.body.results[0], false);

  const phoneSearch = await api('/v1/friends/search', {
    method: 'POST',
    headers: { authorization: `Bearer ${userToken}` },
    body: JSON.stringify({ query: '17880160001' }),
  });
  assert.equal(phoneSearch.response.status, 200);
  assert.equal(phoneSearch.body.results.length, 1);
  assert.equal(phoneSearch.body.results[0].matchType, 'phone');
  assert.match(phoneSearch.body.results[0].maskedMatch, /^\+86 178\*{4}0001$/);
  assert.equal('normalized_value' in phoneSearch.body.results[0], false);

  const request = await api('/v1/friends/requests', {
    method: 'POST',
    headers: { authorization: `Bearer ${userToken}` },
    body: JSON.stringify({ targetUserId: phoneSearch.body.results[0].id }),
  });
  assert.equal(request.response.status, 201);

  const ambiguous = await api('/v1/friends/requests', {
    method: 'POST',
    headers: { authorization: `Bearer ${userToken}` },
    body: JSON.stringify({ targetUserId: phoneSearch.body.results[0].id, identifier: '17880160001' }),
  });
  assert.equal(ambiguous.response.status, 400);
  assert.equal(ambiguous.body.error, 'ambiguous_friend_target');

  const taken = await api('/v1/me/username', {
    method: 'PUT',
    headers: { authorization: `Bearer ${user2Token}` },
    body: JSON.stringify({ username: 'lifting_小林' }),
  });
  assert.equal(taken.response.status, 409);
  assert.equal(taken.body.error, 'username_taken');
});

test('completed workout posts are friend-visible, immutable, and emoji-only interactive', async () => {
  const sourceWorkoutId = `workout-post-${Date.now()}`;
  const created = await api('/v1/friends/workouts', {
    method: 'POST',
    headers: { authorization: `Bearer ${userToken}` },
    body: JSON.stringify({
      sourceWorkoutId,
      workoutName: '周三上肢训练',
      startedAt: '2026-08-31T10:00:00.000Z',
      completedAt: '2026-08-31T11:03:00.000Z',
      durationSeconds: 3780,
      volumeKg: 1240.5,
      effectiveSets: 12,
      completionPercent: 100,
      exerciseSummary: [
        { exerciseId: 'bench_press', name: '卧推', sets: [{ reps: 8 }, { reps: 7 }] },
        { exerciseId: 'row', name: '划船', setCount: 3 },
      ],
      caption: '今天完成了计划',
      cardStyle: 'forest',
      cardImageKey: 'exercise',
    }),
  });
  assert.equal(created.response.status, 201);
  assert.equal(created.body.post.type, 'workout');
  assert.equal(created.body.post.effectiveSets, 12);
  assert.equal(created.body.post.exercises[0].sets, 2);
  assert.equal(created.body.post.likeCount, 0);
  assert.equal(created.body.post.cardStyle, 'forest');
  assert.equal(created.body.post.cardImageKey, 'exercise');

  const duplicate = await api('/v1/friends/workouts', {
    method: 'POST',
    headers: { authorization: `Bearer ${userToken}` },
    body: JSON.stringify({ sourceWorkoutId, name: '修改后的名称', completedAt: '2026-08-31T11:03:00.000Z' }),
  });
  assert.equal(duplicate.response.status, 409);
  assert.equal(duplicate.body.error, 'workout_already_published');

  const feed = await api('/v1/friends/feed', { headers: { authorization: `Bearer ${user2Token}` } });
  assert.equal(feed.response.status, 200);
  const visible = feed.body.workouts.find((item) => item.id === created.body.post.id);
  assert.equal(visible.name, '周三上肢训练');
  assert.equal(visible.cardStyle, 'forest');
  assert.equal(visible.cardImageKey, 'exercise');
  assert.equal('ownerIdentifier' in visible, false);

  const invalidAppearance = await api('/v1/friends/workouts', {
    method: 'POST',
    headers: { authorization: `Bearer ${userToken}` },
    body: JSON.stringify({
      sourceWorkoutId: `${sourceWorkoutId}-invalid`,
      workoutName: '无效卡片',
      completedAt: '2026-08-31T12:00:00.000Z',
      cardStyle: 'custom-css',
      cardImageKey: 'file:///private/photo.jpg',
    }),
  });
  assert.equal(invalidAppearance.response.status, 400);
  assert.equal(invalidAppearance.body.error, 'invalid_workout_card_style');

  const hiddenFromUnrelated = await api(`/v1/friends/workouts/${created.body.post.id}`, { headers: { authorization: `Bearer ${adminToken}` } });
  assert.equal(hiddenFromUnrelated.response.status, 404);

  const like = await api(`/v1/friends/workouts/${created.body.post.id}/likes`, {
    method: 'POST', headers: { authorization: `Bearer ${user2Token}` },
  });
  assert.equal(like.response.status, 200);
  assert.equal(like.body.liked, true);
  assert.equal(like.body.likeCount, 1);
  const duplicateLike = await api(`/v1/friends/workouts/${created.body.post.id}/likes`, {
    method: 'POST', headers: { authorization: `Bearer ${user2Token}` },
  });
  assert.equal(duplicateLike.body.likeCount, 1);
  const unlike = await api(`/v1/friends/workouts/${created.body.post.id}/likes`, {
    method: 'DELETE', headers: { authorization: `Bearer ${user2Token}` },
  });
  assert.equal(unlike.body.liked, false);
  assert.equal(unlike.body.likeCount, 0);
  const toggleOn = await api(`/v1/friends/workouts/${created.body.post.id}/like`, {
    method: 'POST', headers: { authorization: `Bearer ${user2Token}` }, body: '{}',
  });
  assert.equal(toggleOn.body.liked, true);
  const toggleOff = await api(`/v1/friends/workouts/${created.body.post.id}/like`, {
    method: 'POST', headers: { authorization: `Bearer ${user2Token}` }, body: '{}',
  });
  assert.equal(toggleOff.body.liked, false);

  const comment = await api(`/v1/friends/workouts/${created.body.post.id}/comments`, {
    method: 'POST', headers: { authorization: `Bearer ${user2Token}` }, body: JSON.stringify({ emoji: '🔥' }),
  });
  assert.equal(comment.response.status, 201);
  assert.equal(comment.body.comment.emoji, '🔥');
  const textComment = await api(`/v1/friends/workouts/${created.body.post.id}/comments`, {
    method: 'POST', headers: { authorization: `Bearer ${user2Token}` }, body: JSON.stringify({ emoji: '👏', text: '太棒了' }),
  });
  assert.equal(textComment.response.status, 400);
  assert.equal(textComment.body.error, 'emoji_only_comment');
  const comments = await api(`/v1/friends/workouts/${created.body.post.id}/comments`, { headers: { authorization: `Bearer ${user2Token}` } });
  assert.deepEqual(comments.body.comments.map((item) => item.emoji), ['🔥']);

  const deleted = await api(`/v1/friends/workouts/${created.body.post.id}`, {
    method: 'DELETE', headers: { authorization: `Bearer ${userToken}` },
  });
  assert.equal(deleted.response.status, 200);
  assert.equal(deleted.body.deleted, true);
  const gone = await api(`/v1/friends/workouts/${created.body.post.id}`, { headers: { authorization: `Bearer ${user2Token}` } });
  assert.equal(gone.response.status, 404);
});

test('food recognition sends multiple images to a configured OpenAI-compatible vision service and preserves ranges', async () => {
  const isolated = await fs.mkdtemp(path.join(os.tmpdir(), 'kilo-food-vision-'));
  let requestBody;
  const upstream = createHttpServer(async (req, res) => {
    let raw = '';
    for await (const chunk of req) raw += chunk;
    requestBody = { headers: req.headers, body: JSON.parse(raw) };
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({
      model: 'vision-test-response',
      choices: [{ message: { content: JSON.stringify({
        items: [{
          label: '鸡胸肉饭', confidence: 0.84, estimatedGrams: 420, estimatedCalories: 620,
          calorieRange: [520, 740], proteinGrams: 45, proteinRange: [36, 54],
          carbohydratesGrams: 68, carbohydratesRange: [55, 84], fatGrams: 12, fatRange: [8, 18],
          portionDescription: '一盘', uncertainty: 'medium', nutritionSource: 'vision-test',
        }],
        warnings: ['米饭份量受拍摄角度影响'],
      }) } }],
    }));
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  const cfg = {
    ...loadConfig({
      ...process.env,
      NODE_ENV: 'test',
      KILO_ENABLE_TEST_ADMIN: 'false',
      KILO_ENABLE_TEST_MEMBER: 'false',
      KILO_ENABLE_PASSWORD_REGISTRATION: 'true',
      KILO_GPU_API_KEY: 'food-gpu-test-key-12345678901234567890',
      KILO_SESSION_PEPPER: 'food-session-test-pepper-12345678901234567890',
      KILO_DATA_DIR: isolated,
      KILO_DATABASE_PATH: path.join(isolated, 'kilo.sqlite3'),
      KILO_MEDIA_DIR: path.join(isolated, 'media'),
    }),
    foodVisionBaseUrl: `http://127.0.0.1:${upstream.address().port}`,
    foodVisionApiKey: 'vision-test-key',
    foodVisionModel: 'vision-test-model',
    foodVisionMaxImages: 4,
  };
  const isolatedServer = await startServer({ config: cfg, port: 0 });
  const isolatedBase = `http://127.0.0.1:${isolatedServer.address().port}`;
  const localApi = async (pathname, options = {}) => {
    const headers = { ...(options.body !== undefined ? { 'content-type': 'application/json' } : {}), ...(options.headers || {}) };
    const response = await fetch(`${isolatedBase}${pathname}`, { ...options, headers });
    const text = await response.text();
    return { response, body: text ? JSON.parse(text) : null };
  };
  try {
    const registration = await localApi('/v1/auth/register', { method: 'POST', body: JSON.stringify({ identifier: 'food-user', password: '1234' }) });
    assert.equal(registration.response.status, 201);
    const token = registration.body.session.token;
    const tinyPng = Buffer.from('png-test').toString('base64');
    const locked = await localApi('/v1/nutrition/recognitions', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}` },
      body: JSON.stringify({ images: [
        { contentType: 'image/png', dataBase64: tinyPng },
      ] }),
    });
    assert.equal(locked.response.status, 403);
    assert.equal(locked.body.error, 'membership_required');
    isolatedServer.context.db.prepare("UPDATE entitlements SET membership = 'forever', membership_expires_at = NULL WHERE user_id = ?")
      .run(registration.body.user.id);
    const recognized = await localApi('/v1/nutrition/recognitions', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}` },
      body: JSON.stringify({ images: [
        { contentType: 'image/png', dataBase64: tinyPng },
        { contentType: 'image/png', dataBase64: tinyPng },
      ] }),
    });
    assert.equal(recognized.response.status, 200);
    assert.equal(recognized.body.status, 'completed');
    assert.equal(recognized.body.imageCount, 2);
    assert.deepEqual(recognized.body.result.items[0].calorieRange, [520, 740]);
    assert.deepEqual(recognized.body.result.items[0].proteinRange, [36, 54]);
    assert.equal(recognized.body.result.requiresReview, true);
    assert.equal(requestBody.headers.authorization, 'Bearer vision-test-key');
    assert.equal(requestBody.body.messages[0].content.filter((item) => item.type === 'image_url').length, 2);
    assert.equal(requestBody.body.model, 'vision-test-model');

    const form = new FormData();
    form.append('images', new Blob([Buffer.from('png-test-1')]), 'meal-1.png');
    form.append('images', new Blob([Buffer.from('png-test-2')]), 'meal-2.png');
    const multipartResponse = await fetch(`${isolatedBase}/v1/food/recognition`, {
      method: 'POST', headers: { authorization: `Bearer ${token}` }, body: form,
    });
    const multipartBody = await multipartResponse.json();
    assert.equal(multipartResponse.status, 200);
    assert.equal(multipartBody.imageCount, 2);
    assert.equal(multipartBody.items[0].label, '鸡胸肉饭');

    const fetched = await localApi(`/v1/nutrition/jobs/${recognized.body.id}`, { headers: { authorization: `Bearer ${token}` } });
    assert.equal(fetched.response.status, 200);
    assert.equal(fetched.body.result.items[0].label, '鸡胸肉饭');
  } finally {
    await isolatedServer.closeGracefully();
    await new Promise((resolve) => upstream.close(resolve));
    await fs.rm(isolated, { recursive: true, force: true });
  }
});

test('food recognition supports streamed multi-image uploads and explicit unconfigured errors', async () => {
  const isolated = await fs.mkdtemp(path.join(os.tmpdir(), 'kilo-food-stream-'));
  const upstream = createHttpServer(async (_req, res) => {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ choices: [{ message: { content: JSON.stringify({ items: [{ label: '香蕉', confidence: 0.7, estimatedCalories: 105, calorieRange: [80, 130] }] }) } }] }));
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  const cfg = {
    ...loadConfig({
      ...process.env,
      NODE_ENV: 'test',
      KILO_ENABLE_TEST_ADMIN: 'false',
      KILO_ENABLE_TEST_MEMBER: 'false',
      KILO_ENABLE_PASSWORD_REGISTRATION: 'true',
      KILO_GPU_API_KEY: 'food-stream-gpu-key-12345678901234567890',
      KILO_SESSION_PEPPER: 'food-stream-session-pepper-12345678901234567890',
      KILO_DATA_DIR: isolated,
      KILO_DATABASE_PATH: path.join(isolated, 'kilo.sqlite3'),
      KILO_MEDIA_DIR: path.join(isolated, 'media'),
    }),
    foodVisionBaseUrl: `http://127.0.0.1:${upstream.address().port}`,
    foodVisionApiKey: 'stream-vision-key',
    foodVisionModel: 'stream-vision-model',
  };
  const isolatedServer = await startServer({ config: cfg, port: 0 });
  const isolatedBase = `http://127.0.0.1:${isolatedServer.address().port}`;
  const localApi = async (pathname, options = {}) => {
    const headers = { ...(options.body !== undefined ? { 'content-type': 'application/json' } : {}), ...(options.headers || {}) };
    const response = await fetch(`${isolatedBase}${pathname}`, { ...options, headers });
    const text = await response.text();
    return { response, body: text ? JSON.parse(text) : null };
  };
  try {
    const registration = await localApi('/v1/auth/register', { method: 'POST', body: JSON.stringify({ identifier: 'food-stream-user', password: '1234' }) });
    const token = registration.body.session.token;
    isolatedServer.context.db.prepare("UPDATE entitlements SET membership = 'forever', membership_expires_at = NULL WHERE user_id = ?")
      .run(registration.body.user.id);
    const created = await localApi('/v1/nutrition/jobs', {
      method: 'POST', headers: { authorization: `Bearer ${token}` }, body: JSON.stringify({ imageCount: 2 }),
    });
    assert.equal(created.response.status, 202);
    for (const upload of created.body.uploads) {
      const response = await fetch(upload.url.replace(cfg.publicBaseUrl, isolatedBase), {
        method: 'PUT', headers: { authorization: `Bearer ${token}`, 'content-type': 'image/png', 'content-length': '9' }, body: Buffer.from('png-test!'),
      });
      assert.equal(response.status, 200);
    }
    const analyzed = await localApi(`/v1/nutrition/jobs/${created.body.id}/analyze`, { method: 'POST', headers: { authorization: `Bearer ${token}` } });
    assert.equal(analyzed.response.status, 200);
    assert.equal(analyzed.body.status, 'completed');
    assert.equal(analyzed.body.result.items[0].label, '香蕉');

    const missingCfg = { ...cfg, foodVisionBaseUrl: '', foodVisionApiKey: '', foodVisionModel: '' };
    const noServiceDir = await fs.mkdtemp(path.join(os.tmpdir(), 'kilo-food-no-service-'));
    const noServiceServer = await startServer({ config: { ...missingCfg, dataDir: noServiceDir, databasePath: path.join(noServiceDir, 'kilo.sqlite3'), mediaDir: path.join(noServiceDir, 'media') }, port: 0 });
    const noServiceBase = `http://127.0.0.1:${noServiceServer.address().port}`;
    try {
      const noServiceRegistration = await fetch(`${noServiceBase}/v1/auth/register`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ identifier: 'food-no-service', password: '1234' }) });
      const noServicePayload = await noServiceRegistration.json();
      noServiceServer.context.db.prepare("UPDATE entitlements SET membership = 'forever', membership_expires_at = NULL WHERE user_id = ?")
        .run(noServicePayload.user.id);
      const unavailable = await fetch(`${noServiceBase}/v1/nutrition/recognitions`, {
        method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${noServicePayload.session.token}` },
        body: JSON.stringify({ images: [{ contentType: 'image/png', dataBase64: Buffer.from('x').toString('base64') }] }),
      });
      assert.equal(unavailable.status, 503);
      assert.equal((await unavailable.json()).error, 'service_not_configured');
    } finally {
      await noServiceServer.closeGracefully();
      await fs.rm(noServiceDir, { recursive: true, force: true });
    }
  } finally {
    await isolatedServer.closeGracefully();
    await new Promise((resolve) => upstream.close(resolve));
    await fs.rm(isolated, { recursive: true, force: true });
  }
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
      'com.kilostrength.pro.quarterly',
      'com.kilostrength.pro.yearly',
    ],
  );
  assert.deepEqual(
    products.body.products.map((item) => item.amountMinor),
    [1200, 3800, 12800],
  );
  assert.equal((await api('/v1/membership/orders')).response.status, 401);
  const androidCapabilities = await api('/v1/membership/android/capabilities');
  assert.equal(androidCapabilities.response.status, 200);
  assert.deepEqual(androidCapabilities.body, { wechatPay: false, alipay: false });
  const unavailableCheckout = await api('/v1/membership/android/checkout', {
    method: 'POST',
    headers: { authorization: `Bearer ${userToken}` },
    body: JSON.stringify({
      productId: 'com.kilostrength.pro.monthly',
      provider: 'wechat_pay',
      platform: 'android',
      amountMinor: 1200,
      currency: 'CNY',
    }),
  });
  assert.equal(unavailableCheckout.response.status, 503);
  assert.equal(unavailableCheckout.body.error, 'payment_provider_not_configured');
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
      amountMinor: 1200,
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

  const quarterly = await api('/v1/membership/orders', {
    method: 'POST',
    headers: { authorization: `Bearer ${user2Token}` },
    body: JSON.stringify({
      productId: 'com.kilostrength.pro.quarterly',
      provider: 'app_store',
    }),
  });
  assert.equal(quarterly.response.status, 201);
  assert.equal(quarterly.body.order.plan, 'threeMonths');
  assert.equal(quarterly.body.order.amountMinor, 3800);

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

test('legacy check-in endpoints are disabled after removing the reward feature', async () => {
  for (const pathname of ['/v1/checkin/status', '/v1/checkin', '/v1/checkins/status', '/v1/checkins']) {
    const result = await api(pathname, {
      method: pathname.endsWith('status') ? 'GET' : 'POST',
      headers: { authorization: `Bearer ${userToken}` },
      ...(pathname.endsWith('status') ? {} : { body: '{}' }),
    });
    assert.equal(result.response.status, 404);
    assert.equal(result.body.error, 'checkin_disabled');
  }
});

test('administrator remains quota-exempt when recognition balance is zero', async () => {
  const admin = server.context.db.prepare("SELECT id FROM users WHERE identifier = '13023097571'").get();
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
      body: JSON.stringify({ identifier: '13023097571', password: '1234' }),
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
        clientDate: '2026-08-24',
        clientTimezoneOffsetMinutes: 480,
        useTrainingData: true,
        availableTools,
      }),
    });
    const firstBody = await first.json();
    assert.equal(first.status, 200);
    assert.equal(firstBody.toolCalls[0].name, 'read_training_plans');
    assert.ok(upstreamBodies[0].messages.some((item) =>
      item.role === 'system'
      && item.content.includes('今天=2026-08-24')
      && item.content.includes('昨天=2026-08-23')
      && item.content.includes('UTC+08:00')));
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

test('Android gateway checkout and signed webhook grant membership idempotently', async () => {
  const isolated = await fs.mkdtemp(path.join(os.tmpdir(), 'kilo-android-pay-'));
  let gatewayRequest;
  const gateway = createHttpServer(async (req, res) => {
    let raw = '';
    for await (const chunk of req) raw += chunk;
    gatewayRequest = {
      path: req.url,
      authorization: req.headers.authorization,
      body: JSON.parse(raw),
    };
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ paymentUrl: 'weixin://wap/pay?prepayid=test' }));
  });
  await new Promise((resolve) => gateway.listen(0, '127.0.0.1', resolve));
  const gatewayBase = `http://127.0.0.1:${gateway.address().port}`;
  const webhookSecret = 'android-webhook-secret-1234567890';
  const cfg = loadConfig({
    ...process.env,
    NODE_ENV: 'test',
    KILO_ENABLE_PASSWORD_REGISTRATION: 'true',
    KILO_SESSION_PEPPER: 'android-pay-session-pepper-1234567890',
    KILO_DATA_DIR: isolated,
    KILO_DATABASE_PATH: path.join(isolated, 'kilo.sqlite3'),
    KILO_MEDIA_DIR: path.join(isolated, 'media'),
    KILO_PUBLIC_BASE_URL: 'https://api.kilostrength.cn',
    WECHAT_PAY_GATEWAY_URL: gatewayBase,
    WECHAT_PAY_GATEWAY_SECRET: 'wechat-gateway-secret',
    ALIPAY_GATEWAY_URL: gatewayBase,
    ALIPAY_GATEWAY_SECRET: 'alipay-gateway-secret',
    ANDROID_PAYMENT_WEBHOOK_SECRET: webhookSecret,
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
    assert.deepEqual((await localApi('/v1/membership/android/capabilities')).body, {
      wechatPay: true,
      alipay: true,
    });
    const registration = await localApi('/v1/auth/register', {
      method: 'POST',
      body: JSON.stringify({ identifier: '17880160002', password: '1234' }),
    });
    const token = registration.body.session.token;
    const checkout = await localApi('/v1/membership/android/checkout', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}` },
      body: JSON.stringify({
        productId: 'com.kilostrength.pro.monthly',
        provider: 'wechat_pay',
        platform: 'android',
        amountMinor: 1,
        currency: 'USD',
      }),
    });
    assert.equal(checkout.response.status, 201);
    assert.equal(checkout.body.paymentUrl, 'weixin://wap/pay?prepayid=test');
    assert.equal(gatewayRequest.path, '/checkout');
    assert.equal(gatewayRequest.authorization, 'Bearer wechat-gateway-secret');
    assert.equal(gatewayRequest.body.amountMinor, 1200);
    assert.equal(gatewayRequest.body.currency, 'CNY');
    assert.equal(gatewayRequest.body.notifyUrl, 'https://api.kilostrength.cn/v1/membership/android/webhook/wechat_pay');

    const webhook = {
      orderId: checkout.body.order.id,
      transactionId: 'wechat-transaction-001',
      status: 'paid',
    };
    // A delayed official callback still grants access if the user cancelled
    // the local pending order while the provider was completing payment.
    const cancelled = await localApi(
      `/v1/membership/orders/${checkout.body.order.id}/cancel`,
      {
        method: 'POST',
        headers: { authorization: `Bearer ${token}` },
      },
    );
    assert.equal(cancelled.response.status, 200);
    assert.equal(cancelled.body.order.status, 'cancelled');
    const canonicalWebhook = JSON.stringify({
      orderId: webhook.orderId,
      status: webhook.status,
      transactionId: webhook.transactionId,
    });
    const signature = createHmac('sha256', webhookSecret)
      .update(canonicalWebhook)
      .digest('hex');
    const paid = await localApi('/v1/membership/android/webhook/wechat_pay', {
      method: 'POST',
      headers: { 'x-kilo-payment-signature': signature },
      body: JSON.stringify(webhook),
    });
    assert.equal(paid.response.status, 200);
    assert.equal(paid.body.idempotent, false);
    const repeated = await localApi('/v1/membership/android/webhook/wechat_pay', {
      method: 'POST',
      headers: { 'x-kilo-payment-signature': signature },
      body: JSON.stringify(webhook),
    });
    assert.equal(repeated.response.status, 200);
    assert.equal(repeated.body.idempotent, true);
    const entitlement = await localApi('/v1/me/entitlements', {
      headers: { authorization: `Bearer ${token}` },
    });
    assert.equal(entitlement.body.membership, 'oneMonth');
  } finally {
    await isolatedServer.closeGracefully();
    await new Promise((resolve) => gateway.close(resolve));
    await fs.rm(isolated, { recursive: true, force: true });
  }
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
  assert.match(done.body.result.summary, /无法稳定评价/);
});

test('recognition accepts explicit partial-cycle primary evidence without enabling rep count', () => {
  const assessment = recognitionEvidenceAssessment({
    status: 'complete',
    assessment: 'assessable',
    evidenceReason: 'partial_cycle',
    confidence: 0.78,
    evidence: {
      level: 'partial_cycle',
      canJudgePrimary: true,
      canCountRepetitions: false,
    },
    metrics: { completeMotionCycles: 0 },
  });

  assert.equal(assessment.assessable, true);
  assert.equal(assessment.level, 'partial_cycle');
  assert.equal(assessment.canCountRepetitions, false);
});

test('recognition rejects a selected exercise mismatch before coaching', () => {
  const assessment = recognitionEvidenceAssessment({
    assessment: 'insufficient_evidence',
    evidenceReason: 'selected_exercise_mismatch',
    evidence: { level: 'mismatch', canJudgePrimary: false },
  });

  assert.equal(assessment.assessable, false);
  assert.equal(assessment.reason, 'selected_exercise_mismatch');
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
      body: JSON.stringify({ identifier: '123', password: '123' }),
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
