# 01 — 模型与算法清单

## A. 当前核心候选路径

### 1. 对角高斯隐马尔可夫模型（Diagonal Gaussian HMM）

用途：

- 识别不可直接观测的市场状态；
- 为每一分钟输出过滤后的状态概率；
- 给 kernel retrieval 和 short-horizon shadow model 提供 regime posterior。

实现细节：

- emission：多维对角高斯；
- 训练前只用训练集中心与尺度做标准化；
- 状态数候选默认为 `K=2..12`，要求至少包含 `K=8`；
- 四条训练/CLI/walk-forward 路径共用一个 selector；有完整 validation 时所有
  candidate 统一比较平均 predictive log-likelihood，否则所有 candidate 统一比较 BIC，
  禁止逐 candidate fallback；
- fit 与 validation 都必须通过 causal filtered state-occupancy 下限，生产默认每状态
  至少 `1%` 且期望观测数至少 `8`；同分时选择更小的 K；
- deterministic restarts；失败 restart 整体作废，最终参数重新计算完整训练
  log-likelihood 后再参与 BIC 与 restart 排名；
- finite positive variance 才能应用 variance floor；forward/backward、gamma/xi 与
  Viterbi 均在 log space，非有限数值直接 fail closed，不再使用 probability floor
  或下溢后的 uniform reset。

当前证据：

- 9 个历史 v2 artifact 均选中 `K=8`；
- 这些历史 artifact 都带
  `BEST_VALIDATION_SCORE_IS_AT_MAXIMUM_TESTED_K; STATE_COUNT_OPTIMUM_IS_NOT_ESTABLISHED`；
- 因此“8 个状态最优”尚未成立。当前 v3 inference 会拒绝 v1/v2 artifact，必须按
  新数值与 occupancy 合同重训和独立验证，不能原地改版本号。

生产约束：

- 在线只允许使用 `p(z_t | x_1:t)` 的 causal filtered posterior；
- full-sequence smoother 和 Viterbi full path 只能离线诊断；
- 不能把未来观测参与的 smoothed state 当成历史决策时可知信息。

### 2. Baum–Welch 算法（HMM 的 soft EM）


E-step：

- log-space forward recursion 得到 `log_alpha`；
- log-space backward recursion 得到 `log_beta`；
- `gamma_t(i)` 表示时刻 `t` 属于状态 `i` 的后验权重；
- `xi_t(i,j)` 表示从状态 `i` 到 `j` 的软转移计数。

M-step：

- 用 `gamma` 更新 initial probability、state means 和 diagonal variances；
- 用 `xi` 更新 transition matrix；
- 通过 log-sum-exp 归一化 posterior 和转移软计数；
- 每个 M-step 后都用更新后的参数重算完整训练 likelihood，直到增量达到容差或
  最大迭代数。

当前风险：

- EM 只能保证局部最优；
- 初始化主要按第一维特征排序分位点加微扰，覆盖面有限；
- 当前 restarts 是否足够需要 benchmark；
- 9 个旧 artifact 全部顶到旧候选边界，新的 K 网格与 occupancy gate 仍需通过
  重新训练证明存在内部最优；若新选择仍在 K=12 边界，promotion 继续阻断；
- 极端 log density、前向实现一致性、退化 variance、失败 restart、gamma/xi
  归一化和 state occupancy 已有回归测试；不同初始化的更大规模稳定性仍需 benchmark。

### 3. Forward–Backward 与 Viterbi

- Forward–backward：用于 Baum–Welch 的 `gamma/xi` 和训练诊断。
- Causal forward filter：唯一允许进入在线推理的状态概率。
- Viterbi：log-space 最可能完整状态路径，只允许离线诊断。
- 下一状态概率：过滤 posterior 乘 transition matrix。
- 多步状态概率：重复应用 transition matrix。

Viterbi 不是训练算法，也不能替代 online posterior。

### 4. Same-regime 高维 Kernel Regression / Analog Retrieval（Rust canonical）

