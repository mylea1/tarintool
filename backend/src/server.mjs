import { createServer } from 'node:http';
import { createHmac, randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { config as defaultConfig, assertProductionConfiguration, loadConfig } from './config.mjs';
import { openDatabase, closeDatabase, transaction, ensureEntitlement, refreshEntitlement, publicUser, publicEntitlement, seedTestAdmin, seedTestMember, isoWeekKey, membershipActive, publicCheckinState, ensureCheckinState, shanghaiDayKey, normalizeUsername, normalizePhone, normalizeEmail, maskUserIdentity, putUserIdentity, syncAccountPhoneIdentity } from './db.mjs';
import { hashPassword, verifyPassword, sha256, safeEqualText, nowIso, randomId, randomToken } from './security.mjs';
import { LocalStorage, extensionForType } from './storage.mjs';
import { ConcurrencyGate, QueueCapacityError } from './concurrency.mjs';

const JSON_CONTENT_TYPE = 'application/json; charset=utf-8';
const MAX_TEXT = 4000;
const MAX_SUMMARY = 6000;
const MAX_AGENT_TOOL_RESULTS = 3;
const MAX_AGENT_RESULT_BYTES = 12000;
const ISO_DAY = /^\d{4}-\d{2}-\d{2}$/u;
const AI_TOOL_DEFINITIONS = [
  {
    type: 'function',
    function: {
      name: 'read_training_intelligence',
      description: '读取用户设备计算的今日建议、肌群恢复、近四周训练量、动作技术趋势、当前健身房和周报。只读。',
      parameters: { type: 'object', properties: {}, additionalProperties: false },
    },
  },
  {
    type: 'function',
    function: {
      name: 'read_training_plans',
      description: '读取当前用户保存的训练计划及其中的动作、组数、重量、次数和休息时间。只读。',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: '按计划或动作名称筛选，可省略。' },
          limit: { type: 'integer', minimum: 1, maximum: 10 },
        },
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'read_workout_history',
      description: '读取当前用户已完成训练的日期、动作、每组重量次数、休息和备注。只读。',
      parameters: {
        type: 'object',
        properties: {
          startDate: { type: 'string', description: 'YYYY-MM-DD，可省略。' },
          endDate: { type: 'string', description: 'YYYY-MM-DD，可省略。' },
          query: { type: 'string', description: '按训练或动作名称筛选，可省略。' },
          limit: { type: 'integer', minimum: 1, maximum: 20 },
        },
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'read_active_workout',
      description: '读取当前用户设备上正在进行的训练及完成状态。没有训练时返回空状态。只读。',
      parameters: { type: 'object', properties: {}, additionalProperties: false },
    },
  },
  {
    type: 'function',
    function: {
      name: 'read_nutrition_history',
      description: '读取当前用户记录的饮食、热量和三大营养素。只读。',
      parameters: {
        type: 'object',
        properties: {
          startDate: { type: 'string', description: 'YYYY-MM-DD，可省略。' },
          endDate: { type: 'string', description: 'YYYY-MM-DD，可省略。' },
          limit: { type: 'integer', minimum: 1, maximum: 50 },
        },
        additionalProperties: false,
      },
    },
  },
];
const AI_TOOL_NAMES = new Set(AI_TOOL_DEFINITIONS.map((item) => item.function.name));

