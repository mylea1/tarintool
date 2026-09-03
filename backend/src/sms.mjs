import { createHash, createHmac, randomBytes } from 'node:crypto';
import https from 'node:https';

export const ALIYUN_SMS_HOST = 'dypnsapi.aliyuncs.com';
export const ALIYUN_SMS_ACTION = 'SendSmsVerifyCode';
export const ALIYUN_SMS_VERSION = '2017-05-25';
export const SMS_REQUEST_TIMEOUT_MS = 10_000;

export class SmsProviderError extends Error {
  constructor(code = 'sms_send_failed') {
    super(code);
    this.name = 'SmsProviderError';
    this.code = code;
  }
}

export function smsProviderConfigured(config) {
  return Boolean(
    config?.aliyunAccessKeyId &&
    config?.aliyunAccessKeySecret &&
    config?.aliyunSmsSignName &&
    config?.aliyunSmsTemplateCode &&
    isSmsCodeParam(config?.aliyunSmsCodeParam || 'code'),
  );
}

function isSmsCodeParam(value) {
  return /^[A-Za-z][A-Za-z0-9_]{0,31}$/u.test(String(value));
}

export function rfc3986Encode(value) {
  return encodeURIComponent(String(value))
    .replace(/[!'()*]/gu, (character) => `%${character.charCodeAt(0).toString(16).toUpperCase()}`);
}

export function canonicalQueryString(parameters = {}) {
  return Object.entries(parameters)
    .sort(([left], [right]) => left < right ? -1 : left > right ? 1 : 0)
    .map(([key, value]) => `${rfc3986Encode(key)}=${rfc3986Encode(value)}`)
    .join('&');
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function canonicalHeaders(headers) {
  const selected = Object.entries(headers)
    .map(([name, value]) => [name.toLowerCase(), String(value).trim()])
    .filter(([name]) => name === 'host' || name === 'content-type' || name.startsWith('x-acs-'))
    .sort(([left], [right]) => left < right ? -1 : left > right ? 1 : 0);
  const names = selected.map(([name]) => name);
  return {
    headers: selected.map(([name, value]) => `${name}:${value}\n`).join(''),
    signedHeaders: names.join(';'),
  };
}

// The generic builder is also used by the provider-specific request below so
// the exact ACS3 canonicalization remains independently testable.
export function buildAcs3Request({
  host,
  accessKeyId,
  accessKeySecret,
  action,
  version,
  method = 'POST',
  canonicalUri = '/',
  query = {},
  body = '',
  date,
  nonce = randomBytes(16).toString('hex'),
}) {
  if (!host || !accessKeyId || !accessKeySecret || !action || !version || !date) {
    throw new SmsProviderError('provider_not_configured');
  }
  const payload = String(body);
  const payloadHash = sha256(payload);
  const unsignedHeaders = {
    host,
    'x-acs-action': action,
    'x-acs-version': version,
    'x-acs-date': date,
    'x-acs-signature-nonce': nonce,
    'x-acs-content-sha256': payloadHash,
  };
  const normalizedHeaders = canonicalHeaders(unsignedHeaders);
  const canonicalQuery = canonicalQueryString(query);
  const canonicalRequest = [
    method.toUpperCase(),
    canonicalUri,
    canonicalQuery,
    normalizedHeaders.headers,
    normalizedHeaders.signedHeaders,
    payloadHash,
  ].join('\n');
  const stringToSign = `ACS3-HMAC-SHA256\n${sha256(canonicalRequest)}`;
  const signature = createHmac('sha256', accessKeySecret).update(stringToSign).digest('hex');
  const authorization = `ACS3-HMAC-SHA256 Credential=${accessKeyId},SignedHeaders=${normalizedHeaders.signedHeaders},Signature=${signature}`;
  return {
    options: {
      hostname: host,
      port: 443,
      method: method.toUpperCase(),
      path: canonicalQuery ? `${canonicalUri}?${canonicalQuery}` : canonicalUri,
      headers: {
        ...unsignedHeaders,
        authorization,
      },
    },
    authorization,
    canonicalQuery,
    canonicalHeaders: normalizedHeaders.headers,
    signedHeaders: normalizedHeaders.signedHeaders,
    canonicalRequest,
    stringToSign,
    signature,
    body: payload,
    payloadHash,
  };
}

function smsDate(value = new Date()) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) throw new SmsProviderError('sms_send_failed');
  return date.toISOString().replace(/\.\d{3}Z$/u, 'Z');
}

export function buildAliyunSmsVerifyCodeRequest({
  phone,
  config,
  now = new Date(),
  nonce,
}) {
  if (!smsProviderConfigured(config)) throw new SmsProviderError('provider_not_configured');
  const codeParam = config.aliyunSmsCodeParam || 'code';
  const templateParam = JSON.stringify({ [codeParam]: '##code##', min: '5' });
  const request = buildAcs3Request({
    host: ALIYUN_SMS_HOST,
    accessKeyId: config.aliyunAccessKeyId,
    accessKeySecret: config.aliyunAccessKeySecret,
    action: ALIYUN_SMS_ACTION,
    version: ALIYUN_SMS_VERSION,
    canonicalUri: '/',
    query: {
      PhoneNumber: phone.startsWith('+86') ? phone.slice(3) : phone.replace(/^\+/u, ''),
      CountryCode: '86',
      SignName: config.aliyunSmsSignName,
      TemplateCode: config.aliyunSmsTemplateCode,
      TemplateParam: templateParam,
      CodeLength: 6,
      ValidTime: 300,
      Interval: 60,
      DuplicatePolicy: 1,
      AutoRetry: 0,
      ReturnVerifyCode: true,
      CodeType: 1,
    },
    body: '',
    date: smsDate(now),
    nonce,
  });
  return { ...request, templateParam };
}

// Keep the generic name for callers/tests that only depend on the old
// provider module entry point; the concrete request is PNVS SendSmsVerifyCode.
export const buildAliyunSmsRequest = buildAliyunSmsVerifyCodeRequest;

export async function sendAliyunSms({ phone, config }) {
  const request = buildAliyunSmsVerifyCodeRequest({ phone, config });
  return new Promise((resolve, reject) => {
    let settled = false;
    let absoluteTimer;
    const clearDeadline = () => {
      if (absoluteTimer) clearTimeout(absoluteTimer);
      absoluteTimer = undefined;
    };
    const fail = () => {
      if (settled) return;
      settled = true;
      clearDeadline();
      reject(new SmsProviderError('sms_send_failed'));
    };
    const clientRequest = https.request(request.options, (response) => {
      let responseText = '';
      let responseBytes = 0;
      response.setEncoding('utf8');
      response.on('data', (chunk) => {
        responseBytes += Buffer.byteLength(chunk);
        if (responseBytes > 64 * 1024) {
          clientRequest.destroy();
          fail();
          return;
        }
        // The provider response is tiny.  Do not retain arbitrary upstream
        // content, which could contain secrets or diagnostic data.
        responseText += chunk;
      });
      response.on('end', () => {
        if (settled || response.statusCode < 200 || response.statusCode >= 300) {
          fail();
          return;
        }
        let payload;
        try {
          payload = JSON.parse(responseText);
          const verifyCode = payload?.Model?.VerifyCode;
          if (payload?.Code !== 'OK' || payload?.Success !== true || !/^\d{6}$/u.test(String(verifyCode || ''))) {
            fail();
            return;
          }
        } catch {
          fail();
          return;
        }
        settled = true;
        clearDeadline();
        resolve({ sent: true, verifyCode: String(payload.Model.VerifyCode) });
      });
      response.on('error', fail);
      response.on('aborted', fail);
      response.on('close', () => {
        if (!response.complete) fail();
      });
    });
    clientRequest.setTimeout(SMS_REQUEST_TIMEOUT_MS, () => {
      clientRequest.destroy();
      fail();
    });
    clientRequest.on('error', fail);
    absoluteTimer = setTimeout(() => {
      clientRequest.destroy();
      fail();
    }, SMS_REQUEST_TIMEOUT_MS);
    clientRequest.end(request.body);
  });
}