本节只描述 `quant_engine_rs/src/analog_engine/mod.rs` 中由冻结 artifact 使用的
Rust canonical estimator，不描述 Python 旧实现。

模型类型：

- regime-gated nonparametric regression；
- adaptive Gaussian-RBF kernel；
- Nadaraya–Watson kernel-weighted conditional estimate；
- 另报告 locally weighted linear intercept。

当前 12 个核心维度：

1. `ret_1m`
2. `ret_5m`
3. `ret_15m`
4. `vwap_distance`
5. `realized_volatility`
6. `normalized_range`
7. `volume_zscore`
8. `rvol`
9. `session_range_position`
10. `cross_asset_breadth`
11. `slope_15m`
12. `minute_of_session`

训练阶段：

- center 用训练集 median；
- scale 用训练集 MAD；
- covariance 只在训练区间拟合；
- covariance 向球形 target shrink 后求逆；
- 逆矩阵失败时退化为 standardized Euclidean，并显式报告 fallback；
- OOD threshold 用训练样本最近邻距离分位数校准。

检索约束：

- candidate 必须严格早于 query；
- candidate session 必须早于 query session；
- outcome 的整个 horizon 必须在 query 时刻前已经 available；
- 默认相同 5 分钟 clock bucket；
- dominant HMM state 相同；
- query/candidate dominant posterior 都要超过阈值；
- full posterior cosine similarity 要超过阈值；
- 每个历史交易日最多保留一个邻居；
- 没有 cross-regime fallback。

权重：

`w_i ∝ posterior_overlap_i × exp(-0.5 × (distance_i / bandwidth)^2)`

输出：

- kernel-weighted return mean；
- local-linear intercept；
- raw weighted frequency of positive return；
- weighted quantiles；
- MFE/MAE、dispersion、tail frequency；
- effective sample size、OOD score、year concentration 和 sensitivity grid。

重要边界：

- 没有 promotion calibration 时，`probability_up` 只是 raw analog frequency；
- OOD、ESS 不足、单一年份权重过高或相似样本重叠时必须 `NO_TRADE`；
- 当前是 exact search，数据继续扩大后需要 benchmark 决定是否构建 ANN，
  但 ANN 不能改变因果过滤和独立交易日约束。

#### Python legacy estimator 边界

`intraday_quant/src/intraday_quant/models/analog_kernel.py` 保留的是另一个估计量：
mean/std `StandardScaler`、Euclidean `/ sqrt(d)`、最多 51 个特征、固定绝对带宽、
仅按 timestamp 过滤、无 HMM posterior 权重、默认 `k=25`，且 median return 未加权。
它不能被称为 Rust analog 的训练侧实现或 parity backtest。

该模型已改名为 `legacy_exploratory_euclidean_analog`，从 `default.yaml` 和
`yahoo_recent.yaml` 的默认模型列表移除。只有显式 opt-in 才会生成探索性
prediction rows；这些 rows 带 `promotion_eligible=false`、
`production_parity=false` 和 `NOT_RUST_ANALOG_PARITY` blocker，并在 portfolio
selector 进入 ensemble/trade blotter 前被剔除。旧的 `analog_kernel` 配置名会被拒绝。

### 5. Regime-conditioned Markov-switching SDE

用途：5/15/30/60 分钟 short-horizon shadow distribution。

当前实现：

- 根据 causal HMM posterior 对每个 regime 的 log-return 做加权矩估计；
- 每个 regime 估计 drift per minute、variance rate per minute 和 volatility；
- 用 posterior transition counts 加 Dirichlet prior 估计 transition matrix；
- 用 Markov transition 传播不同 horizon 的一阶与二阶矩；
- 当前不是 Monte Carlo path simulator，而是矩传播的参数化 diffusion baseline。

状态：

- 已写入 v2 frozen artifact；
- `decision-neutral` / shadow-only；
- 不能在完成 forward OOS、成本和 calibration 之前参与生产结论。

### 6. VWAP residual Ornstein–Uhlenbeck（OU）过程

用途：建模价格相对 VWAP residual 的均值回复。

当前实现：