function shiftIsoDay(value, days) {
  const date = new Date(`${value}T12:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function shanghaiIsoDay() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

function aiClientTimeInstruction(body) {
  const requestedDate = typeof body?.clientDate === 'string'
    ? body.clientDate.trim()
    : '';
  const today = ISO_DAY.test(requestedDate) ? requestedDate : shanghaiIsoDay();
  const rawOffset = Number(body?.clientTimezoneOffsetMinutes);
  const offsetMinutes = Number.isFinite(rawOffset) && Math.abs(rawOffset) <= 14 * 60
    ? Math.trunc(rawOffset)
    : 8 * 60;
  const sign = offsetMinutes < 0 ? '-' : '+';
  const absolute = Math.abs(offsetMinutes);
  const offset = `${sign}${String(Math.floor(absolute / 60)).padStart(2, '0')}:${String(absolute % 60).padStart(2, '0')}`;
  return `用户设备当前本地日期是 ${today}（UTC${offset}）。今天=${today}，昨天=${shiftIsoDay(today, -1)}，明天=${shiftIsoDay(today, 1)}。解析“昨天、今天、明天、本周、上周”等相对日期时必须以这些日期为准；调用 read_workout_history 或 read_nutrition_history 时必须使用对应的 YYYY-MM-DD，不得依据对话记忆猜测年份或月份。`;
}
const ALLOWED_ENTITIES = new Set(['workout', 'plan', 'template', 'settings']);
const PLANS = new Set(['oneMonth', 'yearly', 'threeMonths', 'forever']);
// Three current subscription products are displayed to customers. Legacy
// product IDs remain verifiable so a previously purchased prototype product
// is not silently lost during migration.
const APPLE_MEMBERSHIP_PRODUCTS = new Map([
  ['com.kilostrength.pro.monthly', 'oneMonth'],
  ['com.kilostrength.pro.quarterly', 'threeMonths'],
  ['com.kilostrength.pro.yearly', 'yearly'],
  ['com.kilostrength.pro.lifetime', 'forever'],
]);
const PUBLIC_MEMBERSHIP_PRODUCTS = new Map([
  ['com.kilostrength.pro.monthly', { plan: 'oneMonth', amountMinor: 1200, currency: 'CNY', duration: '1个月' }],
  ['com.kilostrength.pro.quarterly', { plan: 'threeMonths', amountMinor: 3800, currency: 'CNY', duration: '3个月' }],
  ['com.kilostrength.pro.yearly', { plan: 'yearly', amountMinor: 12800, currency: 'CNY', duration: '12个月' }],
]);
const JOB_STATES = new Set(['created', 'uploading', 'queued', 'processing', 'completed', 'failed', 'cancelled', 'expired']);
const ALLOWED_MEDIA_TYPES = new Set(extensionForType.keys());
const MEDIA_CONTENT_TYPES = new Map([
  ['.mp4', 'video/mp4'], ['.mov', 'video/quicktime'], ['.webm', 'video/webm'],
  ['.jpg', 'image/jpeg'], ['.jpeg', 'image/jpeg'], ['.png', 'image/png'], ['.webp', 'image/webp'],
]);
const FOOD_IMAGE_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);
const FRIEND_WORKOUT_EMOJIS = new Set(['👍', '🔥', '👏', '💪', '❤️', '😂', '😮', '🎉', '🙌', '🥳']);
const FOOD_RECOGNITION_STATUSES = new Set(['created', 'uploading', 'ready', 'processing', 'completed', 'insufficient_image', 'failed', 'cancelled']);
const BASE_RECOGNITION_CAPABILITIES = [
  {
    exerciseId: 'barbell_squat',
    group: '腿部',
    cameras: [
      { id: 'side', label: '正侧面', hint: '镜头与髋部同高，完整拍到头、髋、膝和脚。' },
      { id: 'side_rear', label: '侧后方', hint: '从侧后方完整拍到双脚与杠铃，便于观察膝髋轨迹。' },
      { id: 'front', label: '正前方', hint: '镜头正对身体，完整拍到髋、双膝和双脚，用于观察膝部横向移动。' },
    ],
  },
  {
    exerciseId: 'hip_thrust',
    group: '臀腿',
    cameras: [
      { id: 'side', label: '正侧面', hint: '镜头与髋部同高，完整拍到肩、髋和膝，避免器械遮挡。' },
    ],
  },
  {
    exerciseId: 'romanian_deadlift',
    group: '臀腿',
    cameras: [
      { id: 'side', label: '正侧面', hint: '完整拍到头、肩、髋、膝和脚，镜头保持水平。' },
      { id: 'side_rear', label: '侧后方', hint: '侧后方约 30° 拍摄，确保杠铃与下肢轨迹无遮挡。' },
    ],
  },
  {
    exerciseId: 'lat_pulldown',
    group: '背部',
    cameras: [
      { id: 'rear', label: '正后方', hint: '镜头正对座椅后方，完整拍到双臂、肩胛和躯干。' },
      { id: 'side', label: '正侧面', hint: '镜头与肩部同高，完整拍到手、肩、髋与下拉轨迹。' },
    ],
  },
  { exerciseId: 'goblet_squat', group: '腿部', cameras: [
    { id: 'side', label: '正侧面', hint: '拍全头、髋、膝与双脚，镜头保持水平。' },
    { id: 'side_rear', label: '侧后方', hint: '从侧后方约 30° 拍摄，保留双脚与膝髋轨迹。' },
    { id: 'front', label: '正前方', hint: '镜头正对身体，完整拍到髋、双膝和双脚。' },
  ] },
  { exerciseId: 'deadlift', group: '臀腿', cameras: [
    { id: 'side', label: '正侧面', hint: '完整拍到杠铃、肩、髋、膝和脚。' },
    { id: 'side_rear', label: '侧后方', hint: '侧后方约 30° 拍摄，确保杠铃无遮挡。' },
  ] },
  { exerciseId: 'bench_press', group: '胸部', cameras: [
    { id: 'side', label: '正侧面', hint: '完整拍到杠铃、肩肘、躯干和双脚。' },
    { id: 'side_front', label: '侧前方', hint: '从侧前方约 30° 拍摄可减少遮挡；底部小臂垂直度需正侧面判断。' },
  ] },
  { exerciseId: 'dumbbell_press', group: '胸部', cameras: [
    { id: 'side', label: '正侧面', hint: '拍全哑铃、肩肘、躯干和双脚。' },
    { id: 'side_front', label: '侧前方', hint: '侧前方拍摄可观察两侧路径；底部小臂垂直度需正侧面判断。' },
  ] },
  { exerciseId: 'shoulder_press', group: '肩部', cameras: [
    { id: 'front', label: '正前方', hint: '拍全双手、肩、肘和躯干。' },
    { id: 'side', label: '正侧面', hint: '侧面拍摄，观察躯干与手臂轨迹。' },
  ] },
  { exerciseId: 'push_up', group: '胸部', cameras: [
    { id: 'side', label: '正侧面', hint: '完整拍到头、肩、髋、膝和脚。' },
  ] },
  { exerciseId: 'dip', group: '胸部', cameras: [
    { id: 'side', label: '正侧面', hint: '拍全头、肩肘、髋与双脚，避免器械遮挡。' },
  ] },
  { exerciseId: 'row', group: '背部', cameras: [
    { id: 'side', label: '正侧面', hint: '拍到手、肩、髋和器械完整运动轨迹。' },
    { id: 'rear', label: '正后方', hint: '后方拍摄，观察肩胛与双臂对称性。' },
  ] },
  { exerciseId: 'pull_up', group: '背部', cameras: [
    { id: 'front', label: '正前方', hint: '从正前方拍全单杠、双手和身体。' },
    { id: 'side', label: '正侧面', hint: '侧面拍全身体，避免脚部出画。' },
  ] },
  { exerciseId: 'face_pull', group: '肩背', cameras: [
    { id: 'side', label: '正侧面', hint: '侧面拍到绳索、手肘、肩和躯干。' },
    { id: 'front', label: '正前方', hint: '正面观察双臂轨迹与肩胛对称性。' },
  ] },
  { exerciseId: 'lateral_raise', group: '肩部', cameras: [
    { id: 'front', label: '正前方', hint: '拍全双手、肩、髋和双脚。' },
  ] },
  { exerciseId: 'biceps_curl', group: '手臂', cameras: [
    { id: 'side', label: '正侧面', hint: '拍全肩、肘、手和躯干。' },
    { id: 'front', label: '正前方', hint: '正面观察两侧手臂是否对称。' },
  ] },
  { exerciseId: 'triceps_extension', group: '手臂', cameras: [
    { id: 'side', label: '正侧面', hint: '侧面拍到肩、肘、手与器械轨迹。' },
  ] },
];
const RECOGNITION_CAMERA_PRESETS = {
  side: { id: 'side', label: '正侧面', hint: '镜头保持水平，完整拍到动作使用的肩、肘、腕、髋、膝和脚踝。' },
  side_front: { id: 'side_front', label: '侧前方', hint: '从侧前方约 30° 拍摄，尽量避免器械遮挡四肢。' },
  side_rear: { id: 'side_rear', label: '侧后方', hint: '从侧后方约 30° 拍摄，完整保留身体和器械轨迹。' },
  front: { id: 'front', label: '正前方', hint: '镜头正对身体，完整拍到左右两侧关节，用于判断对称与横向偏移。' },
  rear: { id: 'rear', label: '正后方', hint: '镜头正对身体后方，完整拍到双肩、双臂和下肢。' },
};
const SIDE_RECOGNITION_CAMERAS = ['side', 'side_front', 'side_rear'];
const ALL_RECOGNITION_CAMERAS = [...SIDE_RECOGNITION_CAMERAS, 'front', 'rear'];
const NEW_RECOGNITION_ACTIONS = [
  ['leg_press', '腿部', SIDE_RECOGNITION_CAMERAS],
  ['leg_extension', '腿部', SIDE_RECOGNITION_CAMERAS],
  ['leg_curl', '腿部', SIDE_RECOGNITION_CAMERAS],
  ['bulgarian_split_squat', '腿部', ALL_RECOGNITION_CAMERAS],
  ['barbell_row', '背部', ALL_RECOGNITION_CAMERAS],
  ['yates_row', '背部', ALL_RECOGNITION_CAMERAS],
  ['t_bar_row', '背部', ALL_RECOGNITION_CAMERAS],
  ['chest_supported_row', '背部', ALL_RECOGNITION_CAMERAS],
  ['landmine_one_arm_row', '背部', ALL_RECOGNITION_CAMERAS],
  ['half_kneeling_one_arm_row', '背部', ALL_RECOGNITION_CAMERAS],
  ['standing_one_arm_cable_row', '背部', ALL_RECOGNITION_CAMERAS],
  ['upright_row', '肩背', ALL_RECOGNITION_CAMERAS],
  ['one_arm_dumbbell_row', '背部', ALL_RECOGNITION_CAMERAS],
  ['inverted_row', '背部', ALL_RECOGNITION_CAMERAS],
  ['single_arm_pulldown', '背部', ALL_RECOGNITION_CAMERAS],
  ['straight_arm_pulldown', '背部', ALL_RECOGNITION_CAMERAS],
  ['underhand_pulldown', '背部', ALL_RECOGNITION_CAMERAS],
  ['chest_supported_pulldown', '背部', ALL_RECOGNITION_CAMERAS],
  ['incline_bench_press', '胸部', SIDE_RECOGNITION_CAMERAS],
  ['decline_bench_press', '胸部', SIDE_RECOGNITION_CAMERAS],
  ['close_grip_bench_press', '胸部', ALL_RECOGNITION_CAMERAS],
  ['wide_grip_bench_press', '胸部', ALL_RECOGNITION_CAMERAS],
  ['barbell_floor_press', '胸部', SIDE_RECOGNITION_CAMERAS],
  ['machine_shoulder_press', '肩部', ALL_RECOGNITION_CAMERAS],
  ['machine_chest_press', '胸部', ALL_RECOGNITION_CAMERAS],
  ['single_arm_overhead_press', '肩部', ALL_RECOGNITION_CAMERAS],
  ['push_press', '肩部', ALL_RECOGNITION_CAMERAS],
  ['alternate_dumbbell_press', '胸部', SIDE_RECOGNITION_CAMERAS],
  ['diamond_push_up', '胸部', ALL_RECOGNITION_CAMERAS],
  ['dumbbell_fly', '胸部', ALL_RECOGNITION_CAMERAS],
  ['cable_fly', '胸部', ALL_RECOGNITION_CAMERAS],
  ['low_to_high_cable_fly', '胸部', ALL_RECOGNITION_CAMERAS],
  ['standing_one_arm_cable_fly', '胸部', ALL_RECOGNITION_CAMERAS],
  ['pec_deck_fly', '胸部', ALL_RECOGNITION_CAMERAS],
  ['reverse_fly', '肩背', ALL_RECOGNITION_CAMERAS],
  ['side_lying_lateral_raise', '肩部', SIDE_RECOGNITION_CAMERAS],
  ['dumbbell_front_raise', '肩部', SIDE_RECOGNITION_CAMERAS],
  ['lean_away_lateral_raise', '肩部', ALL_RECOGNITION_CAMERAS],
  ['bent_over_reverse_fly', '肩背', ALL_RECOGNITION_CAMERAS],
  ['cable_reverse_fly', '肩背', ALL_RECOGNITION_CAMERAS],
  ['machine_reverse_fly', '肩背', ALL_RECOGNITION_CAMERAS],
  ['rear_delt_row', '肩背', ALL_RECOGNITION_CAMERAS],
  ['prone_y_raise', '肩背', SIDE_RECOGNITION_CAMERAS],
  ['dumbbell_pullover', '背部', SIDE_RECOGNITION_CAMERAS],
  ['pike_push_up', '肩部', SIDE_RECOGNITION_CAMERAS],
  ['back_extension', '臀腿', SIDE_RECOGNITION_CAMERAS],
  ['landmine_press', '肩部', SIDE_RECOGNITION_CAMERAS],
  ['incline_dumbbell_press', '胸部', SIDE_RECOGNITION_CAMERAS],
  ['decline_dumbbell_press', '胸部', SIDE_RECOGNITION_CAMERAS],
];
const RECOGNITION_CAPABILITIES = [
  ...BASE_RECOGNITION_CAPABILITIES,
  ...NEW_RECOGNITION_ACTIONS.map(([exerciseId, group, cameraIds]) => ({
    exerciseId,
    group,
    cameras: cameraIds.map((cameraId) => RECOGNITION_CAMERA_PRESETS[cameraId]),
  })),
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

export function parseAiSkills(value) {
  if (!Array.isArray(value)) return [];
  return value
    .slice(0, 3)
    .map((item) => ({
      name: String(item?.name || '').trim().slice(0, 60),
      instructions: String(item?.instructions || '').trim().slice(0, 2000),
    }))
    .filter((item) => item.name && item.instructions);
}

function addMonths(from, months) {
  const d = new Date(from);
  const day = d.getUTCDate();
  d.setUTCDate(1);
  d.setUTCMonth(d.getUTCMonth() + months);
  const max = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate();
  d.setUTCDate(Math.min(day, max));
  return d;
}

function recognitionResultWithEvidenceUrls(row, cfg) {
  if (!row?.result_json) return null;
  const result = JSON.parse(row.result_json);
  if (!Array.isArray(result?.events)) return result;
  return {
    ...result,
    events: result.events.map((event) => {
      const evidenceId = typeof event?.evidenceId === 'string' ? event.evidenceId : '';
      return {
        ...event,
        evidenceImageUrl: evidenceId
          ? `${cfg.publicBaseUrl}/v1/analysis/jobs/${encodeURIComponent(row.id)}/media/evidence/${encodeURIComponent(evidenceId)}`
          : null,
      };
    }),
  };
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
    result: recognitionResultWithEvidenceUrls(row, cfg),
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
  if (kind === 'preview' || kind === 'evidence') return contentType.startsWith('image/');
  return kind === 'overlay' && (contentType.startsWith('image/') || contentType.startsWith('video/'));
}

function requireEvidenceArtifactId(value) {
  const artifactId = String(value || '').trim();
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(artifactId)) {
    throw httpError(400, 'invalid_artifact_id');
  }
  return artifactId;
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

function friendPairKey(firstUserId, secondUserId) {
  return [firstUserId, secondUserId].sort().join(':');
}

function publicIdentity(row) {
  return {
    kind: row.kind,
    value: row.kind === 'username' ? row.display_value : undefined,
    maskedValue: maskUserIdentity(row.kind, row.display_value),
    source: row.source,
    verified: Boolean(row.verified_at),
    searchable: Boolean(row.searchable),
  };
}

function friendRelationship(db, firstUserId, secondUserId) {
  const request = db.prepare('SELECT * FROM friend_requests WHERE pair_key = ?')
    .get(friendPairKey(firstUserId, secondUserId));
  if (!request || (request.status !== 'pending' && request.status !== 'accepted')) return 'none';
  if (request.status === 'accepted') return 'friends';
  return request.sender_user_id === firstUserId ? 'outgoing_pending' : 'incoming_pending';
}

function friendSearchKind(query) {
  if (query.includes('@')) {
    const normalized = normalizeEmail(query);
    if (!normalized) throw httpError(400, 'invalid_friend_search');
    return { kind: 'email', normalized, prefix: false };
  }
  const phone = normalizePhone(query);
  if (phone) return { kind: 'phone', normalized: phone, prefix: false };
  const username = normalizeUsername(query);
  if (!username || username.length < 2) throw httpError(400, 'invalid_friend_search');
  return { kind: 'username', normalized: username, prefix: true };
}

function enforceFriendSearchRateLimit(ctx, user, req) {
  const now = Date.now();
  const key = `${user.id}:${req.socket.remoteAddress || 'unknown'}`;
  const recent = (ctx.friendSearchWindows.get(key) || []).filter((stamp) => now - stamp < 60_000);
  if (recent.length >= 30) throw httpError(429, 'friend_search_rate_limited', { retryAfterSeconds: 60 });
  recent.push(now);
  ctx.friendSearchWindows.set(key, recent);
}

function areFriends(db, firstUserId, secondUserId) {
  return Boolean(db.prepare("SELECT 1 FROM friend_requests WHERE pair_key = ? AND status = 'accepted'")
    .get(friendPairKey(firstUserId, secondUserId)));
}

function optionalFiniteNumber(value, code, { min = 0, max = Number.MAX_SAFE_INTEGER, integer = false } = {}) {
  if (value === undefined || value === null || value === '') return null;
  const number = Number(value);
  if (!Number.isFinite(number) || number < min || number > max || (integer && !Number.isInteger(number))) {
    throw httpError(400, code);
  }
  return number;
}

function optionalIsoTimestamp(value, code) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string') throw httpError(400, code);
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) throw httpError(400, code);
  return date.toISOString();
}

function workoutExerciseSnapshot(value) {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 50).map((item) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
    const exerciseId = String(item.exerciseId || item.id || '').trim().slice(0, 120);
    const name = String(item.name || item.label || item.exerciseName || exerciseId || '动作').trim().slice(0, 120);
    const rawSets = Array.isArray(item.sets) ? item.sets.length : item.sets ?? item.setCount ?? item.completedSets;
    const sets = optionalFiniteNumber(rawSets, 'invalid_workout_exercise_sets', { min: 0, max: 1000, integer: true });
    const topWeight = optionalFiniteNumber(item.topWeight ?? item.weight, 'invalid_workout_exercise_weight', { min: 0, max: 100000 });
    const topReps = optionalFiniteNumber(item.topReps ?? item.reps, 'invalid_workout_exercise_reps', { min: 0, max: 1000, integer: true });
    return { exerciseId: exerciseId || null, name, sets: sets === null ? 0 : sets, topWeight, topReps };
  }).filter(Boolean);
}

function workoutSnapshotFromBody(body) {
  const source = body.snapshot && typeof body.snapshot === 'object' && !Array.isArray(body.snapshot)
    ? body.snapshot
    : body.workout && typeof body.workout === 'object' && !Array.isArray(body.workout)
      ? body.workout
      : body;
  const sourceWorkoutId = requireString(
    body.sourceWorkoutId || body.workoutId || source.sourceWorkoutId || source.workoutId || source.id,
    'source_workout_id_required',
    200,
  );
  const completedAt = optionalIsoTimestamp(
    body.completedAt || body.finishedAt || source.completedAt || source.finishedAt,
    'completed_at_required',
  );
  if (!completedAt && body.completed !== true && source.completed !== true) throw httpError(400, 'workout_not_completed');
  const completed = completedAt || nowIso();
  const startedAt = optionalIsoTimestamp(body.startedAt || source.startedAt, 'invalid_started_at');
  if (startedAt && new Date(startedAt) > new Date(completed)) throw httpError(400, 'invalid_workout_time_range');
  const durationSeconds = optionalFiniteNumber(
    body.durationSeconds ?? body.duration ?? source.durationSeconds ?? source.duration,
    'invalid_duration_seconds',
    { min: 0, max: 7 * 24 * 60 * 60, integer: true },
  );
  const volumeKg = optionalFiniteNumber(
    body.volumeKg ?? body.volume ?? body.totalVolume ?? source.volumeKg ?? source.volume ?? source.totalVolume,
    'invalid_workout_volume',
    { min: 0, max: 10000000 },
  );
  let completionRate = optionalFiniteNumber(
    body.completionRate ?? body.completionPercent ?? body.completedRate ?? source.completionRate ?? source.completionPercent ?? source.completedRate,
    'invalid_completion_rate',
    { min: 0, max: 100 },
  );
  if (completionRate !== null && completionRate > 1) completionRate /= 100;
  const effectiveSets = optionalFiniteNumber(
    body.effectiveSets ?? body.setsCompleted ?? source.effectiveSets ?? source.setsCompleted,
    'invalid_effective_sets',
    { min: 0, max: 10000, integer: true },
  );
  const exercises = workoutExerciseSnapshot(body.exercises || body.exerciseSummary || source.exercises || source.exerciseSummary);
  const rawName = body.name || body.title || body.workoutName || source.name || source.title || source.workoutName || '训练完成';
  const name = requireString(String(rawName), 'workout_name_required', 160);
  const rawCaption = body.caption ?? body.publishNote ?? body.note ?? source.caption ?? source.publishNote;
  if (rawCaption !== undefined && rawCaption !== null && typeof rawCaption !== 'string') throw httpError(400, 'invalid_workout_caption');
  const caption = rawCaption ? rawCaption.trim().slice(0, 280) : null;
  return { sourceWorkoutId, name, startedAt, completedAt: completed, durationSeconds, volumeKg, effectiveSets, completionRate, exercises, caption };
}

function parseWorkoutExercises(value) {
  try {
    const parsed = JSON.parse(value || '[]');
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function workoutPostRowsForViewer(db, viewerId, postId = null) {
  const idClause = postId ? 'AND p.id = ?' : '';
  const params = postId
    ? [viewerId, viewerId, viewerId, viewerId, postId]
    : [viewerId, viewerId, viewerId, viewerId];
  return db.prepare(`SELECT p.*, u.display_name,
      (SELECT COUNT(*) FROM friend_workout_post_likes l WHERE l.post_id = p.id) AS like_count,
      EXISTS (SELECT 1 FROM friend_workout_post_likes mine WHERE mine.post_id = p.id AND mine.user_id = ?) AS liked_by_me,
      (SELECT COUNT(*) FROM friend_workout_post_comments c WHERE c.post_id = p.id) AS comment_count
    FROM friend_workout_posts p JOIN users u ON u.id = p.owner_user_id
    WHERE p.owner_user_id = ? OR EXISTS (
      SELECT 1 FROM friend_requests fr
      WHERE fr.status = 'accepted'
        AND ((fr.sender_user_id = ? AND fr.receiver_user_id = p.owner_user_id)
          OR (fr.receiver_user_id = ? AND fr.sender_user_id = p.owner_user_id))
    ) ${idClause}
    ORDER BY p.completed_at DESC, p.created_at DESC LIMIT 100`).all(...params);
}

function publicWorkoutPost(row, db, viewerId, { includeComments = false } = {}) {
  const exercises = parseWorkoutExercises(row.exercises_json);
  const emojiCounts = {};
  db.prepare('SELECT emoji, COUNT(*) AS count FROM friend_workout_post_comments WHERE post_id = ? GROUP BY emoji').all(row.id)
    .forEach((item) => { emojiCounts[item.emoji] = Number(item.count); });
  const result = {
    id: row.id,
    type: 'workout',
    ownerId: row.owner_user_id,
    ownerName: row.display_name,
    sourceWorkoutId: row.source_workout_id,
    name: row.name,
    workoutName: row.name,
    startedAt: row.started_at,
    completedAt: row.completed_at,
    durationSeconds: row.duration_seconds === null ? null : Number(row.duration_seconds),
    volumeKg: row.volume_kg === null ? null : Number(row.volume_kg),
    volume: row.volume_kg === null ? null : Number(row.volume_kg),
    effectiveSets: row.effective_sets === null ? null : Number(row.effective_sets),
    completionRate: row.completion_rate === null ? null : Number(row.completion_rate),
    completionPercent: row.completion_rate === null ? null : Math.round(Number(row.completion_rate) * 100),
    exercises,
    exerciseSummary: exercises,
    caption: row.caption || null,
    likeCount: Number(row.like_count || 0),
    likedByMe: Boolean(row.liked_by_me),
    liked: Boolean(row.liked_by_me),
    commentCount: Number(row.comment_count || 0),
    emojiCounts,
    commentCounts: emojiCounts,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
  if (includeComments) {
    result.comments = db.prepare(`SELECT c.id, c.user_id, u.display_name, c.emoji, c.created_at
      FROM friend_workout_post_comments c JOIN users u ON u.id = c.user_id
      WHERE c.post_id = ? ORDER BY c.created_at ASC LIMIT 100`).all(row.id)
      .map((comment) => ({ id: comment.id, userId: comment.user_id, userName: comment.display_name, emoji: comment.emoji, createdAt: comment.created_at }));
  }
  return result;
}

function workoutPostForViewer(db, postId, viewerId, options = {}) {
  const rows = workoutPostRowsForViewer(db, viewerId, postId);
  if (!rows.length) throw httpError(404, 'workout_post_not_found');
  return publicWorkoutPost(rows[0], db, viewerId, options);
}

function foodVisionSettings(ctx) {
  const cfg = ctx.cfg || {};
  const env = process.env;
  const pick = (configNames, envNames, fallback = '') => {
    for (const name of configNames) {
      if (cfg[name] !== undefined && cfg[name] !== null && String(cfg[name]).trim()) return String(cfg[name]).trim();
    }
    for (const name of envNames) {
      if (env[name] !== undefined && env[name] !== null && String(env[name]).trim()) return String(env[name]).trim();
    }
    return fallback;
  };
  const positiveInt = (value, fallback) => {
    const parsed = Number(value);
    return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : fallback;
  };
  const baseUrl = pick(['foodVisionBaseUrl'], ['KILO_FOOD_VISION_BASE_URL', 'FOOD_VISION_BASE_URL']);
  const apiKey = pick(['foodVisionApiKey'], ['KILO_FOOD_VISION_API_KEY', 'FOOD_VISION_API_KEY']);
  const model = pick(['foodVisionModel'], ['KILO_FOOD_VISION_MODEL', 'FOOD_VISION_MODEL']);
  const endpoint = pick(['foodVisionEndpoint'], ['KILO_FOOD_VISION_ENDPOINT', 'FOOD_VISION_ENDPOINT']);
  return {
    baseUrl: baseUrl.replace(/\/+$/, ''),
    apiKey,
    model,
    endpoint,
    timeoutSeconds: Math.min(180, positiveInt(pick(['foodVisionTimeoutSeconds'], ['KILO_FOOD_VISION_TIMEOUT_SECONDS']), 60)),
    maxImages: Math.min(12, positiveInt(pick(['foodVisionMaxImages'], ['KILO_FOOD_VISION_MAX_IMAGES']), 8)),
    maxImageBytes: Math.min(25 * 1024 * 1024, positiveInt(pick(['foodVisionMaxImageBytes'], ['KILO_FOOD_VISION_MAX_IMAGE_BYTES']), 12 * 1024 * 1024)),
    maxTotalBytes: Math.min(80 * 1024 * 1024, positiveInt(pick(['foodVisionMaxTotalBytes'], ['KILO_FOOD_VISION_MAX_TOTAL_BYTES']), 40 * 1024 * 1024)),
  };
}

function assertFoodVisionConfigured(settings) {
  const missing = [];
  if (!settings.baseUrl && !settings.endpoint) missing.push('baseUrl');
  if (!settings.apiKey) missing.push('apiKey');
  if (!settings.model) missing.push('model');
  if (missing.length) throw httpError(503, 'service_not_configured', { service: 'food_vision', missing });
}

function foodVisionUrl(settings) {
  const raw = settings.endpoint || settings.baseUrl;
  if (!raw) throw httpError(503, 'service_not_configured', { service: 'food_vision', missing: ['baseUrl'] });
  let parsed;
  try { parsed = new URL(raw); } catch { throw httpError(500, 'invalid_food_vision_url'); }
  if (!['http:', 'https:'].includes(parsed.protocol)) throw httpError(500, 'invalid_food_vision_url');
  if (settings.endpoint) return parsed.toString();
  return `${raw.endsWith('/chat/completions') ? raw : `${raw}/chat/completions`}`;
}

function decodeFoodImage(value, settings) {
  let dataBase64;
  let contentType;
  if (typeof value === 'string') {
    const match = value.match(/^data:([^;,]+);base64,(.*)$/su);
    if (!match) throw httpError(400, 'invalid_food_image');
    contentType = match[1].toLowerCase();
    dataBase64 = match[2];
  } else if (value && typeof value === 'object' && !Array.isArray(value)) {
    const dataUrl = typeof value.dataUrl === 'string' ? value.dataUrl : '';
    const match = dataUrl.match(/^data:([^;,]+);base64,(.*)$/su);
    contentType = String(value.contentType || (match && match[1]) || '').split(';')[0].trim().toLowerCase();
    dataBase64 = value.dataBase64 || (match && match[2]);
  }
  if (!FOOD_IMAGE_TYPES.has(contentType) || typeof dataBase64 !== 'string') throw httpError(400, 'invalid_food_image');
  const compact = dataBase64.replace(/\s+/g, '');
  if (!compact || compact.length % 4 === 1 || !/^[A-Za-z0-9+/]*={0,2}$/u.test(compact)) throw httpError(400, 'invalid_food_image');
  const bytes = Buffer.from(compact, 'base64');
  if (!bytes.length) throw httpError(400, 'invalid_food_image');
  if (bytes.length > settings.maxImageBytes) throw httpError(413, 'food_image_too_large', { maxBytes: settings.maxImageBytes });
  return { contentType, bytes };
}

function foodImagesFromBody(body, settings) {
  const images = body.images || body.photos;
  if (!Array.isArray(images) || images.length < 1 || images.length > settings.maxImages) {
    throw httpError(400, 'food_images_required', { minImages: 1, maxImages: settings.maxImages });
  }
  const decoded = images.map((item) => decodeFoodImage(item, settings));
  const total = decoded.reduce((sum, item) => sum + item.bytes.length, 0);
  if (total > settings.maxTotalBytes) throw httpError(413, 'food_images_too_large', { maxBytes: settings.maxTotalBytes });
  return decoded;
}

async function readMultipartFoodImages(req, settings) {
  const header = String(req.headers['content-type'] || '');
  const match = header.match(/^multipart\/form-data;\s*boundary=(?:"([^"]+)"|([^;]+))/iu);
  if (!match) throw httpError(415, 'multipart_content_type_required');
  const boundary = match[1] || match[2];
  const maxRequestBytes = settings.maxTotalBytes + settings.maxImages * 4096;
  const contentLength = Number(req.headers['content-length'] || 0);
  if (contentLength > maxRequestBytes) throw httpError(413, 'food_images_too_large', { maxBytes: settings.maxTotalBytes });
  const chunks = [];
  let total = 0;
  for await (const chunk of req) {
    total += chunk.length;
    if (total > maxRequestBytes) throw httpError(413, 'food_images_too_large', { maxBytes: settings.maxTotalBytes });
    chunks.push(chunk);
  }
  const raw = Buffer.concat(chunks);
  const delimiter = Buffer.from(`--${boundary}`);
  const headerDelimiter = Buffer.from('\r\n\r\n');
  const images = [];
  let cursor = 0;
  while (cursor < raw.length) {
    const marker = raw.indexOf(delimiter, cursor);
    if (marker < 0) break;
    let partStart = marker + delimiter.length;
    if (raw[partStart] === 45 && raw[partStart + 1] === 45) break;
    if (raw[partStart] === 13 && raw[partStart + 1] === 10) partStart += 2;
    const contentStart = raw.indexOf(headerDelimiter, partStart);
    if (contentStart < 0) break;
    const headerText = raw.subarray(partStart, contentStart).toString('utf8');
    const contentEnd = raw.indexOf(Buffer.from(`\r\n--${boundary}`), contentStart + headerDelimiter.length);
    if (contentEnd < 0) break;
    const dispositionText = headerText.match(/content-disposition:[^\r\n]*/iu)?.[0] || '';
    const disposition = dispositionText.match(/\bname="([^"]+)"/iu);
    const filename = dispositionText.match(/\bfilename="([^"]*)"/iu)?.[1] || '';
    const declaredType = headerText.match(/content-type:\s*([^\r\n;]+)/iu)?.[1]?.trim().toLowerCase() || '';
    const inferredType = MEDIA_CONTENT_TYPES.get(path.extname(filename).toLowerCase());
    const type = FOOD_IMAGE_TYPES.has(declaredType) ? declaredType : inferredType;
    if (disposition?.[1] === 'images' && type && FOOD_IMAGE_TYPES.has(type)) {
      const bytes = raw.subarray(contentStart + headerDelimiter.length, contentEnd);
      if (bytes.length > settings.maxImageBytes) throw httpError(413, 'food_image_too_large', { maxBytes: settings.maxImageBytes });
      images.push({ contentType: type, bytes });
      if (images.length > settings.maxImages) throw httpError(400, 'food_images_too_many', { maxImages: settings.maxImages });
    }
    cursor = contentEnd + 2;
  }
  if (!images.length) throw httpError(400, 'food_images_required', { minImages: 1, maxImages: settings.maxImages });
  const imageBytes = images.reduce((sum, image) => sum + image.bytes.length, 0);
  if (imageBytes > settings.maxTotalBytes) throw httpError(413, 'food_images_too_large', { maxBytes: settings.maxTotalBytes });
  if (images.some((image) => !image.bytes.length)) throw httpError(400, 'empty_food_image');
  return images;
}

function numberOrNull(value, { min = 0, max = 10000000 } = {}) {
  const number = Number(value);
  return Number.isFinite(number) && number >= min && number <= max ? number : null;
}

function nutritionRange(value, max = 10000000) {
  let pair = value;
  if (value && typeof value === 'object' && !Array.isArray(value)) pair = [value.min, value.max];
  if (!Array.isArray(pair) || pair.length !== 2) return null;
  const first = numberOrNull(pair[0], { max });
  const second = numberOrNull(pair[1], { max });
  if (first === null || second === null) return null;
  return [Math.min(first, second), Math.max(first, second)];
}

function nutritionCandidate(item, modelName) {
  if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
  const label = String(item.label || item.name || item.foodName || '').trim().slice(0, 160);
  const confidence = numberOrNull(item.confidence, { min: 0, max: 1 });
  if (!label || confidence === null) return null;
  const estimatedGrams = numberOrNull(item.estimatedGrams ?? item.grams ?? item.portionGrams, { max: 100000 });
  const estimatedCalories = numberOrNull(item.estimatedCalories ?? item.calories ?? item.kcal, { max: 1000000 });
  const calorieRange = nutritionRange(item.calorieRange || item.caloriesRange, 1000000);
  const proteinGrams = numberOrNull(item.proteinGrams ?? item.protein ?? item.protein_g, { max: 100000 });
  const proteinRange = nutritionRange(item.proteinRange, 100000);
  const carbohydratesGrams = numberOrNull(item.carbohydratesGrams ?? item.carbsGrams ?? item.carbohydrates ?? item.carbs, { max: 100000 });
  const carbohydratesRange = nutritionRange(item.carbohydratesRange || item.carbsRange, 100000);
  const fatGrams = numberOrNull(item.fatGrams ?? item.fat ?? item.fat_g, { max: 100000 });
  const fatRange = nutritionRange(item.fatRange, 100000);
  const uncertaintyValue = String(item.uncertainty || item.uncertaintyLevel || '').trim().toLowerCase();
  const uncertainty = ['low', 'medium', 'high'].includes(uncertaintyValue) ? uncertaintyValue : 'unknown';
  const source = String(item.nutritionSource || item.source || modelName).trim().slice(0, 160) || modelName;
  return {
    label,
    confidence,
    estimatedGrams,
    estimatedCalories,
    calorieRange,
    proteinGrams,
    proteinRange,
    carbohydratesGrams,
    carbohydratesRange,
    fatGrams,
    fatRange,
    portionDescription: String(item.portionDescription || item.portion || '').trim().slice(0, 160) || null,
    uncertainty,
    nutritionSource: source,
  };
}

function parseFoodVisionContent(content) {
  if (content && typeof content === 'object' && !Array.isArray(content)) return content;
  const text = Array.isArray(content)
    ? content.map((part) => typeof part === 'string' ? part : String(part?.text || '')).join('')
    : String(content || '').trim();
  if (!text) throw httpError(502, 'food_vision_invalid_response');
  const unfenced = text.replace(/^```(?:json)?\s*/iu, '').replace(/\s*```$/u, '').trim();
  try { return JSON.parse(unfenced); } catch {
    const start = unfenced.indexOf('{');
    const end = unfenced.lastIndexOf('}');
    if (start < 0 || end <= start) throw httpError(502, 'food_vision_invalid_response');
    try { return JSON.parse(unfenced.slice(start, end + 1)); } catch { throw httpError(502, 'food_vision_invalid_response'); }
  }
}

function normalizeFoodVisionResult(raw, modelName, imageCount) {
  const source = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
  const sourceItems = Array.isArray(source.items)
    ? source.items
    : Array.isArray(source.foods)
      ? source.foods
      : Array.isArray(source.candidates)
        ? source.candidates
        : [];
  const items = sourceItems.map((item) => nutritionCandidate(item, modelName)).filter(Boolean).slice(0, 30);
  const warnings = Array.isArray(source.warnings)
    ? source.warnings.map((item) => String(item).trim().slice(0, 300)).filter(Boolean).slice(0, 20)
    : [];
  warnings.push('视觉识别结果包含估算值，保存前请复核食物和份量。');
  if (!items.length) warnings.push('当前图片没有识别到可确认的食物。');
  return {
    schemaVersion: 'food-photo-v1',
    status: items.length ? 'completed' : 'insufficient_image',
    requiresReview: true,
    imageCount,
    modelVersion: String(source.modelVersion || source.model || modelName).slice(0, 120),
    items,
    warnings: [...new Set(warnings)],
  };
}

async function callFoodVision(ctx, images) {
  const settings = foodVisionSettings(ctx);
  assertFoodVisionConfigured(settings);
  const content = [
    {
      type: 'text',
      text: '请识别这些食物照片中的食物，并只返回 JSON。每种食物给出 label、confidence（0 到 1）、estimatedGrams、estimatedCalories、calorieRange、proteinGrams、proteinRange、carbohydratesGrams、carbohydratesRange、fatGrams、fatRange、portionDescription、uncertainty（low/medium/high）和 nutritionSource。无法判断的数字必须为 null，不得猜测；calorieRange 和各营养素范围应为 [下限,上限] 或 null。顶层使用 items 数组和 warnings 数组。所有结果都需要用户复核。',
    },
    ...images.map((image) => ({
      type: 'image_url',
      image_url: { url: `data:${image.contentType};base64,${image.bytes.toString('base64')}` },
    })),
  ];
  const body = {
    model: settings.model,
    messages: [{ role: 'user', content }],
    temperature: 0.1,
    max_tokens: 1800,
    response_format: { type: 'json_object' },
  };
  let response;
  try {
    response = await fetch(foodVisionUrl(settings), {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${settings.apiKey}` },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(settings.timeoutSeconds * 1000),
    });
  } catch (error) {
    if (error?.name === 'AbortError' || error?.name === 'TimeoutError') throw httpError(504, 'food_vision_timeout');
    throw httpError(502, 'food_vision_unavailable');
  }
  const responseText = await response.text();
  if (!response.ok) throw httpError(response.status === 429 ? 503 : 502, 'food_vision_upstream_error', { upstreamStatus: response.status });
  let payload;
  try { payload = JSON.parse(responseText); } catch { throw httpError(502, 'food_vision_invalid_response'); }
  const message = payload?.choices?.[0]?.message?.content ?? payload?.output_text ?? payload;
  const rawResult = parseFoodVisionContent(message);
  return normalizeFoodVisionResult(rawResult, settings.model, images.length);
}

