import { createHash, randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';

export const nowIso = () => new Date().toISOString();
export const randomId = (prefix = '') => `${prefix}${randomBytes(16).toString('hex')}`;
export const randomToken = () => randomBytes(32).toString('base64url');
export const sha256 = (value, pepper = '') => createHash('sha256').update(`${pepper}\u0000${value}`).digest('hex');

export function hashPassword(password, salt = randomBytes(16).toString('hex'), minimumLength = 4) {
  if (typeof password !== 'string' || password.length < minimumLength || password.length > 256) throw new Error('invalid_password');
  return { salt, hash: scryptSync(password, salt, 64).toString('hex') };
}

export function verifyPassword(password, salt, expectedHex) {
  if (!password || !salt || !expectedHex) return false;
  const actual = scryptSync(password, salt, 64);
  const expected = Buffer.from(expectedHex, 'hex');
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

export function safeEqualText(left, right) {
  const a = Buffer.from(String(left || ''));
  const b = Buffer.from(String(right || ''));
  return a.length === b.length && timingSafeEqual(a, b);
}
