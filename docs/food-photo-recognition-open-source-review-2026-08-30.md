# 食物拍照热量识别：开源调研与接入边界

## 结论

当前版本已在饮食记录中接入“选择食物照片（实验）”入口，但不会伪造一个看似精确的热量数字。拍照结果必须经用户确认食物、份量和热量后才能保存。稳定的服务输出契约在 `contracts/mobile-food-photo-recognition.json`。

这个决定来自数据本身：Nutrition5k 为了获得餐盘质量与热量标签，使用了 4 路侧视视频、俯视 RGB-D 以及逐份称重的扫描流程。这说明仅靠一张普通 RGB 照片无法稳定推断份量：https://github.com/google-research-datasets/Nutrition5k

## 开源项目对比

| 项目 | 适合用途 | 不直接采用的原因 |
|---|---|---|
| OpenNutriTracker | 饮食日记交互、私有化食品后端、Open Food Facts/USDA/BLS 数据管线 | GPLv3，不适合直接复制进当前商业客户端；可参考产品流程或独立部署后端。https://github.com/simonoppowa/OpenNutriTracker/ |
| Nutrition5k | 餐盘营养回归数据与评测基准 | 181.4 GB，采集条件是多视角 + RGB-D + 称重，且仓库已归档。https://github.com/google-research-datasets/Nutrition5k |
| FoodSAM | 食物语义/全景分割 | 它解决“图中哪些像素是什么食物”，不解决克重和热量；依赖 Python 3.7、PyTorch 1.8、MMCV 和 3 套 checkpoint，不适合打进手机。https://github.com/jamesjg/FoodSAM |
| Open Food Facts API | 条码/包装食品的营养值补全 | 适合包装食品，不是餐盘份量估计；社区数据不保证完整和准确。新接入应用 v3。https://openfoodfacts.github.io/openfoodfacts-server/api/ |

## 建议的可部署架构

1. Flutter 上传前压缩图片，去除 EXIF 位置信息，并显式告知用途。
2. 后端创建异步任务，GPU worker 使用 FoodSAM 或更新的可商用分割/分类模型产生候选食物。模型与客户端解耦。
3. 包装食品优先走条码 + Open Food Facts v3；散装餐盘返回份量区间，不返回伪精确单值。
4. 客户端展示候选项、置信度、热量范围和警告；用户修正后才写入 `NutritionEntry`。
5. 上线门槛：食物 top-3 命中率、份量 MAE、热量 MAPE、用户修正率都必须在中国常见菜品的独立测试集上达标。

## 本次已接入与未接入

- 已接入：饮食独立页、顺序餐次、照片选择入口、人工复核提示、稳定 JSON 契约。
- 未接入：实际模型 checkpoint、GPU worker 推理、Open Food Facts 条码查询。在未完成中国菜品评测和部署资源选型前，不把这些标记为“已部署识别”。
