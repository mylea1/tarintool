# 形域 PRO：饮食拍照识别与进阶数据统计

## 产品判断

这次不把会员理解为“多看几张图”，而是两类有明确持续成本和决策价值的能力：

1. 多图饮食识别需要调用视觉模型，有持续的推理成本，适合作为 PRO 权益。
2. 进阶统计应回答“这段时间发生了什么，下一步做什么”，而不是只重复原始记录。

最小可用路径是：手动饮食记录和基础训练统计继续免费；PRO 提供拍照自动填写、同期对比、营养达标率、训练与饮食联动趋势和确定性的下一步建议。这个边界最可能提升会员转化和第 8 周留存。

## 竞品怎么做

| 产品 | 已有数据能力 | 对形域的启发 |
| --- | --- | --- |
| Hevy | 训练频率、连续性、肌群组数、肌群分布、训练容量、月报、PR 和身体数据；PRO 主要解锁更长历史区间 | 基础统计不应全锁；长期对比、细分趋势和报告适合会员 |
| MyFitnessPal | Premium 提供自定义营养仪表盘、每餐宏量、食物分析、时间戳、无限周报和数据导出 | 会员价值来自“解释历史”和“可导出”，不只是当天数字 |
| MacroFactor | 把体重趋势与记录热量联系，估计消耗并用周检查调整目标；训练产品强调进度与计划决策 | 形域长期应增加体重历史，再做摄入、体重和训练表现的关联；当前不应伪造精确消耗 |

参考：

- Hevy 训练进度功能：https://www.hevyapp.com/features/gym-progress/
- MyFitnessPal Premium 功能：https://support.myfitnesspal.com/hc/en-us/articles/360032625951-MyFitnessPal-Premium-features
- MyFitnessPal 周报：https://support.myfitnesspal.com/hc/en-us/articles/360032622591-Weekly-Digest
- MacroFactor 营养记录与消耗算法：https://help.macrofactorapp.com/en/articles/110-how-frequently-do-i-need-to-log-my-nutrition-for-the-expenditure-algorithm-and-weekly-coaching-updates

## Reddit 用户实际想要什么

1. **数据要能指向行动。** MacroFactor 用户对“给了 App 很多数据，统计和洞察却没用”的抱怨获得了高赞，关键问题是无法看清过去和下一步。
2. **希望把训练和营养放在一起。** 用户希望看到热量、体重趋势与训练的关系，并抱怨各 App 之间数据碎片化。
3. **周均和趋势比单日更重要。** MyFitnessPal 用户长期要求周均热量、蛋白质和更长历史，避免手工用表格计算。
4. **训练数据不能只有“重量 × 次数”。** Hevy 和 MacroFactor Workouts 社区希望看每周肌群组数、RPE/RIR、接近力竭程度和历史表现，而不是粗糙总容量。
5. **要有激励感，但不能增加记录摩擦。** 2026 年 8 月的 Hevy 热门讨论明确赞扬日历标记和 PR 徽章，同时认为营养 App 繁琐、无聊。这支持用一个联合时间轴展示训练点和营养柱，而不是再造一套复杂报表导航。

社区例证：

- https://www.reddit.com/r/MacroFactor/comments/1srs36i/i_love_this_app_but_will_this_ever_be_fixed/
- https://www.reddit.com/r/Hevy/comments/1vmje7o/hevy_is_so_motivating_wish_there_was_a_version/
- https://www.reddit.com/r/MacroFactor/comments/1oo87xi/mf_workouts_leek/
- https://www.reddit.com/r/developersIndia/comments/1uf39pu/building_a_health_connect_dashboard_for_gym/
- https://www.reddit.com/r/Hevy/comments/10wqfqe/what_statistics_would_you_like_to_see/
- https://www.reddit.com/r/Myfitnesspal/comments/1ipwby9/weekly_averages/

## 形域改造前后的差异

| 维度 | 改造前 | 本次 PRO 第一版 | 后续值得做 |
| --- | --- | --- | --- |
| 饮食识别 | 已有多图识别，但免费用户也能调用 | 客户端显示 PRO 锁，服务端强制校验有效会员；手动记录保持免费 | 给会员提供每月识别次数和准确率反馈 |
| 训练统计 | 训练天数、有效组、容量、肌群分布、训练时间、最大重量和 1RM | 保留基础统计免费；PRO 增加与上一等长周期的频率和容量对比 | 加入动作级 e1RM 趋势、RPE/RIR 和计划完成率 |
| 营养统计 | 主要看当天与日历记录 | PRO 增加日均热量、日均蛋白质、记录覆盖率、热量达标率和蛋白达标率 | 增加纤维、钠、糖和食物类别趋势 |
| 联合分析 | 训练与饮食共用日历，但统计仍分散 | PRO 增加最近 14 天训练点与热量柱的联合时间轴 | 建立体重历史后，做热量、体重趋势和训练表现的相关分析 |
| 决策支持 | 用户自己解释图表 | PRO 用可解释的确定性规则给出一条“下一步”，不额外消耗 AI 额度 | 待有更多数据后再评估个性化算法，避免过早给出伪精确建议 |

## 免费与 PRO 边界

### 免费保留

- 手动记录食物、热量和三大营养素
- 饮食时间轴和训练饮食共享日历
- 训练天数、有效组、总容量、肌群分布、时长和 PR

### PRO 解锁

- 一次最多 8 张饮食照片识别和营养自动填入
- 与上一等长周期的训练频率、容量对比
- 热量与蛋白质日均、记录覆盖率、达标率
- 训练与饮食联动时间轴
- 基于真实记录的下一步建议

## 指标与验证

- 会员页到支付页的转化率
- 点击“PRO 拍照识别”后的会员页到达率
- 进阶统计的周活跃使用率
- 记录覆盖率从第 1 周到第 4 周的变化
- 会员第 4 周和第 8 周留存
- 拍照识别后用户修改热量和营养素的平均幅度，用于监控模型质量

## 证据限制

2026-09-01 的 last30days 本地公开 Reddit JSON 检索受到 403 限制，因此近 30 天引用由搜索引擎索引的 Reddit 讨论补足。社区意见用于发现问题，不代表整体用户的统计抽样。