function parseFoodResult(value) {
  if (!value) return null;
  try { return typeof value === 'string' ? JSON.parse(value) : value; } catch { return null; }
}

function publicFoodJob(row, db, cfg) {
  const images = db.prepare('SELECT id, position, content_type, byte_size, uploaded_at FROM nutrition_recognition_images WHERE job_id = ? ORDER BY position').all(row.id);
  return {
    id: row.id,
    status: row.status,
    imageCount: images.length,
    images: images.map((image) => ({ id: image.id, position: Number(image.position), contentType: image.content_type === 'application/octet-stream' ? null : image.content_type, bytes: Number(image.byte_size), uploaded: Boolean(image.uploaded_at) })),
    modelVersion: row.model_version,
    result: parseFoodResult(row.result_json),
    error: row.error_code,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    completedAt: row.completed_at,
  };
}

function foodJobForUser(db, id, userId) {
  const row = db.prepare('SELECT * FROM nutrition_recognition_jobs WHERE id = ? AND user_id = ?').get(id, userId);
  if (!row) throw httpError(404, 'food_recognition_not_found');
  return row;
}

function createFoodJob(db, userId, imageCount) {
  const id = randomId('food_job_');
  const stamp = nowIso();
  transaction(db, () => {
    db.prepare(`INSERT INTO nutrition_recognition_jobs (id, user_id, status, result_json, error_code, model_version, created_at, updated_at, completed_at)
      VALUES (?, ?, 'created', NULL, NULL, NULL, ?, ?, NULL)`).run(id, userId, stamp, stamp);
    const insert = db.prepare(`INSERT INTO nutrition_recognition_images (id, job_id, position, storage_key, content_type, byte_size, created_at, uploaded_at)
      VALUES (?, ?, ?, '', 'application/octet-stream', 0, ?, NULL)`);
    for (let position = 0; position < imageCount; position += 1) insert.run(randomId('food_img_'), id, position, stamp);
  });
  return db.prepare('SELECT * FROM nutrition_recognition_jobs WHERE id = ?').get(id);
}

async function processFoodJob(ctx, jobId, userId) {
  const current = foodJobForUser(ctx.db, jobId, userId);
  if (current.status !== 'ready') throw httpError(409, 'food_images_not_ready', { status: current.status });
  const changed = ctx.db.prepare("UPDATE nutrition_recognition_jobs SET status = 'processing', error_code = NULL, updated_at = ? WHERE id = ? AND user_id = ? AND status = 'ready'").run(nowIso(), jobId, userId);
  if (changed.changes !== 1) throw httpError(409, 'food_recognition_in_progress');
  const images = ctx.db.prepare('SELECT * FROM nutrition_recognition_images WHERE job_id = ? ORDER BY position').all(jobId);
  try {
    const buffers = await Promise.all(images.map(async (image) => ({ contentType: image.content_type, bytes: await fs.promises.readFile(ctx.storage.resolve(image.storage_key)) })));
    const result = await callFoodVision(ctx, buffers);
    const stamp = nowIso();
    ctx.db.prepare(`UPDATE nutrition_recognition_jobs SET status = ?, result_json = ?, model_version = ?, error_code = NULL, completed_at = ?, updated_at = ? WHERE id = ? AND status = 'processing'`)
      .run(result.status, JSON.stringify(result), result.modelVersion, stamp, stamp, jobId);
  } catch (error) {
    const code = error?.code || 'food_vision_unavailable';
    ctx.db.prepare("UPDATE nutrition_recognition_jobs SET status = 'failed', error_code = ?, completed_at = ?, updated_at = ? WHERE id = ? AND status = 'processing'")
      .run(code, nowIso(), nowIso(), jobId);
    throw error;
  }
  return publicFoodJob(ctx.db.prepare('SELECT * FROM nutrition_recognition_jobs WHERE id = ?').get(jobId), ctx.db, ctx.cfg);
}

async function attachFoodImages(ctx, jobId, userId, decodedImages) {
  const rows = ctx.db.prepare('SELECT * FROM nutrition_recognition_images WHERE job_id = ? ORDER BY position').all(jobId);
  if (rows.length !== decodedImages.length) throw httpError(409, 'food_image_count_mismatch');
  try {
    for (let index = 0; index < rows.length; index += 1) {
      const row = rows[index];
      const image = decodedImages[index];
      const key = `food/${userId}/${jobId}/${row.id}${extensionForType.get(image.contentType) || '.bin'}`;
      await ctx.storage.putBuffer(key, image.bytes, { maxBytes: foodVisionSettings(ctx).maxImageBytes });
      ctx.db.prepare(`UPDATE nutrition_recognition_images SET storage_key = ?, content_type = ?, byte_size = ?, uploaded_at = ? WHERE id = ? AND job_id = ?`)
        .run(key, image.contentType, image.bytes.length, nowIso(), row.id, jobId);
    }
    ctx.db.prepare("UPDATE nutrition_recognition_jobs SET status = 'ready', updated_at = ? WHERE id = ? AND user_id = ? AND status IN ('created', 'uploading')")
      .run(nowIso(), jobId, userId);
  } catch (error) {
    ctx.db.prepare("UPDATE nutrition_recognition_jobs SET status = 'failed', error_code = ?, completed_at = ?, updated_at = ? WHERE id = ? AND user_id = ? AND status NOT IN ('completed', 'failed', 'cancelled')")
      .run(error?.code || 'food_image_upload_failed', nowIso(), nowIso(), jobId, userId);
    throw error;
  }
}

function entitlementFor(db, userId) {
  return transaction(db, () => publicEntitlement(ensureEntitlement(db, userId)));
}

function requireActiveMembership(db, userId) {
  const entitlement = ensureEntitlement(db, userId);
  if (!membershipActive(entitlement)) throw httpError(403, 'membership_required');
  return entitlement;
}

function membershipFor(db, userId, plan) {
  const current = ensureEntitlement(db, userId);
  const currentActive = membershipActive(current);
  if (plan === 'forever' || current.membership === 'forever') {
    return { membership: 'forever', membershipExpiresAt: null };
  }
  const months = plan === 'yearly' ? 12 : plan === 'threeMonths' ? 3 : 1;
  const start = currentActive && current.membership_expires_at ? new Date(current.membership_expires_at) : new Date();
  const rank = { free: 0, oneMonth: 1, threeMonths: 2, yearly: 3, forever: 4 };
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
  const quotaExempt = db.prepare('SELECT role FROM users WHERE id = ?').get(userId)?.role === 'admin';
  if (!quotaExempt) {
    if (Number(ent[column]) <= 0) throw httpError(409, 'quota_exhausted', { kind });
    db.prepare(`UPDATE entitlements SET ${column} = ${column} - 1, updated_at = ? WHERE user_id = ? AND ${column} > 0`)
      .run(nowIso(), userId);
  }
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
    const quotaExempt = db.prepare('SELECT role FROM users WHERE id = ?').get(userId)?.role === 'admin';
    if (!quotaExempt) {
      const column = row.kind === 'ai' ? 'ai_remaining' : 'recognition_remaining';
      db.prepare(`UPDATE entitlements SET ${column} = ${column} + 1, updated_at = ? WHERE user_id = ?`).run(nowIso(), userId);
    }
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

function validateAgentDate(value, code) {
  if (value === undefined || value === null || value === '') return undefined;
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/u.test(value)) throw httpError(400, code);
  const date = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value) throw httpError(400, code);
  return value;
}

function validateAgentArguments(name, value) {
  if (!AI_TOOL_NAMES.has(name) || !value || typeof value !== 'object' || Array.isArray(value)) throw httpError(400, 'invalid_ai_tool_arguments');
  const args = { ...value };
  const allowed = name === 'read_training_plans'
    ? new Set(['query', 'limit'])
    : name === 'read_workout_history'
      ? new Set(['startDate', 'endDate', 'query', 'limit'])
      : new Set();
  for (const key of Object.keys(args)) if (!allowed.has(key)) throw httpError(400, 'invalid_ai_tool_argument');
  if (args.query !== undefined && (typeof args.query !== 'string' || args.query.length > 100)) throw httpError(400, 'invalid_ai_tool_query');
  if (args.limit !== undefined && (!Number.isInteger(args.limit) || args.limit < 1 || args.limit > (name === 'read_training_plans' ? 10 : 20))) throw httpError(400, 'invalid_ai_tool_limit');
  if (name === 'read_workout_history') {
    args.startDate = validateAgentDate(args.startDate, 'invalid_ai_tool_start_date');
    args.endDate = validateAgentDate(args.endDate, 'invalid_ai_tool_end_date');
    if (args.startDate && args.endDate && args.startDate > args.endDate) throw httpError(400, 'invalid_ai_tool_date_range');
  }
  if (name === 'read_active_workout' && Object.keys(args).length) throw httpError(400, 'invalid_ai_tool_argument');
  return args;
}

function parseModelToolCalls(rawCalls) {
  if (!Array.isArray(rawCalls) || !rawCalls.length) return [];
  if (rawCalls.length > MAX_AGENT_TOOL_RESULTS) throw httpError(502, 'too_many_ai_tool_calls');
  return rawCalls.map((item) => {
    const id = String(item?.id || '').slice(0, 120);
    const fn = item?.function || {};
    const name = String(fn.name || '').trim();
    if (!id || !AI_TOOL_NAMES.has(name)) throw httpError(502, 'invalid_ai_tool_call');
    let args;
    try { args = typeof fn.arguments === 'string' ? JSON.parse(fn.arguments || '{}') : fn.arguments; } catch { throw httpError(502, 'invalid_ai_tool_arguments'); }
    return { id, name, arguments: validateAgentArguments(name, args || {}) };
  });
}

function parseClientToolResults(value) {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > MAX_AGENT_TOOL_RESULTS) throw httpError(400, 'invalid_ai_tool_results');
  return value.map((item) => {
    const id = requireString(item?.id, 'tool_result_id_required', 120);
    const name = requireString(item?.name, 'tool_result_name_required', 80);
    const argumentsValue = validateAgentArguments(name, item?.arguments || {});
    if (!Object.prototype.hasOwnProperty.call(item, 'result')) throw httpError(400, 'tool_result_required');
    let resultJson;
    try { resultJson = JSON.stringify(item.result); } catch { throw httpError(400, 'invalid_ai_tool_result'); }
    if (resultJson.length > MAX_AGENT_RESULT_BYTES) throw httpError(413, 'ai_tool_result_too_large');
    return { id, name, arguments: argumentsValue, result: item.result };
  });
}

