import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { config as defaultConfig, assertProductionConfiguration, loadConfig } from './config.mjs';
import { openDatabase, closeDatabase, transaction, ensureEntitlement, refreshEntitlement, publicUser, publicEntitlement, seedTestAdmin, seedTestMember, isoWeekKey, membershipActive } from './db.mjs';
import { hashPassword, verifyPassword, sha256, safeEqualText, nowIso, randomId, randomToken } from './security.mjs';
import { LocalStorage, extensionForType } from './storage.mjs';
import { ConcurrencyGate, QueueCapacityError } from './concurrency.mjs';

const JSON_CONTENT_TYPE = 'application/json; charset=utf-8';
const MAX_TEXT = 4000;
const MAX_SUMMARY = 6000;
const ALLOWED_ENTITIES = new Set(['workout', 'plan', 'template', 'settings']);
const PLANS = new Set(['oneMonth', 'threeMonths', 'forever']);
const JOB_STATES = new Set(['created', 'uploading', 'queued', 'processing', 'completed', 'failed', 'cancelled', 'expired']);
const ALLOWED_MEDIA_TYPES = new Set(extensionForType.keys());
const MEDIA_CONTENT_TYPES = new Map([
  ['.mp4', 'video/mp4'], ['.mov', 'video/quicktime'], ['.webm', 'video/webm'],
  ['.jpg', 'image/jpeg'], ['.jpeg', 'image/jpeg'], ['.png', 'image/png'], ['.webp', 'image/webp'],
]);
const RECOGNITION_CAPABILITIES = [
  {
    exerciseId: 'barbell_squat',
    cameras: [
      { id: 'side', label: '正侧面', hint: '镜头与髋部同高，完整拍到头、髋、膝和脚。' },
      { id: 'side_rear', label: '侧后方', hint: '从侧后方完整拍到双脚与杠铃，便于观察膝髋轨迹。' },
    ],
  },
  {
    exerciseId: 'hip_thrust',
    cameras: [
      { id: 'side', label: '正侧面', hint: '镜头与髋部同高，完整拍到肩、髋和膝，避免器械遮挡。' },
    ],
  },
  {
    exerciseId: 'romanian_deadlift',
    cameras: [
      { id: 'side', label: '正侧面', hint: '完整拍到头、肩、髋、膝和脚，镜头保持水平。' },
      { id: 'side_rear', label: '侧后方', hint: '侧后方约 30° 拍摄，确保杠铃与下肢轨迹无遮挡。' },
    ],
  },
  {
    exerciseId: 'lat_pulldown',
    cameras: [
      { id: 'rear', label: '正后方', hint: '镜头正对座椅后方，完整拍到双臂、肩胛和躯干。' },
      { id: 'side', label: '正侧面', hint: '镜头与肩部同高，完整拍到手、肩、髋与下拉轨迹。' },
    ],
  },
];
const RECOGNITION_EXERCISE_IDS = new Set(RECOGNITION_CAPABILITIES.map((item) => item.exerciseId));
const RECOGNITION_CAMERAS = new Map(
  RECOGNITION_CAPABILITIES.map((item) => [item.exerciseId, new Set(item.cameras.map((camera) => camera.id))]),
);

export class HttpError extends Error {
  constructor(status, code, detail = undefined) {
    super(code);
    this.status = status;
    this.code = code;
    this.detail = detail;
  }
}

function httpError(status, code, detail) { return new HttpError(status, code, detail); }

function addMonths(from, months) {
  const d = new Date(from);
  const day = d.getUTCDate();
  d.setUTCDate(1);
  d.setUTCMonth(d.getUTCMonth() + months);
  const max = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate();
  d.setUTCDate(Math.min(day, max));
  return d;
}

function publicJob(row, cfg) {
  if (!row) return null;
  return {
    id: row.id,
    exerciseId: row.exercise_id,
    camera: row.camera,
    includeOverlay: Boolean(row.include_overlay),
    status: row.status,
    uploadExpiresAt: row.upload_expires_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    modelVersion: row.model_version,
    error: row.error_code,
    result: row.result_json ? JSON.parse(row.result_json) : null,
    media: {
      input: row.input_key ? `${cfg.publicBaseUrl}/v1/analysis/jobs/${encodeURIComponent(row.id)}/media/input` : null,
      overlay: row.overlay_key ? `${cfg.publicBaseUrl}/v1/analysis/jobs/${encodeURIComponent(row.id)}/media/overlay` : null,
      preview: row.preview_key ? `${cfg.publicBaseUrl}/v1/analysis/jobs/${encodeURIComponent(row.id)}/media/preview` : null,
    },
  };
}

function mediaContentType(key) {
  return MEDIA_CONTENT_TYPES.get(path.extname(String(key)).toLowerCase()) || 'application/octet-stream';
}

function artifactContentTypeAllowed(kind, contentType) {
  if (!ALLOWED_MEDIA_TYPES.has(contentType)) return false;
  if (kind === 'preview') return contentType.startsWith('image/');
  return kind === 'overlay' && (contentType.startsWith('image/') || contentType.startsWith('video/'));
}

function userFromDb(db, id) { return db.prepare('SELECT * FROM users WHERE id = ?').get(id); }

function audit(db, actorId, action, target, detail = {}) {
  db.prepare('INSERT INTO audit_log (id, actor_user_id, action, target, detail_json, created_at) VALUES (?, ?, ?, ?, ?, ?)')
    .run(randomId('audit_'), actorId || null, action, target, JSON.stringify(detail), nowIso());
}

function parseOrigin(req, cfg) {
  const origin = req.headers.origin;
  if (origin && cfg.allowedOrigins.has(origin)) return origin;
  return undefined;
}

function writeJson(res, status, payload, req, cfg, headers = {}) {
  const origin = parseOrigin(req, cfg);
  const base = {
    'content-type': JSON_CONTENT_TYPE,
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
    'referrer-policy': 'no-referrer',
    ...headers,
  };
  if (origin) {
    base['access-control-allow-origin'] = origin;
    base['access-control-allow-credentials'] = 'true';
    base.vary = 'Origin';
  }
  res.writeHead(status, base);
  res.end(JSON.stringify(payload));
}

function writeError(res, error, req, cfg) {
  const status = Number.isInteger(error?.status) ? error.status : 500;
  const payload = { error: error?.code || 'internal_error' };
  if (error?.detail !== undefined) payload.detail = error.detail;
  if (error?.code === 'ai_busy') {
    res.setHeader('retry-after', String(error?.detail?.retryAfterSeconds || 5));
  }
  if (status >= 500) console.error('[KILO API]', error?.stack || error);
  writeJson(res, status, payload, req, cfg);
}

async function readBody(req, maxBytes) {
  const contentType = String(req.headers['content-type'] || '').split(';')[0].trim().toLowerCase();
  if (contentType && contentType !== 'application/json') throw httpError(415, 'json_content_type_required');
  const headerLength = Number(req.headers['content-length'] || 0);
  if (headerLength > maxBytes) throw httpError(413, 'request_too_large', { maxBytes });
  const chunks = [];
  let total = 0;
  for await (const chunk of req) {
    total += chunk.length;
    if (total > maxBytes) throw httpError(413, 'request_too_large', { maxBytes });
    chunks.push(chunk);
  }
  if (!chunks.length) return {};
  try {
    const value = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('not_object');
    return value;
  } catch { throw httpError(400, 'invalid_json'); }
}

function requireString(value, code, max = 256) {
  if (typeof value !== 'string' || !value.trim() || value.length > max) throw httpError(400, code);
  return value.trim();
}

function bearer(req) {
  const header = req.headers.authorization;
  if (!header || typeof header !== 'string') return null;
  const match = header.match(/^Bearer\s+([^\s]+)$/i);
  return match ? match[1] : null;
}

function createSession(db, cfg, userId) {
  const token = randomToken();
  const created = new Date();
  const expires = new Date(created.getTime() + cfg.sessionTtlDays * 86400000);
  db.prepare('INSERT INTO sessions (id, user_id, token_hash, expires_at, created_at) VALUES (?, ?, ?, ?, ?)')
    .run(randomId('ses_'), userId, sha256(token, cfg.sessionPepper), expires.toISOString(), created.toISOString());
  return { token, expiresAt: expires.toISOString() };
}

function authenticate(req, ctx) {
  const token = bearer(req);
  if (!token) throw httpError(401, 'unauthenticated');
  const hash = sha256(token, ctx.cfg.sessionPepper);
  const row = ctx.db.prepare(`SELECT u.*, s.id AS session_id, s.expires_at AS session_expires_at
    FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token_hash = ?`).get(hash);
  if (!row) throw httpError(401, 'unauthenticated');
  if (new Date(row.session_expires_at) <= new Date()) {
    ctx.db.prepare('DELETE FROM sessions WHERE id = ?').run(row.session_id);
    throw httpError(401, 'session_expired');
  }
  return row;
}

