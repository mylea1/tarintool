# 形域（Flutter 移动端）

`mobile/` 是形域的 Android/iOS Flutter 实现，与 `web-prototype/` 共用产品交互和状态契约。旧的根目录 Flutter 工程不属于本项目。

AI 问答支持每个账号保存最多 3 个自定义 Skill。用户可在 AI 页右上角进入设置完成新增、修改和删除，也可在聊天输入区上方快速启用或关闭；启用的 Skill 会作为独立系统指令传给服务端，并且不能覆盖安全约束。训练记录页通过“记录 / 统计”页内切换展示周、月、年或自定义时段的训练天数、有效组、容量、肌群分布、训练时长和动作 PR，不增加底部导航入口。

## 已实现能力

- 五项底部导航（主页 / 记录 / 动作 / AI / 我的），右侧圆形训练入口独立打开计划与实时训练；记录页独立展示日历与统计，AI 页顶部切换问答与动作识别，实时训练仍是训练入口内的沉浸状态。
- 主页、个人计划与独立实时训练；支持组别类型（正式、热身、递减、技术、失败）、RPE、整行完成反馈、休息 banner、批量编辑、杠片计算器、动作排序和超级组。
- 训练计划页聚焦“我的计划 + 新建计划”；新建计划先进入未落库草稿 composer，输入名称、添加/替换/排序动作、设置组别类型、计划重量、次数和休息，保存一次性写入列表，取消不会留下空计划。已有计划主体点击进入只读详情（含动作图片、计划组数据），再选择“开始训练”或“编辑计划”。
- 计划重量与训练实际重量分离：开始训练时将计划重量复制为本次实际初值，训练中修改只改变实际重量，记录同时保留计划/实际与重量差；没有计划重量的旧记录明确显示“计划重量未记录”。
- 月历、最近三条训练历史（每条最多三张动作缩略图）、全部历史弹窗、补录、备注与删除；点击任意记录可查看动作及每组计划→实际、差值、达成状态、组别类型、次数和组间休息。
- 统计页的关注动作以图片＋名称选择，每次显示一个动作、一条重量或次数折线；自重动作只展示次数。点选、横向拖动和左右按钮可查看同组配对并回到原始训练，沿用统计页时间范围与器械地点隔离。
- 我的 → 训练进步按自然周展示已完成负重工作组的重量×次数，支持时间范围、非完整周提示、原记录回溯与缺少旧组明细的提示；计划重量达成率与平均重量差收纳在展开项，不再仅凭总量涨跌生成训练建议。
- 饮食体重概览与详情共用日期折线：每日最后一次测量、真实时间间隔、缺测虚线、范围内首尾变化及中性增减文案；点选可查看并编辑或删除对应原始记录。
- 动作库左侧 62dp 肌群 rail（全部/胸/背/肩/腿/手臂/核心），右侧两列图片卡、搜索/器械筛选和蓝底白色加号；动作详情使用单一 legacy `library` 备注与教学链接（仅 HTTP/HTTPS）。
- 动作识别：`file_picker` 选择 MP4/MOV/M4V/WebM，显示文件名/大小、格式校验、取消/重试；报告按视频秒数展示问题事件与对应骨骼证据图，不使用“第几次动作”定位。完整骨骼视频为可选慢路径，默认关闭；界面不向用户暴露置信度或模型实现细节。
- AI：顶部切换问答/动作识别；问答主区支持把训练记录以摘要卡片加入对话并直接发送，抽屉支持新建/切换/删除；填写 HTTP Base URL（例如 `http://127.0.0.1:8790`）后请求 `/v1/coach/answer`，客户端不保存 API key。
- 自由训练：计划页“自由训练 · 立即开始”立即启动总计时；空训练可添加动作，动作从 0 组/0 秒休息开始，首组从 0 kg × 0 次开始；训练中可设置 0–600 秒休息、动态添加动作/组并保存真实记录。完成自由训练时默认可保存为计划，实际重量会转换为下一次计划重量。
- Android foreground service ongoing public 通知/计时 MethodChannel、iOS Live Activity 源码和设备能力开关；实时训练使用单一计时面板（总计时 + 组间休息），批量/杠片/暂停/设置与“+15 秒/跳过”均保留图标、文字和语义提示，动作选择器使用固定部位 rail。

## v7 训练与记录更新

- 实时训练组表统一为“组 / 上次 / kg / 次数 / RPE / 完成”列；“上次”只读取同动作的真实历史快照，缺失时显示 `—`，不使用计划重量伪造历史。
- 组别入口使用图标与短标签，点击后打开可滚动的类型选择底部 sheet；完成整行使用绿色容器、输入框、文字和实心勾，并支持撤销且保留数值。
- 我的计划卡支持点击详情；首屏只有一个“开始”主按钮，编辑、重命名和删除收纳在更多菜单。记录卡展示日期/时间、时长、训练量、有效组、完成率和动作摘要，详情按真实组数据展示绿色完成行。

## v9 动作详情、计时与反馈

- 动作详情概览只显示训练次数、最重重量和估算 1RM；备注最多两行，教学链接固定保存到 legacy `library` scope，并提供可恢复的 HTTP/HTTPS 外部打开反馈。
- 默认动作名称为简体中文；“我的 → 动作名称语言”可切换英文名称，覆盖动作库、选择器、详情和训练摘要，不改变其他界面文案。
- 完成组使用整行绿色反馈与约 800–1200ms 一次性庆祝动效；保存真实训练记录后显示训练完成总结（时长、容量、有效组、动作数、完成率），可查看记录或完成返回计划。

## B 方案产品能力

- 训练完成总结提供“发布训练动态”入口。发布前可写一条可选说明；服务端只接收训练快照（时长、容量、有效组、动作摘要和完成率），训练备注、体重等私密信息不会进入动态。好友动态支持点赞和限定表情评论，不提供自由文本评论。
- 饮食页改为按日期的周导航、时间轴和日历入口。同一天可以连续记录“第 1 餐 / 第 2 餐”等，不再强制早餐/正餐/加餐；食物名称可留空。一次最多选择 8 张图片，保存前展示本地预览和服务端候选值，热量、蛋白质、碳水和脂肪只作为可复核估算，不在客户端伪造识别结果。
- 饮食照片识别客户端请求 `POST /v1/food/recognition`，字段为 multipart `images`；响应遵循 `food-photo-v1`（`status`、`requiresReview`、`items`、`warnings`）。识别失败、图片不足和低确定性都保留可见提示，用户仍可手动保存。
- 训练与饮食共享 `UnifiedCalendarPage`，日历圆点分别代表训练和饮食，点击日期后按时间查看合并时间轴。我的页面还提供图文“使用指南”，图片来自本地品牌和动作素材，离线可打开。
- 主题迁移为语义 Material token，默认保留旧版暖橙兼容色，并新增浅色冰川蓝、森氧绿和钛银红。入口为“我的 → 服务与安全 → 主题颜色”，选择会保存到本机下次启动继续使用。

### B 方案服务端接口约定

好友动态客户端预期以下接口：

```text
POST   /v1/friends/workouts
GET    /v1/friends/feed       # 返回 posts（旧 plans 仍兼容）
POST   /v1/friends/workouts/:postId/like
POST   /v1/friends/workouts/:postId/comments  # JSON: {"emoji":"🔥"}
DELETE /v1/friends/workouts/:postId
POST   /v1/food/recognition   # multipart images（最多 8 个）
```

如果服务端尚未实现识别接口，客户端会明确显示“识别服务未配置/识别失败”，不会把图片名称或本地随机数当作营养结果。服务端和移动端的详细字段以 `docs/contracts/mobile-food-photo-recognition.json` 为准。

## 目录

```text
lib/models.dart             领域模型、动作目录和资源映射
lib/controller.dart         Flutter 共享状态、训练/识别/AI 控制器
lib/main.dart               Material 3 页面与交互组件
lib/recognition_api.dart    动作识别接口与未配置服务实现
lib/ai_api.dart             Coach API HTTP/未配置服务边界
assets/exercises/           动作图片及 attribution（reference/ 含 32 组 JPG/GIF 数据集素材）
android/                    Android 通知与计时桥
ios/Runner/                 iOS MethodChannel 计时桥
ios-live-activity/          ActivityKit/Widget Extension 源码模板
test/                       Flutter widget、controller 与响应式验收测试
```

## 本地运行与验证

在 `strength-pro/mobile` 目录执行：

```bash
flutter pub get
flutter analyze
flutter test
flutter run                 # 连接 Android 设备或模拟器
```

Android debug APK：

```powershell
.\mobile\tool\build_android_debug_isolated.ps1 -Flavor cn
```

该命令需要从仓库根目录执行，并只构建当前 Git `HEAD`：源码快照位于 WSL 原生 ext4，构建全程使用同一套 Linux Flutter/JDK/Android SDK，且通过独占锁阻止重复 Gradle 进程。命名后的 APK 与 SHA256 文件输出到根目录 `artifacts/`。完整流程及故障处理见 [`../docs/android-isolated-build-runbook.md`](../docs/android-isolated-build-runbook.md)。不要再从共享的 `mobile/` 工作区直接运行 `flutter build apk`。

## 安装与版本核验

当前移动端发布标识为 `1.0.34 (36)`，国区包名仍为 `com.kilostrength.kilo_strength`。安装新版 APK 前，若设备上仍有旧版同包名应用，请先卸载旧版，或确认安装器明确显示“覆盖更新”并完成升级；不要只依赖桌面图标判断是否已打开新包。启动后进入“我的 → 个性化 → 应用语言”，可以在简体中文和 English 之间切换。完整数据集仍用于恢复旧记录与稳定 ID；动作库和选择器默认展示人工核对的精简动作目录，以减少重复、无效或媒体不匹配的动作。

上一轮完整动作数据集版本为 `1.0.10+11`；本轮国际化与动作媒体审计版本为 `1.0.11+12`。

