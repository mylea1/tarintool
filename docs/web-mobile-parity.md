# Web → Mobile 功能矩阵（Flutter 基线）

本矩阵以 `web-prototype/src/main.ts`、`ui.ts` 与 `state.ts` 为交互基线，记录 Android/iOS 共享层的迁移状态。Flutter 业务状态集中在 `mobile/lib/controller.dart`，平台能力通过 `MethodChannel('kilo.platform.timer')` 边界接入。

| Web 入口/能力 | Flutter 入口 | 状态与交互 | 测试/证据 |
| --- | --- | --- | --- |
| 主页、训练周、下一节动作 | `HomePage` | 始终显示训练概览、训练周、进步摘要、最近记录四个区块；无用户数据时使用紧凑空态并保留自由训练/计划入口，有记录后替换为真实摘要与历史；周条按当前日期、排程和历史动态计算 | `widget_test.dart` clean-state/free training |
| 计划列表 → 独立实时训练、组别类型、RPE、完成与休息计时 | `TrainPage` / `_WorkoutView` | 五项导航中的训练入口顶部切换“计划 / 记录”；计划首屏只保留我的计划、新建计划、自由训练和官方计划入口；实时训练使用单一 timing panel（总计时 + 组间休息），批量/杠片/暂停或开始/设置与“+15 秒/跳过”均保留图标、文字和语义提示；自由训练立即启动总计时，空训练可添加第一个动作，动作选择器支持固定左侧部位 rail、本地搜索和匹配数量，首组默认 0 kg/0 次且休息可设为 0–600 秒；完成组有可减弱动效，结束自由训练可默认保存为计划并展示训练总结；计划重量与实际重量分离并在记录快照中保留 | `widget_test.dart` plan/live/rail/rest/320dp controls/200% text；`controller_test.dart` plannedWeight/free workout/rest |
| 计划详情、官方计划、自定义模板 | `_PlansView` | 新建计划进入未落库草稿 composer，支持添加/替换/排序动作、组别类型、计划重量、次数和休息，保存一次性写入；已有计划主体进入只读详情，显示动作图片与计划数据，再开始训练或编辑；组编辑器使用紧凑两行布局 | `widget_test.dart` official/template/detail/responsive |
| 训练历史与日期排程 | `RecordsPage` | 月历整格显示完成/已安排/错过/今日状态；主页最多三条历史且每条最多三张动作缩略图，“查看全部”打开弹窗；记录详情显示图片、计划→实际重量、差值、达成状态、组别类型、次数和休息；旧记录无计划重量时明确标注未记录 | `widget_test.dart` history/calendar/detail |
| 动作库、搜索、肌群/器械筛选 | `ExerciseLibraryPage` | 左侧 62dp 肌群 rail（全部/胸/背/肩/腿/手臂/核心），右侧两列图片卡、搜索/器械筛选和蓝底白色加号；32 个内置动作 + 自定义动作、空结果态；窄屏搜索会独占一行 | `widget_test.dart` muscle rail；`library_responsive_test.dart` 320dp/200% |
| 动作详情与三标签 | `_showExerciseDetail` | 概览只显示训练次数、最重重量、估算 1RM；教学/记录保留原标签；备注与教学链接固定保存到 legacy `library` scope，仅 HTTP/HTTPS 链接可外部打开 | `widget_test.dart` detail tabs；`link_utils_test.dart` URI normalization |
| 动作识别 | `RecognitionPage`（AI 顶部“动作识别” tab） | idle/ready/processing/error；未配置服务时明确返回 `service_not_configured`，不生成伪报告 | `recognition_api.dart` / `widget_test.dart` |
| 知识库 AI | `AiPage` | 五项导航中的 AI 入口顶部切换问答/动作识别；问答主区只保留消息流和底部输入；抽屉支持新建/切换/删除对话；未配置 URL 时显示服务未配置状态，不显示示例回答 | `widget_test.dart` AI tabs/drawer |
| 我的、设备与隐私 | `ProfilePage` | Android 通知、iOS Live Activity；Apple Watch 显示真实配对/安装状态，并双向同步当前动作、完成组和组间休息 | `controller_test.dart` Watch bridge；macOS 配对模拟器/真机验收 |

## v7 parity evidence