function optionalAuth(req, ctx) {
  try { return authenticate(req, ctx); } catch (error) {
    if (error?.code === 'unauthenticated') return null;
    throw error;
  }
}

function requireAdmin(req, ctx) {
  const user = authenticate(req, ctx);
  if (user.role !== 'admin') throw httpError(403, 'admin_required');
  return user;
}

function entitlementFor(db, userId) {
  return transaction(db, () => publicEntitlement(ensureEntitlement(db, userId)));
}

function membershipFor(db, userId, plan) {
  const current = ensureEntitlement(db, userId);
  const currentActive = membershipActive(current);
  if (plan === 'forever' || current.membership === 'forever') {
    return { membership: 'forever', membershipExpiresAt: null };
  }
  const months = plan === 'threeMonths' ? 3 : 1;
  const start = currentActive && current.membership_expires_at ? new Date(current.membership_expires_at) : new Date();
  const rank = { free: 0, oneMonth: 1, threeMonths: 2, forever: 3 };
  // Never downgrade a still-active entitlement. A shorter code can extend
  // the existing expiry, but it cannot remove higher-tier benefits.
  const membership = currentActive && rank[current.membership] > rank[plan] ? current.membership : plan;
  return { membership, membershipExpiresAt: addMonths(start, months).toISOString() };
}

function grantMembership(db, userId, plan) {
  const grant = membershipFor(db, userId, plan);
  db.prepare(`UPDATE entitlements SET membership = ?, membership_expires_at = ?,
    recognition_weekly_grant = ?, ai_remaining = CASE WHEN ai_remaining < 20 THEN 20 ELSE ai_remaining END,
    updated_at = ? WHERE user_id = ?`)
    .run(grant.membership, grant.membershipExpiresAt, grant.membership !== 'free' ? 3 : 1, nowIso(), userId);
  return publicEntitlement(ensureEntitlement(db, userId));
}

function quotaKind(kind) {
  if (kind !== 'ai' && kind !== 'recognition') throw httpError(400, 'invalid_usage_kind');
  return kind;
}

function reserveQuotaInternal(db, userId, kind, requestId) {
  quotaKind(kind);
  requestId = requireString(requestId, 'request_id_required', 200);
  const existing = db.prepare('SELECT * FROM usage_reservations WHERE request_id = ?').get(requestId);
  if (existing) {
    if (existing.user_id !== userId || existing.kind !== kind) throw httpError(409, 'request_id_conflict');
    const ent = ensureEntitlement(db, userId);
    return { reservation: existing, entitlement: ent, idempotent: true };
  }
  const ent = ensureEntitlement(db, userId);
  const column = kind === 'ai' ? 'ai_remaining' : 'recognition_remaining';
  if (Number(ent[column]) <= 0) throw httpError(409, 'quota_exhausted', { kind });
  db.prepare(`UPDATE entitlements SET ${column} = ${column} - 1, updated_at = ? WHERE user_id = ? AND ${column} > 0`)
    .run(nowIso(), userId);
  const stamp = nowIso();
  db.prepare('INSERT INTO usage_reservations (request_id, user_id, kind, state, created_at, updated_at) VALUES (?, ?, ?, \'reserved\', ?, ?)')
    .run(requestId, userId, kind, stamp, stamp);
  const reservation = db.prepare('SELECT * FROM usage_reservations WHERE request_id = ?').get(requestId);
  return { reservation, entitlement: db.prepare('SELECT * FROM entitlements WHERE user_id = ?').get(userId), idempotent: false };
}

function reserveQuota(db, userId, kind, requestId) {
  return transaction(db, () => reserveQuotaInternal(db, userId, kind, requestId));
}

function changeReservationInternal(db, userId, requestId, action) {
  requestId = requireString(requestId, 'request_id_required', 200);
  if (!['commit', 'rollback'].includes(action)) throw httpError(400, 'invalid_usage_action');
  const row = db.prepare('SELECT * FROM usage_reservations WHERE request_id = ?').get(requestId);
  if (!row || row.user_id !== userId) throw httpError(404, 'reservation_not_found');
  const targetState = action === 'commit' ? 'committed' : 'rolled_back';
  if (row.state === targetState) {
    return { reservation: row, entitlement: ensureEntitlement(db, userId), idempotent: true };
  }
  if (row.state !== 'reserved') throw httpError(409, 'reservation_not_active');
  db.prepare('UPDATE usage_reservations SET state = ?, updated_at = ? WHERE request_id = ? AND state = \'reserved\'')
    .run(targetState, nowIso(), requestId);
  if (action === 'rollback') {
    const column = row.kind === 'ai' ? 'ai_remaining' : 'recognition_remaining';
    db.prepare(`UPDATE entitlements SET ${column} = ${column} + 1, updated_at = ? WHERE user_id = ?`).run(nowIso(), userId);
  }
  return { reservation: db.prepare('SELECT * FROM usage_reservations WHERE request_id = ?').get(requestId), entitlement: ensureEntitlement(db, userId), idempotent: false };
}

function changeReservation(db, userId, requestId, action) {
  return transaction(db, () => changeReservationInternal(db, userId, requestId, action));
}

function usageResponse(result) {
  return {
    requestId: result.reservation.request_id,
    kind: result.reservation.kind,
    state: result.reservation.state,
    idempotent: Boolean(result.idempotent),
    ...publicEntitlement(result.entitlement),
  };
}

function parseEntity(pathname) {
  const parts = pathname.split('/').filter(Boolean);
  if (parts[0] !== 'v1' || parts[1] !== 'sync') return null;
  return { type: parts[2], id: parts[3] };
}

async function verifyProviderToken(provider, token, cfg) {
  const clientId = provider === 'apple' ? cfg.appleClientId : cfg.googleClientId;
  if (!clientId) throw httpError(501, 'provider_not_configured', { provider });
  if (!token) throw httpError(400, `${provider}_token_required`);
  const issuer = provider === 'apple' ? 'https://appleid.apple.com' : 'https://accounts.google.com';
  const jwksUrl = provider === 'apple' ? 'https://appleid.apple.com/auth/keys' : 'https://www.googleapis.com/oauth2/v3/certs';
  try {
    const claims = await jwtVerify(token, createRemoteJWKSet(new URL(jwksUrl)), { issuer, audience: clientId });
    if (!claims.payload.sub) throw new Error('missing_subject');
    return claims.payload;
  } catch (error) {
    console.warn(`[KILO API] ${provider} token verification failed`, error?.message || error);
    throw httpError(401, 'invalid_provider_token');
  }
}

