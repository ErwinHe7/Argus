# 自主规律挖掘与历史相似策略

AXIO7 现在把两类问题分开处理：

1. `AnalogEngine` 回答“当前状态最像历史中的哪些时刻，随后发生了什么”；
2. `PatternFactory` 回答“历史中有哪些重复出现的路径形态，它们是否在独立时期仍有成本后效应”。

两者都只能生成研究或 forward-shadow 候选。回放历史不能直接授予实盘下单权限。

## 当前状态如何匹配历史

实际 forecast 已使用 `analog_engine`，不再使用旧版轻量 analog。查询向量包含：

- 1/5/15 分钟收益；
- VWAP 距离、实现波动率、标准化区间；
- 成交量 z-score、同分钟相对成交量；
- 日内区间位置、跨资产宽度、15 分钟斜率和日内时间。

缩放中位数、MAD、收缩协方差逆矩阵和 OOD 阈值只在当前交易日之前的样本上拟合。检索使用收缩 Mahalanobis 距离、同一 5 分钟时段、每个历史日最多一个邻居和自适应高斯核：

```text
d_i = sqrt((x_t - x_i)' Sigma_shrink^-1 (x_t - x_i))
w_i = exp[-0.5 * (d_i / bandwidth)^2]
E[r | x_t] = sum(w_i r_i) / sum(w_i)
ESS = (sum w_i)^2 / sum(w_i^2)
```

每个预测合同会保留：历史时间、距离、权重、12 个逐特征相似度、完整的后续 1 分钟路径、终点收益、MFE/MAE、标签成熟时间、ESS、OOD、年份集中度和 K/带宽敏感性。

策略方向来自历史条件分布，而不是故事标签：条件均值为正时研究 `LONG`，为负时研究 `SHORT`；信号只在当前分钟完成后生成，最早下一分钟开盘进入，持有期与预测 horizon 相同。若成本后期望、胜率、ESS、OOD、时期集中度或状态不确定性未过门槛，动作必须是 `NO_TRADE`。

## 模型如何自己挖掘规律

`PatternFactory` 的自动流程是：

```text
1 分钟简单收益 -> ln(1+r)
-> 3/5/10/15/30/60 分钟归一化路径
-> 多个确定性投影快速提出近邻种子
-> 用精确归一化欧氏距离复核
-> discovery 冻结 prototype 和出现位置
-> purged validation 只选择 LONG/SHORT 方向
-> test 计算交易成本后效应
-> 按交易日 block bootstrap
-> timestamp/sign/random-motif/random-neighbor 负控
-> 全候选 Benjamini-Hochberg FDR
-> 生成条件策略或 ABSTAIN
```

自动分割为按时间顺序的 discovery、purged validation、test 和 forward-shadow。候选不能重叠计数，必须跨多个独立交易日，不能依赖单日或单月，也不能在近期消失。一个随机或置换对照能复现其效果时，该规律直接被拒绝。

运行：

```powershell
cd quant_engine_rs
target/release/quantctl.exe research pattern-discover `
  --bars data/normalized/market_bars.csv `
  --horizon 15 `
  --windows 3,5,10,15,30,60 `
  --output data/reports/pattern_factory_latest.json
```

输出候选包含 motif ID、原型、完整样本统计、验证期选定方向、test 成本后收益、日块置信区间、原始 p 值、FDR q 值、当前距离/相似度，以及明确的条件策略。常见短 motif 可能有上万次出现，JSON 只保存最多 300 条确定性 lineage 样本；所有聚合统计仍基于完整运行。

## 2026-07-22 实测结论

在仓库现有的 2024-07-18 至 2026-07-17 SPY 分钟数据上，15 分钟目标、六组窗口共发现 9 个候选，但 FDR 后存活数为 0，当前匹配数为 0，因此当前动作是 `ABSTAIN`。这说明系统已经能够自己寻找并证伪规律，但现有数据没有证明可复现的成本后优势。

该历史此前已被检查过，所以自动切出的 test 只能视为研究 test，不是新的 untouched holdout。任何未来存活候选仍必须积累真正向前的 Moomoo shadow 样本；期权策略还必须有历史可执行 OPRA/NBBO，不能用标的收益冒充期权收益。