- 对相邻、同 session、连续时间区间的 residual 做 regime-weighted AR(1)；
- 从 `phi` 转换得到 long-run mean `theta` 和 mean-reversion speed `kappa`；
- 推导 diffusion variance rate；
- 当 `phi` 不在均值回复区间、样本不足或设计退化时关闭该 head。

状态：v2 artifact 中存在，shadow-only。

### 7. Regime-conditioned momentum shadow head

用途：为 short-horizon distribution 提供简单的状态条件动量对照。

状态：决策中立；用于判断 SDE/OU 是否真正提供超越简单动量的增量。

## B. 传统监督模型

### 8. Regularized Logistic Regression

- 任务：方向分类；
- Python/scikit-learn：median imputation、StandardScaler、balanced Logistic；
- Rust：原生 logistic head + validation-only Platt；
- C++：存在重复实现；
- 输出在没有独立校准与 promotion artifact 时不得称为生产概率。

### 9. Ridge Regression

- 任务：return、MFE、MAE 等连续目标；
- Python/scikit-learn，训练区间 scaler；
- 当前是离线 challenger，不是 Rust frozen runtime 核心。

### 10. Histogram Gradient Boosting

- 分类和回归各一套；
- Python 使用 scikit-learn `HistGradientBoostingClassifier/Regressor`；
- 当前不是 LightGBM，也不是 XGBoost；
- 没有形成 Rust 可验证加载的不可变 production artifact。

## C. 深度学习候选

### 11. Causal Temporal Convolutional Network（TCN）

- dilated causal 1D convolution；
- residual blocks；
- symbol embedding；
- 多 horizon heads；
- Python/PyTorch/CUDA 离线训练；
- 当前 artifact 约 54,896 参数；
- 没有 Rust production inference runtime。

### 12. Regime-gated Distributional TCN / Mixture-of-Experts

- 4 个 experts；
- causal attention pooling；
- HMM regime posterior 参与 gating；
- 可接收 SDE prior returns；
- Student-t return location/scale；
- direction、VWAP-cross、MFE、MAE 和 regime auxiliary heads；
- 当前 artifact 约 160,224 参数。

当前证据：

- 方向表现不稳；
- 30m/60m AUC 接近或低于 0.5；
- 多个 horizon 的 Brier gain 为负；
- VWAP-cross AUC 相对更有研究价值；
- 因此只能作为 VWAP-event challenger 继续多折验证。

## D. 校准与模型选择

### 13. Platt Scaling

- validation-only logistic calibration；
- Rust/Python/C++ 均有相关实现；
- production serving 不允许临时拟合 calibrator；
- 必须加载单独验证、不可变并晋升的 calibration artifact。

### 14. Isotonic Regression

- Python validation-only；
- 样本不足时不可随意宣称校准；
- 当前生产没有匹配的 promoted artifact。

### 15. Purged Walk-forward / Embargo

- chronological train/validation/calibration/test；
- 不 shuffle；
- preprocessing 每折重拟合；
- overlapping label windows 做 purge；
- validation/test 之间做 embargo；
- 当前仍需要 repeated folds、per-symbol/per-regime 报告和 untouched final OOS。

## E. 研究性或专用模型

- TVTP-HMM；
- Gaussian HMM / Student-t HMM / minimum-duration HSMM / no-regime competition；
- closing short-cover hazard model；
- gamma convexity aggregation（unsigned exposure + 显式 sign scenario）；
- motif / matrix profile / FDR / pattern factory；
- baseline：clock-time、unconditional direction、momentum、reversal、VWAP mean reversion；
- C++ research HMM、Logistic 和 paper OMS。

这些不能自动算作当前线上 committee。

## F. 当前没有实现的模型

- Bayesian state-space model；
- Bayesian online change-point；
- Naive Bayes；
- PyMC / Stan；
- particle filter；
- Kalman filter；
- LSTM / GRU；
- Transformer price forecaster；
- LightGBM / XGBoost / CatBoost；
- reinforcement-learning execution。

如果未来加入，必须先说明它解决哪个已测量缺陷，而不是因为名字更复杂。
