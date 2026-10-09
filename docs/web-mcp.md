# TrainTool Web 与外部 AI MCP

更新：2026-10-09。新版使用本项目 Flutter App 的动作与业务数据；旧 wger 界面、旧 Web 原型和网页内置聊天已移除。wger 与 health-coach 的知识文件及逐条许可仍保留为可选外部 AI 参考，不代表运行它们的网页或将会员数据交给它们。

## 本地启动

需要 Node.js 22.13+ 与 npm，首次安装依赖需要网络。

- macOS：双击根目录 `start-web.command`；停止用 `stop-web.command`。
- Linux：`./start-web.sh`。
- Windows：双击 `start-web.bat`。
- 通用：`node scripts/agent-launcher.mjs --no-browser`；停止加 `--stop`。

打开 http://127.0.0.1:8792/agent/ 。默认本地体验会员账号与密码均为 `123`，首次无个人记录。该账号只供本地测试。
启动器按锁文件安装依赖，后台运行，复用同版本现有服务。记录位于 `.agent-local/kilo.sqlite3`，日志为 `.agent-local/agent.log`。不会删除旧 `.wger-local` 数据库或 App 数据库。
`start-agent.command`、`start-wger.command`、`start-all.bat` 是新版兼容启动入口。

可复制 `.agent.env.example` 为 `.agent.env` 调整端口、公开地址及 App API 地址。私密配置、令牌、运行数据已加入 Git 忽略规则。无需为网页配置模型密钥。

## 网页使用

首页显示 App 的男女正背面肌肉图，可切换训练量/恢复视图。点选肌群查看近 7 天训练次数、加权训练组数、距上次训练时间及估算恢复时间，点击教学链接打开抖音搜索。
恢复沿用 App 的 38 小时指数疲劳模型：主肌群权重 1，辅助肌群 0.45；按 RIR/RPE 调整努力程度，窗口为 168 小时。预计时间为不新增训练时达到 95% 的模型时间；无近期记录按 App 口径显示 100%，不是生理检测结果。

训练页：新建计划或自由训练，搜索 1324 个 App 动作 ID，查看原有 JPG/GIF 演示和中文说明。可以增删及排序动作、增删组，记录组类型、重量、次数、休息、完成状态、RPE/RIR、有氧数据和备注。勾选完成启动休息计时，支持延长和跳过。每组状态、感受与补充内容保留为组备注，动作和整次训练也有独立备注。只有已完成非热身组计入容量与有效组。
“保存进行中训练”使外部 AI 能读写当前训练；AI 改动后点击“载入 AI 更新”。浏览器中的未提交草稿不会自动替换或上传。

进展页：按同一稳定动作 ID 查看每次训练的最大完成工作组重量、最大次数及日期，完整展示逐组详情和备注。两个最大值可能来自不同组，不能当成同一组成绩。

饮食页：记录餐次、热量、营养素、份量、饮水、备注和估算标志，可调整或删除。每日目标保存热量、目标类型、计算依据与来源。显示已记录摄入与剩余额度；缺少目标显示未设置，超过目标显示超额，不硬编码目标。日期按 Asia/Shanghai。
食物照片交给外部 AI 分析；AI 用 MCP 保存结果。网站不上传或保存食物照片，也不自带照片识别模型。“吃什么”、目标计算和聊天在外部 AI 中完成。

设置页：选择存储方式、连接 App 会员、导入/导出兼容备份、编辑身高体重资料、添加 Markdown Skill、创建或撤销 MCP 授权。顶部按钮切换浅/深主题。系统减少动态偏好关闭大幅动画；移动端使用底部导航和可横向滚动的组表。

## 两种存储与 App 同步

| 选择 | 记录实际位置 | 外部 AI 访问 | 到 Flutter App |
|---|---|---|---|
| 服务器 | 已连接 App 时写入同账号现有 `/v1/sync`；未连接时仅此实例 SQLite | 网站 `/mcp`，浏览器可关闭 | App 重新登录/恢复，或账号设置“同步 MCP 云端记录” |
| 此浏览器本地 | 用户浏览器 IndexedDB，按用户隔离 | 相同网站 `/mcp`，绑定网页须登录且保持在线 | 网页导出 JSON，App 账号设置“导入 Web / MCP 记录” |

切换不会自动迁移、上传或双写，原记录保留在原存储；已有 MCP 令牌会撤销，需要重新创建。请先导出备份。浏览器数据会受到浏览器清理、隐私模式和设备丢失影响；服务器无法恢复它。

服务器模式连接 App：设置中输入自己软件的会员账号与密码，服务使用既有登录、会员权益、同步和聊天 API。密码不存库，上游会话加密保存。每次服务端访问验证会话和会员权益；失败明确报错。连接/断开也会撤销旧 MCP 令牌。当前本地尚未连接真实会员账号，验收用隔离的实际后端 API 测试实例，不能宣称你的线上账号已同步。

新版 App 合并训练、计划、饮食、体重、资料与每日目标，保留较新记录、逐组备注和未识别的备份扩展字段；重复导入不重复新增，删除标记不会被旧备份复活。导入本身不触发上传，后续遵循 App 现有会员备份设置。App 更新需自行编译安装，本次未发布应用商店版本。