- Live workout now renders one responsive set table (`组 / 上次 / kg / 次数 / RPE / 完成`). The previous column reads the latest completed real history set for the same exercise and index, falls back to a recent completed set for that exercise, and shows `—` when no snapshot exists; plan weights are never used as history.
- Set type is an icon plus compact label with an accessible, scroll-safe bottom-sheet picker. Completed rows switch container, inputs, text, borders and check to green; toggling back preserves weight, reps and RPE.
- Routine cards prioritize free training, open a detail sheet, expose one primary start action, and move edit/rename/delete into the More menu. No new folder surface was introduced.
- Record cards show date/time, duration, volume, effective sets, completion rate and action summary. Record details use structured persisted set rows with actual kg × reps, RPE/rest and a green completed state.
- Validation covers controller history fallback, live completion/type interactions, routine actions, record metrics/details, and a 320dp set-table layout. The v7 preview was also checked at 320/375/414dp and 200% text scale.

## v9 parity evidence

- Live workout renders one timing panel rather than separate header/control/rest cards. The rest actions retain stable keys, text labels, tooltips and accessible semantics; the header switches to a vertical compact layout at 320dp or 200% text scale.
- Exercise detail uses three tabs and a three-metric overview. The resource editor stores one trimmed note/link pair under `library`; URI normalization allows only HTTP/HTTPS and prepends `https://` for host-only input. Opening errors reset loading state and do not block saving.
- Completed sets use a green full-row state with one non-repeating 800–1200ms burst (or a static reduced-motion state). Saving a real record opens `_WorkoutCelebration` with duration, volume, effective sets, exercise count and completion rate, plus “查看记录”/“完成”.
- Default action labels remain Chinese. The profile language setting switches action names to English across the library, picker, detail and touched summaries while leaving other UI copy unchanged.

## 页面级差异记录

| 页面 | Web 基线保留 | 移动端平台适配差异 | 未完成项 |
| --- | --- | --- | --- |
| 主页 | 训练周、下一节目标、最近进步、空安排 CTA | 使用 `NavigationBar` 与系统安全区，卡片单列滚动；背景由 `CustomPainter` 绘制低动效粒子趋势线 | — |
| 训练 | 计划/模板、组别类型选择、逐组完成、休息计时 | 训练页顶部计划/记录切换；计划与 live view 分离；实时训练摘要下方采用紧凑工具栏，减少重复标题和进度卡，返回计划不会丢失 workout；开始训练复制计划重量为实际初值，训练修改不覆盖计划；动作 picker 用固定部位 rail + 右侧搜索列表；Android/iOS 计时由 MethodChannel 触发系统能力；输入控件改为 dp 触控目标 | — |
| 记录 | 月历状态、历史、详情、补录、编辑和删除 | 月历固定 42 格，整格颜色/边框/图标表达完成、排程、错过、今日；训练页记录 tab 显示最近三条缩略图，全部历史与动作明细使用 sheet，并展示计划→实际与差值 | — |
| 动作库 | 搜索、肌群/器械筛选、详情、私密备注/链接、自定义动作 | 320/375dp 以 62dp rail + 右侧两列图片卡适配，触控目标至少 44dp；窄屏搜索与筛选分行；详情使用底部 sheet，三个标签切换，资源固定为 legacy `library` scope | — |
| 动作识别 | 上传视频、机位、idle → processing → report/error | `RecognitionApi` 作为 BetterCoach 可替换边界；`file_picker` 选择视频、展示文件名/大小、格式校验和重试；未配置服务返回清晰错误 | 真正 CameraX/Photos 原生相机采集仍由平台产品决定 |
| AI | 对话、等待、引用、训练数据授权 | 引用单独 sheet 展示，授权可撤销；服务设置填写 `http://127.0.0.1:8790` 后调用 `/v1/coach/answer`，客户端不保存 key；后端代理从 `DEEPSEEK_API_KEY` 读取并在未配置/上游失败时返回可解释错误，不生成样例回答 | `backend-mock/server.mjs` DeepSeek proxy |
| 我的 | 设备连接、偏好、隐私、服务配置 | Android 通知、iOS Live Activity；内置 `KiloWatch` target 通过 WatchConnectivity 自动同步，界面只显示真实配对与安装状态；用户数据从空态开始 | Apple Watch 签名、配对模拟器与真机链路需 macOS/Xcode 验收 |

## 迁移约束

- Flutter 与 iOS/Android 原生层共享同一 `AppController` 状态，计时桥只负责系统通知/锁屏展示，不重复实现训练业务规则。Android foreground service 使用 `kilo_workout_v3` ongoing public notification，每秒显示总训练时长与休息倒计时；“跳过休息”仅清除休息状态，Android 13+ 在运行时请求 `POST_NOTIFICATIONS`，Android 14 声明 foreground service 类型。
- 识别与 AI 的网络请求均保留客户端接口边界；客户端不保存密钥，离线时显示可恢复状态。
- 交互目标最小 44dp，页面以单列滚动为主；训练组表只在自身区域需要时滚动，不引入页面级横向滚动。
