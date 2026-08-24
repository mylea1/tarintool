# 动作识别产品返回内容与形域动作规则

核对日期：2026-08-24。这里只记录各产品官方页面或官方帮助中心公开说明；“形域采用方式”是产品设计推论，不代表对方产品的完整能力。

## 11 款同类产品实际返回什么

| 产品 | 用户会收到的内容 | 对形域的启发 | 官方资料 |
|---|---|---|---|
| Tempo | 训练中间歇出现的动作纠正、纠正成功提示、实时动作幅度区间；不会每次错误都打断用户 | 少而准，避免把每帧异常都变成批评 | [Tempo Form Feedback](https://support.tempo.fit/support/solutions/articles/151000154714-3d-tempo-vision-form-feedback) |
| Tonal Smart View | 实时教练提示；训练后回看片段、可视化纠正、个性化建议和教练示范视频 | 结论和视频证据放在同一个复盘闭环 | [Tonal Smart View](https://knowledge.tonal.com/kb/guide/en/tonal-smart-view-vhQ3eTzB5A/Steps/3958423) |
| Peloton Guide | Movement Tracker 完成度、Self Mode 与教练同屏、动作详情和训练后完成情况 | 首屏服务“是否跟上、是否完成”，复杂解释后置 | [Peloton Guide](https://www.onepeloton.com/press/articles/peloton-guide-available) |
| Kaia Motion Coach | 实时音视频纠正、自动次数、动作幅度与稳定性评估、长期数字指标 | 反馈必须能直接驱动当下动作调整 | [Kaia Motion Coach](https://kaiahealth.com/motion-coach/) |
| Hinge Health Motion Insights | 实时语音纠正、骨骼点、次数/目标次数、动作幅度进度环；结果可用于后续计划调整 | 先显示用户能理解的进度，不暴露内部阈值 | [Hinge Health 用户手册](https://www.hingehealth.com/user-manual/) |
| Sword Health | 个性化实时反馈、动作完成质量、疼痛/主观反馈与专业人员共同调整计划 | 自动分析应该连接下一次训练，而不是停在报告 | [Sword Health](https://swordhealth.com/en-ca/articles/virtual-physiotherapy-what-works) |
| MAGIC AI Mirror | 实时动作纠正、次数和组数、节奏与幅度提示、加减重量建议、长期进度 | 下一组建议可以包含负重和节奏，但必须有证据 | [MAGIC AI](https://us.magic.fit/) |
| EGYM Fitness Hub | 错误关节标红、屏幕纠正方法、活动度/深蹲测试、个性化建议和历史进度 | 图像标记必须与一句明确纠正绑定，不能只给红点 | [EGYM Fitness Hub Guide](https://us.egym.com/en-us/fitness-hub-manual) |
| Ochy | 总分和身体部位分数、图示解释、纠正练习、跑姿分类、步频/触地时间等指标和长期对比 | 一次综合评价，下钻时再看各部位数据 | [Ochy 分析说明](https://help.ochy.io/en/articles/7002313-running-analysis-details) |
| Kinotek | 3D 动作模型、活动度、左右差、代偿、总分、健康范围和前后进步对比，可导出报告 | 对称性要放在同一时刻和同一尺度比较 | [Kinotek](https://kinotek.com/medical-professionals) |
| HomeCourt | 实时命中/动作反馈、投篮片段回放、慢动作、出手角度/时间/速度/腿角和训练统计 | 指标要与对应视频片段绑定，证据比孤立数字更可信 | [HomeCourt Shot Analysis](https://www.homecourt.ai/faq/shotanalysis) |

共同规律不是“返回越多越好”，而是实时只给少量可执行提示，训练后把结论、证据片段和下一步放在一起；详细数字默认下钻。

## 当前 17 个可选动作的错误与实现方案

规则分三层：主动作是否完成、支撑姿态是否稳定、证据是否足够。所有事件必须持续至少 300 ms 或出现在一个完整动作阶段，避免单帧抖动。

| 动作 | 常见可见问题 | 已配置的判断信号 | 拍摄/降级边界 | 给用户的调整方向 |
|---|---|---|---|---|
| 杠铃深蹲 | 深度不足、膝向内、躯干突然改变 | 侧面膝角行程；正面/后面膝相对髋踝线；肩髋线变化 | RGB 不能判断脚底压力和腰椎细节 | 降重，脚掌稳定，膝沿脚尖方向，逐步增加深度 |
| 高脚杯深蹲 | 深度不足、膝向内、躯干前倾 | 与深蹲同族；阈值允许更直立躯干 | 哑铃位置不做器械接触判断 | 把负重贴近胸口，先稳住躯干再下蹲 |
| 臀推 | 顶部伸髋不足、左右髋高度差、过度抬胸代偿 | 肩—髋—膝角的顶部范围；正面髋高差；肩髋线同步变化 | 长凳遮挡髋时降级 | 收紧腹部和臀部，顶部停在躯干与大腿接近一线的位置 |
| 罗马尼亚硬拉 | 髋折叠不足、屈膝过多、躯干策略突变 | 肩—髋—膝角、髋—膝—踝角和肩髋线 | 不能由 COCO17 诊断腰椎弯曲 | 轻屈膝，把髋向后送，负重贴近腿 |
| 传统硬拉 | 下蹲主导、髋肩不同步、躯干策略突变 | 髋角、膝角与肩髋线的阶段关系 | 需要侧面拍全杠铃和脚 | 推地并让髋肩一起起，不要先抬髋或先抬胸 |
| 高位下拉 | 顶部/底部行程不足、肘部下降少、左右节奏不一致、明显后仰 | 肘角周期、肘部标准化下降、双侧肘角差、肩髋线 | 腕点可推算；把手落点需器械检测器 | 降重，先下沉肩胛，让肘向下并略向髋移动 |
| 杠铃卧推 | 底部小臂不接近竖直、左右肘角不同步、行程不足 | 侧面小臂方向；正前/斜前双侧肘角差 | 杠路径需器械检测器；推算腕仅用于小臂方向 | 调握距和落点，让手腕尽量在肘上方 |
| 哑铃卧推 | 双侧路径不一致、底部小臂偏斜、行程不足 | 双侧肘角与腕肘方向；侧面小臂竖直度 | 哑铃旋转和腕姿不判断 | 两侧同时下降和推起，先用能控制的重量 |
| 肩推 | 左右伸展不同步、躯干后仰、顶部行程不足 | 双侧肘角差、腕/肘相对肩的高度、肩髋线 | 单目不判断杠铃是否在三维中偏前 | 收紧腹臀，双肘同时向上，不用后仰换行程 |
| 俯卧撑 | 髋下沉/抬高、深度不足、左右肘角不一致 | 肩—髋—踝身体线、肘角最低值和双侧差 | 脚出画时只评价上肢行程 | 从头到脚保持一条线，先缩小难度再增加深度 |
| 双杠臂屈伸 | 下降不足、肩左右不齐、身体摆动 | 肘角周期、肩高差、肩髋线位移 | 器械遮挡腕时允许肘角方向恢复 | 肩保持稳定，身体少摆动，在能控制的范围下降 |
| 坐姿划船 | 肘部回拉不足、躯干借力、左右不同步 | 肘角/肘后移、肩髋线变化、双侧肘角差 | 把手接触与肩胛内收不能直接测 | 稳住胸廓，用肘带动回拉，不用后仰甩动 |
| 引体向上 | 左右肩高度不同、双侧肘角不同步、行程不足、侧摆 | 同时刻肩高差、左右肩—肘—腕角差、肘角完整周期、肩髋横向位移 | 对称性仅正前/正后；腕推算降低置信度 | 降低负重或用辅助，先让双肩和双肘同步发力 |
| 绳索面拉 | 肘部高度不一致、回拉不足、躯干后仰 | 双肘高度差、肘角/肘后移、肩髋线 | 绳索末端不可见时不判断手柄位置 | 轻一点，让肘和手同时向脸两侧展开 |
| 哑铃侧平举 | 两侧抬起高度不同、耸肩代偿、肘角变化过大 | 腕/肘相对肩高度、双侧高度差、肘角稳定性 | COCO17 无法直接测肩胛上提，只描述肩线变化 | 降重，保持轻微屈肘，两侧平稳抬到可控高度 |
| 二头弯举 | 上臂前摆、躯干摆动、两侧不同步、行程不足 | 肘相对肩髋线位移、肩髋线变化、双侧肘角差 | 腕缺失时用小臂方向恢复肘角 | 固定上臂，放慢离心，不用摆身体完成末端 |
| 三头伸展 | 上臂漂移、肘角行程不足、躯干代偿 | 肘相对肩的位置、肘角范围、肩髋线变化 | 器械/手柄不判断 | 固定上臂，减轻重量，让肘部完成伸屈 |

动作基础姿势参考 ACE 的[动作库](https://www.acefitness.org/resources/everyone/exercise-library/)、[高位下拉](https://www.acefitness.org/resources/everyone/exercise-library/158/seated-lat-pulldown/)、[硬拉](https://www.acefitness.org/resources/everyone/exercise-library/6/deadlift/)和[罗马尼亚硬拉](https://www.acefitness.org/resources/everyone/exercise-library/317/romanian-deadlift/)。引体向上的双侧对称、肩角和髋部位移依据来自一项[引体向上运动学研究](https://link.springer.com/article/10.1007/s11332-023-01097-1)。

## 遮挡恢复的技术依据

姿态研究普遍把遮挡关节视为有不确定性的推断，而不是等同于可见关节。POCO 使用置信度识别不确定帧并从可信帧补全；ProbPose 特别处理出画关键点；遮挡研究也强调利用可信可见点、人体结构和时间关系恢复不可见点。因此形域采用置信度门控、时间邻域、相对肢段角和长度约束四层方法，并把推算结果限制在肘角/小臂方向等任务中。

- [POCO: 3D Pose and Shape Estimation with Confidence](https://arxiv.org/abs/2308.12965)
- [ProbPose, CVPR 2025](https://openaccess.thecvf.com/content/CVPR2025/html/Purkrabek_ProbPose_A_Probabilistic_Approach_to_2D_Human_Pose_Estimation_CVPR_2025_paper.html)
- [Temporal Keypoint Matching and Refinement, ECCV 2020](https://www.ecva.net/papers/eccv_2020/papers_ECCV/papers/123670681.pdf)
