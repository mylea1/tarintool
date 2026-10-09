# TrainTool / 形域智能训练

Flutter iOS/Android App、会员后端及外部 AI 可访问的 Web/MCP。新版网页已替换旧 wger UI 和 Web 原型，围绕真实训练、饮食和身体记录运行；聊天、照片分析与建议由外部 AI 完成。

## 一键启动

需要 Node.js 22.13+。macOS 双击 `start-web.command`；Linux 执行 `./start-web.sh`；Windows 双击 `start-web.bat`。首次按锁文件安装依赖，打开 http://127.0.0.1:8792/agent/ 。本地体验账号/密码为 `123/123`。

```sh
node scripts/agent-launcher.mjs --no-browser
node scripts/agent-launcher.mjs --stop
```

配置参考 `.agent.env.example`，实际 `.agent.env` 不提交。默认数据在 `.agent-local/`，旧运行数据库与 Flutter 数据保留。

## 新版能力

- 人体肌肉图、App 一致的恢复估算与训练次数、抖音教学入口。
- 1324 个真实 App 动作、原教学素材、训练计划及逐组重量/次数/休息/RPE/感受与备注。
- 同动作按日期的重量、次数趋势及每组详情。
- 饮食/饮水/体重/资料、可编辑估算与有依据的每日目标/剩余热量。
- 服务器或真正的浏览器 IndexedDB 两种存储，同一 `/mcp` 地址；外部 AI 可按授权读写记录、追加计划/当前动作和调用 Markdown Skill。
- 服务器模式连接同一 App 会员同步 API；本地模式通过兼容备份导入 App。
- 浅/深主题、移动布局、状态过渡与系统减少动态支持。

详细连接、存储语义、App 同步、工具参数、许可和功能边界见 [Web/MCP 使用说明](docs/web-mcp.md)。后端认证/支付/识别服务见 [backend README](backend/README.md)。

## Flutter App

`mobile/` 为现有正式 Flutter 客户端，新添账号设置中的云端 MCP 同步与 Web 备份导入入口。

```sh
cd mobile
flutter pub get
flutter test
```

Android 隔离构建方法见 [构建说明](docs/android-isolated-build-runbook.md)。iOS 的 Live Activity/Apple Watch 功能保持现有实现，真机签名及发布需在 Xcode 中进行；本次没有发布 App。

## 代码与素材

新版前端在 `backend/agent-web/`；MCP/业务路由在 `backend/src/agent.mjs`，写入在 `web-records.mjs`，浏览器中转在 `browser-bridge.mjs`。动作目录从 App 源文件生成：`node scripts/generate_agent_exercises.mjs`。
第三方知识声明见 `backend/knowledge/THIRD_PARTY_NOTICES.md`；肌肉素材说明见 `backend/agent-web/muscles/THIRD_PARTY_NOTICES.md`。公开再分发前须核实 Gym Visual 动作素材及原肌群 SVG 授权。
