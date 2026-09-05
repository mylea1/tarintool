import { SignJWT, importPKCS8 } from 'jose';

const TOKEN_AUDIENCE = 'https://oauth2.googleapis.com/token';
const MESSAGING_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

export function fcmConfigured(config) {
  return Boolean(config.firebaseProjectId && config.firebaseClientEmail && config.firebasePrivateKey);
}

export function createFcmSender(config, fetchImpl = fetch) {
  let cachedToken = null;
  let expiresAt = 0;

  async function accessToken() {
    if (cachedToken && Date.now() < expiresAt - 60_000) return cachedToken;
    const key = await importPKCS8(config.firebasePrivateKey.replaceAll('\\n', '\n'), 'RS256');
    const now = Math.floor(Date.now() / 1000);
    const assertion = await new SignJWT({ scope: MESSAGING_SCOPE })
      .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
      .setIssuer(config.firebaseClientEmail)
      .setSubject(config.firebaseClientEmail)
      .setAudience(TOKEN_AUDIENCE)
      .setIssuedAt(now)
      .setExpirationTime(now + 3600)
      .sign(key);
    const response = await fetchImpl(TOKEN_AUDIENCE, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }),
    });
    const payload = await response.json();
    if (!response.ok || !payload.access_token) throw new Error('firebase_oauth_failed');
    cachedToken = payload.access_token;
    expiresAt = Date.now() + Number(payload.expires_in || 3600) * 1000;
    return cachedToken;
  }

  return async ({ token, title, body, data = {} }) => {
    if (!fcmConfigured(config)) return { delivered: false, reason: 'not_configured' };
    const bearer = await accessToken();
    const response = await fetchImpl(
      `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(config.firebaseProjectId)}/messages:send`,
      {
        method: 'POST',
        headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data: Object.fromEntries(Object.entries(data).map(([key, value]) => [key, String(value)])),
          },
        }),
      },
    );
    if (!response.ok) {
      const error = new Error('firebase_send_failed');
      error.statusCode = response.status;
      throw error;
    }
    return { delivered: true };
  };
}
