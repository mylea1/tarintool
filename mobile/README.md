# KILO Strength（Flutter 移动端）

`mobile/` 是 KILO Strength 的 Android/iOS Flutter 实现，与 `web-prototype/` 共用产品交互和状态契约。旧的根目录 Flutter 工程不属于本项目。

## 已实现能力

- 五项底部导航（主页 / 训练 / 动作 / AI / 我的）；训练页顶部切换计划与记录，AI 页顶部切换问答与动作识别，实时训练仍是训练入口内的沉浸状态。
- 主页、个人计划与独立实时训练；支持组别类型（正式、热身、递减、技术、失败）、RPE、整行完成反馈、休息 banner、批量编辑、杠片计算器、动作排序和超级组。
- 训练计划页聚焦“我的计划 + 新建计划”；新建计划先进入未落库草稿 composer，输入名称、添加/替换/排序动作、设置组别类型、计划重量、次数和休息，保存一次性写入列表，取消不会留下空计划。已有计划主体点击进入只读详情（含动作图片、计划组数据），再选择“开始训练”或“编辑计划”。
- 计划重量与训练实际重量分离：开始训练时将计划重量复制为本次实际初值，训练中修改只改变实际重量，记录同时保留计划/实际与重量差；没有计划重量的旧记录明确显示“计划重量未记录”。
- 月历、最近三条训练历史（每条最多三张动作缩略图）、全部历史弹窗、补录、备注与删除；点击任意记录可查看动作及每组计划→实际、差值、达成状态、组别类型、次数和组间休息。
- 主页进步摘要点击后打开进步分析 sheet，包含实际训练量趋势图、计划重量达成率、平均重量差、关键动作表现、最近训练量、有效组、变化率和无数据状态。
- 动作库左侧 62dp 肌群 rail（全部/胸/背/肩/腿/手臂/核心），右侧两列图片卡、搜索/器械筛选和蓝底白色加号；动作详情使用单一 legacy `library` 备注与教学链接（仅 HTTP/HTTPS）。
- 动作识别：`file_picker` 选择 MP4/MOV/M4V/WebM，显示文件名/大小、格式校验、取消/重试；未配置识别服务时明确显示服务未配置，不生成伪报告。
- 知识库 AI：顶部切换问答/动作识别；问答主区只保留对话与输入，抽屉支持新建/切换/删除；填写 HTTP Base URL（例如 `http://127.0.0.1:8790`）后请求 `/v1/coach/answer`，客户端不保存 API key；未配置时显示服务未配置状态。
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

```bash
flutter build apk --debug
# build/app/outputs/flutter-apk/app-debug.apk
```

## 安装与版本核验

当前移动端发布标识为 `1.0.10 (11)`，包名仍为 `com.kilostrength.kilo_strength`。安装新版 APK 前，若设备上仍有旧版同包名应用，请先卸载旧版，或确认安装器明确显示“覆盖更新”并完成升级；不要只依赖桌面图标判断是否已打开新包。启动后进入“我的 → 应用版本”，确认看到 `1.0.10 (11)` 以及“新版导航：训练/记录、AI/识别已合并”。动作库完整包含 1,324 个数据集动作，每个动作使用独立 reference JPG 封面，并可查看 GIF、概览、教学和训练记录。

上一轮账号/会员/额度改动版本为 `1.0.9+10`；本轮完整动作数据集版本为 `1.0.10+11`。

也可以使用 `android/gradlew.bat assembleDebug --offline`。仓库配置优先使用中科大 Maven 代理，其次阿里云 HTTPS 镜像，最后回退 Google/Maven Central；Gradle wrapper 保持官方 HTTPS URL，不使用 `file:///E:` 本地仓库。首次构建如果本机没有 Gradle、AndroidX 或 Flutter Maven 缓存，需要联网下载，网络失败时请保留官方 wrapper URL 并稍后重试。

## Android 锁屏通知验收（One UI）

在 Android 13+ 首次开始训练时允许“通知”权限。训练开始即启动 foreground service；完成一组后，将应用切到后台或锁屏，`KILO · 训练中` 通知应保持公开可见并显示总训练时长与休息 `mm:ss`；“跳过休息”只清除休息状态，整次训练结束才移除 ongoing 通知。Samsung One UI 设备若倒计时停止，请在“设置 → 应用 → KILO Strength → 电池”选择“不受限制”，在“通知 → 锁屏通知”启用显示内容，并确认系统未限制后台活动。Android 14 需要允许应用使用对应 foreground service 类型；通知权限被拒绝时 Flutter 计时仍可用，但锁屏卡片不可见。

## AI 服务配置

进入 AI 页面“服务设置”，填写例如 `http://127.0.0.1:8790` 后，客户端会调用 `${baseUrl}/v1/coach/answer`。留空时显示服务未配置状态，不生成示例回答。训练摘要授权是独立开关，Base URL 只保存在内存状态，不写入密钥或凭据。

## iOS Live Activity

`ios-live-activity/` 提供 `ActivityAttributes`、Dynamic Island UI 和 Live Activity intents 的 Swift 源码。Windows 环境不能运行 Xcode；在 macOS 上请将这些文件加入 Widget Extension target，配置同名 App Group（默认 `group.com.kilostrength.shared`），并按项目签名/部署目标启用 ActivityKit 后再构建 iOS。
