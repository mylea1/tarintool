# 形域支付上线检查清单

本文档区分“仓库中已经实现的代码”和“必须由账号持有人在支付平台完成的配置”。任何商户私钥、App Store 共享密钥或回调签名密钥都只放在服务端私密环境文件中，不提交 GitHub，也不写入 Flutter `dart-define`。

## 已实现的支付边界

| 平台 | 客户端流程 | 服务端确认 | 未配置时行为 |
| --- | --- | --- | --- |
| iOS | StoreKit 拉取月付/年付商品、发起购买、恢复购买 | Apple 收据校验成功后才将订单置为已支付并发放权益 | 商品或共享密钥缺失时显示明确错误，不生成虚假会员 |
| Android 微信支付 | 创建服务端订单后打开微信支付网关返回的链接 | HMAC 签名回调确认 `paid` 后发放权益，重复回调幂等 | 能力接口返回关闭，按钮禁用 |
| Android 支付宝 | 创建服务端订单后打开支付宝支付网关返回的链接 | HMAC 签名回调确认 `paid` 后发放权益，重复回调幂等 | 能力接口返回关闭，按钮禁用 |

订单状态模型包括待支付、处理中、已完成、已取消、失败、已恢复和退款；当前客户端只允许用户取消待支付订单。Android 从微信/支付宝返回 App 后会重新拉取订单与会员权益。若用户取消本地待支付订单时支付平台的成功通知已经在路上，经过签名验证的成功通知仍会发放会员，避免已经扣款却没有权益。微信/支付宝退款状态自动同步仍需在正式网关中接入各平台的退款通知后才能启用。

## Apple（必须手动完成）

1. 在 [App Store Connect](https://appstoreconnect.apple.com/) 的 App 内购买项目中创建自动续期订阅组。
2. 创建并提交完全一致的商品 ID：
   - `com.kilostrength.pro.monthly`
   - `com.kilostrength.pro.yearly`
3. 填写价格、订阅本地化、审核截图和订阅说明，并确保付费协议、税务和银行信息有效。
4. 将 App 专用共享密钥写入阿里云后端私密环境变量 `APPLE_SHARED_SECRET`；不要写入 Codemagic YAML 或客户端。
5. 使用 Sandbox Apple ID 在 TestFlight 真机完成：购买、取消、续订、恢复购买、重复交易和网络中断测试。
6. App Store Connect 配置入口和官方说明：
   - [配置 App 内购买项目](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/)
   - [测试 App 内购买](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox)
   - [App Review Guidelines 3.1](https://developer.apple.com/app-store/review/guidelines/#payments)

当前服务端使用 StoreKit 1 收据验证兼容路径。它可以用于首版沙盒与审核，但 App Store Server Notifications V2 尚未接入；正式上线自动续订前必须补齐该通知，才能及时处理用户不打开 App 时发生的续订、退款和撤销：[App Store Server Notifications](https://developer.apple.com/documentation/appstoreservernotifications)。Apple 提供了官方 Node.js 验签库，后续应优先使用它而不是自行解析 JWS：[Apple App Store Server Library for Node.js](https://github.com/apple/app-store-server-library-node)。

## 微信支付（必须手动完成）

1. 在 [微信支付商户平台](https://pay.weixin.qq.com/) 开通商户号，并完成 App 支付或 H5 支付所需资质。
2. 在微信开放平台绑定 Android 应用包名与签名；支付能力审批通过前不要在正式包中开启按钮。
3. 部署一个使用微信支付官方 API v3 的网关适配器，并在阿里云后端设置：
   - `WECHAT_PAY_GATEWAY_URL`
   - `WECHAT_PAY_GATEWAY_SECRET`
   - `ANDROID_PAYMENT_WEBHOOK_SECRET`
4. 网关需提供 `POST /checkout`，接受订单号、金额、币种、通知地址和回跳地址，返回 `paymentUrl`。网关收到微信官方通知并验签、核对金额后，再向形域回调。回调 JSON 的 key 递归按字典序排列并紧凑序列化后，使用共享密钥计算 HMAC-SHA256。
5. 参考 [微信支付开发文档](https://pay.weixin.qq.com/doc/v3/merchant/4012791897)。

## 支付宝（必须手动完成）

1. 在 [支付宝开放平台](https://open.alipay.com/) 创建应用并签约 App 支付或手机网站支付。
2. 配置应用公钥证书、支付宝公钥证书和回调地址；私钥只保存在支付网关。
3. 部署支付宝官方 API 网关适配器，并在阿里云后端设置：
   - `ALIPAY_GATEWAY_URL`
   - `ALIPAY_GATEWAY_SECRET`
   - 与微信共用的 `ANDROID_PAYMENT_WEBHOOK_SECRET`
4. 网关验签并核对订单号、金额、商户应用后，才向形域发送已支付回调。
5. 参考 [支付宝 App 支付文档](https://opendocs.alipay.com/open/204/105051)。

## 发布前验收

- iOS 真机分别测试月付、年付、恢复购买、取消续订、退款和同一交易重复回调。
- Android 真机分别测试微信/支付宝已安装、未安装、用户取消、支付成功、支付超时、重复通知和金额篡改。
- 关闭任意商户配置后，对应按钮必须禁用；客户端不得自行改会员状态。
- 服务端日志不得记录完整收据、商户私钥、支付签名密钥、用户密码或会话令牌。
- App Store 版本只展示 Apple 内购；Android 版本只展示微信/支付宝，不在 iOS 数字会员页面引导外部支付。