浏览器本地中转：服务器只保存存储选择、设备绑定和授权信息，记录请求及回应在进程内存中转，不写记录或操作结果到服务器数据库。记录仍会经过网站服务器与获授权 AI，应信任部署者；“本地存储”不代表数据完全不经过网络。网页离线、换设备、令牌过期或撤销时明确失败；不回退读取云端缓存。中转队列/在线状态为单进程内存，部署应使用单进程或保证同实例路由。

## 外部 AI 连接

地址：`http://127.0.0.1:8792/mcp`。传输为官方 MCP SDK Streamable HTTP。设置中创建独立、限时、分范围的令牌，仅显示一次。在支持自定义 Bearer 请求头的客户端配置：

```json
{
  "url": "http://127.0.0.1:8792/mcp",
  "transport": "streamable-http",
  "headers": { "Authorization": "Bearer <网页生成的专用令牌>" }
}
```

网页登录 token 与 MCP token 不通用。写权限单独勾选，不会给旧只读令牌增加写权限。Skill 不自动授予数据权限。当前没有 OAuth 登录流程，只接受 OAuth 的客户端不能直接连接；不能保证每个 AI 产品支持此配置。
云端 AI 访问不到你电脑的 127.0.0.1。远程使用须将本服务部署到可达的 HTTPS 域名，并将 `KILO_PUBLIC_BASE_URL` 配成该站点、配置可信 Host/Origin；仅改变 URL 不会自动部署。本次仅本地启动，没有公开发布。
可选 stdio 桥仅用于需要它的本机客户端，两种存储模式都不依赖在用户电脑额外安装 MCP 服务。

| 范围 | 主要工具 |
|---|---|
| workouts | search_app_exercises、get_app_exercise、read_workout_history、read_training_plans、read_current_workout、read_exercise_progress、read_recovery |
| workouts.write | save_workout、save_training_plan、save_active_workout、append_plan_exercise、append_current_workout_exercise |
| nutrition / nutrition.write | read_nutrition_history、read_nutrition_day；save_nutrition_entry、save_nutrition_goal |
| profile / profile.write | read_body_profile；save_body_profile、save_body_weight |
| chats | list_conversations、read_conversation，仅服务器模式读取 App 已保存的会员聊天；上游一次最多最近 50 条 |
| skills | 自定义共享 Skill 的 tools/prompts/resources，以及保留的 wger/health-coach 参考资料 |

写工具默认 create；修改/删除传 action、recordId。每个独立操作须有唯一 `idempotencyKey`，网络重试保持同 key 与原参数；改参数必须换 key。建议提供 `expectedVersion`，冲突时重新读取，不覆盖用户更新。
追加工具原子保留原动作和备注；`append_plan_exercise` 需 planId。exerciseId 必须来自 App 动作库；外部 AI 先搜索再使用，不靠名称猜 ID。

保存训练示例（工具 `save_workout`）：

```json
{
  "idempotencyKey": "workout-20261009-unique-01",
  "record": {
    "name": "胸部训练", "date": "2026-10-09T04:00:00.000Z", "note": "睡眠一般",
    "exercises": [{
      "exerciseId": "bench_press", "note": "肩胛收紧", "restSeconds": 120,
      "sets": [{"weight": 60, "reps": 8, "restSeconds": 120, "completed": true,
        "rpe": 8, "rir": 2, "state": "动作稳定", "feeling": "末组吃力",
        "additionalNotes": "下次充分热身", "note": "记录用户原话"}]
    }]
  }
}
```

Skill 是用户提供的 Markdown 指令，通过 MCP 共享给获授权 AI；不会在网站执行任意上传代码，也没有自动安装脚本依赖。

## 部署与许可边界

本版本覆盖上述核心记录流程；App 的订阅支付、原生视频识别、Watch/Live Activity、通知、官方智能排程与全部专用统计界面仍留在 App，没有宣称所有原生能力均迁移到网页。
保持数据库、媒体与 session pepper 持久化，勿启用生产测试账号。反向代理支持普通 HTTP POST 和长轮询，不需要另设浏览器本地 MCP 地址。请勿配置代理正文日志记录浏览器中转内容。
动作媒体由已有 `mobile/assets/exercises/reference` 提供，未复制生成假图片。其 Gym Visual 署名不等于再分发授权；肌群 SVG 原来源授权尚需维护者核实。未来公开源码时须确认素材再分发许可或提供可替换/自带素材方式。第三方知识文件保留各自许可声明，本次未实际公开发布。

## 验证

后端：`cd backend && npm ci && npm test`。包含官方 MCP SDK 真实 HTTP 请求、服务器写到独立实际 App API、上游响应丢失重试、修改冲突、账号/范围隔离、离线/错误设备/撤销、同一网页 IndexedDB 执行模块的持久化与去重、恢复模型。
Flutter：`cd mobile && flutter test`；`flutter analyze`。当前 SDK 在含中文目录分析时曾发生 LSP 路径解析异常，复制相同 lib/test 到 ASCII 临时路径后分析通过；没有跳过错误文件或改测试断言规避问题。