// The mobile client sends its local registry so the server can tell whether
// the user actually granted the agent read access. Never trust the registry's
// descriptions or schemas: the server owns the canonical allow-list above.
// Rejecting unknown/duplicate names also prevents a future client bug from
// silently turning on an unreviewed tool.
function parseClientAvailableTools(value) {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > AI_TOOL_DEFINITIONS.length) {
    throw httpError(400, 'invalid_ai_tools');
  }
  const names = [];
  for (const item of value) {
    const name = String(item?.function?.name || '').trim();
    if (!AI_TOOL_NAMES.has(name) || names.includes(name)) {
      throw httpError(400, 'invalid_ai_tools');
    }
    names.push(name);
  }
  return names;
}

function toolUsesFor(names) {
  const counts = new Map();
  for (const name of names) counts.set(name, (counts.get(name) || 0) + 1);
  return [...counts.entries()].map(([name, count]) => ({ name, count }));
}

async function callDeepSeek(ctx, messages, userId, options = {}) {
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
        ...(options.tools?.length ? { tools: options.tools, tool_choice: 'auto' } : {}),
      }),
      signal: controller.signal,
    });
    if (!response.ok) throw httpError(response.status === 429 ? 503 : 502, 'deepseek_upstream_error', { upstreamStatus: response.status });
    const payload = await response.json().catch(() => null);
    const message = payload?.choices?.[0]?.message || {};
    const answer = typeof message.content === 'string' ? message.content.trim() : '';
    const toolCalls = options.tools?.length ? parseModelToolCalls(message.tool_calls) : [];
    if (!answer && !toolCalls.length) throw httpError(502, 'deepseek_empty_response');
    return options.tools?.length ? { answer, toolCalls } : answer;
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

