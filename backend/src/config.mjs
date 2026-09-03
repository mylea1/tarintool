import path from 'node:path';
import { fileURLToPath } from 'node:url';

// URL.pathname is not a valid Windows filesystem path (spaces remain encoded
// as %20). Resolve relative paths from the backend directory through the
// standard URL-to-path conversion instead.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const resolveFromRoot = (value, fallback) => path.resolve(root, value || fallback);
const intValue = (env, name, fallback) => {
  const value = Number(env[name] || fallback);
  if (!Number.isFinite(value) || value <= 0) throw new Error(`invalid_${name.toLowerCase()}`);
  return Math.floor(value);
};
const nonNegativeIntValue = (env, name, fallback) => {
  const value = Number(env[name] ?? fallback);
  if (!Number.isFinite(value) || value < 0) throw new Error(`invalid_${name.toLowerCase()}`);
  return Math.floor(value);
};

export function loadConfig(env = process.env) {
  const resolve = (value, fallback) => resolveFromRoot(value, fallback);
  return Object.freeze({
    nodeEnv: env.NODE_ENV || 'development',
    host: env.KILO_HOST || '127.0.0.1',
    port: intValue(env, 'KILO_PORT', 8790),
    publicBaseUrl: (env.KILO_PUBLIC_BASE_URL || `http://127.0.0.1:${env.KILO_PORT || 8790}`).replace(/\/+$/, ''),
    allowedOrigins: new Set((env.KILO_ALLOWED_ORIGINS || '').split(',').map((item) => item.trim()).filter(Boolean)),
    trustedProxyIps: new Set((env.KILO_TRUSTED_PROXY_IPS || '').split(',').map((item) => item.trim()).filter(Boolean)),
    dataDir: resolve(env.KILO_DATA_DIR, 'data'),
    databasePath: resolve(env.KILO_DATABASE_PATH, 'data/kilo.sqlite3'),
    mediaDir: resolve(env.KILO_MEDIA_DIR, 'data/media'),
    maxUploadBytes: intValue(env, 'KILO_MAX_UPLOAD_BYTES', 250 * 1024 * 1024),
    maxJsonBytes: intValue(env, 'KILO_MAX_JSON_BYTES', 2 * 1024 * 1024),
    sessionPepper: env.KILO_SESSION_PEPPER || 'development-only-session-pepper',
    gpuApiKey: env.KILO_GPU_API_KEY || '',
    enableTestAdmin: env.KILO_ENABLE_TEST_ADMIN === 'true',
    enablePasswordRegistration: env.KILO_ENABLE_PASSWORD_REGISTRATION === 'true',
    testAdminIdentifier: env.KILO_TEST_ADMIN_IDENTIFIER || '13023097571',
    testAdminPassword: env.KILO_TEST_ADMIN_PASSWORD || '1234',
    enableTestMember: env.KILO_ENABLE_TEST_MEMBER === 'true',
    testMemberIdentifier: env.KILO_TEST_MEMBER_IDENTIFIER || '123',
    testMemberPassword: env.KILO_TEST_MEMBER_PASSWORD || '123',
    deepSeekApiKey: env.DEEPSEEK_API_KEY || '',
    deepSeekBaseUrl: (env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com').replace(/\/+$/, ''),
    deepSeekModel: env.DEEPSEEK_MODEL || 'deepseek-v4-flash',
    deepSeekThinkingMode: env.DEEPSEEK_THINKING_MODE || 'disabled',
    aiMaxConcurrency: intValue(env, 'KILO_AI_MAX_CONCURRENCY', 10),
    aiQueueLimit: nonNegativeIntValue(env, 'KILO_AI_QUEUE_LIMIT', 40),
    aiRequestTimeoutSeconds: intValue(env, 'KILO_AI_REQUEST_TIMEOUT_SECONDS', 60),
    appleClientId: env.APPLE_CLIENT_ID || '',
    appleSharedSecret: env.APPLE_SHARED_SECRET || '',
    appleBundleId:
      env.APPLE_BUNDLE_ID || 'com.kilostrength.kiloStrength',
    wechatPayGatewayUrl: (env.WECHAT_PAY_GATEWAY_URL || '').replace(/\/+$/, ''),
    wechatPayGatewaySecret: env.WECHAT_PAY_GATEWAY_SECRET || '',
    alipayGatewayUrl: (env.ALIPAY_GATEWAY_URL || '').replace(/\/+$/, ''),
    alipayGatewaySecret: env.ALIPAY_GATEWAY_SECRET || '',
    androidPaymentWebhookSecret: env.ANDROID_PAYMENT_WEBHOOK_SECRET || '',
    googleClientId: env.GOOGLE_CLIENT_ID || '',
    sessionTtlDays: intValue(env, 'KILO_SESSION_TTL_DAYS', 30),
    gpuClaimTimeoutSeconds: intValue(env, 'KILO_GPU_CLAIM_TIMEOUT_SECONDS', 900),
    smsOtpPepper: env.KILO_SMS_OTP_PEPPER || env.KILO_SESSION_PEPPER || 'development-only-sms-otp-pepper',
    aliyunAccessKeyId: env.ALIYUN_ACCESS_KEY_ID || '',
    aliyunAccessKeySecret: env.ALIYUN_ACCESS_KEY_SECRET || '',
    aliyunSmsSignName: env.ALIYUN_SMS_SIGN_NAME || '',
    aliyunSmsTemplateCode: env.ALIYUN_SMS_TEMPLATE_CODE || '',
    aliyunSmsCodeParam: env.ALIYUN_SMS_CODE_PARAM || 'code',
  });
}

export const config = loadConfig();

export function assertProductionConfiguration(candidate = config, env = process.env) {
  if (env.NODE_ENV !== 'production' && candidate.nodeEnv !== 'production') return;
  const problems = [];
  if (candidate.sessionPepper === 'development-only-session-pepper' || candidate.sessionPepper.length < 32) problems.push('KILO_SESSION_PEPPER');
  if (!candidate.gpuApiKey || candidate.gpuApiKey.length < 32) problems.push('KILO_GPU_API_KEY');
  if (candidate.enableTestAdmin) problems.push('KILO_ENABLE_TEST_ADMIN=false');
  if (candidate.enableTestMember) problems.push('KILO_ENABLE_TEST_MEMBER=false');
  if (candidate.enablePasswordRegistration) problems.push('KILO_ENABLE_PASSWORD_REGISTRATION=false');
  const smsProviderConfigured = Boolean(
    candidate.aliyunAccessKeyId &&
    candidate.aliyunAccessKeySecret &&
    candidate.aliyunSmsSignName &&
    candidate.aliyunSmsTemplateCode,
  );
  if (smsProviderConfigured && (!candidate.smsOtpPepper || candidate.smsOtpPepper === 'development-only-sms-otp-pepper' || candidate.smsOtpPepper.startsWith('replace-with-') || candidate.smsOtpPepper.length < 32)) problems.push('KILO_SMS_OTP_PEPPER');
  if (problems.length) throw new Error(`unsafe_production_configuration:${problems.join(',')}`);
}
