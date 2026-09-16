# Apple 9 月 11 日审核整改（1.0.6+54）

反馈对应提交 d2088fb1-11f1-4888-ba46-aa33cf7a39bd，审核版本 1.0 (38)，iPad Air 11-inch (M3)。

## 代码修复
- 客户端 StoreKit 商品 ID 改成用户 App Store Connect 截图的月度 `11`、年度 `33`；后端创建订单和收据校验同时兼容两个实际 ID，保留旧 ID 的历史恢复支持。Android 商品目录保持原样。
- StoreKit 1 必须在 InAppPurchase.instance 首次访问之前启用，并等待启用完成。当前后端依赖 StoreKit 1 收据，未盲目迁移 StoreKit 2。
- 未找到商品、连接失败显示错误和可点击的重新加载入口；查询有超时；购买期间防止重复点击。
- iOS/macOS 不展示自建兑换码、管理员开通入口与训练解锁 PRO 活动；iOS 兑换调用和训练试用请求也被阻止。Android 保留既有路径。
- 购买页法律链接使用低强调小字号，置于购买按钮下方。“我的”使用正常设置行进入“账号与法律信息”，包含政策链接和删除账号。
- POST /v1/me/delete-account 要求当前会话和 DELETE 确认。删除账号、会话、云同步、社交、AI 对话、识别数据及关联媒体；Apple 账号重新验证同一身份后交换 code、撤销 token；删除成功后清理本机账号和持久训练数据。

## 必须完成的上线步骤
1. 先部署后端补丁，再发布客户端。不能仅上传 IPA，否则新商品 ID 与删除接口不会在旧服务端生效。
2. 服务器私密环境配置：APPLE_SHARED_SECRET（自动续订收据）、APPLE_BUNDLE_ID、APPLE_CLIENT_ID（原生 App ID）、APPLE_TEAM_ID、APPLE_KEY_ID、APPLE_PRIVATE_KEY（Sign in with Apple 私钥）。不得放进 Dart define 或 Git。
3. App Store Connect 确认实际商品 ID 仍为 11、33；付费 App 协议已生效，订阅销售地区、价格、本地化信息完整。商品无需提前审核通过即可在沙盒测试。
4. 在 Mac/Codemagic 构建新 IPA，在真实 iPhone/iPad + TestFlight/沙盒验证月度/年度购买、取消、恢复、重复点击、断网后重试及权益刷新。
5. 用独立可删除测试账号，在实体设备录制登录 → 我的 → 账号与法律信息 → 删除账号 → 确认 → 账号已删除。不得删除真实用户数据做测试。
6. 将录屏链接加入审核备注，App Store 描述继续保留 EULA 链接。Android APK 无法用于验证 StoreKit。

## 审核回复草稿（真机验证完成后使用）
已修正 App Store 商品标识及 StoreKit 初始化，移除 iOS 自建兑换码和相关开通入口，并新增永久账号删除。入口为“我的 → 账号与法律信息 → 删除账号”。请在此附上真机删除流程录屏链接以及已验证的新构建号；未完成真机验证前请勿宣称购买与删除已通过沙盒验收。

## 官方依据
- https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox
- https://developer.apple.com/support/offering-account-deletion-in-your-app/
- https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple
