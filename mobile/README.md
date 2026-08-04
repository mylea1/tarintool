# KILO Strength（Flutter 移动端）

`mobile/` 是 KILO Strength 的 Android/iOS Flutter 实现，与 `web-prototype/` 共用产品交互和状态契约。旧的根目录 Flutter 工程不属于本项目。

## 已实现能力

- 五项底部导航（主页 / 训练 / 动作 / AI / 我的）；训练页顶部切换计划与记录，AI 页顶部切换问答与动作识别，实时训练仍是训练入口内的沉浸状态。
- 主页、个人计划与独立实时训练；支持组别类型（正式、热身、递减、技术、失败）、RPE、整行完成反馈、休息 banner、批量编辑、杠片计算器、动作排序和超级组。
- 训练计划页聚焦“我的计划 + 新建计划”；官方计划收敛为“使用官方计划”入口，先选单日计划再查看动作、组数、次数、休息，并提供“使用此计划 / 开始训练”。模板编辑器支持显式“保存训练模板”与即时反馈，组别类型、重量、次数、删除控件在窄屏自动换行。
- 月历、最近三条训练历史、全部历史弹窗、补录、备注与删除；点击任意记录可查看动作及每组组别类型、重量、次数和组间休息。
- 主页进步摘要点击后打开进步分析 sheet，包含训练量趋势图、关键动作表现、最近训练量、有效组、变化率和无数据状态。
- 动作库左侧肌群 rail（全部/胸/背/肩/腿/手臂/核心），右侧搜索与器械筛选、自定义动作、动作图片和分作用域备注/教学链接。
- 动作识别：`file_picker` 选择 MP4/MOV/M4V/WebM，显示文件名/大小、格式校验、取消/重试和 Mock 识别报告。
- 知识库 AI：顶部切换问答/动作识别；问答主区只保留对话与输入，抽屉支持新建/切换/删除；服务 URL、训练授权和场景在设置 sheet 中；Mock 或可配置 HTTP Base URL（例如 `http://127.0.0.1:8790`），请求 `/v1/coach/answer`，客户端不保存 API key，保留引用、离线/无证据提示。
- Android ongoing public 通知/计时 MethodChannel、iOS Live Activity 源码和设备能力开关。

## 目录

```text
lib/models.dart             领域模型、动作目录和资源映射
lib/controller.dart         Flutter 共享状态、训练/识别/AI 控制器
lib/main.dart               Material 3 页面与交互组件
lib/recognition_api.dart    动作识别接口与 Mock 实现
lib/ai_api.dart             Coach API HTTP/Mock 边界
assets/exercises/           Web 动作图片及 attribution
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

```bash
flutter build apk --debug
# build/app/outputs/flutter-apk/app-debug.apk
```

也可以使用 `android/gradlew.bat assembleDebug --offline`。仓库配置优先使用中科大 Maven 代理，其次阿里云 HTTPS 镜像，最后回退 Google/Maven Central；Gradle wrapper 保持官方 HTTPS URL，不使用 `file:///E:` 本地仓库。首次构建如果本机没有 Gradle、AndroidX 或 Flutter Maven 缓存，需要联网下载，网络失败时请保留官方 wrapper URL 并稍后重试。

## Android 锁屏通知验收（One UI）

在 Android 13+ 首次开始训练时允许“通知”权限。完成一组后，将应用切到后台或锁屏，通知应保持公开可见并显示当前动作、剩余秒数/结束时间和倒计时；“跳过休息”操作会回到 Flutter 状态并取消通知。Samsung One UI 设备若倒计时停止，请在“设置 → 应用 → KILO Strength → 电池”选择“不受限制”，并在“通知 → 锁屏通知”启用显示内容；再次开始一组确认通知使用同一 ongoing 卡片更新，而不是重复堆叠。

## AI 服务配置

进入 AI 页面“服务设置”，留空使用 Mock；填写例如 `http://127.0.0.1:8790` 后，客户端会调用 `${baseUrl}/v1/coach/answer`。训练摘要授权是独立开关，Base URL 只保存在内存状态，不写入密钥或凭据。

## iOS Live Activity

`ios-live-activity/` 提供 `ActivityAttributes`、Dynamic Island UI 和 Live Activity intents 的 Swift 源码。Windows 环境不能运行 Xcode；在 macOS 上请将这些文件加入 Widget Extension target，配置同名 App Group（默认 `group.com.kilostrength.shared`），并按项目签名/部署目标启用 ActivityKit 后再构建 iOS。
