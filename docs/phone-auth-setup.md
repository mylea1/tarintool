# 手机号注册与短信登录部署说明

本文说明正式后端的中国大陆手机号注册、短信登录和阿里云 PNVS 配置。实现不会在请求中返回验证码，也不会在日志或数据库中保存验证码明文；本地/测试环境可以通过代码注入 `smsSender` 隔离真实短信，生产环境不得使用该注入路径。

## 1. 阿里云 PNVS 配置

短信实现调用固定的阿里云号码认证服务（PNVS）端点：

- Host：`dypnsapi.aliyuncs.com`
- Action：`SendSmsVerifyCode`
- Version：`2017-05-25`
- 方法：HTTPS `POST`，ACS3-HMAC-SHA256 签名
- 端点和 Action 不接受 URL 或环境变量覆盖，避免把请求转发到任意主机

在后端私密环境中设置以下变量；访问密钥只放服务端环境/密钥管理器，不要放入 Flutter define、客户端资源、Git 或日志：

```dotenv
ALIYUN_ACCESS_KEY_ID=替换为服务端访问密钥 ID
ALIYUN_ACCESS_KEY_SECRET=替换为服务端访问密钥 Secret
ALIYUN_SMS_SIGN_NAME=恒创联众
ALIYUN_SMS_TEMPLATE_CODE=100001
ALIYUN_SMS_CODE_PARAM=code
KILO_SMS_OTP_PEPPER=替换为至少32字节的独立随机值
```

PNVS 请求固定包含：`PhoneNumber=11位号码`、`CountryCode=86`、`CodeLength=6`、`CodeType=1`、`ValidTime=300`、`Interval=60`、`DuplicatePolicy=1`、`AutoRetry=0`、`ReturnVerifyCode=true`。模板参数严格为：

```json
{"code":"##code##","min":"5"}
```

只有上游 HTTP 成功、`Code` 为 `OK`、`Success` 为 `true` 且 `Model.VerifyCode` 严格为六位数字时，后端才把请求标记为可验证。PNVS 失败、超时、响应过大或返回结构不符合要求均返回通用 `sms_send_failed`，不会自动重发。

## 2. API

所有 `identifier` 先做 NFKC/空白和 `+86` 归一化；短信路由随后只接受 `/^\+861[3-9]\d{9}$/`。因此 `13812345678` 和 `+8613812345678` 是同一账号，国际号码不会被错误发送给 `CountryCode=86`。

### 请求验证码

```http
POST /v1/auth/phone/request
Content-Type: application/json

{"identifier":"13812345678","purpose":"register"}
```

成功（HTTP 200）：

```json
{
  "sent": true,
  "retryAfterSeconds": 60,
  "expiresInSeconds": 300,
  "challengeId": "sms_..."
}
```

`purpose` 必须为 `register` 或 `login`，两种用途的验证码互不相认。供应商未配置返回 HTTP 503 `provider_not_configured`；格式错误返回 HTTP 400；持久化限频返回 HTTP 429 `sms_rate_limited`；供应商失败返回 HTTP 502 `sms_send_failed`。

### 短信注册

```http
POST /v1/auth/phone/register
Content-Type: application/json

{"identifier":"+8613812345678","password":"至少8个字符","code":"123456"}
```

成功（HTTP 201）返回既有认证格式：`{user, session}`。密码为 8–128 个字符，注册不依赖、也不会开启旧的不安全 `KILO_ENABLE_PASSWORD_REGISTRATION`。已存在原始手机号账号、已占用 phone identity 或 identity 冲突时返回 HTTP 409 `identifier_taken`/`phone_identity_conflict`，不会创建第二个用户。

### 短信登录

```http
POST /v1/auth/phone/verify
Content-Type: application/json

{"identifier":"13812345678","code":"123456"}
```

