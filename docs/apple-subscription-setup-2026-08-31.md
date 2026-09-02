# 形域 Apple 自动续期订阅配置（2026-08-31）

## 建议售价

| 方案 | 中国区售价 | 折合每月 | 相对月付节省 | 推荐展示文案 |
|---|---:|---:|---:|---|
| 月会员 | ¥12 / 月 | ¥12.00 | — | 灵活体验 |
| 年会员 | ¥128 / 年 | 约 ¥10.67 | 约 11% | 最划算 |

商业判断：月卡降低首次长期承诺，年卡提供清晰但不过度的折扣；主要观察指标是付费页到购买成功的转化率，以及年卡选择率。不要用“永久会员”替代自动续期年卡。

> App Store Connect 必须从 Apple 提供的价格点中选择。如果页面没有完全相同的 `¥12 / ¥128`，选择最接近的中国大陆价格点，并以 App Store Connect 最终显示为准。App 内最终展示 StoreKit 返回的本地化价格。

## 固定标识（创建后不要改）

订阅组只创建一个：

- 订阅组参考名称：`KILOSTRENGTH PRO`
- 简体中文显示名称：`形域 PRO`

两个当前在售订阅放在同一个组、同一个服务等级，因为权益相同，只有计费周期不同。已创建的季度订阅停止新售，但不要删除或修改其 Product ID；服务端仍保留历史季度订单读取和 Apple 恢复校验兼容：

| 参考名称 | Product ID | 时长 | 简体中文显示名称 |
|---|---|---|---|
| `KILO PRO Monthly` | `com.kilostrength.pro.monthly` | 1 Month | `形域 PRO 月度会员` |
| `KILO PRO Yearly` | `com.kilostrength.pro.yearly` | 1 Year | `形域 PRO 年度会员` |

历史兼容（不用于新建订单或 App 内商品查询）：`com.kilostrength.pro.quarterly` / 3 Months。若该产品已存在，在 App Store Connect 中保留其记录，但关闭销售地区或将其从当前版本提交项中移除；不要删除产品。

建议本地化描述：

- 月度：`解锁进阶训练分析、AI 训练建议与会员专属功能，按月自动续订。`
- 年度：`解锁进阶训练分析、AI 训练建议与会员专属功能，按年自动续订。`

## App Store Connect 点击路径

入口：[App Store Connect](https://appstoreconnect.apple.com/) → `我的 App` → 选择形域/KILO 应用。

1. 左侧 `商业化（Monetization）` → `订阅（Subscriptions）`。
2. 在“订阅组”右侧点击 `+`，参考名称填 `KILOSTRENGTH PRO`，点击 `创建`。
3. 进入该订阅组，在“订阅”区域点击 `创建`（后续新增时是 `+`）。
4. 依次创建上表两个产品。Product ID 必须完全一致；创建后不能复用或随意修改。不要为季度方案创建新产品。
5. 每个产品进入详情后填写：
   - `Subscription Duration`：月度选 1 Month，年度选 1 Year。
   - `Subscription Prices` → `Add Subscription Price`：基准地区选中国大陆，选对应价格点，确认其他地区自动换算价格。
   - `Availability`：选择准备销售的国家或地区。只做国区首发时先选中国大陆。
   - `App Store Localizations` 右侧 `+`：语言选简体中文，填上表显示名称和描述。
   - `Review Information`：上传付费页截图，并填写审核说明。
6. 如果订阅组中已有季度产品：打开季度产品详情，进入 `Availability`，关闭中国大陆及其他销售地区，或取消其在当前版本中的提交；不要删除季度产品，以便已购买用户继续恢复。
7. 回到订阅组，点击 `Edit Order`。月度和年度权益相同，应放在同一个订阅等级；不要人为做成不同权益等级。
8. 每个当前在售订阅详情点击 `Add for Review`。
9. 第一次提交自动续期订阅时，必须把订阅与一个新的 App 版本一起提交：进入该 iOS 版本页面，在 `In-App Purchases and Subscriptions` 区域点击 `+`，勾选月度和年度订阅，再提交审核。

## 审核截图与审核备注

审核截图应展示应用内真实会员购买页，至少能看到：

- 月度和年度方案及 Apple 返回的本地化价格；
- 自动续期周期；
- 恢复购买；
- 隐私政策与使用条款入口；
- 购买后解锁的具体权益。

可复制的审核备注：

```text
测试路径：启动 App → 我的 → 形域 PRO → 选择月度/年度方案 → 使用 Apple 沙盒账号购买。
两个当前产品提供相同的 PRO 权益，仅续订周期不同。购买完成后会员状态会在“我的”页面显示；“恢复购买”位于同一页面底部。历史季度订阅不再出现在新购买列表，但历史购买仍应可以通过“恢复购买”恢复。
测试期间如需登录，请使用审核账号（在 App Review Information 中单独提供账号和密码）。
```

## 上架前检查

- App 内 Product ID 与本文件完全一致。
- 新购列表只包含 `com.kilostrength.pro.monthly` 和 `com.kilostrength.pro.yearly`；季度 Product ID 仅用于历史恢复。
- 价格只显示 StoreKit 返回值，不在 iOS 界面硬编码人民币价格。
- 购买按钮附近明确写出周期和自动续期。
- 提供“恢复购买”、隐私政策、使用条款。
- App Store Connect 的《付费应用协议》、税务和银行信息均为有效状态。
- 使用 Sandbox/TestFlight 完成购买、续订、取消、恢复购买测试。
- 第一个订阅与新 App 版本一起提交。

## Apple 官方依据

- [创建订阅组、订阅产品、等级、本地化与审核信息](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/)
- [设置自动续期订阅价格](https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions)
- [订阅可用地区](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-availability-for-an-auto-renewable-subscription)
- [首次内购/订阅必须随新版本提交](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase)
- [订阅必填、可本地化字段](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/)
