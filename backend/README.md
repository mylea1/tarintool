# KILO Strength 正式后端

这是 KILO 的 Node.js 22+ 正式服务端。账号、会话、会员/兑换码、权限、AI/识别额度、AI 对话记忆和 GPU 任务均在服务端强制执行；训练、计划、模板和设置通过 `/v1/sync/*` 以用户隔离的本地优先实体同步。

## 本地运行

```powershell
npm install --registry=https://registry.npmmirror.com
$env:KILO_ENABLE_TEST_ADMIN='true' # 仅本地测试时使用
$env:KILO_ENABLE_TEST_MEMBER='true' # 普通体验账号 123/123
$env:KILO_ENABLE_PASSWORD_REGISTRATION='true' # 仅 development/test
npm start
```

健康检查为 `GET /health`。测试管理员 `1234/1234` 和普通体验账号 `123/123` 分别由 `KILO_ENABLE_TEST_ADMIN`、`KILO_ENABLE_TEST_MEMBER` 显式启用；两种测试开关都只允许 development/test，生产安全校验会拒绝它们。App 内的管理员身份不会绕过服务端角色校验。

数据库由 `migrations/001_init.sql` 自动初始化。`KILO_DATA_DIR`、`KILO_DATABASE_PATH` 和 `KILO_MEDIA_DIR` 应指向持久卷；当前媒体实现是服务器磁盘上的 `LocalStorage`，API 使用逻辑 key，未来替换 OSS 不需要改移动端 API。媒体下载始终要求资源所属用户的会话。

## 会员订单与平台支付

- iOS 客户端商品 ID 固定为 `com.kilostrength.pro.monthly`、`com.kilostrength.pro.yearly`，必须在 App Store Connect 中创建完全一致的自动续期订阅。
- 服务器通过 `POST /v1/membership/apple/verify` 校验 App Store 收据，只有 Apple 校验成功后才写入 `membership_orders` 并授予权益；客户端不能直接把订单改成已付款。
- 在服务器私密环境文件中配置 `APPLE_SHARED_SECRET` 和 `APPLE_BUNDLE_ID=com.kilostrength.kiloStrength`。共享密钥不得提交到仓库或放入 Codemagic 的 Dart define。
- `GET /v1/membership/orders` 只返回当前登录用户的订单。相同 Apple transaction ID 不能绑定到另一个形域账号。
- 当前实现主动使用 StoreKit 1 收据完成服务端校验；后续切换 StoreKit 2 时，应迁移到 Apple 签名交易 JWS 校验后再移除兼容路径。
- Android 使用微信支付/支付宝网关适配层。`GET /v1/membership/android/capabilities` 只在对应网关 URL 和密钥均已配置时开放按钮；`POST /v1/membership/android/checkout` 创建服务端订单后向网关请求支付链接。
- 网关回调 `POST /v1/membership/android/webhook/:provider` 必须先将 JSON 对象的 key 递归按字典序排列并紧凑序列化，再使用 `ANDROID_PAYMENT_WEBHOOK_SECRET` 计算 HMAC-SHA256，通过 `x-kilo-payment-signature` 发送。只有 `status=paid` 且签名、订单、支付渠道均匹配时才发放权益；重复回调幂等。
- 完整商户开通、沙盒测试和上线检查见 [`../docs/payment-launch-checklist.md`](../docs/payment-launch-checklist.md)。

## 关键边界

- Bearer session 只以 pepper 哈希存库；Apple/Google token 必须通过服务端 JWKS 校验，未配置 provider 返回 `provider_not_configured`；短信供应商未接入时返回同样的明确失败。
- 密码注册默认关闭，生产环境即使误设 `KILO_ENABLE_PASSWORD_REGISTRATION=true` 也会拒绝启动；客户端可使用 `/v1/auth/logout` 撤销当前 opaque session。
- AI 额度使用 requestId 原子 reserve/commit/rollback。DeepSeek key 只读服务端环境变量；未配置或上游失败会回滚额度。若 key 曾泄露，应立即在 DeepSeek 控制台撤销并重新生成。
- 识别任务为 `create -> upload -> queued -> processing -> completed/failed` 状态机。上传 token 仅 15 分钟有效；计算节点只接受 `KILO_GPU_API_KEY`，原始视频、overlay、preview 和事件证据图均经过大小、MIME、路径及所有者校验。artifact 支持 `PUT` 流式上传（`x-artifact-kind: overlay|preview|evidence`；证据图另带 `x-artifact-id`），大文件不受 JSON body 限制。结果事件以 `startMs/peakMs/endMs/displayTime` 定位，完整 overlay 默认关闭。
- 训练摘要只有请求显式 `useTrainingData: true` 时才注入 AI；对话仅发送近期窗口和可选 `memory_summary`，不会每次上传全部历史。

## 训练方法知识库测试

部署或更新后执行 `npm run seed:knowledge`，会同时写入通用知识与 `knowledge/training-framework.zh-CN.json`。新增内容只保留训练思想、计划结构、进退阶、恢复和安全边界，不启用人物角色、称呼或语言模仿。在 App 的现有 AI 对话中直接输入以下内容即可测试，无需更新客户端：

```text
帮我安排每周三天的增肌计划，并说明每两周怎么复盘
卧推时肩膀不舒服，我应该如何调整？
训练状态连续下降时，计划该怎么改？
```

计划仍使用现有 `<KILO_PLAN>` 数据契约，因此 App 可以继续查看动作、组数、重量、次数、休息并保存到日历。

## 测试

```powershell
npm test
```

测试应使用随机临时目录和端口（不要污染 `backend/data`），覆盖认证、角色、兑换码幂等、额度回滚、同步冲突、AI 未配置、识别/GPU/媒体、用户隔离及上传安全边界。
