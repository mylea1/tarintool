# EMBER AI service deployment checklist

## Current pre-ICP test endpoint

The current TestFlight/Android test endpoint is
`https://magnitude-detail-pipe-cake.trycloudflare.com`. It is provided by
the `kilo-quick-tunnel.service` systemd unit and is intentionally temporary.
Keep `api.kilostrength.cn` as the production endpoint after ICP filing. A
Cloudflare quick-tunnel URL can change when the tunnel is recreated, so update
the `KILO_API_BASE_URL` Dart define before rebuilding if that happens.

The mobile default and the current Codemagic TestFlight workflow intentionally
use this quick-tunnel URL during pre-ICP testing. After the filed domain passes
`curl https://api.kilostrength.cn/health`, change both build entries back to
the production domain. Quick-tunnel URLs are not a permanent production SLA.

This checklist deploys the API gateway and DeepSeek-backed coach on the
existing Alibaba Cloud ECS. GPU action recognition remains a separate worker.

## Architecture for ten simultaneous AI users

- Nginx terminates TLS and proxies only to `127.0.0.1:8790`.
- The Node service authenticates users, stores conversations and knowledge in
  SQLite, and calls DeepSeek. The DeepSeek key never ships in the app.
- `KILO_AI_MAX_CONCURRENCY=10` permits ten upstream AI calls. The next forty
  wait in FIFO order. Additional requests fail with `503 ai_busy` instead of
  exhausting memory.
- A 2 vCPU / 2 GiB ECS is sufficient for this gateway workload. It is not the
  action-recognition machine.

## Manual deployment

1. Add DNS `A` record `api.kilostrength.cn -> 8.145.57.235`.
2. In the ECS security group, allow public TCP 80 and 443. Restrict TCP 22 to
   the developer's current public IP. Do not expose port 8790.
3. Copy the repository to `/opt/kilo/strength-pro` and create the service user:

   ```bash
   useradd --system --home /opt/kilo --shell /usr/sbin/nologin kilo
   mkdir -p /opt/kilo /var/lib/kilo /etc/kilo
   chown -R kilo:kilo /opt/kilo /var/lib/kilo
   ```

4. Install Node.js 22, Nginx and Certbot. In `backend`, run `npm ci
   --omit=dev`.
5. Copy `deploy/ai-production/backend.env.example` to
   `/etc/kilo/backend.env`, replace every placeholder, then protect it with
   `chmod 600 /etc/kilo/backend.env`.
6. Copy `kilo-backend.service` to `/etc/systemd/system/`, then run:

   ```bash
   systemctl daemon-reload
   systemctl enable --now kilo-backend
   curl http://127.0.0.1:8790/health
   ```

7. Copy `nginx-api.conf` to `/etc/nginx/conf.d/kilo-api.conf`, validate with
   `nginx -t`, reload Nginx, then issue TLS with
   `certbot --nginx -d api.kilostrength.cn`.
8. Seed the curated knowledge base once with `npm run seed:knowledge` while the
   same `KILO_DATABASE_PATH` environment is loaded.
9. Verify `https://api.kilostrength.cn/health`. Its `ai.configured` field must
   be `true`, and `ai.limit` must be `10`.
10. Build the app with
    `--dart-define=KILO_API_BASE_URL=https://api.kilostrength.cn`.

## Production switch

The shared test accounts make all people using `123` share the same identity,
conversation memory and quota. Keep `NODE_ENV=staging` for TestFlight testing.
Before a public release, configure Apple/phone login, disable both test
accounts, set `NODE_ENV=production`, and restart the service. Production mode
intentionally refuses to start while test credentials are enabled.

Rotate any DeepSeek or Apple key that has ever been pasted into chat, logs or a
repository. Never put provider secrets in Flutter `--dart-define` values.

## Configuration consoles

- DeepSeek API keys: https://platform.deepseek.com/api_keys
- DeepSeek usage and balance: https://platform.deepseek.com/usage
- DeepSeek API documentation: https://api-docs.deepseek.com/
- Alibaba Cloud ECS instance: https://ecs.console.aliyun.com/server/i-0jl6lw92zpboe7bt3fyz/detail?regionId=cn-wulanchabu
- Alibaba Cloud security groups: https://ecs.console.aliyun.com/securityGroup/region/cn-wulanchabu
- Alibaba Cloud ICP filing: https://beian.aliyun.com/
- MIIT filing lookup: https://beian.miit.gov.cn/
- GoDaddy domain and DNS manager: https://dcc.godaddy.com/
- Certbot Nginx instructions: https://certbot.eff.org/instructions?ws=nginx&os=pip
- Apple identifiers and capabilities: https://developer.apple.com/account/resources/identifiers/list
- Apple provisioning profiles: https://developer.apple.com/account/resources/profiles/list
- Apple APNs keys: https://developer.apple.com/account/resources/authkeys/list
- App Store Connect API integration: https://appstoreconnect.apple.com/access/integrations/api
- App Store Connect TestFlight: https://appstoreconnect.apple.com/teams/b08ee04b-c3b2-45be-a285-adcf249f22ab/apps/6798718494/testflight
- Codemagic application settings: https://codemagic.io/app/6a7163482be1f8e3c5c6794b/settings
- Google OAuth credentials (only when Google login is implemented): https://console.cloud.google.com/apis/credentials
- Alibaba Cloud SMS (only when real phone login is implemented): https://dysms.console.aliyun.com/
- Cloudflare dashboard (optional DNS/CDN, not required for the AI gateway): https://dash.cloudflare.com/
