# 形域智能训练

这是一个与女性照片日记应用完全隔离的商业产品原型。当前阶段优先验证移动端形态的 Web 高保真交互，再冻结数据契约并进入 Flutter iOS/Android 正式客户端开发。

## 当前实现

- `web-prototype/`：Vite + TypeScript，可交互高保真原型，状态保存在 `localStorage`
- 六个一级入口：主页、训练、记录、动作库、识别、AI；计划入口保留在“训练”内
- 训练入口先展示已保存计划；可直接开始、编辑计划或创建新计划。空白训练必须先添加动作，未添加动作时不会启动计时
- 训练模板：文件夹、空白训练、组数/组类型/重量/次数范围/动作休息、热身、超级组、替换、排序和私密备注/链接
- 实时训练：上次数据、RPE、每组休息、逐组完成、组类型选择器、实时 PR、杠片计算器、批量修改和训练计时
- 计划详情：查看计划不会启动计时，只有点击“开始训练”才会生成当前训练并开始计时
- 训练记录：独立“记录”入口，保存、补录、编辑、删除、完整月历、未来排程；已完成、已安排和已安排但未完成使用不同状态色
- 动作库：完整导入 `exercise-dataset-reference` 的 1,324 个动作；每个动作都有独立 JPG 封面、GIF 演示、中文教学和详情记录入口
- 计划：官方计划库、等级/目标/器械筛选、规则/AI 草案、上次训练转模板和单节模板保存
- 动作备注与私密链接：动作库、计划/模板和实时训练三个场景独立保存，可直接打开教学视频
- 进步中心：肌群分布、周热力图、动作趋势、长期目标正反馈
- 动作识别：上传、机位、分析、报告、低置信度和离线场景
- AI 问答：独立界面、来源引用、本地训练摘要授权和离线状态
- 设备能力模拟：灵动岛、锁屏、Android 通知和 Apple Watch
- 移动端预览：Web 在宽屏中仍保持 520 px 以内的手机应用结构；浅色主题、粒子背景支持系统“减少动态效果”

## 一键运行前后端

双击根目录的 `start-all.bat`。脚本会自动：

- 检查 Node.js 与 npm
- 缺少依赖时使用 npmmirror 安装前端依赖
- 启动 Web 前端 `http://127.0.0.1:4174`
- 启动 Mock API 后端 `http://127.0.0.1:8790`
- 等待健康检查通过后打开浏览器

脚本会检测已经运行的服务，不会重复占用端口。不希望自动打开浏览器时运行：

```powershell
.\start-all.bat --no-browser
```

## 单独运行与验证前端

```powershell
cd "E:\fitness app\strength-pro\web-prototype"
npm install --registry=https://registry.npmmirror.com
npm run dev
npm run build
```

## Flutter 移动端

`mobile/` 是与根目录旧 Flutter/BetterCoach 工程隔离的形域 Android/iOS 主应用，业务状态和交互以 `web-prototype/` 为基线。Android 可离线复用本机 Gradle 分发版构建 Debug APK：

```powershell
cd "E:\fitness app\strength-pro\mobile"
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

产物位于 `mobile/build/app/outputs/flutter-apk/app-debug.apk`。iOS 业务界面共享同一 Flutter 代码；灵动岛、锁屏 Live Activity 和 AppIntent 源码位于 `mobile/ios-live-activity/`，需在 macOS Xcode 中加入 Widget Extension 后构建。移动端功能矩阵见 [`docs/web-mobile-parity.md`](docs/web-mobile-parity.md)，识别请求/结果边界见 [`contracts/mobile-recognition.json`](contracts/mobile-recognition.json)。

## 阶段边界

Web 原型不接入正式认证、支付、生产数据库或真实原生系统能力。Flutter 移动端已接入本地优先训练状态、识别/AI 客户端边界和 Android/iOS 计时桥；正式云端 Drift 同步、BetterCoach 生产识别服务、ActivityKit Xcode target 与 WatchConnectivity 仍需在契约冻结后配置。

粒子层只使用少量点、邻近连线和可见性暂停。Flutter 端可用 `CustomPainter` 和 `AnimationController` 实现同类效果，开启 Reduce Motion 时只绘制静态帧。

## 素材与许可

- 动作插画许可：`web-prototype/public/assets/exercises/ATTRIBUTION.md`
- 肌群图第三方声明：`web-prototype/public/assets/muscles/THIRD_PARTY_NOTICES.md`