成功（HTTP 200）返回 `{user, session}`。只允许已注册账号；未知号码返回 HTTP 404 `phone_not_registered`，不会自动注册。历史密码账号若其 `users.identifier` 本身就是唯一的 11 位手机号，可在首次成功短信验证后写入 `verified_at`；任意未验证 profile alias 不会被单独当成登录凭据，也不能跨账号绑定。

原有密码接口 `POST /v1/auth/phone/login` 保持不变，仍兼容显式启用的测试账号和既有短密码；密码不会 trim，长度上限为 256，失败尝试另有持久化限频。新手机号注册仍限制为 8–128 个字符。

验证码错误、过期、重放和用途不匹配不会泄漏账号状态以外的上游信息：

- `invalid_sms_code`（HTTP 401）：无可用 challenge、错误码、已消费或并发消费失败
- `sms_code_expired`（HTTP 401）：challenge 已过期，并立即标记消费
- `sms_code_attempts_exceeded`（HTTP 429）：同一 challenge 五次错误后消费且锁定
- `phone_not_registered`（HTTP 404）：登录用途验证码正确但没有可登录账号
- `phone_identity_conflict`（HTTP 409）：多个原始账号或 identity 占用导致无法安全猜测归属

## 3. 持久化安全边界

迁移 `backend/migrations/003_phone_auth.sql` 创建 `sms_challenges`、`sms_rate_events` 和 `password_login_failures`：

- challenge 只存 `KILO_SMS_OTP_PEPPER` 域隔离 HMAC、创建/过期时间、用途、尝试次数和状态；不存验证码明文
- TTL 为 5 分钟，最多 5 次验证，成功/过期/重放/替换均为一次性状态；并发消费使用条件 UPDATE
- 错误尝试在抛出 HTTP 错误前单独提交，不能被外层业务事务回滚
- 注册/登录成功时，challenge 消费、用户/phone identity、权益和 session 在同一 SQLite 事务中提交
- 重发会先替换同手机号同用途的旧 pending/sent challenge；限频预留与 challenge 插入在同一事务中，随后才调用上游。上游失败会将 challenge 标记 `failed`，失败请求不能登录
- 手机号和 IP 限制：每手机号 60 秒 1 次、1 小时 5 次、1 日 10 次；每 IP 60 秒 5 次、1 小时 20 次、1 日 100 次
- 密码失败限制：每 identifier 15 分钟 5 次、每 IP 15 分钟 20 次；记录值是服务端 pepper hash

## 4. 反向代理 IP 信任

默认按 TCP socket peer 限制 IP，完全忽略 `X-Forwarded-For`。只有把反向代理实际 peer 明确写入 `KILO_TRUSTED_PROXY_IPS` 后，后端才接受一个合法的 `X-Real-IP`；缺失、逗号分隔、多值或非法值都会回退 socket peer。IPv4-mapped IPv6 会规范为 IPv4。

例如服务仅监听本机且 Nginx 在本机转发时，可配置：

```dotenv
KILO_TRUSTED_PROXY_IPS=127.0.0.1,::1
```

只有确认网络路径不可由外部伪造该 peer/header 时才这样配置。部署配置文件本身不由本文自动修改；应在实际运维环境按可信代理拓扑设置。

## 5. 本地测试与上线前检查

在 `backend` 目录执行：

```powershell
npm test
```

`backend/test/phone-auth.test.mjs` 使用随机临时数据库，并注入只返回合成验证码的 sender，不触发真实短信。线上验收前应确认：PNVS 签名权限仅允许所需 Action，访问密钥来自密钥管理器，`KILO_SMS_OTP_PEPPER` 与 session/GPU pepper 不复用，数据库和日志目录权限正确，代理 IP/header 配置与真实拓扑一致。

验证码由 PNVS 生成并通过 `ReturnVerifyCode` 返回服务端；客户端只收到发送成功状态，必须由用户手工输入短信中的验证码。运行时 AI/远端内容与真实短信上游响应不属于可穷举的本地静态文案或测试数据。
