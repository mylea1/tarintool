# Web → Mobile 功能矩阵（Flutter 基线）

本矩阵以 `web-prototype/src/main.ts`、`ui.ts` 与 `state.ts` 为交互基线，记录 Android/iOS 共享层的迁移状态。Flutter 业务状态集中在 `mobile/lib/controller.dart`，平台能力通过 `MethodChannel('kilo.platform.timer')` 边界接入。

| Web 入口/能力 | Flutter 入口 | 状态与交互 | 测试/证据 |
| --- | --- | --- | --- |
| 主页、训练周、下一节动作 | `HomePage` | 空安排、训练中进度、周条、长期趋势、最近进步；摘要打开趋势图与解释性指标 | `widget_test.dart` progress chart |
| 计划列表 → 独立实时训练、组别类型、RPE、完成与休息计时 | `TrainPage` / `_WorkoutView` | 五项导航中的训练入口顶部切换“计划 / 记录”；计划首屏只保留我的计划、新建计划和官方计划入口；每个计划明确开始训练，进入可返回且保留状态的 live view | `widget_test.dart` plan/live route |
| 计划详情、官方计划、自定义模板 | `_PlansView` | 官方计划以单日模板弹窗呈现，二级详情列动作、组数、次数和休息；模板显式保存，组别类型/重量/次数/删除在窄屏换行 | `widget_test.dart` official/template/responsive |
| 训练历史与日期排程 | `RecordsPage` | 月历整格显示完成/已安排/错过/今日状态；主页最多三条历史，“查看全部”打开弹窗，记录详情显示每组数据 | `widget_test.dart` history/calendar/detail |
| 动作库、搜索、肌群/器械筛选 | `ExerciseLibraryPage` | 左侧固定肌群 rail（全部/胸/背/肩/腿/手臂/核心），右侧动作搜索与器械筛选；32 个内置动作 + 自定义动作、空结果态 | `widget_test.dart` muscle rail |
| 动作详情与三作用域资源 | `_showExerciseDetail` | library/workout/plan 备注及教学链接独立保存 | 详情 sheet 手动验收 |
| 动作识别 | `RecognitionPage`（AI 顶部“动作识别” tab） | idle/ready/processing/complete/low-confidence/offline/error；主页进步项可直达该 tab；`RecognitionApi` Mock 边界可替换服务端 | `recognition_api.dart` / `widget_test.dart` |
| 知识库 AI | `AiPage` | 五项导航中的 AI 入口顶部切换问答/动作识别；问答主区只保留消息流和底部输入；抽屉支持新建/切换/删除对话；URL、训练授权和演示场景集中在设置 sheet | `widget_test.dart` AI tabs/drawer |
| 我的、设备与隐私 | `ProfilePage` | Android 通知、iOS Live Activity、Apple Watch 开关；训练偏好和模拟场景入口 | Profile 手动验收 |

## 页面级差异记录

| 页面 | Web 基线保留 | 移动端平台适配差异 | 未完成项 |
| --- | --- | --- | --- |
| 主页 | 训练周、下一节目标、最近进步、空安排 CTA | 使用 `NavigationBar` 与系统安全区，卡片单列滚动；背景由 `CustomPainter` 绘制低动效粒子趋势线 | — |
| 训练 | 计划/模板、组别类型选择、逐组完成、休息计时 | 训练页顶部计划/记录切换；计划与 live view 分离；返回计划不会丢失 workout；Android/iOS 计时由 MethodChannel 触发系统能力；输入控件改为 dp 触控目标 | — |
| 记录 | 月历状态、历史、详情、补录、编辑和删除 | 月历固定 42 格，整格颜色/边框/图标表达完成、排程、错过、今日；训练页记录 tab 显示最近三条，全部历史与动作明细使用 sheet | — |
| 动作库 | 搜索、肌群/器械筛选、详情、私密备注/链接、自定义动作 | 320/375dp 以左 rail + 右列表适配，触控目标至少 44dp；详情使用底部 sheet，三个 scope 通过 segmented control 切换 | — |
| 动作识别 | 上传/演示视频、机位、idle → processing → report、低置信度/离线 | `RecognitionApi` 作为 Mock/BetterCoach 可替换边界；`file_picker` 选择视频、展示文件名/大小、格式校验和重试 | 真正 CameraX/Photos 原生相机采集仍由平台产品决定 |
| AI | 对话、等待、引用、训练数据授权、离线 | 引用单独 sheet 展示，授权可撤销；服务设置支持 Mock 或 `http://127.0.0.1:8790`，调用 `/v1/coach/answer`，不保存 key | — |
| 我的 | 设备连接、偏好、隐私、重置演示 | Android 通知、iOS Live Activity、WatchConnectivity 用 capability switch 表达，不伪造系统构建 | Xcode App Group/Widget target 需 macOS 配置 |

## 迁移约束

- Flutter 与 iOS/Android 原生层共享同一 `AppController` 状态，计时桥只负责系统通知/锁屏展示，不重复实现训练业务规则。Android `MainActivity` 的 ongoing public notification 使用 `VISIBILITY_PUBLIC`、倒计时 chronometer、结束时间和“跳过休息” PendingIntent；Android 13+ 在运行时请求 `POST_NOTIFICATIONS`。
- 识别与 AI 的网络请求均保留客户端接口边界；客户端不保存密钥，离线时显示可恢复状态。
- 交互目标最小 44dp，页面以单列滚动为主；训练组表只在自身区域需要时滚动，不引入页面级横向滚动。
