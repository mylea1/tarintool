# KILO 完整动作数据集导入

日期：2026-08-09

## 范围

- 将 `exercise-dataset-reference` 的 1,324 个动作全部加入 Flutter 动作库。
- 打包 1,324 张 JPG 封面和 1,324 个 GIF 演示。
- 保留原有 32 个动作 ID，确保既有计划、训练和历史记录继续关联原动作。
- 原有 32 个动作对应的数据集条目不重复展示，剩余 1,292 个动作使用 `dataset_<id>` 作为稳定 ID。

## 性能策略

动作库搜索、肌群和器械筛选覆盖全部 1,324 个动作。页面每批构建 60 个图片卡，用户可继续加载更多，避免首屏同时构建和解码上千张图片。

## 生成方式

运行：

```powershell
node scripts\generate_exercise_dataset.mjs
```

脚本读取源 JSON、复制全部 JPG/GIF，并生成 `mobile/lib/exercise_dataset.generated.dart`。App 启动时使用编译期 Dart 数据，不解析 17 MB JSON。

## 验收

- 动作目录总数为 1,324，动作 ID 不重复。
- 媒体映射总数为 1,324，2,648 个资源均可由 `rootBundle` 加载。
- 搜索可直接找到未包含在原 32 个动作中的数据集动作并打开 GIF 详情。
