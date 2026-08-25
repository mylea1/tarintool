# 互动肌群 SVG 资源说明

本目录中的男女正面/背面人体 SVG 及肌群叠加图来自项目文档指定的
`E:\\gymsys\\miniprogram\\assets\\muscle-selector` 资源，配套交互说明见
`docs/ai-training-muscle-selector-files.md`。文件保持原始 viewBox 和路径数据，
Flutter 端仅通过 `flutter_svg` 进行本地渲染和颜色叠加。

资源的原始授权信息由源项目维护者提供；发布前请随源项目的授权文件一并核对。
`manifest.js` 和 `masks.js` 与 SVG 一起保留，用于追溯源资源；Flutter 端在
`muscle_selector.dart` 中使用同一套 48×88 alpha-mask 坐标规则进行命中判断。
