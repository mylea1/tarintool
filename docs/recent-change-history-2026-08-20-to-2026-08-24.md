# 近期修改与发布记录（2026-08-20—2026-08-24）

本文档按时间记录近期已经完成的主要代码修改、部署操作和后端数据变更。内容保持简要，只说明“改了什么”和“怎么改的”，不记录 API 密钥、密码哈希、会话令牌等敏感值。

## 2026-08-20

### 18:18｜会员订单与签到奖励

- Git 提交：`ed43630`（`feat: add membership orders and check-in rewards`）
- 更改内容：增加会员月付/年付订单、待支付订单取消、Apple 收据校验、每日签到及累计签到奖励。
- 实现方式：扩展 SQLite 数据表和后端会员接口；移动端增加订单、会员和签到状态组件，并补充迁移、接口及界面测试。

### 22:34｜AI 读取训练数据工具

- Git 提交：`57fa710`（`feat: add read-only AI training tools`）
- 更改内容：允许 AI 在用户授权范围内读取训练计划和训练记录，为回答提供真实训练上下文。
- 实现方式：后端增加只读训练工具；移动端接入工具调用状态和教学链接处理；AI 只能读取，不允许直接破坏或覆盖训练数据。

## 2026-08-21

### 09:33｜自由训练与 AI 计划流程简化

- Git 提交：`048fb09`（`feat: streamline free workout planning and rest flow`）
- 更改内容：自由训练准备阶段可生成 AI 训练计划；动作详情入口、首次休息时间设置及训练总结流程得到简化。
- 实现方式：调整训练控制器和训练页状态；首次完成组且没有休息设置时只询问一次，并将选择应用到后续动作。

## 2026-08-23

### 15:24｜休息计时持久化与训练历史 PR

- Git 提交：`455b419`（`fix: persist rest timers and add workout history PRs`）
- 更改内容：修复休息计时和训练历史在重启后的恢复问题；PR 开始结合历史同动作记录计算。
- 实现方式：增加训练历史本地持久化层；保存绝对计时状态和历史动作数据；增加历史、休息和 PR 自动化测试。

### 15:57—18:48｜Master APK 来源隔离

- Git 提交：`c42ee2f`、`686ee5f`、`e089462`、`bd32b56`
- 更改内容：避免多个工作区或分支复用固定 `app-debug.apk`，导致安装到错误版本。
- 实现方式：新增 Master 专用构建脚本；从指定提交创建隔离源码快照；输出带分支和提交号的唯一 APK，同时生成 SHA256 校验文件；构建成功后即使临时目录清理失败也不丢失成品。

### 18:37｜AI 流式建议与动作识别时间证据

- Git 提交：`de11b55`（`feat: stream plan advice and refine training workflows`）
- 更改内容：AI 查看计划时支持流式回答；动作识别结果增加时间证据、目标人物跟踪和可选标注视频；训练相关流程进一步统一。
- 实现方式：扩展后端流式输出和动作识别接口；Worker 增加人物跟踪、动作事件和证据图生成；移动端增加识别进度、结果媒体和证据展示。

### 21:15｜CPU Worker 干净环境测试与证据 UI

- Git 提交：`73f988c`（`fix: publish CPU worker tests and refine recognition evidence UI`）
- 更改内容：修复 GitHub Actions 在干净 Runner 中因缺少 NumPy 而失败；动作识别结果改成暖橙色证据流界面。
- 实现方式：增加轻量 `requirements-test.txt`，工作流通过中科大 PyPI 镜像安装测试依赖；结果页使用“文字解释 + 对应时间证据图片”，隐藏面向开发者的技术面板。

## 2026-08-24

### 12:13｜AI 日期理解与安全中止训练

- Git 提交：`28a17d0`（`fix AI dates and safe workout abort`）
- 更改内容：修复 AI 把“昨天”解析成错误日期的问题；自由训练增加明确的放弃入口，避免只能保存才能退出。
- 实现方式：请求 AI 时传入客户端当前日期和时区；调整提示词及日期测试；训练退出使用独立操作和二次确认，避免误触直接丢失完整训练。

### 12:40｜动作遮挡恢复与详细证据解释

- Git 提交：`c65f0c0`（`fix: improve recognition evidence and occlusion handling`）
- 更改内容：提升遮挡、短暂关键点丢失和复杂动作情况下的动作轨迹恢复；增加下拉行程、肘部路径等问题的时间定位与详细解释；移动端结果页重新整理为证据报告。
- 实现方式：Worker 新增姿态恢复模块，扩展事件检测和推理逻辑；增加视频回归脚本及 Worker 单元测试；后端优化用户可读的动作评价提示；移动端按时间顺序显示问题、解释和证据图片。