async function callDeepSeekStream(ctx, messages, userId, onDelta) {
  const controller = new AbortController();
  const timeout = setTimeout(
    () => controller.abort(),
    ctx.cfg.aiRequestTimeoutSeconds * 1000,
  );
  try {
    const response = await fetch(`${ctx.cfg.deepSeekBaseUrl}/chat/completions`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${ctx.cfg.deepSeekApiKey}` },
      body: JSON.stringify({
        model: ctx.cfg.deepSeekModel,
        temperature: 0.2,
        thinking: { type: ctx.cfg.deepSeekThinkingMode },
        user_id: userId,
        messages,
        stream: true,
      }),
      signal: controller.signal,
    });
    if (!response.ok || !response.body) throw httpError(response.status === 429 ? 503 : 502, 'deepseek_upstream_error', { upstreamStatus: response.status });
    const decoder = new TextDecoder();
    let buffer = '';
    let answer = '';
    for await (const chunk of response.body) {
      buffer += decoder.decode(chunk, { stream: true });
      const lines = buffer.split(/\r?\n/u);
      buffer = lines.pop() || '';
      for (const line of lines) {
        if (!line.startsWith('data:')) continue;
        const data = line.slice(5).trim();
        if (!data || data === '[DONE]') continue;
        const payload = JSON.parse(data);
        const delta = payload?.choices?.[0]?.delta?.content;
        if (typeof delta === 'string' && delta) {
          answer += delta;
          onDelta(delta);
        }
      }
    }
    if (!answer.trim()) throw httpError(502, 'deepseek_empty_response');
    return answer.trim();
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error?.name === 'AbortError') throw httpError(504, 'deepseek_timeout');
    throw httpError(502, 'deepseek_upstream_unavailable');
  } finally { clearTimeout(timeout); }
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
            const note = String(exercise?.note || '').trim().slice(0, 220);
            return sets.length ? { exerciseId, note, sets } : null;
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

export function isVisibleKnowledgeSource(item) {
  const source = String(item?.source || '').toLowerCase();
  if (!source || !/https?:\/\//.test(source) || ['internal', 'admin', 'test-fixture'].includes(source)) return false;
  // Internal coaching material may inform the answer, but repository pages and
  // social-video pages are not useful evidence for an end user. Everything
  // else with a public source remains visible, including papers, standards and
  // reputable public guidance.
  return !/github\.com|githubusercontent\.com|bilibili\.com|b23\.tv/.test(source);
}

// Compatibility export for older imports. Visibility is no longer restricted
// to academic-only sources; the product now excludes only internal/GitHub/B站.
export const isAcademicKnowledgeSource = isVisibleKnowledgeSource;

export function recognitionEvidenceAssessment(result) {
  const metrics = result?.metrics && typeof result.metrics === 'object' ? result.metrics : {};
  const evidence = result?.evidence && typeof result.evidence === 'object' ? result.evidence : null;
  if (result?.evidenceReason === 'selected_exercise_mismatch' || evidence?.level === 'mismatch') {
    return { assessable: false, reason: 'selected_exercise_mismatch', level: 'mismatch', canCountRepetitions: false };
  }
  if (evidence?.canJudgePrimary === true) {
    return {
      assessable: true,
      reason: String(result?.evidenceReason || evidence?.level || 'assessable'),
      level: String(evidence?.level || 'full_cycle'),
      canCountRepetitions: evidence?.canCountRepetitions === true,
    };
  }
  if (result?.assessment === 'insufficient_evidence' || metrics.assessable === false) {
    return { assessable: false, reason: String(result?.evidenceReason || metrics.evidenceReason || 'insufficient_evidence'), level: String(evidence?.level || 'none'), canCountRepetitions: false };
  }
  const confidence = Number(result?.confidence || 0);
  const completeMotionCycles = Number(
    metrics.completeMotionCycles ?? result?.repetitions ?? 0,
  );
  const detectedFrames = Number(metrics.detectedFrames || 0);
  const inferenceFrames = Number(metrics.inferenceFrames || 0);
  if (inferenceFrames > 0 && (detectedFrames < 6 || detectedFrames / inferenceFrames < 0.55)) return { assessable: false, reason: 'insufficient_landmarks', level: 'none', canCountRepetitions: false };
  if (!Number.isFinite(confidence) || confidence < 0.25) return { assessable: false, reason: 'insufficient_pose_quality', level: 'none', canCountRepetitions: false };
  if (!Number.isFinite(completeMotionCycles) || completeMotionCycles < 1) return { assessable: false, reason: 'no_complete_motion_cycle', level: 'none', canCountRepetitions: false };
  return { assessable: true, reason: 'assessable', level: 'full_cycle', canCountRepetitions: true };
}

async function postAppleReceipt(url, receipt, sharedSecret) {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      'receipt-data': receipt,
      password: sharedSecret,
      'exclude-old-transactions': false,
    }),
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw httpError(502, 'apple_verification_unavailable');
  return response.json();
}

async function verifyAppleReceipt(cfg, verificationData) {
  if (!cfg.appleSharedSecret) throw httpError(503, 'apple_iap_not_configured');
  let result = await postAppleReceipt(
    'https://buy.itunes.apple.com/verifyReceipt',
    verificationData,
    cfg.appleSharedSecret,
  );
  if (Number(result.status) === 21007) {
    result = await postAppleReceipt(
      'https://sandbox.itunes.apple.com/verifyReceipt',
      verificationData,
      cfg.appleSharedSecret,
    );
  }
  if (Number(result.status) !== 0) {
    throw httpError(422, 'apple_receipt_invalid', { appleStatus: result.status });
  }
  if (String(result.receipt?.bundle_id || '') !== cfg.appleBundleId) {
    throw httpError(422, 'apple_bundle_mismatch');
  }
  return result;
}

function appleTransactions(receipt) {
  const latest = Array.isArray(receipt.latest_receipt_info)
    ? receipt.latest_receipt_info
    : [];
  const inApp = Array.isArray(receipt.receipt?.in_app)
    ? receipt.receipt.in_app
    : [];
  const byId = new Map();
  for (const row of [...inApp, ...latest]) {
    const key = String(row.transaction_id || '');
    if (key) byId.set(key, row);
  }
  return [...byId.values()];
}

function applyVerifiedAppleMembership(db, userId, plan, transaction) {
  ensureEntitlement(db, userId);
  if (plan === 'forever') {
    db.prepare(`UPDATE entitlements SET membership = 'forever', membership_expires_at = NULL,
      recognition_weekly_grant = 3,
      ai_remaining = CASE WHEN ai_remaining < 20 THEN 20 ELSE ai_remaining END,
      updated_at = ? WHERE user_id = ?`).run(nowIso(), userId);
    return publicEntitlement(ensureEntitlement(db, userId));
  }
  const expiresMs = Number(transaction.expires_date_ms || 0);
  if (!Number.isFinite(expiresMs) || expiresMs <= Date.now()) {
    throw httpError(422, 'apple_subscription_inactive');
  }
  const current = ensureEntitlement(db, userId);
  const currentExpiresMs = Date.parse(current.membership_expires_at || '') || 0;
  const effectiveExpires = new Date(Math.max(expiresMs, currentExpiresMs)).toISOString();
  const rank = { free: 0, oneMonth: 1, threeMonths: 2, yearly: 3, forever: 4 };
  const effectivePlan = rank[current.membership] > rank[plan]
    ? current.membership
    : plan;
  db.prepare(`UPDATE entitlements SET membership = ?, membership_expires_at = ?,
    recognition_weekly_grant = 3,
    ai_remaining = CASE WHEN ai_remaining < 20 THEN 20 ELSE ai_remaining END,
    updated_at = ? WHERE user_id = ?`)
    .run(effectivePlan, effectiveExpires, nowIso(), userId);
  return publicEntitlement(ensureEntitlement(db, userId));
}

function publicMembershipOrder(row) {
  return {
    id: row.id,
    productId: row.product_id,
    plan: row.plan,
    provider: row.provider,
    status: row.status,
    amountMinor: row.amount_minor,
    currency: row.currency,
    transactionId: row.provider_transaction_id,
    localOrderId: row.local_order_id,
    failureReason: row.failure_reason,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    paidAt: row.paid_at,
  };
}

function membershipProduct(productId) {
  const id = String(productId || '').trim();
  const product = PUBLIC_MEMBERSHIP_PRODUCTS.get(id);
  if (!product) throw httpError(400, 'unknown_membership_product');
  return { productId: id, ...product };
}

function normalizeOrderProvider(value) {
  const provider = String(value || 'app_store').trim().toLowerCase();
  if (!['app_store', 'google_play', 'wechat_pay', 'alipay'].includes(provider)) {
    throw httpError(400, 'unsupported_payment_provider');
  }
  return provider;
}

function createPendingMembershipOrder(db, userId, body) {
  const product = membershipProduct(body.productId);
  const provider = normalizeOrderProvider(body.provider);
  const existing = db.prepare(`SELECT * FROM membership_orders
    WHERE user_id = ? AND product_id = ? AND provider = ? AND status = 'pending'
    ORDER BY created_at DESC LIMIT 1`).get(userId, product.productId, provider);
  if (existing) return { order: existing, reused: true };
  const stamp = nowIso();
  const row = {
    id: randomId('ord_'),
    user_id: userId,
    product_id: product.productId,
    plan: product.plan,
    provider,
    status: 'pending',
    // Prices are server-owned. Never let a modified client choose what the
    // official payment gateway will charge for a membership product.
    amount_minor: product.amountMinor,
    currency: product.currency,
    provider_transaction_id: null,
    local_order_id: null,
    failure_reason: null,
    created_at: stamp,
    updated_at: stamp,
    paid_at: null,
  };
  try {
    db.prepare(`INSERT INTO membership_orders
      (id, user_id, product_id, plan, provider, status, amount_minor, currency,
       provider_transaction_id, local_order_id, failure_reason, created_at, updated_at, paid_at)
      VALUES (@id, @user_id, @product_id, @plan, @provider, @status, @amount_minor, @currency,
       @provider_transaction_id, @local_order_id, @failure_reason, @created_at, @updated_at, @paid_at)`).run(row);
  } catch (error) {
    // A concurrent request may win the partial unique index. Reuse its
    // pending order so tapping the purchase button twice remains idempotent.
    if (!String(error?.message || '').includes('UNIQUE')) throw error;
    const concurrent = db.prepare(`SELECT * FROM membership_orders
      WHERE user_id = ? AND product_id = ? AND provider = ? AND status = 'pending'
      ORDER BY created_at DESC LIMIT 1`).get(userId, product.productId, provider);
    if (concurrent) return { order: concurrent, reused: true };
    throw error;
  }
  return { order: db.prepare('SELECT * FROM membership_orders WHERE id = ?').get(row.id), reused: false };
}

function markMembershipOrderCancelled(db, userId, orderId) {
  const order = db.prepare('SELECT * FROM membership_orders WHERE id = ?').get(orderId);
  if (!order || order.user_id !== userId) throw httpError(404, 'membership_order_not_found');
  if (order.status !== 'pending') throw httpError(409, 'membership_order_not_cancellable', { status: order.status });
  const changed = db.prepare(`UPDATE membership_orders SET status = 'cancelled', updated_at = ?, failure_reason = NULL
    WHERE id = ? AND user_id = ? AND status = 'pending'`).run(nowIso(), orderId, userId);
  if (changed.changes !== 1) throw httpError(409, 'membership_order_not_cancellable');
  return db.prepare('SELECT * FROM membership_orders WHERE id = ?').get(orderId);
}

function applyCheckinMembershipReward(db, userId, at = new Date()) {
  const current = ensureEntitlement(db, userId, at);
  if (current.membership === 'forever') return publicEntitlement(current);
  const currentExpires = current.membership_expires_at && new Date(current.membership_expires_at) > at
    ? new Date(current.membership_expires_at)
    : at;
  const expires = new Date(currentExpires.getTime() + 15 * 24 * 60 * 60 * 1000).toISOString();
  const membership = current.membership === 'free' ? 'oneMonth' : current.membership;
  db.prepare(`UPDATE entitlements SET membership = ?, membership_expires_at = ?,
    recognition_weekly_grant = 3,
    ai_remaining = CASE WHEN ai_remaining < 20 THEN 20 ELSE ai_remaining END,
    updated_at = ? WHERE user_id = ?`).run(membership, expires, nowIso(), userId);
  return publicEntitlement(ensureEntitlement(db, userId, at));
}

function recordDailyCheckin(db, userId, at = new Date()) {
  const stamp = at.toISOString();
  const dateKey = shanghaiDayKey(at);
  const state = ensureCheckinState(db, userId, at);
  const inserted = db.prepare('INSERT OR IGNORE INTO daily_checkins (user_id, date_key, created_at) VALUES (?, ?, ?)').run(userId, dateKey, stamp);
  if (!inserted.changes) {
    return { ...publicCheckinState(db, userId, at), awarded: false, alreadyCheckedIn: true, entitlement: publicEntitlement(ensureEntitlement(db, userId, at)) };
  }
  const nextRoundDays = Number(state.round_days) + 1;
  const totalDays = Number(state.total_days) + 1;
  const completedRound = nextRoundDays >= 7;
  const nextState = {
    roundDays: completedRound ? 0 : nextRoundDays,
    totalDays,
    rewardRound: Number(state.reward_round) + (completedRound ? 1 : 0),
    lastRewardAt: completedRound ? stamp : state.last_reward_at,
  };
  db.prepare(`UPDATE checkin_state SET round_days = ?, total_days = ?, reward_round = ?,
    last_reward_at = ?, updated_at = ? WHERE user_id = ?`)
    .run(nextState.roundDays, nextState.totalDays, nextState.rewardRound, nextState.lastRewardAt, stamp, userId);
  const entitlement = completedRound
    ? applyCheckinMembershipReward(db, userId, at)
    : publicEntitlement(ensureEntitlement(db, userId, at));
  return {
    ...publicCheckinState(db, userId, at),
    awarded: completedRound,
    alreadyCheckedIn: false,
    rewardDays: completedRound ? 15 : 0,
    entitlement,
  };
}

function insufficientRecognitionResult(result, reason) {
  const copy = {
    selected_exercise_mismatch: {
      summary: '视频中的动作过程与所选动作不一致，请确认动作类型后重新分析。',
      headline: '所选动作可能与视频不一致',
      nextSet: '返回后确认动作名称和拍摄机位，再重新提交这段视频。',
      basis: '当前只确认动作类型不匹配，不会继续套用错误动作的评价规则。',
    },
    no_complete_motion_cycle: {
      summary: '已经看到动作变化，但没有稳定识别到起始—关键位置—返回的完整过程。',
      headline: '这段视频没有形成可计次的完整动作周期',
      nextSet: '下次从起始位多保留一小段画面，完成动作后再回到起始位。',
      basis: '没有完整周期时不会猜测次数或节奏。',
    },
    insufficient_landmarks: {
      summary: '目标关节在画面中持续不可见，目前无法稳定评价。',
      headline: '目标部位没有持续出现在画面中',
      nextSet: '调整机位，让本动作需要的主要关节链保持可见后重新拍摄。',
      basis: '关键关节覆盖不足时不会使用其他身体部位代替主动作证据。',
    },
    insufficient_pose_quality: {
      summary: '人物过小、模糊或遮挡较多，目前无法稳定评价。',
      headline: '当前骨骼证据不够稳定',
      nextSet: '靠近一些拍摄，保持光线充足，并减少器械或他人遮挡。',
      basis: '低质量关键点可能产生错误角度，因此本次不输出动作结论。',
    },
  }[reason] || {
    summary: '当前画面没有提供足够的目标动作证据，暂不判断动作好坏。',
    headline: '当前证据不足以完成动作评价',
    nextSet: '请重新上传目标关节清晰、包含主要动作阶段的视频。',
    basis: '证据不足时不会猜测动作问题。',
  };
  return {
    ...result,
    assessment: 'insufficient_evidence',
    evidenceReason: reason,
    summary: copy.summary,
    aiReview: {
      headline: copy.headline,
      strengths: [],
      risks: [],
      nextSet: copy.nextSet,
      basis: copy.basis,
    },
    aiReviewError: null,
  };
}

function recognitionCoachingObservations(result) {
  const metrics = result?.metrics && typeof result.metrics === 'object' ? result.metrics : {};
  const observations = { events: [] };
  for (const key of ['durationSeconds']) {
    const value = Number(metrics[key]);
    if (Number.isFinite(value)) observations[key] = value;
  }
  if (Array.isArray(result?.events)) {
    observations.events = result.events.slice(0, 8).map((event) => ({
      code: String(event?.code || '').slice(0, 80),
      label: String(event?.label || '').slice(0, 120),
      displayTime: String(event?.displayTime || '').slice(0, 20),
      startMs: Number(event?.startMs || 0),
      peakMs: Number(event?.peakMs || 0),
      endMs: Number(event?.endMs || 0),
      explanation: String(event?.explanation || '').slice(0, 500),
      measurements: event?.measurements && typeof event.measurements === 'object'
        ? event.measurements
        : {},
    }));
  }
  return observations;
}

function androidPaymentConfig(cfg, provider) {
  if (provider === 'wechat_pay') {
    return { url: cfg.wechatPayGatewayUrl, secret: cfg.wechatPayGatewaySecret };
  }
  if (provider === 'alipay') {
    return { url: cfg.alipayGatewayUrl, secret: cfg.alipayGatewaySecret };
  }
  return { url: '', secret: '' };
}

function androidPaymentCapabilities(cfg) {
  return {
    wechatPay: Boolean(cfg.wechatPayGatewayUrl && cfg.wechatPayGatewaySecret),
    alipay: Boolean(cfg.alipayGatewayUrl && cfg.alipayGatewaySecret),
  };
}

function canonicalPaymentJson(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalPaymentJson).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalPaymentJson(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

async function createAndroidCheckout(cfg, provider, order) {
  const gateway = androidPaymentConfig(cfg, provider);
  if (!gateway.url || !gateway.secret) {
    throw httpError(503, 'payment_provider_not_configured', { provider });
  }
  const response = await fetch(`${gateway.url}/checkout`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${gateway.secret}`,
    },
    body: JSON.stringify({
      provider,
      orderId: order.id,
      description: order.plan === 'yearly'
        ? '形域年度会员'
        : order.plan === 'threeMonths'
          ? '形域季度会员'
          : '形域月度会员',
      amountMinor: order.amount_minor,
      currency: order.currency,
      notifyUrl: `${cfg.publicBaseUrl}/v1/membership/android/webhook/${provider}`,
      returnUrl: 'ember://membership/payment-result',
    }),
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw httpError(502, 'payment_gateway_unavailable', { provider });
  const payload = await response.json();
  const paymentUrl = requireString(payload.paymentUrl, 'payment_url_missing', 2000);
  return { paymentUrl, expiresAt: payload.expiresAt || null };
}

function verifyAndroidPaymentWebhook(cfg, body, signature) {
  if (!cfg.androidPaymentWebhookSecret) throw httpError(503, 'payment_webhook_not_configured');
  const canonical = canonicalPaymentJson(body);
  const expected = createHmac('sha256', cfg.androidPaymentWebhookSecret).update(canonical).digest('hex');
  if (!safeEqualText(expected, signature)) throw httpError(401, 'invalid_payment_signature');
}

function completeAndroidMembershipOrder(db, provider, body) {
  const orderId = requireString(body.orderId, 'order_id_required', 180);
  const transactionId = requireString(body.transactionId, 'transaction_id_required', 180);
  const order = db.prepare('SELECT * FROM membership_orders WHERE id = ?').get(orderId);
  if (!order || order.provider !== provider) throw httpError(404, 'membership_order_not_found');
  const duplicate = db.prepare('SELECT * FROM membership_orders WHERE provider_transaction_id = ?').get(transactionId);
  if (duplicate && duplicate.id !== order.id) throw httpError(409, 'payment_transaction_conflict');
  if (order.status === 'paid') return { order, entitlement: publicEntitlement(ensureEntitlement(db, order.user_id)), idempotent: true };
  // A user can close the app or cancel the local pending order while the
  // provider's asynchronous paid callback is already in flight. The signed
  // provider callback is authoritative: never leave a customer charged but
  // without entitlement solely because that race changed the local status.
  if (!['pending', 'cancelled'].includes(order.status)) {
    throw httpError(409, 'membership_order_not_payable', { status: order.status });
  }
  const stamp = nowIso();
  db.prepare(`UPDATE membership_orders SET status = 'paid', provider_transaction_id = ?,
    paid_at = ?, updated_at = ?, failure_reason = NULL WHERE id = ? AND status IN ('pending', 'cancelled')`)
    .run(transactionId, stamp, stamp, order.id);
  const entitlement = grantMembership(db, order.user_id, order.plan);
  return {
    order: db.prepare('SELECT * FROM membership_orders WHERE id = ?').get(order.id),
    entitlement,
    idempotent: false,
  };
}

async function enrichRecognitionResult(ctx, job, result) {
  const evidence = recognitionEvidenceAssessment(result);
  if (!evidence.assessable) return insufficientRecognitionResult(result, evidence.reason);
  if (!ctx.cfg.deepSeekApiKey) return { ...result, assessment: 'assessable', aiReview: null, aiReviewError: 'deepseek_not_configured' };
  const observations = recognitionCoachingObservations(result);
  const messages = [
    {
      role: 'system',
      content: `你是形域的专业动作反馈助手。用户刚完成一组动作，希望立刻知道出现了什么、下一组怎么改。
写法要求：
 1. 使用客观、中性、简明的训练语言。只描述可观察到的关节位置、左右差异、移动方向和动作阶段，不为了显得亲切而添加情绪或拟人表达。
 2. 你只能改写用户 JSON 中 observations.events 已明确给出的事实，不能新增任何观察结论。
 3. 需要定位问题时，只能使用事件的 displayTime，例如“00:12.4 附近”。禁止写“第几次动作”、动作序号或完成次数。
 4. 没有对应测量值时，禁止评价深度、膝盖方向、站姿、重心、稳定性、左右对称、关节轨迹或动作质量；信息不足的字段直接省略。
 5. 绝不能出现算法、模型、置信度、关键点、识别率、拍摄、机位、光线、画面质量或技术故障等词。
 6. 不推测伤病、疲劳、力量或主观意图，不责怪用户。建议只能依据 observations，证据不足时 strengths 和 risks 必须为空数组。
 7. 同一种问题出现在多个时间点时，把全部 displayTime 合并在同一句话里，只评价一次；不要逐秒生成重复段落，也不要写“系统看到了什么”“这意味着什么”“本组建议”等报告标题。
 8. 禁止使用“整体有劲”“抢跑”“果断”“拖泥带水”“犹豫”“拉满”“做得有劲”等模糊或拟人说法。不要写“达到可稳定复现的完整范围”这类无法让用户直接理解的抽象句子。
 9. 行程不足必须写清楚哪个关节、在动作哪个阶段、没有到达什么可理解的位置；左右不对称必须写清楚哪一侧更高、先移动或角度更大。没有这些事实就省略。
仅输出 JSON：{"headline":"一句客观的总体结论","strengths":["明确的可观察表现"],"risks":["明确的可观察问题"],"nextSet":"下一组具体怎么做","basis":"用普通训练语言简述直接依据"}。每个数组最多 3 条。`,
    },
    {
      role: 'user',
      content: JSON.stringify({
        exerciseId: job.exercise_id,
        observations,
      }),
    },
  ];
  try {
    const raw = await ctx.aiGate.run(() => callDeepSeek(ctx, messages, job.user_id));
    const match = raw.match(/\{[\s\S]*\}/u);
    if (!match) return { ...result, assessment: 'assessable', aiReview: { headline: observations.events.length ? '已找到可以复核的动作时间点' : '这段动作已经看完了', strengths: [], risks: observations.events.map((event) => `${event.displayTime} 附近：${event.label}`).slice(0, 3), nextSet: '', basis: '只使用带时间和骨骼证据的测量结果。' }, aiReviewError: 'ai_review_invalid_json' };
    const parsed = JSON.parse(match[0]);
    return {
      ...result,
      assessment: 'assessable',
      aiReview: {
        headline: String(parsed.headline || '这一组已经看完了').slice(0, 120),
        strengths: Array.isArray(parsed.strengths) ? parsed.strengths.map(String).slice(0, 3) : [],
        risks: Array.isArray(parsed.risks) ? parsed.risks.map(String).slice(0, 3) : [],
        nextSet: String(parsed.nextSet || '').slice(0, 600),
        basis: String(parsed.basis || '根据本组动作表现').slice(0, 300),
      },
      aiReviewError: null,
    };
  } catch (error) {
    return { ...result, aiReview: null, aiReviewError: error?.code || 'ai_review_unavailable' };
  }
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
      ensureEntitlement(ctx.db, id);
      const user = ctx.db.prepare('SELECT * FROM users WHERE id = ?').get(id);
      syncAccountPhoneIdentity(ctx.db, user);
      return user;
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
    syncAccountPhoneIdentity(ctx.db, user);
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
    const email = normalizeEmail(claims.email);
    const emailVerified = claims.email_verified === true || claims.email_verified === 'true';
    if (email && emailVerified) {
      const identityResult = putUserIdentity(ctx.db, {
        userId: user.id,
        kind: 'email',
        normalizedValue: email,
        displayValue: email,
        source: provider,
        verifiedAt: nowIso(),
        searchable: true,
      });
      if (identityResult.status === 'conflict') {
        audit(ctx.db, user.id, `${provider}_email_identity_conflict`, user.id, { existingUserId: identityResult.identity.user_id });
      }
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

  if (req.method === 'GET' && url.pathname === '/v1/me/identities') {
    const user = authenticate(req, ctx);
    const identities = ctx.db.prepare('SELECT * FROM user_identities WHERE user_id = ? ORDER BY kind')
      .all(user.id)
      .map(publicIdentity);
    writeJson(res, 200, { identities }, req, ctx.cfg); return;
  }
  if (req.method === 'PUT' && url.pathname === '/v1/me/username') {
    const user = authenticate(req, ctx);
    const body = await readBody(req, ctx.cfg.maxJsonBytes);
    const rawUsername = requireString(body.username, 'username_required', 80);
    const username = normalizeUsername(rawUsername);
    if (!username) throw httpError(400, 'invalid_username');
    const result = putUserIdentity(ctx.db, {
      userId: user.id,
      kind: 'username',
      normalizedValue: username,
      displayValue: rawUsername.normalize('NFKC').trim(),
      source: 'user',
      verifiedAt: nowIso(),
      searchable: true,
      replaceForUser: true,
    });
    if (result.status === 'conflict') throw httpError(409, 'username_taken');
    writeJson(res, 200, { identity: publicIdentity(result.identity) }, req, ctx.cfg); return;
  }

  if (req.method === 'GET' && url.pathname === '/v1/me/entitlements') {
    const user = authenticate(req, ctx); writeJson(res, 200, publicEntitlement(entitlementRow(ctx.db, user.id)), req, ctx.cfg); return;
  }
  // Daily check-in rewards were removed from the product. Keep the legacy
  // database tables for migration/audit compatibility, but intentionally do
  // not expose either the status or reward endpoint anymore.
  if (['/v1/checkin', '/v1/checkins', '/v1/checkin/status', '/v1/checkins/status'].includes(url.pathname)) {
    throw httpError(404, 'checkin_disabled');
  }
  if (req.method === 'GET' && url.pathname === '/v1/membership/products') {
    writeJson(res, 200, {
      products: [...PUBLIC_MEMBERSHIP_PRODUCTS.entries()].map(([productId, product]) => ({
        productId,
        ...product,
        type: 'subscription',
      })),
    }, req, ctx.cfg); return;
  }
  if (req.method === 'GET' && url.pathname === '/v1/membership/android/capabilities') {
    writeJson(res, 200, androidPaymentCapabilities(ctx.cfg), req, ctx.cfg); return;
  }
  if (req.method === 'POST' && url.pathname === '/v1/membership/android/checkout') {
    const user = authenticate(req, ctx);
    const body = await readBody(req, ctx.cfg.maxJsonBytes);
    const provider = normalizeOrderProvider(body.provider);
    if (!['wechat_pay', 'alipay'].includes(provider)) throw httpError(400, 'unsupported_payment_provider');
    if (body.platform !== 'android') throw httpError(400, 'android_payment_only');
    const gateway = androidPaymentConfig(ctx.cfg, provider);
    if (!gateway.url || !gateway.secret) {
      throw httpError(503, 'payment_provider_not_configured', { provider });
    }
    const created = transaction(ctx.db, () => {
      const result = createPendingMembershipOrder(ctx.db, user.id, { ...body, provider });
      audit(ctx.db, user.id, result.reused ? 'reuse_membership_order' : 'create_membership_order', result.order.id, { provider, productId: result.order.product_id });
      return result;
    });
    const checkout = await createAndroidCheckout(ctx.cfg, provider, created.order);
    writeJson(res, created.reused ? 200 : 201, {
      order: publicMembershipOrder(created.order),
      reused: created.reused,
      ...checkout,
    }, req, ctx.cfg); return;
  }
  const androidPaymentWebhook = url.pathname.match(/^\/v1\/membership\/android\/webhook\/(wechat_pay|alipay)$/);
  if (req.method === 'POST' && androidPaymentWebhook) {
    const body = await readBody(req, ctx.cfg.maxJsonBytes);
    verifyAndroidPaymentWebhook(ctx.cfg, body, String(req.headers['x-kilo-payment-signature'] || ''));
    if (body.status !== 'paid') throw httpError(400, 'payment_status_not_paid');
    const result = transaction(ctx.db, () => {
      const completed = completeAndroidMembershipOrder(ctx.db, androidPaymentWebhook[1], body);
      audit(ctx.db, completed.order.user_id, 'verify_android_membership', completed.order.id, {
        provider: androidPaymentWebhook[1],
        idempotent: completed.idempotent,
      });
      return completed;
    });
    writeJson(res, 200, {
      ok: true,
      idempotent: result.idempotent,
      order: publicMembershipOrder(result.order),
    }, req, ctx.cfg); return;
  }
  if (req.method === 'POST' && url.pathname === '/v1/membership/orders') {
    const user = authenticate(req, ctx);
    const body = await readBody(req, ctx.cfg.maxJsonBytes);
    const result = transaction(ctx.db, () => {
      const created = createPendingMembershipOrder(ctx.db, user.id, body);
      audit(ctx.db, user.id, created.reused ? 'reuse_membership_order' : 'create_membership_order', created.order.id, { productId: created.order.product_id, plan: created.order.plan });
      return created;
    });
    writeJson(res, result.reused ? 200 : 201, { order: publicMembershipOrder(result.order), reused: result.reused }, req, ctx.cfg); return;
  }
  if (req.method === 'GET' && url.pathname === '/v1/membership/orders') {
    const user = authenticate(req, ctx);
    const rows = ctx.db.prepare('SELECT * FROM membership_orders WHERE user_id = ? ORDER BY created_at DESC LIMIT 100').all(user.id);
    writeJson(res, 200, { orders: rows.map(publicMembershipOrder) }, req, ctx.cfg); return;
  }
  const membershipCancelMatch = url.pathname.match(/^\/v1\/membership\/orders\/([^/]+)\/cancel$/);
  if (membershipCancelMatch && ((req.method === 'POST' && url.pathname.endsWith('/cancel')) || req.method === 'DELETE')) {
    const user = authenticate(req, ctx);
    const order = transaction(ctx.db, () => markMembershipOrderCancelled(ctx.db, user.id, decodeURIComponent(membershipCancelMatch[1])));
    audit(ctx.db, user.id, 'cancel_membership_order', order.id, {});
    writeJson(res, 200, { order: publicMembershipOrder(order) }, req, ctx.cfg); return;
  }
  if (req.method === 'POST' && url.pathname === '/v1/membership/apple/verify') {
    const user = authenticate(req, ctx);
    const body = await readBody(req, ctx.cfg.maxJsonBytes);
    const productId = requireString(body.productId, 'product_id_required', 180);
    const plan = APPLE_MEMBERSHIP_PRODUCTS.get(productId);
    if (!plan) throw httpError(400, 'unknown_membership_product');
    const verificationData = requireString(body.verificationData, 'verification_data_required', ctx.cfg.maxJsonBytes);
    const requestedTransactionId = typeof body.transactionId === 'string' ? body.transactionId.trim().slice(0, 180) : '';
    const localOrderId = typeof body.localOrderId === 'string' ? body.localOrderId.trim().slice(0, 180) : '';
    const receipt = await verifyAppleReceipt(ctx.cfg, verificationData);
    const candidates = appleTransactions(receipt)
      .filter((item) => String(item.product_id || '') === productId)
      .filter((item) => !item.cancellation_date_ms && !item.revocation_date_ms)
      .sort((a, b) => Number(b.purchase_date_ms || 0) - Number(a.purchase_date_ms || 0));
    const selectedTransaction = requestedTransactionId
      ? candidates.find((item) => String(item.transaction_id || '') === requestedTransactionId) || candidates[0]
      : candidates[0];
    if (!selectedTransaction) throw httpError(422, 'apple_product_not_in_receipt');
    const transactionId = requireString(selectedTransaction.transaction_id, 'apple_transaction_missing', 180);
    const existing = ctx.db.prepare('SELECT * FROM membership_orders WHERE provider_transaction_id = ?').get(transactionId);
    if (existing && existing.user_id !== user.id) throw httpError(409, 'purchase_linked_to_another_account');
    const localOrder = localOrderId
      ? ctx.db.prepare('SELECT * FROM membership_orders WHERE id = ? AND user_id = ?').get(localOrderId, user.id)
      : null;
    if (localOrder && localOrder.product_id !== productId) throw httpError(409, 'membership_order_product_mismatch');
    if (localOrder && !['pending', 'failed', 'cancelled'].includes(localOrder.status)) {
      throw httpError(409, 'membership_order_not_verifiable', { status: localOrder.status });
    }
    const result = transaction(ctx.db, () => {
      const stamp = nowIso();
      const order = existing || localOrder || {
        id: randomId('ord_'),
        user_id: user.id,
        product_id: productId,
        plan,
        provider: 'app_store',
        status: 'paid',
        provider_transaction_id: transactionId,
        local_order_id: localOrderId || null,
        created_at: stamp,
        updated_at: stamp,
        paid_at: stamp,
      };
      if (!existing) {
        if (localOrder) {
          ctx.db.prepare(`UPDATE membership_orders SET status = 'paid', provider_transaction_id = ?,
            local_order_id = COALESCE(local_order_id, ?), updated_at = ?, paid_at = ?, failure_reason = NULL
            WHERE id = ? AND user_id = ? AND status IN ('pending', 'failed', 'cancelled')`)
            .run(transactionId, localOrderId || localOrder.id, stamp, stamp, localOrder.id, user.id);
        } else {
          ctx.db.prepare(`INSERT INTO membership_orders
            (id, user_id, product_id, plan, provider, status, provider_transaction_id,
             local_order_id, created_at, updated_at, paid_at)
            VALUES (@id, @user_id, @product_id, @plan, @provider, @status,
             @provider_transaction_id, @local_order_id, @created_at, @updated_at, @paid_at)`)
            .run(order);
        }
      } else if (existing.status !== 'paid' && existing.status !== 'restored') {
        ctx.db.prepare(`UPDATE membership_orders SET status = 'paid', updated_at = ?, paid_at = COALESCE(paid_at, ?), failure_reason = NULL WHERE id = ?`)
          .run(stamp, stamp, existing.id);
      }
      const entitlement = applyVerifiedAppleMembership(ctx.db, user.id, plan, selectedTransaction);
      audit(ctx.db, user.id, existing ? 'restore_apple_membership' : 'verify_apple_membership', transactionId, { productId, plan });
      return { entitlement, order: ctx.db.prepare('SELECT * FROM membership_orders WHERE provider_transaction_id = ?').get(transactionId) };
    });
    writeJson(res, 200, { entitlement: result.entitlement, order: publicMembershipOrder(result.order) }, req, ctx.cfg); return;
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
  if (req.method === 'POST' && url.pathname === '/v1/admin/users') {
    const admin = requireAdmin(req, ctx);
    const body = await readBody(req, ctx.cfg.maxJsonBytes);
    const identifier = requireString(body.identifier, 'identifier_required', 32).trim();
    const password = requireString(body.password || '1234', 'password_required', 128);
    const displayName = typeof body.displayName === 'string' && body.displayName.trim()
      ? body.displayName.trim().slice(0, 120)
      : identifier;
    const membershipPlan = body.membershipPlan == null || body.membershipPlan === 'free'
      ? null
      : requireString(body.membershipPlan, 'plan_required', 32);
    if (!/^1[3-9]\d{9}$/.test(identifier)) throw httpError(400, 'invalid_phone_identifier');
    if (password.length < 4) throw httpError(400, 'invalid_password');
    if (membershipPlan && !PLANS.has(membershipPlan)) throw httpError(400, 'invalid_plan');
    const result = transaction(ctx.db, () => {
      if (ctx.db.prepare('SELECT 1 FROM users WHERE identifier = ?').get(identifier)) {
        throw httpError(409, 'identifier_taken');
      }
      const id = randomId('usr_');
      const hp = hashPassword(password);
      const stamp = nowIso();
      ctx.db.prepare(`INSERT INTO users
        (id, identifier, display_name, role, auth_provider, password_salt, password_hash, created_at)
        VALUES (?, ?, ?, 'user', 'password', ?, ?, ?)`)
        .run(id, identifier, displayName, hp.salt, hp.hash, stamp);
      ensureEntitlement(ctx.db, id);
      syncAccountPhoneIdentity(ctx.db, ctx.db.prepare('SELECT * FROM users WHERE id = ?').get(id));
      const entitlement = membershipPlan
        ? grantMembership(ctx.db, id, membershipPlan)
        : publicEntitlement(ensureEntitlement(ctx.db, id));
      audit(ctx.db, admin.id, 'create_managed_user', id, {
        identifier,
        membershipPlan: membershipPlan || 'free',
      });
      return {
        user: publicUser(ctx.db.prepare('SELECT * FROM users WHERE id = ?').get(id)),
        entitlement,
      };
    });
    writeJson(res, 201, result, req, ctx.cfg); return;
  }
  if (req.method === 'POST' && url.pathname === '/v1/admin/redemption-codes') {
    const admin = requireAdmin(req, ctx); const body = await readBody(req, ctx.cfg.maxJsonBytes); const plan = requireString(body.plan, 'plan_required', 32); if (!PLANS.has(plan)) throw httpError(400, 'invalid_plan');
    let code; do { code = `KILO-${randomToken().slice(0, 16).toUpperCase()}`; } while (ctx.db.prepare('SELECT 1 FROM redemption_codes WHERE code = ?').get(code));
    ctx.db.prepare('INSERT INTO redemption_codes (code, plan, created_by, created_at) VALUES (?, ?, ?, ?)').run(code, plan, admin.id, nowIso()); audit(ctx.db, admin.id, 'create_redemption_code', code, { plan });
    writeJson(res, 201, { code, plan }, req, ctx.cfg); return;
  }

  if (req.method === 'POST' && url.pathname === '/v1/friends/search') {
    const user = authenticate(req, ctx);
    enforceFriendSearchRateLimit(ctx, user, req);
    const body = await readBody(req, ctx.cfg.maxJsonBytes);
    const query = requireString(body.query, 'friend_search_required', 128);
    const search = friendSearchKind(query);
    const verificationClause = search.kind === 'phone'
      ? "AND (matched.source = 'account' OR matched.verified_at IS NOT NULL)"
      : search.kind === 'email'
        ? 'AND matched.verified_at IS NOT NULL'
        : '';
    const valueClause = search.prefix
      ? 'AND matched.normalized_value >= ? AND matched.normalized_value < ?'
      : 'AND matched.normalized_value = ?';
    const sql = `SELECT matched.*, u.display_name,
      (SELECT display_value FROM user_identities username
        WHERE username.user_id = u.id AND username.kind = 'username' AND username.searchable = 1) AS username
      FROM user_identities matched JOIN users u ON u.id = matched.user_id
      WHERE matched.kind = ? AND matched.searchable = 1 AND matched.user_id <> ?
        ${verificationClause} ${valueClause}
      ORDER BY CASE WHEN matched.normalized_value = ? THEN 0 ELSE 1 END,
        matched.normalized_value, u.id LIMIT 20`;
    const parameters = search.prefix
      ? [search.kind, user.id, search.normalized, `${search.normalized}\uffff`, search.normalized]
      : [search.kind, user.id, search.normalized, search.normalized];
    const results = ctx.db.prepare(sql).all(...parameters).map((row) => ({
      id: row.user_id,
      displayName: row.display_name,
      username: row.username || null,
      matchType: row.kind,
      maskedMatch: maskUserIdentity(row.kind, row.display_value),
      relationshipStatus: friendRelationship(ctx.db, user.id, row.user_id),
    }));
    writeJson(res, 200, { results }, req, ctx.cfg); return;
  }
  if (req.method === 'GET' && url.pathname === '/v1/friends') {
    const user = authenticate(req, ctx);
    const friends = ctx.db.prepare(`SELECT fr.updated_at, u.id, u.identifier, u.display_name,
      (SELECT display_value FROM user_identities identity
        WHERE identity.user_id = u.id AND identity.kind = 'username' AND identity.searchable = 1) AS username
      FROM friend_requests fr JOIN users u
      ON u.id = CASE WHEN fr.sender_user_id = ? THEN fr.receiver_user_id ELSE fr.sender_user_id END
      WHERE (fr.sender_user_id = ? OR fr.receiver_user_id = ?) AND fr.status = 'accepted'
      ORDER BY fr.updated_at DESC`).all(user.id, user.id, user.id);
    const pending = ctx.db.prepare(`SELECT fr.id AS request_id, fr.created_at,
      u.id, u.identifier, u.display_name,
      (SELECT display_value FROM user_identities identity
        WHERE identity.user_id = u.id AND identity.kind = 'username' AND identity.searchable = 1) AS username
      FROM friend_requests fr
      JOIN users u ON u.id = fr.sender_user_id
      WHERE fr.receiver_user_id = ? AND fr.status = 'pending' ORDER BY fr.created_at DESC`).all(user.id);
    writeJson(res, 200, {
      friends: friends.map((row) => ({ id: row.id, identifier: row.identifier, displayName: row.display_name, username: row.username || null, since: row.updated_at })),
      pending: pending.map((row) => ({ requestId: row.request_id, id: row.id, identifier: row.identifier, displayName: row.display_name, username: row.username || null, createdAt: row.created_at })),
    }, req, ctx.cfg); return;
  }
  if (req.method === 'POST' && url.pathname === '/v1/friends/requests') {
    const user = authenticate(req, ctx); const body = await readBody(req, ctx.cfg.maxJsonBytes);
    const hasTargetUserId = typeof body.targetUserId === 'string' && body.targetUserId.trim();
    const hasIdentifier = typeof body.identifier === 'string' && body.identifier.trim();
    if (hasTargetUserId && hasIdentifier) throw httpError(400, 'ambiguous_friend_target');
    if (!hasTargetUserId && !hasIdentifier) throw httpError(400, 'friend_target_required');
    const target = hasTargetUserId
      ? ctx.db.prepare('SELECT * FROM users WHERE id = ?').get(String(body.targetUserId).trim())
      : ctx.db.prepare('SELECT * FROM users WHERE identifier = ?').get(String(body.identifier).trim());
    if (!target) throw httpError(404, 'friend_not_found');
    if (target.id === user.id) throw httpError(400, 'cannot_friend_self');
    const pairKey = friendPairKey(user.id, target.id);
    const existing = ctx.db.prepare('SELECT * FROM friend_requests WHERE pair_key = ?').get(pairKey);
    if (existing?.status === 'accepted') throw httpError(409, 'already_friends');
    if (existing?.status === 'pending') {
      throw httpError(409, existing.sender_user_id === user.id
        ? 'friend_request_pending'
        : 'incoming_friend_request_pending');
    }
    const stamp = nowIso(); const id = existing?.id || randomId('frq_');
    ctx.db.prepare(`INSERT INTO friend_requests
      (id, pair_key, sender_user_id, receiver_user_id, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, 'pending', ?, ?)
      ON CONFLICT(pair_key) DO UPDATE SET sender_user_id=excluded.sender_user_id,
        receiver_user_id=excluded.receiver_user_id, status='pending', updated_at=excluded.updated_at`)
      .run(id, pairKey, user.id, target.id, stamp, stamp);
    writeJson(res, 201, { request: { id, status: 'pending' } }, req, ctx.cfg); return;
  }
  const friendAcceptMatch = url.pathname.match(/^\/v1\/friends\/requests\/([^/]+)\/accept$/);
  if (req.method === 'POST' && friendAcceptMatch) {
    const user = authenticate(req, ctx);
    const request = ctx.db.prepare("SELECT * FROM friend_requests WHERE id = ? AND receiver_user_id = ? AND status = 'pending'")
      .get(friendAcceptMatch[1], user.id);
    if (!request) throw httpError(404, 'friend_request_not_found');
    ctx.db.prepare("UPDATE friend_requests SET status = 'accepted', updated_at = ? WHERE id = ?").run(nowIso(), request.id);
    writeJson(res, 200, { request: { id: request.id, status: 'accepted' } }, req, ctx.cfg); return;
  }

  if (req.method === 'POST' && url.pathname === '/v1/friends/workouts') {
    const user = authenticate(req, ctx);
    const body = await readBody(req, ctx.cfg.maxJsonBytes);
    const snapshot = workoutSnapshotFromBody(body);
    if (ctx.db.prepare('SELECT 1 FROM friend_workout_posts WHERE owner_user_id = ? AND source_workout_id = ?').get(user.id, snapshot.sourceWorkoutId)) {
      throw httpError(409, 'workout_already_published');
    }
    const id = randomId('fwp_');
    const stamp = nowIso();
    try {
      ctx.db.prepare(`INSERT INTO friend_workout_posts
        (id, owner_user_id, source_workout_id, name, started_at, completed_at,
         duration_seconds, volume_kg, effective_sets, completion_rate, exercises_json,
         caption, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
        .run(id, user.id, snapshot.sourceWorkoutId, snapshot.name, snapshot.startedAt, snapshot.completedAt,
          snapshot.durationSeconds, snapshot.volumeKg, snapshot.effectiveSets, snapshot.completionRate,
          JSON.stringify(snapshot.exercises), snapshot.caption, stamp, stamp);
    } catch (error) {
      if (String(error?.message || '').includes('UNIQUE')) throw httpError(409, 'workout_already_published');
      throw error;
    }
    writeJson(res, 201, { post: workoutPostForViewer(ctx.db, id, user.id) }, req, ctx.cfg); return;
  }
  const friendWorkoutCommentListMatch = url.pathname.match(/^\/v1\/friends\/workouts\/([^/]+)\/comments$/);
  if (friendWorkoutCommentListMatch && req.method === 'GET') {
    const user = authenticate(req, ctx);
    const post = workoutPostForViewer(ctx.db, decodeURIComponent(friendWorkoutCommentListMatch[1]), user.id, { includeComments: true });
    writeJson(res, 200, { postId: post.id, comments: post.comments }, req, ctx.cfg); return;
  }
  if (friendWorkoutCommentListMatch && req.method === 'POST') {
    const user = authenticate(req, ctx);
    const postId = decodeURIComponent(friendWorkoutCommentListMatch[1]);
    workoutPostForViewer(ctx.db, postId, user.id);
    const body = await readBody(req, ctx.cfg.maxJsonBytes);
    if (body.text !== undefined || body.content !== undefined || body.comment !== undefined) throw httpError(400, 'emoji_only_comment');
    const emoji = requireString(body.emoji, 'emoji_required', 16);
    if (!FRIEND_WORKOUT_EMOJIS.has(emoji)) throw httpError(400, 'invalid_workout_emoji');
    const id = randomId('fwc_');
    const stamp = nowIso();
    ctx.db.prepare('INSERT INTO friend_workout_post_comments (id, post_id, user_id, emoji, created_at) VALUES (?, ?, ?, ?, ?)')
      .run(id, postId, user.id, emoji, stamp);
    const count = ctx.db.prepare('SELECT COUNT(*) AS count FROM friend_workout_post_comments WHERE post_id = ?').get(postId).count;
    writeJson(res, 201, { comment: { id, postId, userId: user.id, emoji, createdAt: stamp }, commentCount: Number(count) }, req, ctx.cfg); return;
  }
  const friendWorkoutLikeMatch = url.pathname.match(/^\/v1\/friends\/workouts\/([^/]+)\/(?:likes?|like)$/);
  if (friendWorkoutLikeMatch && (req.method === 'POST' || req.method === 'DELETE')) {
    const user = authenticate(req, ctx);
    const postId = decodeURIComponent(friendWorkoutLikeMatch[1]);
    workoutPostForViewer(ctx.db, postId, user.id);
    const toggle = url.pathname.endsWith('/like');
    let liked = req.method === 'POST';
    if (req.method === 'POST') {
      if (toggle && ctx.db.prepare('SELECT 1 FROM friend_workout_post_likes WHERE post_id = ? AND user_id = ?').get(postId, user.id)) {
        ctx.db.prepare('DELETE FROM friend_workout_post_likes WHERE post_id = ? AND user_id = ?').run(postId, user.id);
        liked = false;
      } else {
        ctx.db.prepare('INSERT OR IGNORE INTO friend_workout_post_likes (post_id, user_id, created_at) VALUES (?, ?, ?)')
          .run(postId, user.id, nowIso());
      }
    } else {
      ctx.db.prepare('DELETE FROM friend_workout_post_likes WHERE post_id = ? AND user_id = ?').run(postId, user.id);
      liked = false;
    }
    const count = ctx.db.prepare('SELECT COUNT(*) AS count FROM friend_workout_post_likes WHERE post_id = ?').get(postId).count;
    writeJson(res, 200, { postId, liked, likeCount: Number(count) }, req, ctx.cfg); return;
  }
  const friendWorkoutPostMatch = url.pathname.match(/^\/v1\/friends\/workouts\/([^/]+)$/);
  if (friendWorkoutPostMatch && req.method === 'GET') {
    const user = authenticate(req, ctx);
    writeJson(res, 200, { post: workoutPostForViewer(ctx.db, decodeURIComponent(friendWorkoutPostMatch[1]), user.id, { includeComments: true }) }, req, ctx.cfg); return;
  }
  if (friendWorkoutPostMatch && req.method === 'DELETE') {
    const user = authenticate(req, ctx);
    const postId = decodeURIComponent(friendWorkoutPostMatch[1]);
    const post = ctx.db.prepare('SELECT id, owner_user_id FROM friend_workout_posts WHERE id = ?').get(postId);
    if (!post || post.owner_user_id !== user.id) throw httpError(404, 'workout_post_not_found');
    ctx.db.prepare('DELETE FROM friend_workout_posts WHERE id = ? AND owner_user_id = ?').run(postId, user.id);
    writeJson(res, 200, { id: postId, deleted: true }, req, ctx.cfg); return;
  }
  if (req.method === 'GET' && url.pathname === '/v1/friends/workouts') {
    const user = authenticate(req, ctx);
    const rows = workoutPostRowsForViewer(ctx.db, user.id);
    writeJson(res, 200, { workouts: rows.map((row) => publicWorkoutPost(row, ctx.db, user.id)) }, req, ctx.cfg); return;
  }
  if (req.method === 'GET' && url.pathname === '/v1/friends/feed') {
    const user = authenticate(req, ctx);
    const rows = ctx.db.prepare(`SELECT s.*, u.display_name, u.identifier,
      (SELECT COUNT(*) FROM friend_plan_reactions r WHERE r.share_id=s.id) AS reaction_count,
      (SELECT emoji FROM friend_plan_reactions r WHERE r.share_id=s.id AND r.user_id=?) AS my_reaction
      FROM friend_plan_shares s JOIN users u ON u.id=s.owner_user_id
      WHERE s.owner_user_id=? OR EXISTS (SELECT 1 FROM friend_requests fr
        WHERE fr.pair_key=CASE WHEN s.owner_user_id < ? THEN s.owner_user_id||':'||? ELSE ?||':'||s.owner_user_id END
        AND fr.status='accepted') ORDER BY s.updated_at DESC LIMIT 100`)
      .all(user.id, user.id, user.id, user.id, user.id);
    const workoutRows = workoutPostRowsForViewer(ctx.db, user.id);
    writeJson(res, 200, { plans: rows.map((row) => ({ id: row.id, ownerId: row.owner_user_id,
      ownerName: row.display_name, ownerIdentifier: row.identifier, name: row.name,
      plan: JSON.parse(row.payload_json), reactionCount: Number(row.reaction_count),
      myReaction: row.my_reaction, updatedAt: row.updated_at })),
      workouts: workoutRows.map((row) => publicWorkoutPost(row, ctx.db, user.id)),
    }, req, ctx.cfg); return;
  }
  if (req.method === 'POST' && url.pathname === '/v1/friends/plans') {
    const user = authenticate(req, ctx); const body = await readBody(req, ctx.cfg.maxJsonBytes);
    const sourcePlanId = requireString(body.sourcePlanId, 'source_plan_id_required', 160);
    const name = requireString(body.name, 'plan_name_required', 120);
    if (!body.plan || typeof body.plan !== 'object' || Array.isArray(body.plan)) throw httpError(400, 'plan_required');
    const encoded = JSON.stringify(body.plan); if (Buffer.byteLength(encoded) > 256000) throw httpError(413, 'plan_too_large');
    const stamp = nowIso(); const existing = ctx.db.prepare('SELECT id FROM friend_plan_shares WHERE owner_user_id=? AND source_plan_id=?').get(user.id, sourcePlanId);
    const id = existing?.id || randomId('fps_');
    ctx.db.prepare(`INSERT INTO friend_plan_shares (id,owner_user_id,source_plan_id,name,payload_json,created_at,updated_at)
      VALUES (?,?,?,?,?,?,?) ON CONFLICT(owner_user_id,source_plan_id)
      DO UPDATE SET name=excluded.name,payload_json=excluded.payload_json,updated_at=excluded.updated_at`)
      .run(id, user.id, sourcePlanId, name, encoded, stamp, stamp);
    writeJson(res, 201, { share: { id, name, updatedAt: stamp } }, req, ctx.cfg); return;
  }
  const friendReactionMatch = url.pathname.match(/^\/v1\/friends\/plans\/([^/]+)\/reactions$/);
  if (req.method === 'POST' && friendReactionMatch) {
    const user = authenticate(req, ctx); const share = ctx.db.prepare('SELECT * FROM friend_plan_shares WHERE id=?').get(friendReactionMatch[1]);
    if (!share || (share.owner_user_id !== user.id && !areFriends(ctx.db, user.id, share.owner_user_id))) throw httpError(404, 'shared_plan_not_found');
    const body = await readBody(req, ctx.cfg.maxJsonBytes); const emoji = requireString(body.emoji, 'reaction_required', 8);
    if (!['👍','🔥','👏','💪'].includes(emoji)) throw httpError(400, 'invalid_reaction');
    const stamp = nowIso();
    ctx.db.prepare(`INSERT INTO friend_plan_reactions (share_id,user_id,emoji,created_at,updated_at)
      VALUES (?,?,?,?,?) ON CONFLICT(share_id,user_id) DO UPDATE SET emoji=excluded.emoji,updated_at=excluded.updated_at`)
      .run(share.id, user.id, emoji, stamp, stamp);
    const count = ctx.db.prepare('SELECT COUNT(*) AS count FROM friend_plan_reactions WHERE share_id=?').get(share.id).count;
    writeJson(res, 200, { reaction: emoji, reactionCount: Number(count) }, req, ctx.cfg); return;
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
  if (req.method === 'POST' && url.pathname === '/v1/coach/stream') {
    const user = authenticate(req, ctx);
    const body = await readBody(req, ctx.cfg.maxJsonBytes);
    const question = requireString(body.question || body.message, 'question_required', MAX_TEXT);
    const clientToolResults = parseClientToolResults(body.toolResults);
    if (clientToolResults.length && body.useTrainingData !== true) {
      throw httpError(400, 'ai_tools_consent_required');
    }
    const requestId = body.requestId || `ai_${randomUUID()}`;
    reserveQuota(ctx.db, user.id, 'ai', requestId);
    res.writeHead(200, {
      'content-type': 'text/event-stream; charset=utf-8',
      'cache-control': 'no-cache, no-transform',
      connection: 'keep-alive',
      'x-accel-buffering': 'no',
    });
    const sendEvent = (event, data) => {
      if (!res.destroyed) res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
    };
    try {
      let conversationId = body.conversationId;
      let conversation = conversationId
        ? ctx.db.prepare('SELECT * FROM conversations WHERE id = ? AND user_id = ?').get(conversationId, user.id)
        : null;
      if (!conversation) {
        conversationId = randomId('conv_');
        const stamp = nowIso();
        ctx.db.prepare('INSERT INTO conversations (id, user_id, title, memory_summary, created_at, updated_at) VALUES (?, ?, ?, \'\', ?, ?)').run(conversationId, user.id, question.slice(0, 80), stamp, stamp);
        conversation = ctx.db.prepare('SELECT * FROM conversations WHERE id = ?').get(conversationId);
      }
      const recent = conversationMessages(ctx.db, conversationId, 20);
      const knowledge = knowledgeSearch(ctx.db, question, 20);
      const answerLocale = String(body.locale || '').toLowerCase().startsWith('en') ? 'en' : 'zh-CN';
      const messages = [{ role: 'system', content: `你是 KILO Strength 健身训练助手。优先基于用户长期训练数据解释下一步怎么练，不要给通用健身话术。提供一般训练、恢复和动作记录建议，不进行医疗诊断。证据不足时明确说明。视频动作分析不得识别或猜测训练重量，重量只能来自用户实际记录。${answerLocale === 'en' ? ' Answer in natural, concise English.' : ' 使用自然、简洁的中文回答。'}回答使用简洁 Markdown。不要在正文中披露内部知识库名称或技能名。` }];
      messages.push({ role: 'system', content: aiClientTimeInstruction(body) });
      if (conversation.memory_summary) messages.push({ role: 'system', content: `长期记忆摘要：${conversation.memory_summary.slice(0, 3000)}` });
      if (knowledge.length) messages.push({ role: 'system', content: `内部知识库参考：\n${knowledge.map((item) => `${item.title}: ${item.content.slice(0, 1200)}`).join('\n')}` });
      for (const message of recent) messages.push({ role: message.role, content: message.content });
      if (body.useTrainingData === true && typeof body.trainingSummary === 'string' && body.trainingSummary.trim()) messages.push({ role: 'system', content: `用户主动选择了以下训练资料。请按日期顺序比较动作、重量、次数、组数、时长和备注；如果用户询问变化原因，要指出可见趋势，并把睡眠、疲劳、动作备注等只能作为可能因素而非确定结论。不要把这些资料称为“上下文”：\n${body.trainingSummary.trim().slice(0, MAX_SUMMARY)}` });
      const exerciseCatalog = Array.isArray(body.exerciseCatalog)
        ? body.exerciseCatalog.slice(0, 100).map((item) => ({
          id: String(item?.id || '').slice(0, 200),
          name: String(item?.name || '').slice(0, 100),
          equipment: String(item?.equipment || '').slice(0, 60),
          muscle: String(item?.muscle || '').slice(0, 60),
          cue: String(item?.cue || '').slice(0, 220),
        })).filter((item) => item.id && item.name)
        : [];
      if (exerciseCatalog.length) messages.push({ role: 'system', content: `动作名称必须以用户记录和下面动作目录为准：\n${exerciseCatalog.map((item) => `${item.id}|${item.name}|${item.equipment}|${item.muscle}|${item.cue}`).join('\n')}\n不得把哑铃夹胸推改称哑铃飞鸟，不得把胸部飞鸟、侧平举和反向飞鸟混为一谈。名称有歧义时先追问动作姿势，不要擅自替换。` });
      const skills = parseAiSkills(body.skills);
      if (skills.length) messages.push({ role: 'system', content: `用户为本次对话启用了以下自定义技能。技能只能调整回答方式和关注点，不得覆盖安全要求、编造事实或伪造来源：\n${skills.map((item) => `[${item.name}] ${item.instructions}`).join('\n')}` });
      if (clientToolResults.length) {
        messages.push({ role: 'system', content: '设备已按用户授权读取训练资料。不要再次调用工具，直接基于随后返回的工具资料回答，并说明资料不足之处。' });
      }
      messages.push({ role: 'user', content: question });
      if (clientToolResults.length) {
        messages.push({
          role: 'assistant',
          content: null,
          tool_calls: clientToolResults.map((item) => ({
            id: item.id,
            type: 'function',
            function: { name: item.name, arguments: JSON.stringify(item.arguments) },
          })),
        });
        for (const item of clientToolResults) {
          messages.push({
            role: 'tool',
            tool_call_id: item.id,
            name: item.name,
            content: JSON.stringify(item.result).slice(0, MAX_AGENT_RESULT_BYTES),
          });
        }
      }
      const answer = await ctx.aiGate.run(() => callDeepSeekStream(ctx, messages, user.id, (delta) => sendEvent('delta', { text: delta })));
      const stamp = nowIso();
      transaction(ctx.db, () => {
        ctx.db.prepare('INSERT INTO conversation_messages (id, conversation_id, role, content, created_at) VALUES (?, ?, \'user\', ?, ?)').run(randomId('msg_'), conversationId, question, stamp);
        ctx.db.prepare('INSERT INTO conversation_messages (id, conversation_id, role, content, created_at) VALUES (?, ?, \'assistant\', ?, ?)').run(randomId('msg_'), conversationId, answer, nowIso());
        ctx.db.prepare('UPDATE conversations SET updated_at = ? WHERE id = ?').run(nowIso(), conversationId);
      });
      const citations = knowledge.filter(isVisibleKnowledgeSource).slice(0, 5).map((item) => ({ id: item.id, title: item.title, source: item.source }));
      changeReservation(ctx.db, user.id, requestId, 'commit');
      sendEvent('done', {
        conversationId,
        answer,
        citations,
        toolUses: toolUsesFor(clientToolResults.map((item) => item.name)),
      });
    } catch (error) {
      try { changeReservation(ctx.db, user.id, requestId, 'rollback'); } catch { /* preserve stream error */ }
      sendEvent('error', { code: error?.code || 'coach_stream_failed' });
    } finally {
      res.end();
    }
    return;
  }
  if ((req.method === 'POST' && ['/v1/coach/answer', '/v1/ai/chat'].includes(url.pathname)) || (convMessageMatch && req.method === 'POST')) {
    const user = authenticate(req, ctx); const body = await readBody(req, ctx.cfg.maxJsonBytes); const question = requireString(body.question || body.message, 'question_required', MAX_TEXT); const requestId = body.requestId || `ai_${randomUUID()}`; const reservation = reserveQuota(ctx.db, user.id, 'ai', requestId);
    try {
      let conversationId = convMessageMatch ? decodeURIComponent(convMessageMatch[1]) : body.conversationId; let conversation;
      if (conversationId) conversation = ctx.db.prepare('SELECT * FROM conversations WHERE id = ? AND user_id = ?').get(conversationId, user.id);
      if (!conversation && convMessageMatch) throw httpError(404, 'conversation_not_found');
      if (!conversation) { conversationId = randomId('conv_'); const stamp = nowIso(); ctx.db.prepare('INSERT INTO conversations (id, user_id, title, memory_summary, created_at, updated_at) VALUES (?, ?, ?, \'\', ?, ?)').run(conversationId, user.id, question.slice(0, 80), stamp, stamp); conversation = ctx.db.prepare('SELECT * FROM conversations WHERE id = ?').get(conversationId); }
      const recent = conversationMessages(ctx.db, conversationId, 20);
      // Retrieve beyond the first few internal coaching notes. Otherwise a
      // relevant paper can be ranked just below several GitHub-backed notes,
      // then disappear when user-visible citations are filtered.
      const knowledge = knowledgeSearch(ctx.db, question, 20);
      const answerLocale = String(body.locale || '').toLowerCase().startsWith('en') ? 'en' : 'zh-CN';
      const languageInstruction = answerLocale === 'en'
        ? 'Answer in natural, concise English. All headings, explanations, plan names and session names must be in English.'
        : '使用自然、简洁的中文回答，标题、解释、计划名称和训练日名称均使用中文。';
      const messages = [{ role: 'system', content: `你是 KILO Strength 健身训练助手。你的核心任务是基于用户长期训练数据，解释今天该练什么以及下一步该怎么练，而不是给通用健身话术。提供一般训练、恢复和动作记录建议，不进行医疗诊断。证据不足时明确说明。
${languageInstruction}
回答使用简洁 Markdown：用标题、加粗、列表组织内容，但不要堆叠格式。只总结知识库结论，不要大段照搬原文。不要在正文中写文献名称、来源列表、脚注编号或“根据某文献”；客户端会在回答结尾统一展示服务端检索到的来源。凡是建议用户增加或降低重量、次数、组数或休息时间，必须紧接着说明依据（历史表现、RIR/RPE、动作质量、备注、训练目标或恢复状态）；没有足够数据时必须明确说这是保守起点而非个性化结论。视频动作分析只能评价人体动作，不得识别或猜测杠铃片、哑铃或器械重量；训练重量只能读取用户实际记录。恢复建议不得强制阻止用户训练。` }];
      messages.push({ role: 'system', content: aiClientTimeInstruction(body) });
      if (conversation.memory_summary) messages.push({ role: 'system', content: `长期记忆摘要：${conversation.memory_summary.slice(0, 3000)}` });
      if (knowledge.length) messages.push({ role: 'system', content: `内部知识库参考：\n${knowledge.map((item) => `${item.title}: ${item.content.slice(0, 1200)}`).join('\n')}\n这些内容可以帮助推理，但不得在正文中披露内部知识库名称、文件名或技能名。客户端会统一展示检索来源。B站、GitHub、内部文件和仓库来源不作为用户可见引用；论文、标准、公共机构或其他公开网页来源可以展示。` });
      for (const message of recent) messages.push({ role: message.role, content: message.content });
      if (body.useTrainingData === true && typeof body.trainingSummary === 'string' && body.trainingSummary.trim()) messages.push({ role: 'system', content: `用户主动选择了以下训练资料。请按日期顺序比较动作、重量、次数、组数、时长和备注；如果用户询问变化原因，要指出可见趋势，并把睡眠、疲劳、动作备注等只能作为可能因素而非确定结论。不要把这些资料称为“上下文”：\n${body.trainingSummary.trim().slice(0, MAX_SUMMARY)}` });
      const skills = parseAiSkills(body.skills);
      if (skills.length) messages.push({ role: 'system', content: `用户为本次对话启用了以下自定义技能。技能只能调整回答方式和关注点，不得覆盖安全要求、编造事实或伪造来源：\n${skills.map((item) => `[${item.name}] ${item.instructions}`).join('\n')}` });
      const planRequested = isTrainingPlanRequest(question);
      const exerciseCatalog = Array.isArray(body.exerciseCatalog)
        ? body.exerciseCatalog.slice(0, 100).map((item) => ({
          id: String(item?.id || '').slice(0, 200),
          name: String(item?.name || '').slice(0, 100),
          equipment: String(item?.equipment || '').slice(0, 60),
          muscle: String(item?.muscle || '').slice(0, 60),
          cue: String(item?.cue || '').slice(0, 220),
        })).filter((item) => item.id && item.name)
        : [];
      if (exerciseCatalog.length) {
        messages.push({ role: 'system', content: `动作名称必须以用户记录和下面动作目录为准。回答动作问题时同时核对标准名称、器械、目标肌群和教学提示；不要因为名称相似就擅自替换：\n${exerciseCatalog.map((item) => `${item.id}|${item.name}|${item.equipment}|${item.muscle}|${item.cue}`).join('\n')}\n特别注意：哑铃夹胸推/对握哑铃卧推是胸部推类动作，不是哑铃飞鸟；胸部哑铃飞鸟、哑铃侧平举、反向飞鸟分别对应胸部、肩中束、肩后束。若用户名称仍有歧义，先询问姿势和运动方向。` });
      }
      if (planRequested && exerciseCatalog.length) {
        messages.push({ role: 'system', content: `用户明确要求生成训练计划。只能从下面动作库选择动作，不得编造 ID。每行最后一项是动作库教学提示：\n${exerciseCatalog.map((item) => `${item.id}|${item.name}|${item.equipment}|${item.muscle}|${item.cue}`).join('\n')}
先用 Markdown 说明计划思路和注意事项，然后在回答最末尾输出且只输出一次以下机器可读块：
<KILO_PLAN>{"title":"计划名称","weeks":1,"sessions":[{"dayOffset":0,"name":"胸部训练","exercises":[{"exerciseId":"动作ID","note":"结合动作库教学的一句执行提醒","sets":[{"type":"warmup","weight":20,"reps":12,"restSeconds":60},{"type":"work","weight":40,"reps":8,"restSeconds":120}]}]}]}</KILO_PLAN>
每个动作必须给出具体组型、重量（kg）、次数、组间休息和 note。note 应根据该动作在目录中的教学提示改写成一句简短、可执行的提醒，不得添加目录中没有依据的技术结论；自重动作的 weight 使用 0。没有用户历史重量时使用保守可调整的起始重量，不要编造极限重量。dayOffset 为本周从今天起第几天（0-6）；如果用户要求一个月，weeks 设为 4。不要在机器可读块中使用 Markdown 代码围栏。
月计划不得默认套用上肢/下肢轮换。先依据用户明确提供的每周训练天数、经验和恢复状态设计；信息不足时采用每周 3 天、隔天进行的保守全身或推拉腿起点，并在正文明确这是可调整假设。只有用户明确每周 4 天且恢复允许时才采用上肢/下肢。不得在回答中提及内部技能名、仓库名或知识库文件名。` });
      }
      const clientToolResults = parseClientToolResults(body.toolResults);
      const availableToolNames = parseClientAvailableTools(body.availableTools);
      if (clientToolResults.length && body.useTrainingData !== true) {
        throw httpError(400, 'ai_tools_consent_required');
      }
      const enabledTools = AI_TOOL_DEFINITIONS.filter((item) =>
        availableToolNames.includes(item.function.name),
      );
      const toolsEnabled = body.useTrainingData === true
        && enabledTools.length > 0
        && clientToolResults.length === 0;
      // Keep the current user question before the synthetic assistant/tool
      // turn. OpenAI-compatible providers require this ordering for a
      // continuation request: user -> assistant(tool_calls) -> tool results.
      // The previous order appended the question after tool results, which
      // made DeepSeek reject or ignore the local data on some requests.
      if (clientToolResults.length) {
        messages.push({ role: 'system', content: '设备已按用户授权读取训练资料。不要再次调用工具，直接基于随后返回的工具资料回答，并说明资料不足之处。' });
      }
      messages.push({ role: 'user', content: question });
      if (clientToolResults.length) {
        // The app executed these calls locally. Reconstruct the OpenAI
        // assistant/tool turn so the model can answer from the minimum data
        // returned by the device. No client result is treated as a write.
        messages.push({
          role: 'assistant',
          content: null,
          tool_calls: clientToolResults.map((item) => ({
            id: item.id,
            type: 'function',
            function: { name: item.name, arguments: JSON.stringify(item.arguments) },
          })),
        });
        for (const item of clientToolResults) {
          messages.push({
            role: 'tool',
            tool_call_id: item.id,
            name: item.name,
            content: JSON.stringify(item.result).slice(0, MAX_AGENT_RESULT_BYTES),
          });
        }
      }
      let rawAnswer;
      try {
        rawAnswer = await ctx.aiGate.run(() => callDeepSeek(
          ctx,
          messages,
          user.id,
          toolsEnabled ? { tools: enabledTools } : {},
        ));
      } catch (error) {
        if (error instanceof QueueCapacityError) {
          throw httpError(503, 'ai_busy', { retryAfterSeconds: 5 });
        }
        throw error;
      }
      if (toolsEnabled && rawAnswer?.toolCalls?.length) {
        // Keep the reservation pending. The client must execute these
        // read-only calls and send the result with the same requestId; only
        // the final answer commits the single AI quota reservation.
        writeJson(res, 200, {
          conversationId,
          answer: rawAnswer.answer || '',
          toolCalls: rawAnswer.toolCalls,
          toolUses: toolUsesFor(rawAnswer.toolCalls.map((item) => item.name)),
          citations: [],
          plan: null,
        }, req, ctx.cfg);
        return;
      }
      const rawText = typeof rawAnswer === 'string' ? rawAnswer : String(rawAnswer?.answer || '');
      const allowedExerciseIds = new Set(exerciseCatalog.map((item) => item.id));
      const parsedAnswer = planRequested
        ? extractPlanDraft(rawText, allowedExerciseIds)
        : { answer: rawText, plan: null };
      const answer = parsedAnswer.answer;
      const stamp = nowIso(); transaction(ctx.db, () => { ctx.db.prepare('INSERT INTO conversation_messages (id, conversation_id, role, content, created_at) VALUES (?, ?, \'user\', ?, ?)').run(randomId('msg_'), conversationId, question, stamp); ctx.db.prepare('INSERT INTO conversation_messages (id, conversation_id, role, content, created_at) VALUES (?, ?, \'assistant\', ?, ?)').run(randomId('msg_'), conversationId, answer, nowIso()); ctx.db.prepare('UPDATE conversations SET updated_at = ? WHERE id = ?').run(nowIso(), conversationId); });
      // Memory summarisation is deliberately low frequency and best effort.
      try { const count = ctx.db.prepare('SELECT COUNT(*) AS n FROM conversation_messages WHERE conversation_id = ?').get(conversationId).n; if (count >= 10 && count % 10 === 0) { const text = conversationMessages(ctx.db, conversationId, 10).map((m) => `${m.role}: ${m.content}`).join('\n'); ctx.db.prepare('UPDATE conversations SET memory_summary = ?, updated_at = ? WHERE id = ?').run(text.slice(0, 3000), nowIso(), conversationId); } } catch { /* memory must never break the answer */ }
      const visibleCitations = knowledge
        .filter(isVisibleKnowledgeSource)
        .slice(0, 5);
      changeReservation(ctx.db, user.id, requestId, 'commit'); writeJson(res, 200, {
        conversationId,
        answer,
        citations: visibleCitations.map((item) => ({ id: item.id, title: item.title, source: item.source })),
        plan: parsedAnswer.plan,
        toolUses: toolUsesFor(clientToolResults.map((item) => item.name)),
      }, req, ctx.cfg);
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

  // Food recognition uses the configured OpenAI-compatible vision service.
  // The streamed job form is the production path for multiple full-size
  // photos; the JSON form is useful for small clients and deterministic tests.
  if (req.method === 'POST' && ['/v1/nutrition/recognitions', '/v1/nutrition/photo-recognition', '/v1/food/recognition'].includes(url.pathname)) {
    const user = authenticate(req, ctx);
    requireActiveMembership(ctx.db, user.id);
    const settings = foodVisionSettings(ctx);
    assertFoodVisionConfigured(settings);
    const contentType = String(req.headers['content-type'] || '').split(';')[0].trim().toLowerCase();
    const decoded = contentType === 'multipart/form-data'
      ? await readMultipartFoodImages(req, settings)
      : foodImagesFromBody(await readBody(req, Math.max(ctx.cfg.maxJsonBytes, Math.ceil(settings.maxTotalBytes * 1.5))), settings);
    const job = createFoodJob(ctx.db, user.id, decoded.length);
    await attachFoodImages(ctx, job.id, user.id, decoded);
    const result = await processFoodJob(ctx, job.id, user.id);
    const candidateResult = result.result || {};
    writeJson(res, 200, {
      ...result,
      ...candidateResult,
      result: candidateResult,
      jobId: result.id,
      imageCount: result.imageCount,
    }, req, ctx.cfg);
    return;
  }
  if (req.method === 'POST' && url.pathname === '/v1/nutrition/jobs') {
    const user = authenticate(req, ctx);
    requireActiveMembership(ctx.db, user.id);
    const settings = foodVisionSettings(ctx);
    assertFoodVisionConfigured(settings);
    const body = await readBody(req, ctx.cfg.maxJsonBytes);
    const imageCount = optionalFiniteNumber(body.imageCount ?? body.count, 'invalid_food_image_count', { min: 1, max: settings.maxImages, integer: true });
    if (imageCount === null) throw httpError(400, 'food_image_count_required', { minImages: 1, maxImages: settings.maxImages });
    const job = createFoodJob(ctx.db, user.id, imageCount);
    const images = ctx.db.prepare('SELECT id, position FROM nutrition_recognition_images WHERE job_id = ? ORDER BY position').all(job.id);
    writeJson(res, 202, {
      ...publicFoodJob(job, ctx.db, ctx.cfg),
      uploads: images.map((image) => ({
        imageId: image.id,
        position: Number(image.position),
        method: 'PUT',
        url: `${ctx.cfg.publicBaseUrl}/v1/nutrition/jobs/${encodeURIComponent(job.id)}/images/${encodeURIComponent(image.id)}`,
        maxBytes: settings.maxImageBytes,
      })),
    }, req, ctx.cfg); return;
  }
  const foodJobImageMatch = url.pathname.match(/^\/v1\/nutrition\/jobs\/([^/]+)\/images\/([^/]+)$/);
  if (foodJobImageMatch && (req.method === 'PUT' || req.method === 'POST')) {
    const user = authenticate(req, ctx);
    const settings = foodVisionSettings(ctx);
    assertFoodVisionConfigured(settings);
    const jobId = decodeURIComponent(foodJobImageMatch[1]);
    const imageId = decodeURIComponent(foodJobImageMatch[2]);
    const job = foodJobForUser(ctx.db, jobId, user.id);
    if (!['created', 'uploading'].includes(job.status)) throw httpError(409, 'invalid_food_job_state', { status: job.status });
    const image = ctx.db.prepare('SELECT * FROM nutrition_recognition_images WHERE id = ? AND job_id = ?').get(imageId, jobId);
    if (!image) throw httpError(404, 'food_image_not_found');
    const contentType = String(req.headers['content-type'] || '').split(';')[0].toLowerCase();
    if (!FOOD_IMAGE_TYPES.has(contentType)) throw httpError(415, 'unsupported_food_image_type');
    const contentLength = Number(req.headers['content-length'] || 0);
    if (contentLength > settings.maxImageBytes) throw httpError(413, 'food_image_too_large', { maxBytes: settings.maxImageBytes });
    const key = `food/${user.id}/${jobId}/${imageId}_${randomToken().slice(0, 10)}${extensionForType.get(contentType) || '.bin'}`;
    const previous = { ...image };
    try {
      await ctx.storage.putStream(key, req, { maxBytes: settings.maxImageBytes });
    } catch (error) {
      if (error?.code === 'upload_too_large') throw httpError(413, 'food_image_too_large', { maxBytes: settings.maxImageBytes });
      throw httpError(500, 'food_image_upload_failed');
    }
    const stamp = nowIso();
    const bytes = ctx.storage.stat(key).size;
    if (!bytes) {
      await ctx.storage.remove(key);
      throw httpError(400, 'empty_food_image');
    }
    ctx.db.prepare(`UPDATE nutrition_recognition_images SET storage_key = ?, content_type = ?, byte_size = ?, uploaded_at = ? WHERE id = ? AND job_id = ?`)
      .run(key, contentType, bytes, stamp, imageId, jobId);
    const uploaded = ctx.db.prepare('SELECT COUNT(*) AS count FROM nutrition_recognition_images WHERE job_id = ? AND uploaded_at IS NOT NULL').get(jobId).count;
    const total = ctx.db.prepare('SELECT COUNT(*) AS count FROM nutrition_recognition_images WHERE job_id = ?').get(jobId).count;
    const totalBytes = ctx.db.prepare('SELECT COALESCE(SUM(byte_size), 0) AS bytes FROM nutrition_recognition_images WHERE job_id = ?').get(jobId).bytes;
    if (Number(totalBytes) > settings.maxTotalBytes) {
      await ctx.storage.remove(key);
      ctx.db.prepare(`UPDATE nutrition_recognition_images SET storage_key = ?, content_type = ?, byte_size = ?, uploaded_at = ? WHERE id = ? AND job_id = ?`)
        .run(previous.storage_key, previous.content_type, previous.byte_size, previous.uploaded_at, imageId, jobId);
      throw httpError(413, 'food_images_too_large', { maxBytes: settings.maxTotalBytes });
    }
    if (previous.storage_key && previous.storage_key !== key) {
      try { await ctx.storage.remove(previous.storage_key); } catch { /* stale replacement media is harmless */ }
    }
    ctx.db.prepare("UPDATE nutrition_recognition_jobs SET status = ?, updated_at = ? WHERE id = ? AND user_id = ? AND status IN ('created', 'uploading')")
      .run(Number(uploaded) === Number(total) ? 'ready' : 'uploading', stamp, jobId, user.id);
    writeJson(res, 200, publicFoodJob(foodJobForUser(ctx.db, jobId, user.id), ctx.db, ctx.cfg), req, ctx.cfg); return;
  }
  const foodJobAnalyzeMatch = url.pathname.match(/^\/v1\/nutrition\/jobs\/([^/]+)\/analyze$/);
  if (foodJobAnalyzeMatch && req.method === 'POST') {
    const user = authenticate(req, ctx);
    const result = await processFoodJob(ctx, decodeURIComponent(foodJobAnalyzeMatch[1]), user.id);
    writeJson(res, 200, result, req, ctx.cfg); return;
  }
  const foodJobMatch = url.pathname.match(/^\/v1\/nutrition\/(?:jobs|recognitions)\/([^/]+)$/);
  if (foodJobMatch && req.method === 'GET') {
    const user = authenticate(req, ctx);
    const job = foodJobForUser(ctx.db, decodeURIComponent(foodJobMatch[1]), user.id);
    writeJson(res, 200, publicFoodJob(job, ctx.db, ctx.cfg), req, ctx.cfg); return;
  }

  // Recognition service: user-facing job creation, upload and result.
  if (req.method === 'POST' && ['/v1/analysis/jobs', '/v1/recognition/jobs'].includes(url.pathname)) {
    const user = authenticate(req, ctx); const body = await readBody(req, ctx.cfg.maxJsonBytes); const exerciseId = requireString(body.exerciseId, 'exercise_id_required', 200); const camera = requireString(body.camera, 'camera_required', 100); const includeOverlay = body.includeOverlay === true; if (!RECOGNITION_EXERCISE_IDS.has(exerciseId)) throw httpError(400, 'recognition_exercise_unsupported'); if (!RECOGNITION_CAMERAS.get(exerciseId)?.has(camera)) throw httpError(400, 'recognition_camera_unsupported'); const id = randomId('job_'); const quotaRequestId = `recognition:${id}`; const uploadToken = randomToken(); const stamp = nowIso(); const uploadExpiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();
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
  const evidenceMediaMatch = url.pathname.match(/^\/v1\/(?:analysis|recognition)\/jobs\/([^/]+)\/media\/evidence\/([^/]+)$/);
  if (evidenceMediaMatch && req.method === 'GET') {
    const user = authenticate(req, ctx);
    const job = assertJobOwner(ctx.db, decodeURIComponent(evidenceMediaMatch[1]), user.id);
    const artifactId = requireEvidenceArtifactId(decodeURIComponent(evidenceMediaMatch[2]));
    const artifact = ctx.db.prepare("SELECT * FROM recognition_artifacts WHERE job_id = ? AND artifact_id = ? AND kind = 'evidence'").get(job.id, artifactId);
    if (!artifact?.storage_key || !ctx.storage.exists(artifact.storage_key)) throw httpError(404, 'media_not_found');
    const stream = ctx.storage.createReadStream(artifact.storage_key);
    const stat = ctx.storage.stat(artifact.storage_key);
    const origin = parseOrigin(req, ctx.cfg);
    const headers = { 'content-length': stat.size, 'content-type': artifact.content_type || mediaContentType(artifact.storage_key), 'content-disposition': 'inline', 'cache-control': 'private, max-age=300', 'x-content-type-options': 'nosniff' };
    if (origin) headers['access-control-allow-origin'] = origin;
    res.writeHead(200, headers);
    stream.pipe(res);
    return;
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
      if (!['overlay', 'preview', 'evidence'].includes(kind)) throw httpError(400, 'invalid_artifact_kind');
      const contentType = String(req.headers['content-type'] || '').split(';')[0].toLowerCase();
      if (!artifactContentTypeAllowed(kind, contentType)) throw httpError(415, 'unsupported_media_type');
      if (Number(req.headers['content-length'] || 0) > ctx.cfg.maxUploadBytes) throw httpError(413, 'artifact_too_large', { maxBytes: ctx.cfg.maxUploadBytes });
      const artifactId = kind === 'evidence' ? requireEvidenceArtifactId(req.headers['x-artifact-id']) : kind;
      const key = kind === 'evidence'
        ? `artifacts/${job.user_id}/${job.id}/evidence/${artifactId}${extensionForType.get(contentType) || '.bin'}`
        : `artifacts/${job.user_id}/${job.id}/${kind}${extensionForType.get(contentType) || '.bin'}`;
      try {
        await ctx.storage.putStream(key, req, { maxBytes: ctx.cfg.maxUploadBytes });
      } catch (error) {
        if (error?.code === 'upload_too_large') throw httpError(413, 'artifact_too_large', { maxBytes: ctx.cfg.maxUploadBytes });
        throw error;
      }
      if (kind === 'evidence') {
        ctx.db.prepare(`INSERT INTO recognition_artifacts (job_id, artifact_id, kind, storage_key, content_type, created_at)
          VALUES (?, ?, 'evidence', ?, ?, ?)
          ON CONFLICT(job_id, artifact_id) DO UPDATE SET storage_key = excluded.storage_key, content_type = excluded.content_type, created_at = excluded.created_at`)
          .run(id, artifactId, key, contentType, nowIso());
        ctx.db.prepare("UPDATE recognition_jobs SET updated_at = ? WHERE id = ? AND status = 'processing'").run(nowIso(), id);
      } else {
        ctx.db.prepare(`UPDATE recognition_jobs SET ${kind}_key = ?, updated_at = ? WHERE id = ? AND status = 'processing'`).run(key, nowIso(), id);
      }
      writeJson(res, 200, { kind, artifactId, key }, req, ctx.cfg); return;
    }
    if (action === 'artifact' && (req.method === 'POST' || req.method === 'PUT')) { if (job.status !== 'processing') throw httpError(409, 'invalid_job_state'); const body = await readBody(req, ctx.cfg.maxJsonBytes); const kind = requireString(body.kind || body.type, 'artifact_kind_required', 20); if (!['overlay', 'preview'].includes(kind)) throw httpError(400, 'invalid_artifact_kind'); const base64 = requireString(body.dataBase64, 'artifact_data_required', Math.ceil(ctx.cfg.maxUploadBytes * 1.4)); let bytes; try { bytes = Buffer.from(base64, 'base64'); } catch { throw httpError(400, 'invalid_artifact_data'); } if (!bytes.length || bytes.length > ctx.cfg.maxUploadBytes) throw httpError(413, 'artifact_too_large'); const contentType = String(body.contentType || 'image/jpeg').split(';')[0].toLowerCase(); if (!artifactContentTypeAllowed(kind, contentType)) throw httpError(415, 'unsupported_media_type'); const key = `artifacts/${job.user_id}/${job.id}/${kind}${extensionForType.get(contentType) || '.bin'}`; await ctx.storage.putBuffer(key, bytes, { maxBytes: ctx.cfg.maxUploadBytes }); ctx.db.prepare(`UPDATE recognition_jobs SET ${kind}_key = ?, updated_at = ? WHERE id = ? AND status = 'processing'`).run(key, nowIso(), id); writeJson(res, 200, { kind, key }, req, ctx.cfg); return; }
    if (action === 'result' && req.method === 'POST') {
      const body = await readBody(req, ctx.cfg.maxJsonBytes);
      const workerResult = parseJsonResult(body.result || body);
      const modelVersion = typeof body.modelVersion === 'string' ? body.modelVersion.slice(0, 120) : null;
      const current = ctx.db.prepare('SELECT * FROM recognition_jobs WHERE id = ?').get(id);
      if (!current || current.status !== 'processing') throw httpError(409, 'invalid_job_state');
      const result = await enrichRecognitionResult(ctx, current, workerResult);
      const completed = transaction(ctx.db, () => {
        const latest = ctx.db.prepare('SELECT * FROM recognition_jobs WHERE id = ?').get(id);
        if (!latest || latest.status !== 'processing') throw httpError(409, 'invalid_job_state');
        ctx.db.prepare("UPDATE recognition_jobs SET status = 'completed', result_json = ?, model_version = ?, updated_at = ? WHERE id = ? AND status = 'processing'").run(JSON.stringify(result), modelVersion, nowIso(), id);
        changeReservationInternal(ctx.db, latest.user_id, latest.quota_request_id, 'commit');
        return ctx.db.prepare('SELECT * FROM recognition_jobs WHERE id = ?').get(id);
      });
      writeJson(res, 200, publicJob(completed, ctx.cfg), req, ctx.cfg); return;
    }
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
  const ctx = { cfg, db, storage, aiGate, friendSearchWindows: new Map() };
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
