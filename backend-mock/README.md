# KILO 本地后端代理

零依赖 Node.js 本地服务，用于启动 Web/Flutter 需要的接口。Coach 请求由服务端代理 DeepSeek，API key 只从服务端环境变量读取，不会返回或打印；服务不保存用户训练数据，也不执行真实动作识别。

默认地址：`http://127.0.0.1:8790`

健康检查：`GET /health`

支持的原型接口：

- `POST /v1/analysis/jobs`
- `GET /v1/analysis/jobs/{id}`
- `GET /v1/analysis/jobs/{id}/result`
- `POST /v1/analysis/jobs/{id}/ack`
- `POST /v1/coach/answer`（需要 `DEEPSEEK_API_KEY`，未配置返回 503）
- `POST /v1/coach/plan-draft`
- `GET /v1/content/exercises`
- `GET /v1/content/plans`

账号、会员和额度接口已登记在 `../contracts/mobile-account-membership.json`。
当前 mock 对这些路径返回 `501 account_service_not_configured`，不会伪造登录成功或扣减额度；Flutter 使用本地测试 repository，生产服务必须按契约在服务端完成鉴权、角色校验和原子扣减/回滚。

## DeepSeek 配置

`.env.example` 只是字段模板；当前 `server.mjs` 不会自动加载 `.env`。请在部署平台配置环境变量，或在 PowerShell 当前进程中设置后再启动服务（命令只会交互读取 key，不要把真实 key 写入文档、脚本或 Git）：

```powershell
$env:DEEPSEEK_API_KEY = Read-Host '输入新 key'
$env:DEEPSEEK_BASE_URL = 'https://api.deepseek.com'
$env:DEEPSEEK_MODEL = 'deepseek-v4-flash'
node server.mjs
```

- `DEEPSEEK_API_KEY`：必填，只在服务器环境中设置。不要提交 `.env`，也不要把 key 放进 Flutter、网页或日志。
- `DEEPSEEK_BASE_URL`：可选，默认 `https://api.deepseek.com`。
- `DEEPSEEK_MODEL`：可选，默认 `deepseek-v4-flash`。

客户端只填写自家后端地址，例如 `http://127.0.0.1:8790`，不会直连 DeepSeek。若旧 key 曾经泄漏，请先在 DeepSeek 控制台撤销，再在服务器设置新 key；本仓库不会替你管理或恢复密钥。

Coach 请求会校验问题非空和长度，服务端使用 30 秒超时，并在医学风险、证据不足时要求模型明确提示。上游错误只返回通用错误码，不透传响应正文。