当前 `1.0.15+16` 调整自由训练主流程：准备阶段可让 AI 生成本次训练计划；训练动作缩略图可直达动作详情；首次完成组且未设置休息时只询问一次，并把所选时间应用到本次训练后续动作。实时训练顶部暂时只保留“组间休息”辅助入口；完成总结优先对比同名计划或动作重合度最高的上次训练，并可把本次与基线一起交给 AI 总结。动作库和选择器使用人工校验的精简目录与六类器械筛选，旧记录仍可通过完整数据集 ID 恢复。

`1.0.18+19` 增加 `cn/global` 构建渠道：Android 使用手机号入口，国区 iOS 使用手机号与 Apple，海外 iOS 使用 Apple/Google 组合。渠道只控制可见登录方式，未配置 OAuth 或短信供应商时不会模拟成功。饮食、记录与好友页面使用统一 Material 图标和更短的空状态文案。

`1.0.19+20` 接通 iOS 原生 Apple 登录：客户端通过系统 Apple 授权取得 identity token，提交 `/v1/auth/apple` 由服务端使用 Apple JWKS 校验，再保存服务端 session；项目已加入 `Sign in with Apple` entitlement，并绑定 Team ID `Y726TUG6G3`。生产服务器必须设置 `APPLE_CLIENT_ID=com.kilostrength.kiloStrength`，不得把 `.p8`、App Store Connect API 密钥或其他长期密钥写入 Flutter、APK 或 Git。

`1.0.20+21` 完善跨端好友发现：Android 与 iOS 共用服务端稳定用户 ID，可设置唯一用户名，并通过用户名、账号手机号或 Apple 已验证邮箱搜索。手机号和邮箱只支持完整匹配，搜索结果仅显示脱敏联系方式；Apple 不提供“绑定手机号”，因此 Apple 用户如需手机号搜索能力，后续必须通过独立短信验证流程绑定。

国区 Android 构建命令：`flutter build apk --release --flavor cn --dart-define=APP_MARKET=cn`。海外 Android 构建命令：`flutter build apk --release --flavor global --dart-define=APP_MARKET=global`。

也可以使用 `android/gradlew.bat assembleDebug --offline`。仓库配置优先使用中科大 Maven 代理，其次阿里云 HTTPS 镜像，最后回退 Google/Maven Central；Gradle wrapper 保持官方 HTTPS URL，不使用 `file:///E:` 本地仓库。首次构建如果本机没有 Gradle、AndroidX 或 Flutter Maven 缓存，需要联网下载，网络失败时请保留官方 wrapper URL 并稍后重试。

## Android 锁屏通知验收（One UI）

在 Android 13+ 首次开始训练时允许“通知”权限。训练开始即启动 foreground service；完成一组后，将应用切到后台或锁屏，`形域 · 训练中` 通知应保持公开可见并显示总训练时长与休息 `mm:ss`；“跳过休息”只清除休息状态，整次训练结束才移除 ongoing 通知。Samsung One UI 设备若倒计时停止，请在“设置 → 应用 → 形域 → 电池”选择“不受限制”，在“通知 → 锁屏通知”启用显示内容，并确认系统未限制后台活动。Android 14 需要允许应用使用对应 foreground service 类型；通知权限被拒绝时 Flutter 计时仍可用，但锁屏卡片不可见。

## AI 服务配置

远程推送需要把 Firebase 控制台下载的 `google-services.json` 放入 `android/app/`，并在 macOS 工程中加入 `ios/Runner/GoogleService-Info.plist`；iOS 同时要在 Firebase Console 连接 APNs key。没有这些平台文件时，每日训练提醒仍可使用，远程 token 注册会安全降级为不可用，不会模拟推送成功。

进入 AI 页面“服务设置”，填写例如 `http://127.0.0.1:8790` 后，客户端会调用 `${baseUrl}/v1/coach/answer`。留空时显示服务未配置状态，不生成示例回答。训练摘要授权是独立开关，Base URL 只保存在内存状态，不写入密钥或凭据。

## iOS Live Activity

`ios-live-activity/` 提供 `ActivityAttributes`、Dynamic Island UI 和 Live Activity intents 的 Swift 源码。Windows 环境不能运行 Xcode；在 macOS 上请将这些文件加入 Widget Extension target，配置同名 App Group（默认 `group.com.kilostrength.shared`），并按项目签名/部署目标启用 ActivityKit 后再构建 iOS。


## 1.0.34（36）导航与资料调整

主页使用紧凑的“今日安排”，训练建议折叠展开；右上角可进入好友。训练 AI 按钮为可长按拖动的圆形悬浮控件。我的页面顶部展示头像、昵称和十位数字公开 ID，会员独立图片卡展示开通或到期状态；手机号登录和好友搜索继续可用。好友成果卡使用中文指标，动作显示对应组数，点赞与表情移到成果图片之外。复用上次训练时不会把相同的历史备注填入本次备注。签到保持停用。

详见 `../docs/navigation-profile-refresh-2026-09-05.md`。