### 12:44—12:45｜GitHub 与 GHCR 发布

- GitHub：`master` 推送至 `c65f0c0de64b23dfeea84d8a7ddc593360f38c61`。
- Actions：运行 `32691116170`，Worker 测试、权重校验、Docker 构建及 GHCR 推送全部成功。
- 镜像标签：`ghcr.io/mylea1/tarintool-cpu-worker:latest`、`ghcr.io/mylea1/tarintool-cpu-worker:sha-c65f0c0`。
- GHCR 摘要：`sha256:92461d6d23a0192d106bd4c5ab86a663a93975a86dd7d4b8c31388bd3dac6122`。
- 实现方式：GitHub Actions 使用中科大 PyPI 镜像安装测试依赖，测试通过后通过 Buildx 构建并推送镜像。

### 12:45｜阿里云业务 API 更新

- 部署版本：`/opt/kilo/releases/c65f0c0`。
- 服务状态：`kilo-api.service` 为 `active`，监听服务器本机 `127.0.0.1:8790`。
- 实现方式：复制上一稳定版本建立新 release，只替换本次后端文件；完成语法检查后原子切换 `/opt/kilo/current` 并重启服务，同时保留旧 release 作为回滚点。
- 验证结果：本机和 `https://api.kilostrength.cn/health` 均返回健康；DeepSeek 已配置，AI 并发上限为 10。

### 12:51｜腾讯云 CPU Worker 更新

- 运行版本：`kilo-cpu-worker:c65f0c0`。
- 服务器镜像摘要：`sha256:d6f20d34e97ed0b378902d688737f8d9ef588802de45610db2f77fb4566c4d37`。
- 服务状态：`kilo-cpu-worker.service` 为 `active`。
- 实现方式：腾讯云 Docker 镜像代理拉取 GHCR 大层时出现摘要不一致，因此保留旧在线服务，用服务器上已经验证的完整推理基础镜像叠加 `c65f0c0` 的 Worker 代码生成本地发布镜像，再原子切换 systemd；旧镜像和 unit 备份继续保留，可随时回滚。

### 12:53｜公网真实动作识别冒烟测试

- 测试任务：`job_a3bfa7ec74328db7689dfe0dbeb82ef8`。
- 验证内容：公网创建任务、视频上传、腾讯云领取任务、CPU 推理、结果回传和鉴权媒体读取。
- 验证结果：任务完成，返回 4 个动作证据事件；证据图片请求返回 HTTP 200、`image/jpeg`，Worker 日志包含 `job_claimed`、`job_progress` 和 `job_completed`。

### 约 12:58｜提交号绑定的 Android APK

- 文件：`mobile/build/app/outputs/flutter-apk/xingyu-master-c65f0c0-api-kilostrength-debug.apk`。
- API 配置：构建时写入 `KILO_API_BASE_URL=https://api.kilostrength.cn`。
- SHA256：`6d4be7199117e904506be1a51459623d10fab11b8b07bcd037fa6ca9fefc34ad`。
- 实现方式：使用 Flutter Debug 构建并将成品复制成带 Master 提交号和 API 标识的唯一文件，避免与固定 `app-debug.apk` 混淆。

### 13:43｜新增两个普通登录账号

- 新增账号：`17880169489`、`13470006920`。
- 账号类型：普通密码用户，会员状态为免费用户。
- 初始额度：AI 问答 3 次、动作识别 5 次。
- 实现方式：先备份 `/var/lib/kilo/kilo.sqlite3`，再通过后端现有 `hashPassword`、`openDatabase` 和 `ensureEntitlement` 逻辑写入用户及默认权益；没有修改接口和 App 代码。
- 验证结果：两个账号均已通过 `https://api.kilostrength.cn/v1/auth/phone/login` 公网登录验证。

## 本轮主要验收结果

- Backend：31/31 测试通过。
- CPU Worker：15/15 测试通过。
- Mobile：122/122 测试通过。
- Flutter analyze：通过。
- GitHub Actions：成功。
- 阿里云 API：健康。
- 腾讯云 Worker：在线并完成真实视频识别。
- 证据图片：可通过用户鉴权正常读取。
- Git 工作区：整理本文档前保持干净，`master` 与 `origin/master` 均指向 `c65f0c0`。

