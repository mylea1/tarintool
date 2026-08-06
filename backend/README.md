# KILO Strength 正式后端

这是 KILO 的 Node.js 22+ 正式服务端。账号、会话、会员/兑换码、权限、AI/识别额度、AI 对话记忆和 GPU 任务均在服务端强制执行；训练、计划、模板和设置通过 `/v1/sync/*` 以用户隔离的本地优先实体同步。

## 本地运行

```powershell
npm install --registry=https://registry.npmmirror.com
$env:KILO_ENABLE_TEST_ADMIN='true' # 仅本地测试时使用
$env:KILO_ENABLE_PASSWORD_REGISTRATION='true' # 仅 development/test
npm start
```

健康检查为 `GET /health`。测试管理员 `1234/1234` 只会在显式设置 `KILO_ENABLE_TEST_ADMIN=true` 时种子；生产环境会拒绝该开关、弱 session pepper 和弱 GPU key。

数据库由 `migrations/001_init.sql` 自动初始化。`KILO_DATA_DIR`、`KILO_DATABASE_PATH` 和 `KILO_MEDIA_DIR` 应指向持久卷；当前媒体实现是服务器磁盘上的 `LocalStorage`，API 使用逻辑 key，未来替换 OSS 不需要改移动端 API。媒体下载始终要求资源所属用户的会话。

## 关键边界

- Bearer session 只以 pepper 哈希存库；Apple/Google token 必须通过服务端 JWKS 校验，未配置 provider 返回 `provider_not_configured`；短信供应商未接入时返回同样的明确失败。
- 密码注册默认关闭，生产环境即使误设 `KILO_ENABLE_PASSWORD_REGISTRATION=true` 也会拒绝启动；客户端可使用 `/v1/auth/logout` 撤销当前 opaque session。
- AI 额度使用 requestId 原子 reserve/commit/rollback。DeepSeek key 只读服务端环境变量；未配置或上游失败会回滚额度。若 key 曾泄露，应立即在 DeepSeek 控制台撤销并重新生成。
- 识别任务为 `create -> upload -> queued -> processing -> completed/failed` 状态机。上传 token 仅 15 分钟有效；GPU 只接受 `KILO_GPU_API_KEY`，原始视频、overlay 和 preview 均经过大小、MIME 和路径校验。artifact 支持 `PUT` 流式上传（`x-artifact-kind: overlay|preview`），大文件不受 JSON body 限制。
- 训练摘要只有请求显式 `useTrainingData: true` 时才注入 AI；对话仅发送近期窗口和可选 `memory_summary`，不会每次上传全部历史。

## 测试

```powershell
npm test
```

测试应使用随机临时目录和端口（不要污染 `backend/data`），覆盖认证、角色、兑换码幂等、额度回滚、同步冲突、AI 未配置、识别/GPU/媒体、用户隔离及上传安全边界。