async function callDeepSeek(ctx, messages, userId) {
  if (!ctx.cfg.deepSeekApiKey) throw httpError(503, 'deepseek_not_configured');
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), ctx.cfg.aiRequestTimeoutSeconds * 1000);
  try {
    const response = await fetch(`${ctx.cfg.deepSeekBaseUrl}/chat/completions`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${ctx.cfg.deepSeekApiKey}` },
      body: JSON.stringify({
        model: ctx.cfg.deepSeekModel,
        temperature: 0.2,
        thinking: { type: ctx.cfg.deepSeekThinkingMode },
        // A pseudonymous internal id gives DeepSeek per-user safety, cache and
        // scheduling isolation without sending a phone number or Apple id.
        user_id: userId,
        messages,
      }),
      signal: controller.signal,
    });
    if (!response.ok) throw httpError(response.status === 429 ? 503 : 502, 'deepseek_upstream_error', { upstreamStatus: response.status });
    const payload = await response.json().catch(() => null);
    const answer = payload?.choices?.[0]?.message?.content;
    if (typeof answer !== 'string' || !answer.trim()) throw httpError(502, 'deepseek_empty_response');
    return answer.trim();
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error?.name === 'AbortError') throw httpError(504, 'deepseek_timeout');
    throw httpError(502, 'deepseek_upstream_unavailable');
  } finally { clearTimeout(timeout); }
}

function isTrainingPlanRequest(question) {
  const normalized = question.toLocaleLowerCase();
  const mentionsPlan = /(计划|方案|workout plan|training plan)/u.test(normalized);
  const asksToCreate = /(生成|制定|安排|创建|做一份|设计|帮我做|帮我排|generate|create|build|make)/u.test(normalized);
  const shortPlanIntent = /(今日|今天|明天|本周|这周|练胸|练背|练腿|练肩|练手臂)/u.test(normalized);
  return mentionsPlan && (asksToCreate || shortPlanIntent);
}

function extractPlanDraft(rawAnswer, allowedExerciseIds) {
  const marker = rawAnswer.match(/<KILO_PLAN>([\s\S]*?)<\/KILO_PLAN>/u);
  if (!marker) return { answer: rawAnswer.trim(), plan: null };
  const answer = rawAnswer.replace(marker[0], '').trim();
  try {
    const parsed = JSON.parse(marker[1].trim());
    const allowedSetTypes = new Set(['warmup', 'work', 'backoff', 'drop', 'failure', 'technique']);
    const sessions = Array.isArray(parsed?.sessions)
      ? parsed.sessions.slice(0, 7).map((session) => {
        const structuredExercises = Array.isArray(session?.exercises)
          ? session.exercises.slice(0, 10).map((exercise) => {
            const exerciseId = String(exercise?.exerciseId || '');
            if (!allowedExerciseIds.has(exerciseId)) return null;
            const sets = Array.isArray(exercise?.sets)
              ? exercise.sets.slice(0, 8).map((set) => ({
                type: allowedSetTypes.has(String(set?.type)) ? String(set.type) : 'work',
                weight: Math.max(0, Math.min(1000, Number(set?.weight) || 0)),
                reps: Math.max(1, Math.min(100, Math.round(Number(set?.reps) || 8))),
                restSeconds: Math.max(15, Math.min(600, Math.round(Number(set?.restSeconds) || 90))),
              }))
              : [];
            return sets.length ? { exerciseId, sets } : null;
          }).filter(Boolean)
          : [];
        const legacyIds = Array.isArray(session?.exerciseIds)
          ? [...new Set(session.exerciseIds.map(String).filter((id) => allowedExerciseIds.has(id)))].slice(0, 10)
          : [];
        const exerciseIds = structuredExercises.length
          ? structuredExercises.map((exercise) => exercise.exerciseId)
          : legacyIds;
        return {
          dayOffset: Math.max(0, Math.min(6, Number(session?.dayOffset) || 0)),
          name: String(session?.name || '训练').trim().slice(0, 60),
          exerciseIds,
          exercises: structuredExercises,
        };
      }).filter((session) => session.exerciseIds.length)
      : [];
    if (!sessions.length) return { answer, plan: null };
    return {
      answer: answer || '训练计划已经整理好。请先检查动作和训练频率，确认后再保存。',
      plan: {
        title: String(parsed?.title || 'AI 训练计划').trim().slice(0, 80),
        weeks: Math.max(1, Math.min(8, Number(parsed?.weeks) || 1)),
        sessions,
      },
    };
  } catch {
    return { answer, plan: null };
  }
}

function knowledgeSearch(db, query, limit = 5) {
  if (!query) return [];
  const safe = query.replace(/[\"']/g, ' ').trim().split(/\s+/).filter(Boolean).slice(0, 8).join(' ');
  if (!safe) return [];
  const found = [];
  const seen = new Set();
  try {
    const rows = db.prepare(`SELECT k.id, k.title, k.source, k.content, k.tags_json
      FROM knowledge_fts f JOIN knowledge_chunks k ON k.id = f.id WHERE knowledge_fts MATCH ? ORDER BY rank LIMIT ?`).all(safe, limit);
    for (const row of rows) {
      found.push(row);
      seen.add(row.id);
    }
  } catch { /* Chinese sentences often need the substring fallback below. */ }

  if (found.length >= limit) return found;
  const terms = [];
  const addTerm = (term) => {
    const normalized = term.toLocaleLowerCase().trim();
    if (normalized.length >= 2 && !terms.includes(normalized)) terms.push(normalized);
  };
  for (const token of safe.match(/[\p{Script=Han}]+|[\p{L}\p{N}]+/gu) || []) {
    if (/^[\p{Script=Han}]+$/u.test(token)) {
      if (token.length <= 4) addTerm(token);
      for (let index = 0; index < token.length - 1; index += 1) addTerm(token.slice(index, index + 2));
    } else {
      addTerm(token);
    }
  }
  const selectedTerms = terms.slice(0, 16);
  if (!selectedTerms.length) return found;
  const candidates = db.prepare('SELECT id, title, source, content, tags_json FROM knowledge_chunks LIMIT 500').all();
  const scored = candidates
    .filter((row) => !seen.has(row.id))
    .map((row) => {
      const haystack = `${row.title}\n${row.content}`.toLocaleLowerCase();
      const score = selectedTerms.reduce((total, term) => total + (haystack.includes(term) ? (row.title.toLocaleLowerCase().includes(term) ? 3 : 1) : 0), 0);
      return { row, score };
    })
    .filter((item) => item.score > 0)
    .sort((left, right) => right.score - left.score || left.row.title.localeCompare(right.row.title));
  for (const item of scored) {
    found.push(item.row);
    if (found.length >= limit) break;
  }
  return found;
}

function conversationMessages(db, conversationId, limit = 20) {
  return db.prepare('SELECT id, role, content, created_at FROM conversation_messages WHERE conversation_id = ? ORDER BY created_at DESC LIMIT ?')
    .all(conversationId, limit).reverse();
}

function assertJobOwner(db, jobId, userId) {
  const job = db.prepare('SELECT * FROM recognition_jobs WHERE id = ? AND user_id = ?').get(jobId, userId);
  if (!job) throw httpError(404, 'job_not_found');
  return job;
}

function markJobFailedAndRollback(db, job, errorCode) {
  return transaction(db, () => {
    db.prepare("UPDATE recognition_jobs SET status = 'failed', error_code = ?, updated_at = ? WHERE id = ? AND status IN ('created', 'uploading')").run(errorCode, nowIso(), job.id);
    changeReservationInternal(db, job.user_id, job.quota_request_id, 'rollback');
    return db.prepare('SELECT * FROM recognition_jobs WHERE id = ?').get(job.id);
  });
}

function parseJsonResult(value) {
  if (typeof value === 'string') {
    try { return JSON.parse(value); } catch { throw httpError(400, 'invalid_result_json'); }
  }
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw httpError(400, 'result_required');
  return value;
}

function gpuAuth(req, ctx) {
  const supplied = req.headers['x-kilo-gpu-key'] || bearer(req);
  if (!ctx.cfg.gpuApiKey) throw httpError(503, 'gpu_not_configured');
  if (!supplied || !safeEqualText(supplied, ctx.cfg.gpuApiKey)) throw httpError(401, 'gpu_unauthorized');
}

async function handleRequest(req, res, ctx) {
  const url = new URL(req.url || '/', `http://${req.headers.host || `${ctx.cfg.host}:${ctx.cfg.port}`}`);
  if (req.method === 'OPTIONS') {
    const origin = parseOrigin(req, ctx.cfg);
    const headers = {
      'access-control-allow-methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
      'access-control-allow-headers': 'authorization,content-type,x-kilo-gpu-key,x-upload-token',
      'access-control-max-age': '600',
    };
    if (origin) { headers['access-control-allow-origin'] = origin; headers.vary = 'Origin'; }
    res.writeHead(204, headers); res.end(); return;
  }
  if (req.method === 'GET' && url.pathname === '/health') {
    writeJson(res, 200, {
      ok: true,
      service: 'kilo-backend',
      time: nowIso(),
      ai: {
        configured: Boolean(ctx.cfg.deepSeekApiKey),
        ...ctx.aiGate.snapshot(),
      },
    }, req, ctx.cfg); return;
  }
  if (req.method === 'GET' && url.pathname === '/v1/analysis/capabilities') {
    writeJson(res, 200, {
      modelVersion: 'bettercoach-cpu-v1',
      exercises: RECOGNITION_CAPABILITIES,
    }, req, ctx.cfg); return;
  }

  // Explicitly configured test credentials are seeded at startup; no test
  // account exists when KILO_ENABLE_TEST_ADMIN is false.
  if (req.method === 'POST' && url.pathname === '/v1/auth/register') {
    if (!ctx.cfg.enablePasswordRegistration) throw httpError(404, 'password_registration_disabled');
    const body = await readBody(req, ctx.cfg.maxJsonBytes);
    const identifier = requireString(body.identifier, 'identifier_required', 256);
    const password = requireString(body.password, 'password_required', 256);
    const displayName = typeof body.displayName === 'string' && body.displayName.trim() ? body.displayName.trim().slice(0, 120) : identifier;
    if (password.length < 4) throw httpError(400, 'invalid_password');
    const created = transaction(ctx.db, () => {
      if (ctx.db.prepare('SELECT 1 FROM users WHERE identifier = ?').get(identifier)) throw httpError(409, 'identifier_taken');
      const id = randomId('usr_'); const hp = hashPassword(password); const stamp = nowIso();
      ctx.db.prepare(`INSERT INTO users (id, identifier, display_name, role, auth_provider, password_salt, password_hash, created_at)
        VALUES (?, ?, ?, 'user', 'password', ?, ?, ?)`).run(id, identifier, displayName, hp.salt, hp.hash, stamp);
      ensureEntitlement(ctx.db, id); return ctx.db.prepare('SELECT * FROM users WHERE id = ?').get(id);
    });
    const session = createSession(ctx.db, ctx.cfg, created.id);
    writeJson(res, 201, { user: publicUser(created), session }, req, ctx.cfg); return;
  }
  if (req.method === 'POST' && url.pathname === '/v1/auth/phone/login') {
    const body = await readBody(req, ctx.cfg.maxJsonBytes);
    const identifier = requireString(body.identifier, 'identifier_required', 256);
    const password = requireString(body.password, 'password_required', 256);
    if (!ctx.cfg.enableTestAdmin && !ctx.cfg.enableTestMember && identifier === ctx.cfg.testAdminIdentifier && password === ctx.cfg.testAdminPassword) throw httpError(401, 'invalid_credentials');
    if (!ctx.cfg.enableTestMember && identifier === ctx.cfg.testMemberIdentifier && password === ctx.cfg.testMemberPassword) throw httpError(401, 'invalid_credentials');
    const user = ctx.db.prepare("SELECT * FROM users WHERE identifier = ? AND auth_provider = 'password'").get(identifier);
    if (!user || !verifyPassword(password, user.password_salt, user.password_hash)) throw httpError(401, 'invalid_credentials');
    ensureEntitlement(ctx.db, user.id);
    const session = createSession(ctx.db, ctx.cfg, user.id);
    writeJson(res, 200, { user: publicUser(user), session }, req, ctx.cfg); return;
  }
  if (req.method === 'POST' && ['/v1/auth/apple', '/v1/auth/google'].includes(url.pathname)) {
    const provider = url.pathname.endsWith('apple') ? 'apple' : 'google';
    const body = await readBody(req, ctx.cfg.maxJsonBytes);
    const token = provider === 'apple' ? body.identityToken : body.idToken;
    const claims = await verifyProviderToken(provider, token, ctx.cfg);
    const subject = String(claims.sub);
    let user = ctx.db.prepare('SELECT * FROM users WHERE auth_provider = ? AND provider_subject = ?').get(provider, subject);
    if (!user) {
      const id = randomId('usr_'); const identifier = `${provider}:${subject}`; const stamp = nowIso();
      ctx.db.prepare(`INSERT INTO users (id, identifier, display_name, role, auth_provider, provider_subject, created_at) VALUES (?, ?, ?, 'user', ?, ?, ?)`)
        .run(id, identifier, String(claims.email || identifier).slice(0, 120), provider, subject, stamp);
      ensureEntitlement(ctx.db, id); user = ctx.db.prepare('SELECT * FROM users WHERE id = ?').get(id);
    }
    const session = createSession(ctx.db, ctx.cfg, user.id);
    writeJson(res, 200, { user: publicUser(user), session }, req, ctx.cfg); return;
  }
  if (req.method === 'POST' && url.pathname === '/v1/auth/phone/request') throw httpError(501, 'provider_not_configured', { provider: 'sms' });
  if (req.method === 'POST' && url.pathname === '/v1/auth/logout') {
    const user = authenticate(req, ctx);
    const token = bearer(req);
    ctx.db.prepare('DELETE FROM sessions WHERE id = ? AND user_id = ?').run(user.session_id, user.id);
    writeJson(res, 200, { loggedOut: true }, req, ctx.cfg); return;
  }

  if (req.method === 'GET' && url.pathname === '/v1/me/entitlements') {
    const user = authenticate(req, ctx); writeJson(res, 200, publicEntitlement(entitlementRow(ctx.db, user.id)), req, ctx.cfg); return;
  }
  if (req.method === 'POST' && url.pathname === '/v1/redemptions/redeem') {
    const user = authenticate(req, ctx); const body = await readBody(req, ctx.cfg.maxJsonBytes); const code = requireString(body.code, 'code_required', 128).toUpperCase();
    const entitlement = transaction(ctx.db, () => {
      ensureEntitlement(ctx.db, user.id);
      const row = ctx.db.prepare('SELECT * FROM redemption_codes WHERE code = ?').get(code);
      if (!row) throw httpError(404, 'invalid_code');
      if (row.used_by) throw httpError(409, 'code_already_used');
      const changed = ctx.db.prepare('UPDATE redemption_codes SET used_by = ?, used_at = ? WHERE code = ? AND used_by IS NULL').run(user.id, nowIso(), code);
      if (changed.changes !== 1) throw httpError(409, 'code_already_used');
      const result = grantMembership(ctx.db, user.id, row.plan); audit(ctx.db, user.id, 'redeem_code', code, { plan: row.plan }); return result;
    });
    writeJson(res, 200, { entitlement }, req, ctx.cfg); return;
  }
  if (req.method === 'POST' && ['/v1/usage/consume', '/v1/usage/reserve', '/v1/usage/commit', '/v1/usage/rollback'].includes(url.pathname)) {
    const user = authenticate(req, ctx); const body = await readBody(req, ctx.cfg.maxJsonBytes); const kind = quotaKind(body.kind); const action = url.pathname.endsWith('/reserve') ? 'reserve' : url.pathname.endsWith('/commit') ? 'commit' : url.pathname.endsWith('/rollback') ? 'rollback' : (body.action || 'reserve');
    const result = action === 'reserve' ? reserveQuota(ctx.db, user.id, kind, body.requestId) : changeReservation(ctx.db, user.id, body.requestId, action);
    writeJson(res, 200, usageResponse(result), req, ctx.cfg); return;
  }
  if (req.method === 'POST' && url.pathname === '/v1/rewards/workout-completed') {
    const user = authenticate(req, ctx); const body = await readBody(req, ctx.cfg.maxJsonBytes); const workoutId = requireString(body.workoutId, 'workout_id_required', 200);
    const result = transaction(ctx.db, () => {
      ensureEntitlement(ctx.db, user.id);
      const inserted = ctx.db.prepare('INSERT OR IGNORE INTO workout_rewards (user_id, workout_id, created_at) VALUES (?, ?, ?)').run(user.id, workoutId, nowIso());
      if (inserted.changes) ctx.db.prepare('UPDATE entitlements SET recognition_remaining = recognition_remaining + 1, updated_at = ? WHERE user_id = ?').run(nowIso(), user.id);
      return { awarded: Boolean(inserted.changes), entitlement: ensureEntitlement(ctx.db, user.id) };
    });
    writeJson(res, 200, { awarded: result.awarded, ...publicEntitlement(result.entitlement) }, req, ctx.cfg); return;
  }
  if (req.method === 'POST' && url.pathname === '/v1/admin/memberships/grant') {
    const admin = requireAdmin(req, ctx); const body = await readBody(req, ctx.cfg.maxJsonBytes); const identifier = requireString(body.identifier, 'identifier_required', 256); const plan = requireString(body.plan, 'plan_required', 32);
    if (!PLANS.has(plan)) throw httpError(400, 'invalid_plan');
    const target = ctx.db.prepare('SELECT * FROM users WHERE identifier = ?').get(identifier); if (!target) throw httpError(404, 'user_not_found');
    const entitlement = transaction(ctx.db, () => { ensureEntitlement(ctx.db, target.id); const result = grantMembership(ctx.db, target.id, plan); audit(ctx.db, admin.id, 'grant_membership', target.id, { identifier, plan }); return result; });
    writeJson(res, 200, { user: publicUser(target), entitlement }, req, ctx.cfg); return;
  }
  if (req.method === 'POST' && url.pathname === '/v1/admin/redemption-codes') {
    const admin = requireAdmin(req, ctx); const body = await readBody(req, ctx.cfg.maxJsonBytes); const plan = requireString(body.plan, 'plan_required', 32); if (!PLANS.has(plan)) throw httpError(400, 'invalid_plan');
    let code; do { code = `KILO-${randomToken().slice(0, 16).toUpperCase()}`; } while (ctx.db.prepare('SELECT 1 FROM redemption_codes WHERE code = ?').get(code));
    ctx.db.prepare('INSERT INTO redemption_codes (code, plan, created_by, created_at) VALUES (?, ?, ?, ?)').run(code, plan, admin.id, nowIso()); audit(ctx.db, admin.id, 'create_redemption_code', code, { plan });
    writeJson(res, 201, { code, plan }, req, ctx.cfg); return;
  }

  const entity = parseEntity(url.pathname);
  if (req.method === 'GET' && url.pathname === '/v1/sync') {
    const user = authenticate(req, ctx); const entityType = url.searchParams.get('entityType'); if (!ALLOWED_ENTITIES.has(entityType)) throw httpError(400, 'entity_type_required'); const since = Number(url.searchParams.get('sinceRevision') || url.searchParams.get('since') || 0); const rows = since ? ctx.db.prepare('SELECT * FROM sync_entities WHERE user_id = ? AND entity_type = ? AND revision > ? ORDER BY revision').all(user.id, entityType, since) : ctx.db.prepare('SELECT * FROM sync_entities WHERE user_id = ? AND entity_type = ? ORDER BY revision').all(user.id, entityType); writeJson(res, 200, { entityType, entities: rows.map(syncPublic) }, req, ctx.cfg); return;
  }
  if (req.method === 'POST' && url.pathname === '/v1/sync') {
    const user = authenticate(req, ctx); const body = await readBody(req, ctx.cfg.maxJsonBytes); const entityType = requireString(body.entityType || body.type, 'entity_type_required', 30); const entityId = requireString(body.entityId || body.id, 'entity_id_required', 200); if (!ALLOWED_ENTITIES.has(entityType)) throw httpError(400, 'unknown_entity'); const payload = body.payload === undefined ? body.data : body.payload; const deleted = body.deleted === true; if (!deleted && (payload === undefined || payload === null || typeof payload !== 'object')) throw httpError(400, 'payload_required');
    const result = transaction(ctx.db, () => { const current = ctx.db.prepare('SELECT * FROM sync_entities WHERE user_id = ? AND entity_type = ? AND entity_id = ?').get(user.id, entityType, entityId); let expected; if (body.baseRevision !== undefined || body.expectedRevision !== undefined) expected = body.baseRevision ?? body.expectedRevision; else if (current) { if (body.revision === undefined || Number(body.revision) <= current.revision) throw httpError(409, 'revision_conflict', { current: syncPublic(current) }); expected = current.revision; } else expected = 0; if (current && Number(expected) !== current.revision) throw httpError(409, 'revision_conflict', { current: syncPublic(current) }); const revision = current ? current.revision + 1 : Math.max(1, Number(body.revision) || 1); const stamp = nowIso(); ctx.db.prepare(`INSERT INTO sync_entities (user_id, entity_type, entity_id, revision, payload_json, deleted_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(user_id, entity_type, entity_id) DO UPDATE SET revision=excluded.revision, payload_json=excluded.payload_json, deleted_at=excluded.deleted_at, updated_at=excluded.updated_at`).run(user.id, entityType, entityId, revision, JSON.stringify(payload ?? {}), deleted ? stamp : null, stamp); return ctx.db.prepare('SELECT * FROM sync_entities WHERE user_id = ? AND entity_type = ? AND entity_id = ?').get(user.id, entityType, entityId); });
    writeJson(res, 200, syncPublic(result), req, ctx.cfg); return;
  }
  if (entity) {
    const user = authenticate(req, ctx); if (!ALLOWED_ENTITIES.has(entity.type)) throw httpError(404, 'unknown_entity');
    if (req.method === 'GET' && !entity.id) {
      const since = Number(url.searchParams.get('sinceRevision') || url.searchParams.get('since') || 0); const rows = since ? ctx.db.prepare('SELECT * FROM sync_entities WHERE user_id = ? AND entity_type = ? AND revision > ? ORDER BY revision').all(user.id, entity.type, since) : ctx.db.prepare('SELECT * FROM sync_entities WHERE user_id = ? AND entity_type = ? ORDER BY revision').all(user.id, entity.type);
      writeJson(res, 200, { entityType: entity.type, entities: rows.map(syncPublic) }, req, ctx.cfg); return;
    }
    if ((req.method === 'PUT' || req.method === 'PATCH' || req.method === 'POST') && entity.id) {
      const body = await readBody(req, ctx.cfg.maxJsonBytes); const payload = body.payload === undefined ? body.data : body.payload; const deleted = body.deleted === true;
      if (!deleted && (payload === undefined || payload === null || typeof payload !== 'object')) throw httpError(400, 'payload_required');
      const result = transaction(ctx.db, () => {
        const current = ctx.db.prepare('SELECT * FROM sync_entities WHERE user_id = ? AND entity_type = ? AND entity_id = ?').get(user.id, entity.type, entity.id);
        let expected;
        if (body.baseRevision !== undefined || body.expectedRevision !== undefined) {
          expected = body.baseRevision ?? body.expectedRevision;
        } else if (current) {
          // A revision-only update carries the next revision. Replaying the
          // current (or an older) revision is a stale write and must conflict.
          if (body.revision === undefined || Number(body.revision) <= Number(current.revision)) {
            throw httpError(409, 'revision_conflict', { current: syncPublic(current) });
          }
          expected = current.revision;
        } else expected = 0;
        if (current && Number(expected) !== Number(current.revision)) throw httpError(409, 'revision_conflict', { current: syncPublic(current) });
        const revision = current ? current.revision + 1 : Math.max(1, Number(body.revision) || 1); const stamp = nowIso();
        ctx.db.prepare(`INSERT INTO sync_entities (user_id, entity_type, entity_id, revision, payload_json, deleted_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(user_id, entity_type, entity_id) DO UPDATE SET revision=excluded.revision, payload_json=excluded.payload_json, deleted_at=excluded.deleted_at, updated_at=excluded.updated_at`).run(user.id, entity.type, entity.id, revision, JSON.stringify(payload ?? {}), deleted ? stamp : null, stamp);
        return ctx.db.prepare('SELECT * FROM sync_entities WHERE user_id = ? AND entity_type = ? AND entity_id = ?').get(user.id, entity.type, entity.id);
      });
      writeJson(res, 200, syncPublic(result), req, ctx.cfg); return;
    }
    if (req.method === 'DELETE' && entity.id) {
      const current = ctx.db.prepare('SELECT * FROM sync_entities WHERE user_id = ? AND entity_type = ? AND entity_id = ?').get(user.id, entity.type, entity.id); if (!current) throw httpError(404, 'entity_not_found');
      const expected = Number(url.searchParams.get('revision') || current.revision); if (expected !== current.revision) throw httpError(409, 'revision_conflict');
      const stamp = nowIso(); ctx.db.prepare('UPDATE sync_entities SET revision = revision + 1, deleted_at = ?, updated_at = ? WHERE user_id = ? AND entity_type = ? AND entity_id = ? AND revision = ?').run(stamp, stamp, user.id, entity.type, entity.id, expected);
      writeJson(res, 200, syncPublic(ctx.db.prepare('SELECT * FROM sync_entities WHERE user_id = ? AND entity_type = ? AND entity_id = ?').get(user.id, entity.type, entity.id)), req, ctx.cfg); return;
    }
  }

  if (req.method === 'POST' && ['/v1/ai/conversations', '/v1/coach/conversations'].includes(url.pathname)) {
    const user = authenticate(req, ctx); const body = await readBody(req, ctx.cfg.maxJsonBytes); const title = typeof body.title === 'string' && body.title.trim() ? body.title.trim().slice(0, 200) : 'KILO Coach'; const id = randomId('conv_'); const stamp = nowIso();
    ctx.db.prepare('INSERT INTO conversations (id, user_id, title, memory_summary, created_at, updated_at) VALUES (?, ?, ?, \'\', ?, ?)').run(id, user.id, title, stamp, stamp); writeJson(res, 201, conversationPublic(ctx.db.prepare('SELECT * FROM conversations WHERE id = ?').get(id), []), req, ctx.cfg); return;
  }
  if (req.method === 'GET' && ['/v1/ai/conversations', '/v1/coach/conversations'].includes(url.pathname)) {
    const user = authenticate(req, ctx); const rows = ctx.db.prepare('SELECT * FROM conversations WHERE user_id = ? ORDER BY updated_at DESC LIMIT 100').all(user.id); writeJson(res, 200, { conversations: rows.map((row) => conversationPublic(row, [])) }, req, ctx.cfg); return;
  }
  const convMatch = url.pathname.match(/^\/v1\/(?:ai\/conversations|coach\/conversations)\/([^/]+)$/);
  if (convMatch && req.method === 'GET') {
    const user = authenticate(req, ctx); const row = ctx.db.prepare('SELECT * FROM conversations WHERE id = ? AND user_id = ?').get(decodeURIComponent(convMatch[1]), user.id); if (!row) throw httpError(404, 'conversation_not_found'); writeJson(res, 200, conversationPublic(row, conversationMessages(ctx.db, row.id, 50)), req, ctx.cfg); return;
  }
  const convMessageMatch = url.pathname.match(/^\/v1\/(?:ai\/conversations|coach\/conversations)\/([^/]+)\/messages$/);
  if ((req.method === 'POST' && ['/v1/coach/answer', '/v1/ai/chat'].includes(url.pathname)) || (convMessageMatch && req.method === 'POST')) {
    const user = authenticate(req, ctx); const body = await readBody(req, ctx.cfg.maxJsonBytes); const question = requireString(body.question || body.message, 'question_required', MAX_TEXT); const requestId = body.requestId || `ai_${randomUUID()}`; const reservation = reserveQuota(ctx.db, user.id, 'ai', requestId);
    try {
      let conversationId = convMessageMatch ? decodeURIComponent(convMessageMatch[1]) : body.conversationId; let conversation;
      if (conversationId) conversation = ctx.db.prepare('SELECT * FROM conversations WHERE id = ? AND user_id = ?').get(conversationId, user.id);
      if (!conversation && convMessageMatch) throw httpError(404, 'conversation_not_found');
      if (!conversation) { conversationId = randomId('conv_'); const stamp = nowIso(); ctx.db.prepare('INSERT INTO conversations (id, user_id, title, memory_summary, created_at, updated_at) VALUES (?, ?, ?, \'\', ?, ?)').run(conversationId, user.id, question.slice(0, 80), stamp, stamp); conversation = ctx.db.prepare('SELECT * FROM conversations WHERE id = ?').get(conversationId); }
      const recent = conversationMessages(ctx.db, conversationId, 20);
      const knowledge = knowledgeSearch(ctx.db, question, 5);
      const messages = [{ role: 'system', content: `你是 KILO Strength 健身训练助手。提供一般训练、恢复和动作记录建议，不进行医疗诊断。证据不足时明确说明。
回答使用简洁 Markdown：用标题、加粗、列表组织内容，但不要堆叠格式。只总结知识库结论，不要大段照搬原文。不要在正文中写文献名称、来源列表、脚注编号或“根据某文献”；客户端会在回答结尾统一展示服务端检索到的来源。凡是建议用户增加或降低重量、次数、组数或休息时间，必须紧接着说明依据（历史表现、完成质量、备注、训练目标或恢复状态）；没有足够数据时必须明确说这是保守起点而非个性化结论。` }];
      if (conversation.memory_summary) messages.push({ role: 'system', content: `长期记忆摘要：${conversation.memory_summary.slice(0, 3000)}` });
      if (knowledge.length) messages.push({ role: 'system', content: `知识库参考：\n${knowledge.map((item) => `${item.title}: ${item.content.slice(0, 1200)}`).join('\n')}` });
      for (const message of recent) messages.push({ role: message.role, content: message.content });
      if (body.useTrainingData === true && typeof body.trainingSummary === 'string' && body.trainingSummary.trim()) messages.push({ role: 'system', content: `用户已明确授权的训练摘要：${body.trainingSummary.trim().slice(0, MAX_SUMMARY)}` });
      const planRequested = isTrainingPlanRequest(question);
      const exerciseCatalog = Array.isArray(body.exerciseCatalog)
        ? body.exerciseCatalog.slice(0, 100).map((item) => ({
          id: String(item?.id || '').slice(0, 200),
          name: String(item?.name || '').slice(0, 100),
          equipment: String(item?.equipment || '').slice(0, 60),
          muscle: String(item?.muscle || '').slice(0, 60),
        })).filter((item) => item.id && item.name)
        : [];
      if (planRequested && exerciseCatalog.length) {
        messages.push({ role: 'system', content: `用户明确要求生成训练计划。只能从下面动作库选择动作，不得编造 ID：\n${exerciseCatalog.map((item) => `${item.id}|${item.name}|${item.equipment}|${item.muscle}`).join('\n')}
先用 Markdown 说明计划思路和注意事项，然后在回答最末尾输出且只输出一次以下机器可读块：
<KILO_PLAN>{"title":"计划名称","weeks":1,"sessions":[{"dayOffset":0,"name":"胸部训练","exercises":[{"exerciseId":"动作ID","sets":[{"type":"warmup","weight":20,"reps":12,"restSeconds":60},{"type":"work","weight":40,"reps":8,"restSeconds":120}]}]}]}</KILO_PLAN>
每个动作必须给出具体组型、重量（kg）、次数和组间休息；自重动作的 weight 使用 0。没有用户历史重量时使用保守可调整的起始重量，不要编造极限重量。dayOffset 为本周从今天起第几天（0-6）；如果用户要求一个月，weeks 设为 4。不要在机器可读块中使用 Markdown 代码围栏。` });
      }
      messages.push({ role: 'user', content: question });
      let rawAnswer;
      try {
        rawAnswer = await ctx.aiGate.run(() => callDeepSeek(ctx, messages, user.id));
      } catch (error) {
        if (error instanceof QueueCapacityError) {
          throw httpError(503, 'ai_busy', { retryAfterSeconds: 5 });
        }
        throw error;
      }
      const allowedExerciseIds = new Set(exerciseCatalog.map((item) => item.id));
      const parsedAnswer = planRequested
        ? extractPlanDraft(rawAnswer, allowedExerciseIds)
        : { answer: rawAnswer, plan: null };
      const answer = parsedAnswer.answer;
      const stamp = nowIso(); transaction(ctx.db, () => { ctx.db.prepare('INSERT INTO conversation_messages (id, conversation_id, role, content, created_at) VALUES (?, ?, \'user\', ?, ?)').run(randomId('msg_'), conversationId, question, stamp); ctx.db.prepare('INSERT INTO conversation_messages (id, conversation_id, role, content, created_at) VALUES (?, ?, \'assistant\', ?, ?)').run(randomId('msg_'), conversationId, answer, nowIso()); ctx.db.prepare('UPDATE conversations SET updated_at = ? WHERE id = ?').run(nowIso(), conversationId); });
      // Memory summarisation is deliberately low frequency and best effort.
      try { const count = ctx.db.prepare('SELECT COUNT(*) AS n FROM conversation_messages WHERE conversation_id = ?').get(conversationId).n; if (count >= 10 && count % 10 === 0) { const text = conversationMessages(ctx.db, conversationId, 10).map((m) => `${m.role}: ${m.content}`).join('\n'); ctx.db.prepare('UPDATE conversations SET memory_summary = ?, updated_at = ? WHERE id = ?').run(text.slice(0, 3000), nowIso(), conversationId); } } catch { /* memory must never break the answer */ }
      changeReservation(ctx.db, user.id, requestId, 'commit'); writeJson(res, 200, { conversationId, answer, citations: knowledge.map((item) => ({ id: item.id, title: item.title, source: item.source })), plan: parsedAnswer.plan }, req, ctx.cfg);
    } catch (error) { try { changeReservation(ctx.db, user.id, requestId, 'rollback'); } catch { /* preserve original error */ } throw error; }
    return;
  }
  if (req.method === 'POST' && url.pathname === '/v1/admin/knowledge') {
    const admin = requireAdmin(req, ctx); const body = await readBody(req, ctx.cfg.maxJsonBytes); const title = requireString(body.title, 'title_required', 300); const source = requireString(body.source || 'admin', 'source_required', 500); const content = requireString(body.content, 'content_required', 100000); const id = randomId('kn_'); const tags = Array.isArray(body.tags) ? body.tags.slice(0, 30) : []; const stamp = nowIso();
    transaction(ctx.db, () => { ctx.db.prepare('INSERT INTO knowledge_chunks (id, title, source, content, tags_json, updated_at) VALUES (?, ?, ?, ?, ?, ?)').run(id, title, source, content, JSON.stringify(tags), stamp); ctx.db.prepare('INSERT INTO knowledge_fts (id, title, content) VALUES (?, ?, ?)').run(id, title, content); audit(ctx.db, admin.id, 'knowledge_write', id, { title }); }); writeJson(res, 201, { id, title, source, tags }, req, ctx.cfg); return;
  }
  if (req.method === 'GET' && url.pathname === '/v1/knowledge/search') {
    authenticate(req, ctx); const q = url.searchParams.get('q') || ''; writeJson(res, 200, { results: knowledgeSearch(ctx.db, q, Math.min(20, Number(url.searchParams.get('limit') || 5))).map((item) => ({ id: item.id, title: item.title, source: item.source, content: item.content, tags: JSON.parse(item.tags_json || '[]') })) }, req, ctx.cfg); return;
  }

  if (req.method === 'POST' && url.pathname === '/v1/push-tokens') {
    const user = authenticate(req, ctx); const body = await readBody(req, ctx.cfg.maxJsonBytes); const platform = requireString(body.platform, 'platform_required', 20); const token = requireString(body.token, 'token_required', 2048); if (!['ios', 'android'].includes(platform)) throw httpError(400, 'invalid_platform'); const tokenHash = sha256(token, ctx.cfg.sessionPepper); ctx.db.prepare(`INSERT INTO push_tokens (user_id, platform, token_hash, token, updated_at) VALUES (?, ?, ?, ?, ?) ON CONFLICT(user_id, token_hash) DO UPDATE SET platform=excluded.platform, token=excluded.token, updated_at=excluded.updated_at`).run(user.id, platform, tokenHash, token, nowIso()); writeJson(res, 200, { registered: true, platform }, req, ctx.cfg); return;
  }

  // Recognition service: user-facing job creation, upload and result.
  if (req.method === 'POST' && ['/v1/analysis/jobs', '/v1/recognition/jobs'].includes(url.pathname)) {
    const user = authenticate(req, ctx); const body = await readBody(req, ctx.cfg.maxJsonBytes); const exerciseId = requireString(body.exerciseId, 'exercise_id_required', 200); const camera = requireString(body.camera, 'camera_required', 100); const includeOverlay = body.includeOverlay !== false; if (!RECOGNITION_EXERCISE_IDS.has(exerciseId)) throw httpError(400, 'recognition_exercise_unsupported'); if (!RECOGNITION_CAMERAS.get(exerciseId)?.has(camera)) throw httpError(400, 'recognition_camera_unsupported'); const id = randomId('job_'); const quotaRequestId = `recognition:${id}`; const uploadToken = randomToken(); const stamp = nowIso(); const uploadExpiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();
    const job = transaction(ctx.db, () => {
      reserveQuotaInternal(ctx.db, user.id, 'recognition', quotaRequestId);
      ctx.db.prepare(`INSERT INTO recognition_jobs (id, user_id, exercise_id, camera, include_overlay, status, upload_token_hash, upload_expires_at, input_key, result_json, overlay_key, preview_key, error_code, model_version, quota_request_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 'created', ?, ?, '', NULL, NULL, NULL, NULL, NULL, ?, ?, ?)`).run(id, user.id, exerciseId, camera, includeOverlay ? 1 : 0, sha256(uploadToken, ctx.cfg.sessionPepper), uploadExpiresAt, quotaRequestId, stamp, stamp);
      return ctx.db.prepare('SELECT * FROM recognition_jobs WHERE id = ?').get(id);
    });
    writeJson(res, 202, { ...publicJob(job, ctx.cfg), upload: { method: 'PUT', url: `${ctx.cfg.publicBaseUrl}/v1/analysis/jobs/${encodeURIComponent(id)}/upload?token=${encodeURIComponent(uploadToken)}`, expiresInSeconds: 900, expiresAt: uploadExpiresAt } }, req, ctx.cfg); return;
  }
  const uploadMatch = url.pathname.match(/^\/v1\/(?:analysis|recognition)\/jobs\/([^/]+)\/upload$/);
  if (uploadMatch && (req.method === 'PUT' || req.method === 'POST')) {
    const id = decodeURIComponent(uploadMatch[1]); const job = ctx.db.prepare('SELECT * FROM recognition_jobs WHERE id = ?').get(id); if (!job) throw httpError(404, 'job_not_found');
    let user = null; try { user = authenticate(req, ctx); } catch (error) { if (error.code !== 'unauthenticated') throw error; }
    const suppliedToken = url.searchParams.get('token') || req.headers['x-upload-token']; if ((!user || user.id !== job.user_id) && (!suppliedToken || !safeEqualText(sha256(suppliedToken, ctx.cfg.sessionPepper), job.upload_token_hash))) throw httpError(401, 'upload_unauthorized');
    if (!['created', 'uploading'].includes(job.status)) throw httpError(409, 'invalid_job_state');
    if (job.upload_expires_at && new Date(job.upload_expires_at) <= new Date()) {
      transaction(ctx.db, () => {
        ctx.db.prepare("UPDATE recognition_jobs SET status = 'expired', error_code = 'upload_expired', updated_at = ? WHERE id = ? AND status IN ('created', 'uploading')").run(nowIso(), id);
        changeReservationInternal(ctx.db, job.user_id, job.quota_request_id, 'rollback');
      });
      throw httpError(410, 'upload_expired');
    }
    const rejectUpload = (status, code, detail) => { markJobFailedAndRollback(ctx.db, job, code); throw httpError(status, code, detail); };
    const contentType = String(req.headers['content-type'] || '').split(';')[0].toLowerCase(); if (!ALLOWED_MEDIA_TYPES.has(contentType)) rejectUpload(415, 'unsupported_media_type');
    if (Number(req.headers['content-length'] || 0) > ctx.cfg.maxUploadBytes) rejectUpload(413, 'upload_too_large', { maxBytes: ctx.cfg.maxUploadBytes });
    const key = `inputs/${job.user_id}/${job.id}${extensionForType.get(contentType) || '.bin'}`; ctx.db.prepare("UPDATE recognition_jobs SET status = 'uploading', updated_at = ? WHERE id = ?").run(nowIso(), id);
    try { await ctx.storage.putStream(key, req, { maxBytes: ctx.cfg.maxUploadBytes }); ctx.db.prepare("UPDATE recognition_jobs SET status = 'queued', input_key = ?, updated_at = ? WHERE id = ?").run(key, nowIso(), id); } catch (error) { markJobFailedAndRollback(ctx.db, job, error.code === 'upload_too_large' ? 'upload_too_large' : 'upload_failed'); if (error.code === 'upload_too_large') throw httpError(413, 'upload_too_large', { maxBytes: ctx.cfg.maxUploadBytes }); throw error; }
    writeJson(res, 200, publicJob(ctx.db.prepare('SELECT * FROM recognition_jobs WHERE id = ?').get(id), ctx.cfg), req, ctx.cfg); return;
  }
  const jobMatch = url.pathname.match(/^\/v1\/(?:analysis|recognition)\/jobs\/([^/]+)(?:\/(result|ack))?$/);
  if (jobMatch && req.method === 'GET') { const user = authenticate(req, ctx); const job = assertJobOwner(ctx.db, decodeURIComponent(jobMatch[1]), user.id); writeJson(res, 200, publicJob(job, ctx.cfg), req, ctx.cfg); return; }
  if (jobMatch && req.method === 'POST' && jobMatch[2] === 'ack') { const user = authenticate(req, ctx); const job = assertJobOwner(ctx.db, decodeURIComponent(jobMatch[1]), user.id); if (!['completed', 'failed', 'cancelled', 'expired'].includes(job.status)) throw httpError(409, 'invalid_job_state'); writeJson(res, 200, { id: job.id, acknowledged: true }, req, ctx.cfg); return; }
  const mediaMatch = url.pathname.match(/^\/v1\/(?:analysis|recognition)\/jobs\/([^/]+)\/media\/(input|overlay|preview)$/);
  if (mediaMatch && req.method === 'GET') {
    const user = authenticate(req, ctx); const job = assertJobOwner(ctx.db, decodeURIComponent(mediaMatch[1]), user.id); const kind = mediaMatch[2]; const key = kind === 'input' ? job.input_key : kind === 'overlay' ? job.overlay_key : job.preview_key; if (!key || !ctx.storage.exists(key)) throw httpError(404, 'media_not_found'); const stream = ctx.storage.createReadStream(key); const stat = ctx.storage.stat(key); const origin = parseOrigin(req, ctx.cfg); const headers = { 'content-length': stat.size, 'content-type': mediaContentType(key), 'content-disposition': 'inline', 'cache-control': 'private, max-age=300', 'x-content-type-options': 'nosniff' }; if (origin) headers['access-control-allow-origin'] = origin; res.writeHead(200, headers); stream.pipe(res); return;
  }

  // Compute-worker protocol. The route name stays /gpu/ for backwards
  // compatibility, but both the current CPU worker and a future GPU worker use
  // the same authenticated queue.
  if (req.method === 'POST' && url.pathname === '/v1/internal/gpu/jobs/claim') {
    gpuAuth(req, ctx); const result = transaction(ctx.db, () => {
      const cutoff = new Date(Date.now() - ctx.cfg.gpuClaimTimeoutSeconds * 1000).toISOString();
      // A worker that disappeared after claim leaves a reserved quota. Put it
      // back in the queue so another worker can retry without double charging.
      ctx.db.prepare("UPDATE recognition_jobs SET status = 'queued', error_code = NULL, updated_at = ? WHERE status = 'processing' AND updated_at < ?").run(nowIso(), cutoff);
      const job = ctx.db.prepare("SELECT * FROM recognition_jobs WHERE status = 'queued' AND input_key <> '' ORDER BY created_at LIMIT 1").get(); if (!job) return null; ctx.db.prepare("UPDATE recognition_jobs SET status = 'processing', updated_at = ? WHERE id = ? AND status = 'queued'").run(nowIso(), job.id); return ctx.db.prepare('SELECT * FROM recognition_jobs WHERE id = ?').get(job.id);
    }); if (!result) { writeJson(res, 204, {}, req, ctx.cfg); return; } writeJson(res, 200, { job: { id: result.id, exerciseId: result.exercise_id, camera: result.camera, includeOverlay: Boolean(result.include_overlay), status: result.status, inputUrl: `${ctx.cfg.publicBaseUrl}/v1/internal/gpu/jobs/${encodeURIComponent(result.id)}/input` } }, req, ctx.cfg); return;
  }
  const gpuJobMatch = url.pathname.match(/^\/v1\/internal\/gpu\/jobs\/([^/]+)\/(input|artifact|heartbeat|result|fail)$/);
  if (gpuJobMatch) {
    gpuAuth(req, ctx); const id = decodeURIComponent(gpuJobMatch[1]); const job = ctx.db.prepare('SELECT * FROM recognition_jobs WHERE id = ?').get(id); if (!job) throw httpError(404, 'job_not_found'); const action = gpuJobMatch[2];
    if (action === 'input' && req.method === 'GET') { if (!job.input_key || !ctx.storage.exists(job.input_key)) throw httpError(404, 'media_not_found'); const stat = ctx.storage.stat(job.input_key); res.writeHead(200, { 'content-length': stat.size, 'content-type': mediaContentType(job.input_key), 'content-disposition': 'inline', 'cache-control': 'no-store' }); ctx.storage.createReadStream(job.input_key).pipe(res); return; }
    if (action === 'heartbeat' && req.method === 'POST') {
      const touched = ctx.db.prepare("UPDATE recognition_jobs SET updated_at = ? WHERE id = ? AND status = 'processing'").run(nowIso(), id);
      if (!touched.changes) throw httpError(409, 'invalid_job_state');
      writeJson(res, 200, { id, status: 'processing' }, req, ctx.cfg); return;
    }
    if (action === 'artifact' && req.method === 'PUT' && req.headers['x-artifact-kind']) {
      if (job.status !== 'processing') throw httpError(409, 'invalid_job_state');
      const kind = String(req.headers['x-artifact-kind']).trim();
      if (!['overlay', 'preview'].includes(kind)) throw httpError(400, 'invalid_artifact_kind');
      const contentType = String(req.headers['content-type'] || '').split(';')[0].toLowerCase();
      if (!artifactContentTypeAllowed(kind, contentType)) throw httpError(415, 'unsupported_media_type');
      if (Number(req.headers['content-length'] || 0) > ctx.cfg.maxUploadBytes) throw httpError(413, 'artifact_too_large', { maxBytes: ctx.cfg.maxUploadBytes });
      const key = `artifacts/${job.user_id}/${job.id}/${kind}${extensionForType.get(contentType) || '.bin'}`;
      try {
        await ctx.storage.putStream(key, req, { maxBytes: ctx.cfg.maxUploadBytes });
      } catch (error) {
        if (error?.code === 'upload_too_large') throw httpError(413, 'artifact_too_large', { maxBytes: ctx.cfg.maxUploadBytes });
        throw error;
      }
      ctx.db.prepare(`UPDATE recognition_jobs SET ${kind}_key = ?, updated_at = ? WHERE id = ? AND status = 'processing'`).run(key, nowIso(), id);
      writeJson(res, 200, { kind, key }, req, ctx.cfg); return;
    }
    if (action === 'artifact' && (req.method === 'POST' || req.method === 'PUT')) { if (job.status !== 'processing') throw httpError(409, 'invalid_job_state'); const body = await readBody(req, ctx.cfg.maxJsonBytes); const kind = requireString(body.kind || body.type, 'artifact_kind_required', 20); if (!['overlay', 'preview'].includes(kind)) throw httpError(400, 'invalid_artifact_kind'); const base64 = requireString(body.dataBase64, 'artifact_data_required', Math.ceil(ctx.cfg.maxUploadBytes * 1.4)); let bytes; try { bytes = Buffer.from(base64, 'base64'); } catch { throw httpError(400, 'invalid_artifact_data'); } if (!bytes.length || bytes.length > ctx.cfg.maxUploadBytes) throw httpError(413, 'artifact_too_large'); const contentType = String(body.contentType || 'image/jpeg').split(';')[0].toLowerCase(); if (!artifactContentTypeAllowed(kind, contentType)) throw httpError(415, 'unsupported_media_type'); const key = `artifacts/${job.user_id}/${job.id}/${kind}${extensionForType.get(contentType) || '.bin'}`; await ctx.storage.putBuffer(key, bytes, { maxBytes: ctx.cfg.maxUploadBytes }); ctx.db.prepare(`UPDATE recognition_jobs SET ${kind}_key = ?, updated_at = ? WHERE id = ? AND status = 'processing'`).run(key, nowIso(), id); writeJson(res, 200, { kind, key }, req, ctx.cfg); return; }
    if (action === 'result' && req.method === 'POST') { const body = await readBody(req, ctx.cfg.maxJsonBytes); const result = parseJsonResult(body.result || body); const modelVersion = typeof body.modelVersion === 'string' ? body.modelVersion.slice(0, 120) : null; const completed = transaction(ctx.db, () => { const current = ctx.db.prepare('SELECT * FROM recognition_jobs WHERE id = ?').get(id); if (!current || current.status !== 'processing') throw httpError(409, 'invalid_job_state'); ctx.db.prepare("UPDATE recognition_jobs SET status = 'completed', result_json = ?, model_version = ?, updated_at = ? WHERE id = ? AND status = 'processing'").run(JSON.stringify(result), modelVersion, nowIso(), id); changeReservationInternal(ctx.db, current.user_id, current.quota_request_id, 'commit'); return ctx.db.prepare('SELECT * FROM recognition_jobs WHERE id = ?').get(id); }); writeJson(res, 200, publicJob(completed, ctx.cfg), req, ctx.cfg); return; }
    if (action === 'fail' && req.method === 'POST') { const body = await readBody(req, ctx.cfg.maxJsonBytes); const errorCode = requireString(body.errorCode || 'gpu_failed', 'error_code_required', 120); const failed = transaction(ctx.db, () => { const current = ctx.db.prepare('SELECT * FROM recognition_jobs WHERE id = ?').get(id); if (!current || ['completed', 'failed', 'cancelled', 'expired'].includes(current.status)) throw httpError(409, 'invalid_job_state'); ctx.db.prepare("UPDATE recognition_jobs SET status = 'failed', error_code = ?, updated_at = ? WHERE id = ? AND status NOT IN ('completed', 'failed', 'cancelled', 'expired')").run(errorCode, nowIso(), id); changeReservationInternal(ctx.db, current.user_id, current.quota_request_id, 'rollback'); return ctx.db.prepare('SELECT * FROM recognition_jobs WHERE id = ?').get(id); }); writeJson(res, 200, publicJob(failed, ctx.cfg), req, ctx.cfg); return; }
  }

  throw httpError(404, 'not_found', { path: url.pathname });
}

function entitlementRow(db, userId) { return transaction(db, () => ensureEntitlement(db, userId)); }
function syncPublic(row) { return { entityType: row.entity_type, entityId: row.entity_id, revision: row.revision, payload: JSON.parse(row.payload_json), deleted: Boolean(row.deleted_at), deletedAt: row.deleted_at, updatedAt: row.updated_at }; }
function conversationPublic(row, messages) { return { id: row.id, title: row.title, memorySummary: row.memory_summary, createdAt: row.created_at, updatedAt: row.updated_at, messages }; }

export function createApp(options = {}) {
  const cfg = options.config || defaultConfig;
  if (options.assertProduction !== false) assertProductionConfiguration(cfg);
  fs.mkdirSync(cfg.dataDir, { recursive: true }); fs.mkdirSync(cfg.mediaDir, { recursive: true });
  const db = options.db || openDatabase(cfg.databasePath); const storage = options.storage || new LocalStorage(cfg.mediaDir, { maxBytes: cfg.maxUploadBytes }); seedTestMember(db, cfg); seedTestAdmin(db, cfg);
  const aiGate = options.aiGate || new ConcurrencyGate({ limit: cfg.aiMaxConcurrency, queueLimit: cfg.aiQueueLimit });
  const ctx = { cfg, db, storage, aiGate };
  const server = createServer((req, res) => handleRequest(req, res, ctx).catch((error) => writeError(res, error, req, cfg)));
  server.context = ctx;
  server.closeGracefully = async () => { await new Promise((resolve) => server.close(resolve)); closeDatabase(db); };
  return server;
}

export function startServer(options = {}) {
  const cfg = options.config || loadConfig(); const server = createApp({ ...options, config: cfg });
  const port = options.port ?? cfg.port; const host = options.host ?? cfg.host;
  return new Promise((resolve, reject) => { server.once('error', reject); server.listen(port, host, () => { console.log(`[KILO API] backend listening at http://${host}:${server.address().port}`); resolve(server); }); });
}

if (process.argv[1] && process.argv[1].replaceAll('\\', '/').endsWith('/src/server.mjs')) {
  try { await startServer(); } catch (error) { console.error('[KILO API] startup failed', error); process.exitCode = 1; }
}
