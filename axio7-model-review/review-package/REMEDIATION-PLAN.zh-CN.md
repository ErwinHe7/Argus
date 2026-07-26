# AXIO7 交接包修复方案

> 路径前缀约定（仓库根：`C:/Users/84119/Documents/GitHub/Argus`）：
> `RS/` = `axio7-model-review/source/quant_engine_rs/`
> `PY/` = `axio7-model-review/source/intraday_quant/`
> `CPP/` = `axio7-model-review/source/quant_core_cpp/`
> 交付分支 = `agent/axio7-model-review`（tip `8d18b73`）；构建修复分支 = `fix/handoff-buildable`（tip `3df6111`，含 7 个尚未合回交付分支的提交）。

---

## 1. 执行摘要

交付分支 `agent/axio7-model-review` 目前**不是一个可被外部审查的快照**：`.gitignore` 的 `data/`、`reports/` 目录名规则吞掉了三个源码包，Rust crate 缺少整个数据接入层因而无法编译，286 个 Rust 测试从未运行，Python 有 collection error，C++ 从未被构建过——所谓"本地全绿"是脏工作树上的结论，仓库本身从来没有被验证过。`fix/handoff-buildable` 分支已经修掉了 `.gitignore`、CMake target 名、Dockerfile、entrypoint 监督和 CI，但它给 `RS/src/data/` 补的是**全部 `unimplemented!()` 的 stub**（`RS/src/data/mod.rs:1-16` 自述），所以"能编译"不等于"能跑"，真正的数据接入层仍然不在包里。

在编译问题之下，模型层有三个各自独立的 P0：HMM 发射概率在线性空间计算并硬钳到 `1e-300`（`RS/src/engine/regime.rs:214-223`），使得每个时刻的对数似然被限制在 `[-690.776, +14.746]`——下界有限、上界为正，直接把"加状态"变成一个稳赚不赔的操作；状态数选择是对留出对数似然的裸 argmax，没有复杂度惩罚也没有占用率约束（同一条规则在四处重复），9/9 个 artifact 的验证似然对 K 严格单调递增、全部选中候选集边界 K=8 并永久标记 DEGRADED；以及 Rust 与 Python 的 analog kernel 在标准化、度量、特征集、带宽、权重、邻居筛选、k 值八个维度上全部不同，也就是说**Python 回测验证的估计量不是 Rust 里会上线的那个**。

需要明确的边界：`RS/src/predictor.rs:2193` 对每一个 forecast 无条件 push `RESEARCH_ONLY_NO_TRADE`，`:2185` 还有 `OOS_PROBABILITY_CALIBRATION_NOT_PROMOTED` 门控。因此以上模型缺陷**当前不会驱动任何真实订单**——它们损害的是"这套模型该不该被 promote"这个判断本身的可信度。这份交接包存在的目的正是支撑那个判断，所以它们仍然是阻塞项。

---

## 2. 阻断级问题（外部审查者开不了工）

按修复顺序排列。B1→B2 有严格依赖，B3~B6 可并行。

### B1 — `RS/src/data/` 真实实现从未进入交付快照，现有的只是 stub

| 项 | 内容 |
|---|---|
| **严重度** | 阻断（Blocker） |
| **类型** | packaging / 源码缺失 |
| **精确位置** | 交付分支 `agent/axio7-model-review` 上 `RS/src/data/` 整个目录不存在；`fix/handoff-buildable` 上的替代实现见 `RS/src/data/mod.rs:1-16`（自述为 STUB）、`RS/src/data/massive_live.rs`、`capability.rs`、`context.rs`、`csv_import.rs`、`databento.rs`、`dbn_decode.rs`、`market_store.rs`、`massive.rs`、`readiness.rs`、`sample_plan.rs`。同类缺失：`PY/src/intraday_quant/data/{__init__,clean,ingest}.py` 与 `PY/src/intraday_quant/reports/{__init__,pattern_analog,report,theory_audit}.py`（同样是诊断 stub） |

**最小复现**
```bash
git clone <repo> && git checkout agent/axio7-model-review
cd axio7-model-review/source/quant_engine_rs && cargo check
# → unresolved module `crate::data`（RS/src/lib.rs 声明 pub mod data，目录不存在）
```

**为什么有影响**
`RS/src/engine/l1_order_flow.rs:5` 直接 `use crate::data::massive_live::RealtimeStockTapeEvent;`，`RS/src/api.rs`、`RS/src/live.rs`、`RS/src/bin/quantctl.rs` 全部依赖该模块。模块缺失意味着 crate 完全无法编译，286 个测试一个都跑不了。更危险的是当前的补救方式：stub 的类型签名是**从调用点反推**的（`RS/src/data/mod.rs:8` 明说"签名全部从调用点反推"），所以任何在 stub 树上得到的类型正确性结论都不能外推到原实现——包括下面 B3 的那个类型错误。

**最小修复**
不是写代码，是把原始模块从上游工作树恢复出来并提交：
```bash
# 在拥有完整工作树的机器上
git checkout agent/axio7-model-review
git add -f axio7-model-review/source/quant_engine_rs/src/data \
           axio7-model-review/source/intraday_quant/src/intraday_quant/data \
           axio7-model-review/source/intraday_quant/src/intraday_quant/reports
git commit -m "Restore data/report source packages swallowed by .gitignore"
# 恢复后整体删除 fix/handoff-buildable 上的 stub 版 src/data/
```
**恢复前不要合并 B2 之外的任何东西**——先让 `.gitignore` 修好，否则 `git add` 之后的下一次 `git add .` 会再次漏掉。

**必须新增的测试**
1. `scripts/check-no-ignored-sources.sh`（`fix/handoff-buildable` 已有）接入 CI，对每一个 `src/` 下的路径跑 `git check-ignore`，命中即失败。
2. 一条"stub 不得进入交付"的断言：`grep -rn "unimplemented!()" RS/src/data/ && exit 1`。
3. `cargo test --locked` 必须在 clean checkout 上运行（见 B6）。

**阻塞 promotion**：是。在此之前无法回答"除了被吞掉的模块，模型代码还有没有别的问题"。

---

### B2 — `.gitignore` 按目录名匹配，静默吞掉源码包

| 项 | 内容 |
|---|---|
| **严重度** | 阻断 |
| **类型** | 仓库配置 / 交付完整性 |
| **精确位置** | `.gitignore:30-33`（`data/`、`outputs/`、`reports/`、`logs/`）。修复已存在于 `fix/handoff-buildable` 的 `.gitignore:35-45` |

**最小复现**
```bash
git checkout agent/axio7-model-review
git check-ignore -v axio7-model-review/source/quant_engine_rs/src/data/mod.rs
# → .gitignore:30:data/
```

**为什么有影响**
git 的排除是目录级的：一旦 `data/` 被排除，其内部文件无法用 `!` 单独放回，只能整体放行目录本身。这是 B1 的直接成因，而且它是**静默**的——`git status` 干净，本地构建通过，只有 clean clone 才暴露。

**最小修复**（`fix/handoff-buildable` 已实现，需合回交付分支）
```diff
 data/
 outputs/
 reports/
 logs/
+
+# 放行：源码树下的同名目录是 Rust/Python 模块，不是数据目录
+!**/src/data/
+!**/src/**/data/
+!**/src/reports/
+!**/src/**/reports/
+!**/src/outputs/
+!**/src/**/outputs/
+!**/src/logs/
+!**/src/**/logs/
+!**/include/data/
+!**/tests/data/
```

**必须新增的测试**
CI job `no-ignored-sources`（`.github/workflows/ci.yml:21-27`）；新增任何按目录名匹配的 ignore 规则时必须同步加放行规则，脚本负责强制。

**阻塞 promotion**：是（B1 的前置）。

---

### B3 — `l1_order_flow.rs:179` 的陈旧度比较：不要在 stub 树上"修"它

| 项 | 内容 |
|---|---|
| **严重度** | 阻断 |
| **类型** | 类型正确性 / 契约不明 |
| **精确位置** | `RS/src/engine/l1_order_flow.rs:177-180`（`ensure!(cutoff - latest.event_at <= max_age, ...)`），签名在 `:138-144`，依赖类型在 stub `RS/src/data/massive_live.rs:42`（`provider_timestamp: Option<DateTime<Utc>>`） |

**最小复现**
在交付分支上 `cargo check` 会先在 `l1_order_flow.rs:5` 因模块缺失而失败；补上 stub 后，因为 stub 把 `provider_timestamp` 反推成 `Option<DateTime<Utc>>`，`DateTime - DateTime` 得到 `chrono::TimeDelta`，与 `max_age: Duration` 同型，表达式反而通过。**这正是问题所在**：类型是否匹配完全取决于原模块怎么定义那个字段，而原模块不在包里。

**为什么有影响**
E0308 的报告与 stub 的实测行为不一致，说明这一行的类型正确性是"由缺失代码决定"的。审查者据此得到的任何结论都不成立。同时 `cutoff - x` 这种写法在 `x` 被改成 `Duration` 时会静默变成 `DateTime`，错误会飘到很远的地方才炸。

**最小修复**（B1 恢复原模块后再应用；这是防御性硬化，不是猜测性修补）
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/engine/l1_order_flow.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/engine/l1_order_flow.rs
@@ -176,10 +176,9 @@
     quotes.sort_by_key(|row| (row.event_at, row.sequence));
     let latest = *quotes.last().context("quote window is empty")?;
-    ensure!(
-        cutoff - latest.event_at <= max_age,
-        "latest quote is stale at cutoff"
-    );
+    // signed_duration_since 把两侧都钉死为 DateTime<Utc> 并必返回 TimeDelta，
+    // 任何一侧被改型都会在这里报错，而不是静默变成 DateTime。
+    let staleness: Duration = cutoff.signed_duration_since(latest.event_at);
+    ensure!(staleness <= max_age, "latest quote is stale at cutoff");
```

**必须新增的测试**
```rust
#[test]
fn quote_event_time_is_a_timestamp_not_a_duration() {
    const _: fn(&RealtimeStockTapeEvent) -> Option<DateTime<Utc>> =
        |e| e.provider_timestamp;   // 编译期锁死字段类型
}
#[test]
fn stale_latest_quote_is_rejected_at_the_boundary() { /* max_age 边界 ±1ms 两侧 */ }
```

**阻塞 promotion**：是。

---

### B4 — C++ 用了不存在的 imported target `SQLite3::SQLite3`

| 项 | 内容 |
|---|---|
| **严重度** | 阻断（对 C++ 树而言） |
| **类型** | 构建配置 |
| **精确位置** | 交付分支 `CPP/CMakeLists.txt:18`；已修复版本在 `fix/handoff-buildable` 的 `CPP/CMakeLists.txt:18-20` |

**最小复现**
```bash
cd axio7-model-review/source/quant_core_cpp
cmake -S . -B build -G Ninja   # configure 阶段不报错
# generate 阶段失败：Target "axio_quant_core" links to "SQLite3::SQLite3" but no such target
```

**为什么有影响**
CMake 官方 `Modules/FindSQLite3.cmake` 导出的名字是 `SQLite::SQLite3`。写错名字**不会在 configure 阶段报错**，只在 generate 阶段炸——这是"C++ 从没被构建过"的直接证据，也说明这棵树从未进过任何自动化。

**最小修复**（已在 `fix/handoff-buildable` 应用）
```diff
-target_link_libraries(axio_quant_core PUBLIC SQLite3::SQLite3 OpenSSL::Crypto)
+# CMake 官方 FindSQLite3 导出的 imported target 名为 SQLite::SQLite3（不是 SQLite3::SQLite3）。
+target_link_libraries(axio_quant_core PUBLIC SQLite::SQLite3 OpenSSL::Crypto)
```

**必须新增的测试**
CI job `cpp`（`.github/workflows/ci.yml:66-83`），保留 `-Werror -Wall -Wextra -Wpedantic -Wconversion -Wshadow`（`CPP/CMakeLists.txt:28-30`），并跑 `ctest --test-dir build --output-on-failure`（`CPP/tests/test_main.cpp`，243 行，从未执行过）。

**阻塞 promotion**：否（C++ 不在生产推理路径上，见 §5），但阻塞"这份包是自洽的"这一说法。

---

### B5 — Python 硬依赖 `torch` 未声明，模块级 import 导致 collection error

| 项 | 内容 |
|---|---|
| **严重度** | 阻断（对 Python 树而言） |
| **类型** | 依赖声明 |
| **精确位置** | `PY/src/intraday_quant/models/causal_tcn.py:6-8`（模块级 `import torch`）；`PY/pyproject.toml:36` 只把 torch 放进可选 extra `neural`；`PY/src/intraday_quant/training/cuda_challenger.py:440` 是函数内惰性 import，因此 `PY/tests/test_cuda_challenger.py` 只是 skip 而不是报错 |

**最小复现**
```bash
cd axio7-model-review/source/intraday_quant
python -m pip install -e ".[dev]"   # 不含 torch
python -m pytest
# → collection error：任何 import models.causal_tcn 的路径直接 ModuleNotFoundError
```

**为什么有影响**
TCN / regime-gated MoE / Student-t head 三个模型在默认安装下**根本无法导入**，而 `test_cuda_challenger.py` 的 skip 把这一点掩盖成"测试通过"。审查者会以为这些模型是可用的候选，实际上它们连加载都做不到。

**最小修复**（二选一，推荐 a）
```diff
# a) 如果 TCN 属于交付范围：升级为硬依赖
 [project]
 dependencies = [
   ...
+  "torch>=2.4",
 ]
-neural = ["torch>=2.4"]
```
```diff
# b) 如果 TCN 是研究玩具：改成惰性 import，与 cuda_challenger.py:440 保持一致
-import torch
-from torch import nn
-from torch.nn import functional as F
+def _torch():
+    import torch
+    return torch
```
并同步移除 `.github/workflows/ci.yml:61-63` 那条"已知问题"注释。

**必须新增的测试**
```python
def test_every_declared_model_is_importable(config):
    for name in config.models:            # PY/configs/default.yaml:20
        importlib.import_module(f"intraday_quant.models.{name}")
```
——这条测试同时会抓住 §3 的 M5（`analog_kernel` 被列在 `config.models` 里）。

**阻塞 promotion**：是。任何"Python 侧回测证据"在 collection error 未清之前都不可引用。

---

### B6 — 没有任何 CI；"286 个测试通过"是脏工作树上的结论

| 项 | 内容 |
|---|---|
| **严重度** | 阻断 |
| **类型** | 流程 / 可验证性 |
| **精确位置** | 交付分支上 `.github/workflows/` 不存在；补丁在 `fix/handoff-buildable` 的 `.github/workflows/ci.yml:1-96` |

**最小复现**
交付分支上三棵树没有任何一棵能从 clean checkout 构建成功（B1/B4/B5），而交接文档声称测试全绿。

**为什么有影响**
B1~B5 的共同根因就是"验证发生在本地未提交的工作树上"。没有 clean-checkout CI，这四类问题会在下一次交付时原样复现。

**最小修复**：合并 `fix/handoff-buildable` 的 `.github/workflows/ci.yml`，五个 job：`no-ignored-sources` / `rust`（`cargo fmt --check`、`clippy -D warnings`、`cargo test --locked`）/ `python` / `cpp` / `docker`（从 clean context 构建镜像本身就是 `COPY data ./data` 那类问题的回归测试）。

**必须新增的测试**：CI 即测试。额外加一条 `git ls-files | wc -l` 快照断言并不必要，`no-ignored-sources` 已经覆盖。

**阻塞 promotion**：是。

---

## 3. 模型与数值问题

已在 §2 覆盖的构建/打包问题不再重复。以下按 P0 → P1 → P2 排序，严重度已按"是否影响生产决策路径"重估（原报告的 critical/high 已归一到 P0/P1）。

**统一前提**：`RS/src/predictor.rs:2193` 对每个 forecast 无条件 push `RESEARCH_ONLY_NO_TRADE`，`:2185` 另有 `OOS_PROBABILITY_CALIBRATION_NOT_PROMOTED`。因此下述缺陷当前**不会导致错误下单**；它们的伤害是让"该 promote 哪个模型"这个决定建立在错误的数字上。

---

### M1（P0）— `GaussianHmm::emission` 在线性空间计算并钳到 1e-300；`normalize` 静默填 uniform

**类型**：数值正确性 / 下溢

**精确位置**
- `RS/src/engine/regime.rs:214-223`（`emission`，末行 `log_probability.exp().max(PROBABILITY_FLOOR)`）
- `RS/src/engine/regime.rs:41-52`（`normalize`，第 43-47 行在整行下溢时 `values.fill(uniform)` 并返回 `PROBABILITY_FLOOR`）
- 常量：`regime.rs:4`（`PROBABILITY_FLOOR = 1.0e-300`）、`regime.rs:5`（`VARIANCE_FLOOR = 1.0e-4`）
- 消费方：`regime.rs:225-268`（`forward_backward`）、`:348-366`（`filtered_probabilities`）、`:507-532`（`average_log_likelihood`）
- 同仓库内**正确**的对照实现：`RS/src/engine/regime_competition.rs:223-245`（log 空间 + logsumexp）、`RS/src/engine/tvtp_regime.rs:399-406`（max 减法）

**最小复现**
观测维度为 4（`RS/src/engine/regime_competition.rs:95-100`、`RS/src/predictor.rs:503-506`）。方差在 floor 上时，单维峰值对数密度 `-0.5*ln(2π*1e-4)=3.6865`，四维合计 `+14.746`；钳位触发阈值为 `Σd² = (690.776+14.746)/5000 = 0.1411`，即每维约 `0.188σ`。因此：
- 残差 0σ → 对数似然 `+14.746`（正确）
- 残差 0.2σ → 报告 `-690.776`，真值 `-785.3`
- 残差 1.0σ → 报告 `-690.776`，真值 `-19985.3`

**为什么有影响**
1. **单时刻对数似然被囚禁在 `[-690.776, +14.746]`**：下界有限、上界为正。`best_hmm`（`regime_competition.rs:394-425`）恰好用这个量选状态数，于是"多加一个状态"变成一个下行有限、上行为正的赌注——这是 M2 的动力来源。
2. **同一个模型被两条不同的前向算法打分**：`regime_competition.rs:515` 用 `regime.rs` 的线性空间 `average_log_likelihood` 给 `gaussian_hmm` 打分，`:537` 用 log 空间的 `average_student_t_log_likelihood` 给 `student_t_hmm` 打分。去掉钳位后两者数学等价，所以任何差异都纯粹来自钳位。仓库内还有一个可立即观测的自相矛盾：`minimum_duration_hsmm` 在 `minimum_duration=1`（候选见 `regime_competition.rs:549`）时退化为普通 HMM，理应与 `gaussian_hmm` 在浮点精度内相等，钳位一咬就不可能相等。
3. **滤波历史被静默清空**：`normalize` 在整行下溢时把 `alpha[t]` 覆盖成均匀向量，filter 忘掉全部历史，无报错、无 flag。`RS/src/market_state.rs:132-150` 的 `validate_probability_vector` 只查长度/有限/非负/和为 1，均匀向量全部通过。注意**终局**均匀向量并不危险——`RS/src/allocation.rs:456` 的 `REGIME_ENTROPY_WITHIN_POLICY` 门（阈值 0.80，`allocation.rs:96`）会 fail-closed。真正危险的是**序列中段**重置：历史被抹掉后重新收敛，最终时刻输出一个看起来很自信的后验，全程静默。

**最小修复**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
-fn emission(&self, observation: &[f64], state: usize) -> f64 {
+/// 返回对数密度。调用方负责在 log 空间做 max 减法后再取 exp。
+fn log_emission(&self, observation: &[f64], state: usize) -> f64 {
     let log_probability = (0..observation.len()).map(|column| {
         let variance = self.variances[state][column].max(VARIANCE_FLOOR);
         -0.5 * ((2.0 * std::f64::consts::PI * variance).ln()
             + (observation[column] - self.means[state][column]).powi(2) / variance)
     }).sum::<f64>();
-    log_probability.exp().max(PROBABILITY_FLOOR)
+    log_probability
 }
```
`forward_backward`（`:225-268`）改为：每个时刻先取 `m = max_s log_alpha[s]`，用 `exp(log_alpha[s] - m)` 归一，把 `m` 累加进 running log-likelihood——这正是 `tvtp_regime.rs:399-406` 已有的写法。同时把 `normalize`（`:41-52`）的签名改成 `Result<f64>`，整行下溢时返回 `Err`，并沿 `filtered_probabilities` → `infer_filtered` 一路传播。

**必须新增的测试**
```rust
// 两条前向算法必须一致（方差在 floor 上、观测偏离 1σ；今天差几千 nat）
assert_abs_diff_eq!(
    model.sequence_log_likelihood(&seq)?,
    hmm_log_likelihood_with_emission(&model, &seq, gaussian)?,
    epsilon = 1e-9);
// 全状态下溢必须报错，而不是返回 uniform
assert!(model.filtered_probabilities(&degenerate_seq).is_err());
// 仓库内自洽：D=1 的 HSMM 必须等于 gaussian_hmm
```
**阻塞 promotion**：是。

---

### M2（P0）— 状态数是留出对数似然的裸 argmax，容差 1e-12，无复杂度惩罚、无占用率约束

**类型**：模型选择 / 复杂度偏置

**精确位置**（同一条规则**四份**拷贝）
- `RS/src/engine/regime_competition.rs:399-424`（`best_hmm`，比较器 `:406-414`）
- `RS/src/predictor.rs:820-846`（`select_hmm_model`，比较器 `:837-843`，判据 `:836` `validation_score.unwrap_or(-model.bic)`）
- `RS/src/bin/quantctl.rs:3121-3143`（比较器 `:3134-3141`）
- `RS/src/bin/quantctl.rs:773` `select_hmm_within_forward_fold`，比较器 `:811-825`（**walk-forward fold 路径，容易被漏掉**）

**最小复现**
默认候选 `state_candidates = (2..=10)`（`RS/src/config.rs:332`），且 `config.rs:626-636` 强制要求 8 必须在候选里。检查 `model-artifacts/axio7-candidate-artifacts-2026-07-26.zip` 里 9 个 `universe/*.frozen.json`：全部 `candidate_state_counts: [2,3,4,5,8]`、`selected_state_count: 8`、`selected_at_candidate_boundary: true`，且验证对数似然对 K **严格单调递增、无内部极大值**（AAPL `[-4.543, -4.167, -3.976, -3.776, -3.353]`；NVDA `[-4.097, -3.792, -3.540, -3.361, -2.968]`）。

**为什么有影响**
这是 9/9 artifact 都选 K=8 的机械成因。系统已经**察觉了症状却没治因**：`predictor.rs:889-893` 计算 `selected_at_candidate_boundary`，`:914-918` 发出 `BEST_VALIDATION_SCORE_IS_AT_MAXIMUM_TESTED_K`，`:2175-2177` push `REGIME_STATE_COUNT_OPTIMUM_UNRESOLVED`，`RS/src/research_api.rs:1515-1530` 把 artifact 降级为 DEGRADED——于是每一个 artifact 都永久 DEGRADED 出厂。抬高候选上限只会把选择推到新的上限（`config.rs:630` 已允许到 12）。

**两处必须纠正的常见误诊**：(a) `1e-12` 容差**不是**成因——候选间的实际差距是 0.2~0.4 nats/obs，比容差高十个数量级；(b) 改用 BIC **也救不了**——artifact 里 `training_bic` 同样对 K 单调递减（AAPL 278250 → 254151 → 240876 → 229473 → 202709），约 3 万条训练样本下 0.4 nats/obs 的增益约 12000 nats，任何 BIC 惩罚都被淹没。真正的解药是**占用率下限 + 扩展候选网格以证明存在内部极优**。

**最小修复**
第一步：把四份拷贝合并成一个函数（否则修复必然漏掉一处）。
```rust
// 新建 RS/src/engine/state_selection.rs
pub struct SelectionPolicy {
    pub minimum_state_occupancy: f64,   // 例如 0.02，即每个状态至少 2% 后验质量
    pub minimum_improvement: f64,       // 1-SE 规则，从各 session 验证分数离散度算
}
pub fn select_state_count<'a>(
    candidates: impl Iterator<Item = (usize, Option<f64>, &'a GaussianHmm)>,
    policy: &SelectionPolicy,
) -> Option<(usize, f64, &'a GaussianHmm)> {
    // 1) 先按占用率淘汰：任一状态有效样本占比 < minimum_state_occupancy → 整个候选出局
    // 2) 在存活候选里取最高分 best
    // 3) 返回「分数 >= best - minimum_improvement 的候选中 K 最小者」
}
```
然后把 `regime_competition.rs:399-424`、`predictor.rs:820-846`、`quantctl.rs:3121-3143`、`quantctl.rs:811-825` 四处全部替换为调用它。注意占用率统计量目前**在整棵 Rust 树里不存在**（`grep -rni "occupancy" RS/src/` 零命中），需要新增：在 `regime.rs` 的 `em_step`（`:270-346`）里把 `state_weight` 归一后挂到 `GaussianHmm` 结构体（`regime.rs:7-23`）并序列化。

**必须新增的测试**
```rust
// 候选上限不变性：已知 3-regime 过程，(2..=6) 与 (2..=10) 必须都选 3
// 占用率淘汰：K=8 拟合 3 簇数据时，含空状态的候选必须出局
// 1-SE：比在位者高 1e-12 nats/obs 的候选，不得取代少 6 个状态的模型
```
**阻塞 promotion**：是。

---

### M3（P0）— Rust 与 Python 的 analog kernel 是两个不同的估计量：回测验证的不是会上线的模型

**类型**：train-serve skew

**精确位置**
- Rust：`RS/src/analog_engine/mod.rs:704-715`（标准化）、`:902-944`（度量）、`:1027-1184`（邻居检索/带宽/权重）、`:10-40`（12 维特征名）、`:134-154`（默认配置）
- Python：`PY/src/intraday_quant/models/analog_kernel.py:13-18,32,36,43`
- Rust 生产接线：`RS/src/predictor.rs:594-611`、`:1661-1677`；`RS/configs/production.yaml:167-168,187-192`
- Python 接线：`PY/src/intraday_quant/models/walk_forward.py:29-42,152,175-187,196`；`PY/configs/default.yaml:20,22-23`；证据消费 `PY/src/intraday_quant/cli.py:49-64`
- 文档把两者混为一谈：`MODEL_SOURCE_MAP.zh-CN.md:13`（同一行同时列出两个文件）；`axio7-model-review/review-package/01-model-algorithm-inventory.md:73-133` 只描述了 Rust 语义却把它当作"该模型的定义"

**最小复现**
用同一批 12 维特征与同一段带标签历史，分别喂给 `AnalogKernelModel(25, 1.0)` 和 `AnalogEngine::fit(..., production config)`。Rust 每个历史交易日最多保留 1 个邻居、带宽由第 40 近邻距离决定；Python 保留全局最近 25 行、带宽固定 1.0——在分钟级数据上通常就是同一天的连续 25 分钟。

**为什么有影响**：八项逐条核实的分歧，没有一项是等价重写
| # | 维度 | Rust | Python |
|---|---|---|---|
| 1 | 标准化 | median + 1.4826·MAD（`mod.rs:709-714`） | SimpleImputer(median) + StandardScaler，即 mean + std（`analog_kernel.py:13-18`） |
| 2 | 度量 | ShrinkageMahalanobis，`sqrt(dᵀΣ⁻¹d)`，**不除以 d**（`mod.rs:914-932`；同函数的 `StandardizedEuclidean` 分支 `:911-913` 却是除的，说明这是刻意的） | 纯 L2 / sqrt(d)，无协方差（`:32`） |
| 3 | 特征集 | 固定 12 维（`mod.rs:10-40`，`maximum_dimensions: 12`） | 最多 51 列（`walk_forward.py:29-42`） |
| 4 | 带宽 | AdaptiveKthNeighbor：第 k 近邻距离 × 0.9（`mod.rs:1159-1169`，`production.yaml:168`），尺度无关 | 固定 h = 1.0 绝对单位（`:36`，`default.yaml:23`） |
| 5 | 权重 | 高斯核 × regime 后验余弦（`mod.rs:1173-1174`） | 无该因子 |
| 6 | 邻居池 | 严格早于当前交易日、同 5m bucket、同主导 regime、余弦 ≥ 0.90、标签已成熟（`mod.rs:1032-1050,1054-1094`）、每日至多 1 个（`:1118-1128`）、不足 10 个独立日直接 `NO_RELIABLE_ANALOG`（`:1132`） | 仅 `timestamps < timestamp`（`:28`） |
| 7 | k | 40（`production.yaml:167`） | 25（`default.yaml:22`） |
| 8 | `median_return` | — | 无权 `np.median`（`:43`），而同函数其它统计量（`:42,44,45,46,48,49`）全部加权 |

Python 的输出经 `walk_forward.py:196` 写入 `models/predictions.parquet`，再由 `cli.py:52-64` 的 `score_and_select` / `run_underlying_backtest` 产出 trade_blotter 与 selected_candidates。也就是说，**这份交接包里唯一的定量回测证据，度量的是一个在中心、尺度、度量、特征空间、带宽规则、加权、邻居资格、k 值八个维度上同时不同的模型**。

**最小修复**（二选一，不要逐字段调和）
```diff
# a) 推荐：Python 侧删掉自己的实现，通过 CLI/FFI 调 Rust 引擎，回测与线上共用一个实现
# b) 若无法立刻做 a：明确把它降级为研究玩具
--- a/axio7-model-review/source/intraday_quant/configs/default.yaml
+++ b/axio7-model-review/source/intraday_quant/configs/default.yaml
-models: [logistic, analog_kernel, gradient_boosting]
+# analog_kernel 与 quant_engine_rs 的生产实现在 8 个维度上不同，
+# 其回测结果不构成对生产模型的证据，已移出默认模型集。
+models: [logistic, gradient_boosting]
```
同时修正 `MODEL_SOURCE_MAP.zh-CN.md:13`：两个文件必须分成两行、标注"研究实现"与"生产实现"，并在 `01-model-algorithm-inventory.md:73-133` 顶部注明所述语义仅适用于 Rust 实现。

**必须新增的测试**
跨语言 golden-vector：仓库内 check-in 固定的合成 states + outcomes（同 k、同 h、同特征），断言两个引擎的 `expected_return` / `win_probability` / `uncertainty` 在 1e-9 内一致，CI 上漂移即失败。详见 §5。

**阻塞 promotion**：是。

---

### M4（P1）— 家族竞争把标准化空间的对数密度和原始空间的对数密度直接相比：缺少变量替换（Jacobian）项

**类型**：打分正确性 / 似然不可比

**精确位置**
- 原始空间基线：`RS/src/engine/regime_competition.rs:369-391`（`DiagonalGaussian::average_log_likelihood`），拟合于 `:339-367`，输入来自 `:95-100` 的原始观测
- 标准化空间：`RS/src/engine/regime.rs:507-532`（`GaussianHmm::average_log_likelihood`，标准化在 `:521`，全程没有 `-Σ ln(scale_d)`）
- 同缺陷的其余三个家族：`regime_competition.rs:148-157`（`standardized()`）、`:159-170`（`gaussian_log_emission`）、`:200-221`（`student_t_log_emission`）、`RS/src/engine/tvtp_regime.rs:378-384` + `:472-473`
- 消费：`regime_competition.rs:478-481`、`:515-516`；判定：`:671-689`
- 唯一调用方：`RS/src/bin/quantctl.rs:2794-2814`（离线研究子命令）

**最小复现**
精确关系为 `log p_X(x) = log p_Z(z) - Σ_d ln(scale_d)`，HMM 路径从不把 `-Σ ln(scale_d)` 加回来。用四个生产特征（`active_5m_return`、`dist_vwap`、`rolling_realized_vol`、`volume_zscore`，尺度约 `[0.0020, 0.0022, 0.0009, 1.0]`）复算：`Σ ln(scale_d) = -19.35`；原始空间基线 `+13.67`，标准化 1 状态 HMM `-5.68`，差值 `19.3455`，与 `-Σ ln(scale_d)` 四位小数吻合。四个特征里有三个是 1e-3 量级的金融量，所以**符号是结构性的，不是数值巧合**。

**为什么有影响**
`RegimeCompetitionReport` 的每一个头部字段——`selected_family`、`selected_family_mean_score`、`no_regime_mean_score`、`promotion_status`——都失去意义，而报告自己的 `scoring_rule` 字符串却声称所有家族共用一套打分规则。由于 `no_regime_iid_gaussian` 本身就是 `max_by`（`:671-680`）的候选之一，它永远胜出，`improvement` 恒为 `0.0`，`enough_evidence`（要求 `> 0.0`）恒为 false，报告永远输出 `NO_FAMILY_PROMOTED`。**当前是 fail-closed，这正是它没被发现的原因**——但它意味着这场竞争一直在输出一个与数据无关的固定答案。

**额外的独立缺陷（修 Jacobian 也不会顺带修好）**：`:671-689` 把基线纳入 `max_by` 后又拿冠军减基线，所以只要基线正当胜出，`improvement` 必然恒等于 0.0，永远不可能满足 `> 0.0`。

**最小修复**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
@@ (GaussianHmm::average_log_likelihood, ~:507-532)
     total += self.forward_backward(&sequence).log_likelihood;
+    // 变量替换：log p_X(x) = log p_Z(z) - Σ_d ln(scale_d)
+    total -= sequence.len() as f64
+        * self.scale.iter().map(|s| s.ln()).sum::<f64>();
     observations += sequence.len();
```
对 `regime_competition::gaussian_log_emission`（`:159-170`）、`student_t_log_emission`（`:200-221`）、`NonHomogeneousGaussianHmm::filter`（`tvtp_regime.rs:472-473`）做同样处理——**全部报告原始空间密度**优于把基线标准化，因为这样得到的数字在不同 refit（scale 向量不同）之间也可比。另外把基线从 `max_by` 的候选集中剔除，改为"冠军 vs 基线"两级结构。

**必须新增的测试**
```rust
// 退化一致性：单状态 GaussianHmm 与 DiagonalGaussian 在同一数据上必须 1e-9 内相等
// 尺度不变性：把某个输入特征乘以 1000，每个家族报告的 avg log-lik/obs
// 必须恰好变化 -ln(1000)。今天 HMM 变 0，基线变 -6.9。
```
**阻塞 promotion**：是（阻塞的是"没有 regime 家族优于 no-regime"这个研究结论，不是线上路径）。

---

### M5（P1）— HSMM 前向递推在 duration 推进路径上重复计入发射；`minimum_duration=1` 不退化为普通 HMM

**类型**：正确性 / 似然误算

**精确位置**：`RS/src/engine/regime_competition.rs:283-311`（`hsmm_sequence_log_likelihood`，函数声明于 `:268`）。重复计入在 **`:288`** 与 **`:293`**；单次发射的收尾循环在 `:304-309`。

**最小复现**
记 `D = minimum_duration`，`index(s,d) = s*D + d`：
- `:286-289` 的内层循环在 `duration = D-2` 时已经把 `next[last]` 写成"含发射"的值；
- `:290-293` 又对该值 `log_sum_exp` 后**再加一次发射**。
- `D = 1` 时内层循环为空、`last == index(state,0) == 目标格`，于是 `:293` 加一次、`:307` 再加一次；而且跨状态转移（`:294-301`）写入的格子不含发射，与含发射的格子混合，**结果还依赖 `state` 的迭代顺序**，状态 0 与状态 1 不对称。

K=2、5 观测、同参数的复算：普通前向 `-6.298141`；hsmm(D=1) `-7.178606`；hsmm(D=2) `-6.527184`；hsmm(D=3) `-20.438980`。D=1 在数学上必须精确等于 `-6.298141`，而 D=1 就在调参网格里（`:549` 的 `[1,2,3,4,6]`）。

**为什么有影响**
`average_hsmm_log_likelihood`（`:315-330`）在 `:552` 用于家族内超参扫描（argmax 在 `:556`），在 `:560` 用于写进 `scores["minimum_duration_hsmm"]`（`:562-566`），最终进入 `:671-680` 的家族排名。**超参选择与家族排名都在消费这个有偏的数**，且偏差随超参非单调变化。注意量级：D=1 时约为每时刻多一次发射（O(T)）；D≥2 时重复只发生在 `d=D-2 → d=D-1` 的推进步，随"状态进入次数"而非 T 增长——原报告的 O(T) 是最坏情形而非典型情形。

**最小修复**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/engine/regime_competition.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/engine/regime_competition.rs
@@ -286,10 +286,9 @@
         for duration in 0..minimum_duration - 1 {
-            next[index(state, duration + 1)] =
-                alpha[index(state, duration)] + gaussian_log_emission(model, row, state)?;
+            next[index(state, duration + 1)] = alpha[index(state, duration)];
         }
         let last = index(state, minimum_duration - 1);
         let stay = alpha[last] + model.transition[state][state].max(1.0e-300).ln();
-        next[last] =
-            log_sum_exp(&[next[last], stay]) + gaussian_log_emission(model, row, state)?;
+        next[last] = log_sum_exp(&[next[last], stay]);
@@ -304,9 +303,12 @@
-    // 旧代码只给 index(state, 0) 加发射
+    // 发射统一在这里加，每个目标格恰好一次
+    for state in 0..states {
+        for duration in 0..minimum_duration {
+            let cell = index(state, duration);
+            if next[cell].is_finite() {
+                next[cell] += gaussian_log_emission(model, row, state)?;
+            }
+        }
+    }
```

**顺带必须修的同函数缺陷（独立问题）**：`log_sum_exp`（`:134-146`）在全部输入为 `-inf` 时返回 `LOG_FLOOR = -690.78` 这个**有限值**，于是 `:306` 的 `is_finite()` 守卫在 t=1 时会对真实质量为 0 的格子放行，注入虚假概率。应改为全 `-inf` 时返回 `f64::NEG_INFINITY`。

**必须新增的测试**
```rust
// 归约恒等式
assert_abs_diff_eq!(
    hsmm_sequence_log_likelihood(&model, &seq, 1)?,
    hmm_log_likelihood_with_emission(&model, &seq, |r,s| gaussian_log_emission(&model,r,s))?,
    epsilon = 1e-10);
// 归一化：2 状态 1 维、长度 3、离散观测网格上，展开状态核总概率质量 = 1
```
**阻塞 promotion**：是（同 M4，阻塞研究结论）。

---

### M6（P1）— MAD 尺度下限 1e-9 让一个近似常量的特征吞掉整个度量，并污染各向同性收缩目标

**类型**：数值稳定性

**精确位置**：`RS/src/analog_engine/mod.rs:714`（`scale[feature] = (1.4826 * quantile(&deviations, 0.5)).max(1.0e-9);`）与 `:747-760`（`target_variance` 为协方差对角线的**均值**，收缩循环对角加 `s*target_variance`、非对角仅乘 `(1-s)`）

**最小复现**
12 特征、400 样本、第 9 个特征 70% 的行恰为 0.0、`shrinkage = 0.20`（生产值）：`scale[9]` 落到 `1.000e-09`，标准化后该列达 `1.0e9`；原始对角线为"十一个健康特征约 1.0 + 退化特征 1.65e17"；`target_variance = 1.38e16`；收缩后**每个健康特征**的对角变成 `2.76e15`（真值约 1.0）。马氏距离平方的贡献：退化特征 7.41，十一个健康特征合计 3.99e-15，比值约 `1.9e15`——健康特征在数值上被彻底抹除。

**退化不是假设，代码自己在制造它**：`RS/src/engine/features.rs:380-384` 的 `cross_asset_breadth_score` 在 6 个 BREADTH_SYMBOLS 任一缺失时**恰为 0.0**（`collect::<Option<Vec<_>>>()...unwrap_or_default()`），即便上下文完整它也只是 6 个 {-1,0,+1} 的均值，众数天然是 0.0。同类常量兜底还有：`session_range_position` 在 `range == 0.0` 时恰为 0.5（`features.rs:313-317`）、`volume_zscore` 在 `volume_sd == 0.0` 时恰为 0.0（`features.rs:297-301`）、`normalized_range` 在 `high == low` 时恰为 0.0。

**为什么有影响**
三道可能的防线全部失效：(1) 恒等回退（`mod.rs:767-781`）不触发——收缩反而让矩阵**良态**（实测条件数 49，主元约 1e15），`invert_matrix`（`:346-394`）的绝对主元阈值 1e-12 顺利通过，于是被污染的度量被真正使用；(2) 非有限守卫（`:761-766`）——1.65e17 是有限值；(3) 冻结 artifact 校验（`:629-651`）只检查 `scale <= 0.0`，1e-9 合法。且这条路径在生产上：`AnalogEngine::fit` 由 `RS/src/predictor.rs:1127` 的 `fit_frozen_predictor` 调用，配置为 `metric: ShrinkageMahalanobis` + `..AnalogEngineConfig::default()`（`predictor.rs:594-611`）。它**fail-open**：无错误、无告警。

**最小修复**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs
@@ -709,7 +709,13 @@
-        scale[feature] = (1.4826 * quantile(&deviations, 0.5)).max(1.0e-9);
+        // 相对下限而非绝对下限：绝对 1e-9 会把常量特征放大 1e9 倍并吞掉整个度量。
+        // 本文件 :578 已经在用相对容差的写法，:714 是唯一的例外。
+        let mad = 1.4826 * quantile(&deviations, 0.5);
+        let typical = values.iter().map(|v| v.abs()).sum::<f64>() / values.len() as f64;
+        if mad < 1.0e-6 * (1.0 + typical) {
+            return None;   // fail-closed：拒绝拟合，而不是发出被单列支配的度量
+        }
+        scale[feature] = mad;
```
并独立地把收缩目标改为**相关结构**：先把协方差归一到单位对角，再施加各向同性目标，使 `target_variance` 无法被最高方差列劫持。

**必须新增的测试**
```rust
// 某特征在 >50% 训练行上为常量时，fit() 必须返回 None（或把该维排除出 selected_dimensions），
// 而不是返回一个距离被该列支配的引擎。
// 注意本文件自己的测试夹具 mod.rs:1572 就把 session_range_position 硬编码成 0.5。
```
**阻塞 promotion**：是。

---

### M7（P1）— `locally_weighted_linear_intercept` 从一簇近乎等距的点外推到 distance=0；1e-12 行列式守卫拦不住，而该值被发布

**类型**：数值稳定性

**精确位置**：`RS/src/analog_engine/mod.rs:1236-1251`（计算；字段声明 `:185`，赋值 `:1261`）；发布于 `RS/src/predictor.rs:2268`（`KernelRegressionEvidence.local_linear_intercept`）；唯一消费者是 `RS/src/api.rs:2056` 的有限性检查

**最小复现**
40 个候选，距离在 `[0.97, 1.03]` 上均匀（`distance_concentration = 0.06`，通过 `mod.rs:1390` 的 < 0.05 门），`terminal_return` 为与距离独立的 `N(0, 0.002)` 噪声。2 万次蒙特卡洛：`sd(intercept) = 185bp`，`sd(Nadaraya-Watson mean) = 3.15bp`，比值 **58.8×**；`determinant = 3.7e-4`，比 1e-12 阈值高四个数量级，回退**永不触发**。

**为什么有影响**
权重已归一（`mod.rs:1181-1184, :1212`），所以 `sum_w == 1`、`determinant == Var_w(d)` 恰好成立，`local_intercept = ȳ - slope·d̄`，而 `d̄/sd(d)` 在自适应带宽下常在 30~60。它是在把一个距离从不接近 0 的簇外推到 0。更根本的问题：对**范数**而非有符号位移向量 `(x_i - x_q)` 做回归**不是** local-linear regression——一阶偏差项是 `E[x_i - x_q]`，取模无法抵消它，因此它连自己名字承诺的偏差修正都没做到。而 `mod.rs:1427` 的 `supported_method_comparison` 里 `locally_weighted_linear_regression` 一项把它宣传成对 NW 均值的改进，且**不发布标准误**，人类消费者看不出 59 倍的噪声放大。

**最小修复**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs
@@ -1240,7 +1240,13 @@
-    let local_intercept = if determinant.abs() > 1.0e-12 {
+    // determinant == Var_w(d)（权重已归一）。绝对阈值对尺度无感，必须用相对判据 +
+    // 杠杆上限：mean_w(d)/sd_w(d) 越大，外推到 d=0 的方差放大越严重。
+    let mean_d = sum_wx;                       // sum_w == 1
+    let sd_d = determinant.max(0.0).sqrt();
+    let well_posed = determinant > 1.0e-6 * mean_d * mean_d
+        && sd_d > 0.0
+        && mean_d / sd_d < 5.0;
+    let local_intercept = if well_posed {
         (sum_wxx * sum_wy - sum_wx * sum_wxy) / determinant
     } else {
         mean
     };
```
并且**要么删掉这个字段，要么**改为对 d 维标准化位移做真正的带岭正则的 local-linear regression，同时发布它自己的标准误。

**必须新增的测试**
```rust
// 属性测试：返回与距离独立的随机候选集上，断言
// |local_linear_intercept - kernel_weighted_mean| <= 3 * dispersion / sqrt(effective_sample_size)
// 或断言回退已触发。上面的 58.8× 场景必须被杠杆上限拒绝。
```
**阻塞 promotion**：否（无决策消费者），但阻塞"这份报告里的证据字段可信"这一说法。

---

### M8（P1）— OOD 阈值在 ~256 点等步长子样本上标定，筛选条件与查询期不同；且步长与交易日周期发生别名

**类型**：正确性 / 标定

**精确位置**：`RS/src/analog_engine/mod.rs:864-890`（标定，步长在 `:866`，最近邻循环 `:873-886`）；使用处 `:1330-1331`（`nearest = distances[0]`，`ood_score = nearest / threshold`）与 `:1381-1383`（`ood_score > 1.0` 为硬 NO_TRADE）；再次抛出于 `RS/src/predictor.rs:2181`（`ANALOG_OOD`）

**最小复现**
三重失配：
1. **样本量**：阈值是**至多 256 个**训练点内部最近邻距离的 0.95 分位；查询期的分子却是对**完整候选池**求的最近邻距离。NN 距离约按 `n^(-1/d)` 缩放，d=12 时从 256 到 10 万点约差 `390^(1/12) ≈ 1.6×`，阈值系统性偏高约 60%，OOD 门相应过松。
2. **筛选条件**：标定循环只排除"同一 session_date"，**不施加** `same_time_bucket`（`:1038`）与 regime 过滤（`:1054-1094`），而这两者在查询期都生效且都会**移除**候选、推高查询期的最小距离。分子分母来自不同总体，比值不是任何东西的概率。
3. **步长别名**：`stride = len.div_ceil(256)`。约一个交易年（99,585~99,840 个 state，每 session 390 根）时 `div_ceil(99700/256) = 390`，恰等于每日 bar 数——**所有标定点落在同一个 session 分钟上**，而 `minute_of_session` 正是 12 个距离特征之一。

**为什么有影响**
`ood_score > 1.0` 直接决定可用率（availability rate）：过松则该拒的不拒，别名则阈值随训练集长度突变。

**最小修复**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs
@@ -864,8 +864,12 @@
-    let stride = engine.train_indices.len().div_ceil(256).max(1);
-    let sampled = engine.train_indices.iter().step_by(stride).copied().collect::<Vec<_>>();
+    // step_by 会与 390 根/session 的严格周期发生别名，导致所有标定点落在同一分钟。
+    // 用 restart/训练集哈希做种子的确定性洗牌，保持可复现性但消除周期性。
+    let mut sampled = engine.train_indices.clone();
+    deterministic_shuffle(&mut sampled, calibration_seed(engine));
+    sampled.truncate(CALIBRATION_SAMPLE.min(sampled.len()));
```
且标定的最近邻必须走**与查询期同一条候选过滤链**（same bucket / same dominant regime / one-per-day / 标签已成熟），取这些"最小距离"的 0.95 分位。并把 `calibration_sample_size` 记入 `AnalogDiagnostics`。

**必须新增的测试**
```rust
// 标定样本必须覆盖至少 N 个不同的 minute_of_session（今天是 1 个）
// 训练集翻倍时 ood_distance_threshold 变化不超过 10%
```
**阻塞 promotion**：是（它决定可用率，可用率是 promotion 证据的一部分）。

---

### M9（P1）— restart 只在一个盆地里搜索：均值扰动关于 restart 以 K 为周期、上限 7e-3σ，真正变化的只有自转移概率

**类型**：优化 / 初始化

**精确位置**：`RS/src/engine/regime.rs:163-212`（`initialized`），关键在 `:179`（`ordered[rank][column] + ((state + restart) % states) as f64 * 1.0e-3`）与 `:184`（`(0.82 + 0.02 * (restart % 5) as f64).min(0.94)`）

**最小复现**
- `(state + restart) % states` 关于 restart 的周期是 `states`，所以 restart `r` 与 `r+K` 产生**逐字节相同**的均值；跨 restart 只是同一个偏移多重集 `{0, 1e-3, …, (K-1)e-3}` 的循环置换，且同一标量被加到每一维，连对角结构都不扰动。
- `persistence` 周期为 5，取值仅 `{0.82, 0.84, 0.86, 0.88, 0.90}`，`.min(0.94)` 是死代码。
- 其余一切与 restart 无关：`initial: vec![1.0/states; states]`（`:201`）、`variances: vec![vec![1.0; dimensions]; states]`（`:204`）。
- 均值扰动跨所有 restart 至多跨越 `(K-1)*1e-3 = 0.007` 标准化单位（相邻状态的分位间距是 O(1)）。`grep -n restart RS/src/engine/regime.rs` 只命中 `101,127,132,167,179,184`；`rand` 不在 `Cargo.toml` 依赖里——**根本没有 RNG**。
- 生产默认 `restarts: 3`（`RS/src/config.rs:336`），所以只有 3 个 persistence 值可达，周期回绕（3 < 8）从不触发。

**为什么有影响**
K=8 的对角高斯 HMM 上 EM 有大量局部极优，`restarts` 是唯一的防线而它不工作。这与 M2 直接耦合：每个 K 都落在同一个确定性盆地，于是 K-vs-K 的比较是"任意局部极优之间的比较"，而不是"各模型可达拟合能力之间的比较"，K 的排名在数据的任何扰动下都不可复现。同时 `regime.rs:629-651` 的确定性测试（`assert_eq!(first, second)` 在 `:636`）**空洞地通过**——它证明的是确定性，不是搜索发生过。

**最小修复**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
@@ -176,10 +176,12 @@
-        (0..dimensions)
-            .map(|column| {
-                ordered[rank][column] + ((state + restart) % states) as f64 * 1.0e-3
-            })
-            .collect::<Vec<_>>()
+        // 种子是 restart 的纯函数 → 确定性不变，只增加多样性。
+        // restart 0 保留原分位阶梯（回归基线），restart >= 1 走 k-means++ 播种。
+        let mut rng = SplitMix64::seeded(splitmix64(restart as u64));
+        if restart == 0 { quantile_ladder(&ordered, rank, dimensions) }
+        else { kmeanspp_seed(&mut rng, normalized_sequences, states)[state].clone() }
```
方差改为对数均匀采样、转移行改为 Dirichlet 采样。不引入 `rand` 依赖：`splitmix64` 二十行手写即可，保持 `Cargo.toml` 不变。

**必须新增的测试**
```rust
// restarts=8 时，initialized() 产生的均值集合中至少有 8 个两两不同的配置，
// 且两两 L2 距离 > 0.1（标准化单位）
// 恢复性测试：已知 3-regime 过程 + 刻意对抗性的分位布局下，
// fit(..., restarts=10) 能恢复真实均值而 restarts=1 不能
```
**阻塞 promotion**：否（不崩溃、不算错、EM 仍收敛到合法局部极优），但它是 M2 结论不可复现的共因，应与 M2 一并修。

---

### M10（P2）— `model.log_likelihood` 与 `model.bic` 描述的是**最后一次 M-step 之前**的参数

**类型**：正确性 / off-by-one

**精确位置**：`RS/src/engine/regime.rs:137-158`（fit 循环；`:142` 存似然、`:150-151` 算 BIC、`:152-158` restart 比较）与 `:270-346`（`em_step`：`:279-280` 用当前参数算似然、`:326-344` 做 M-step 变更、`:345` 返回旧似然）

**最小复现**
`em_step` 用 θ_k 跑 forward_backward 累加 `L(θ_k)`，随后把 `self` 覆写为 θ_{k+1}，返回 `L(θ_k)`。循环结束后存的参数是 θ_{n+1}，而 `log_likelihood = L(θ_n)`，且 fit 全程没有循环后重算。同一个 codebase 的兄弟实现 `RS/src/engine/gmm.rs:157-170` **刻意**在 M-step 之后重跑 E-step 取分数（`:160`）——所以这是不一致，不是设计选择。

**为什么有影响**
BIC 由陈旧似然算出，`RS/src/predictor.rs:836`（`validation_score.unwrap_or(-model.bic)`）与 `RS/src/bin/quantctl.rs:3134` 的 BIC 回退路径在用"属于另一组参数的分数"排名；restart 选择（`:152-158`）同理。`RS/src/market_state.rs:221-224` 只检查有限性，接不住。

**降级理由（P1 → P2）**：循环退出条件是 `|L_k - L_{k-1}| <= 1e-6*(1+|L|)`，缺失的最后一次增量与收敛容差同阶，相对候选间数百 nat 的 BIC 差距翻不了排名；只有 `max_iterations` 耗尽路径才可能产生实质陈旧值，且由 EM 单调性可知偏差在所有候选上同向。BIC 只是**回退**路径（状态字符串字面就是 `BIC_FALLBACK`），生产走的是 `average_log_likelihood(validation)`，那条路是用最终参数算的。另：非有限 break 那条支路实际不可达——`normalize`（`:41-52`）把任何非有限或下溢的和钳到 1e-300，`emission`（`:222`）的 `.max(PROBABILITY_FLOOR)` 在 Rust 里也吞掉 NaN。

**最小修复**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
@@ (fit，收敛循环之后、算 BIC 之前)
+    // 与 gmm.rs:157-170 保持一致：报告的分数必须属于返回的参数。
+    model.log_likelihood = normalized_sequences
+        .iter()
+        .map(|seq| model.sequence_log_likelihood(seq))
+        .sum::<Result<f64>>()?;
     model.bic = ...;
```
非有限分支改为**整个 restart 作废**，而不是带着陈旧元数据 break。（注意：原建议里的 `model.sequences_log_likelihood(...)` 这个方法在本仓库不存在，可用的是 `regime.rs:387` 的 `sequence_log_likelihood` 或 `:507` 的 `average_log_likelihood`。）

**必须新增的测试**
```rust
// fit() 之后：|model.log_likelihood - Σ_seq model.sequence_log_likelihood(seq)| < 1e-9
// 今天差整整一个 EM step
```
**阻塞 promotion**：否。

---

### M11（P2）— 生产 EM 路径没有单调性守卫，且收敛判据用 `abs()`，似然**下降**会被当成收敛而退出

**类型**：缺失不变量 / EM

**精确位置**：`RS/src/engine/regime.rs:144-147`（`if (likelihood - previous).abs() <= 1.0e-6 * (1.0 + likelihood.abs()) { break; }`）与 `:324`（唯一的断言：`debug_assert!(fb.scales.iter().all(|v| v.is_finite()))`，release 下被编译掉，且只查有限性不查单调性）。**同构缺陷复制在** `RS/src/engine/gmm.rs:165-169`（同样的 abs() 判据、同样缺单调性守卫、同样 push `training_likelihoods`）

**最小复现**
`.abs()` 让判据对称：容差带内的下降与收敛不可区分，静默退出。全仓库 grep 不到任何 EM 路径上的似然下降守卫（唯一的 `cannot decrease` bail! 在 `RS/src/anomaly_research/mod.rs:981`，与此无关）。

**为什么有影响**
Baum-Welch 的似然非降是"实现正确"的唯一信号。M1 的钳位确实会破坏这个保证（`regime.rs:222` 的 `.exp().max(PROBABILITY_FLOOR)` + `:43-47` 的 floor 返回），届时只会静默劣化而不是失败。`training_likelihoods` 被序列化进 artifact，但 `RS/src/market_state.rs:225-231` 只检查元素有限。这条路径在生产上：`GaussianHmm::fit` → `predictor.rs:796 select_hmm_model` → `predictor.rs:1124` / `:1296` 构建冻结 artifact → `predictor.rs:641 validate_static` → `market_state::validate_model_artifact`。

**两处必须纠正的表述**：(a) 单调性断言**确实存在**，只是在 `#[cfg(test)]` 里——`regime.rs:645-650` 的 `first.training_likelihoods.windows(2).all(|p| p[1] + 1e-7 >= p[0])`；它今天没保护力，纯粹是因为 crate 编译不过、测试从没跑过。(b) `abs()` 掩盖的只是**容差带以内**的下降；更大的下降会产生大 abs 值，循环会继续而非退出。

**最小修复**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
@@ -144,6 +144,11 @@
-        if (likelihood - previous).abs() <= 1.0e-6 * (1.0 + likelihood.abs()) {
+        // 违规与收敛必须分开判定，否则容差带内的下降会伪装成收敛。
+        if likelihood + 1.0e-9 * (1.0 + likelihood.abs()) < previous {
+            bail!("EM likelihood decreased: {previous} -> {likelihood}");
+        }
+        if likelihood - previous <= 1.0e-6 * (1.0 + likelihood.abs()) {
             break;
         }
```
`gmm.rs:165-169` 同步施加。另在 `market_state::validate_model_artifact`（`:225-231`）拒绝 `training_likelihoods` 非单调的 artifact。

**必须新增的测试**
把 `regime.rs:645-650` 的 `windows(2)` 单调性断言从测试模块提升为 `fit()` 内的硬错误，并新增一条：刻意破坏 M-step（例如转移行不重新归一）时 `fit()` 必须返回 `Err` 而不是一个静默变差的模型。

**阻塞 promotion**：否（防御性纵深）。

---

### M12（P2）— Python 侧邻居资格只查特征时间戳，不查标签成熟时间

**类型**：look-ahead / 泄漏（潜在）

**精确位置**：`PY/src/intraday_quant/models/analog_kernel.py:27-28`（注释 + `eligible = np.flatnonzero((self.timestamps < timestamp).to_numpy())`）；标签读取在 `:38-40`；Rust 侧的正确写法在 `RS/src/analog_engine/mod.rs:1048`（`if realized_path.label_available_at > query.timestamp { continue }`）

**最小复现**
`:28` 只按特征时间筛选，`:38-40` 读的 `return`/`mfe`/`mae` 来自 `walk_forward.py:177` 的 `forward_return_{h}m` / `MFE_{h}m` / `MAE_{h}m`（`PY/src/intraday_quant/labels/pipeline.py:26-38`），是邻居时刻**之后** h 分钟的前瞻结果。

**为什么只有 P2 而不是 critical**
1. 唯一调用方是 `walk_forward.py:176-179`，而 `make_folds`（`:45-57`）产出的是**按整 session 切分且有序不相交**的切片，所有训练时间戳都早于所有测试时间戳——`eligible` 掩码在实际执行路径上是恒真式，**从未过滤掉任何一行**。
2. 原报告称"任何改成 expanding/rolling 窗口或改 purge_minutes 都会静默重新引入前瞻"——这个机制是**错的**。标签不能跨 session 边界：`labels/pipeline.py:28` 强制 horizon 窗口留在候选自己的日期内，否则标签为 NaN，`walk_forward.py:82` 再把这些行丢掉。因此训练邻居的标签必然在其自身 session 内成熟，结构性地早于任何更晚 session 的查询。`purge_minutes` 与 `expanding` 与这个泄漏无关。
3. `joblib.dump`（`walk_forward.py:187`）确实存在，但全项目（排除 `.venv`）grep 不到任何 `joblib.load`——"被持久化后在别处复用"是假设而非现存路径。
4. 不在生产决策路径上（生产是 Rust，且 Rust 已经正确实现了该守卫）。

**最小修复**
```diff
--- a/axio7-model-review/source/intraday_quant/src/intraday_quant/models/analog_kernel.py
+++ b/axio7-model-review/source/intraday_quant/src/intraday_quant/models/analog_kernel.py
-        # The caller already supplies prior-fold history; this guard also makes direct use safe.
-        eligible = np.flatnonzero((self.timestamps < timestamp).to_numpy())
+        # 只有标签已成熟的邻居才可用（对齐 quant_engine_rs analog_engine/mod.rs:1048）。
+        eligible = np.flatnonzero((self.label_available_at <= timestamp).to_numpy())
```
`fit` 时记录 `self.label_available_at = timestamps + pd.Timedelta(minutes=self.horizon)`，构造函数接收 `horizon`。**第 27 行那句注释无论如何都必须删掉**——它宣称了一个代码不具备的安全属性，在一个对泄漏高度敏感的 codebase 里，这本身就是缺陷。

**必须新增的测试**
```python
def test_neighbours_have_matured_labels():
    # 在 t0..t100 上 fit（60m horizon），在 t101 predict，
    # 断言选中的每个邻居索引都满足 timestamps[idx] + 60min <= t101
```
**阻塞 promotion**：否（若 M3 采纳 (b) 方案把该类降级为研究玩具，本条只需保留删注释 + 加测试）。

---

## 4. 实时与部署问题（含 Railway 专项）

**覆盖范围声明**：本节只审计了**容器与平台配置层**（`RS/Dockerfile`、`RS/railway.json`、`RS/container-entrypoint.sh`、`RS/DEPLOY.railway.md`）以及**状态持久化路径**（prediction ledger）。**未覆盖**：Moomoo bridge / WebSocket 的重连与背压、API 鉴权中间件与限流、`tower-http` CORS 策略、TLS 终止、以及实时子进程的内存/句柄泄漏。这几块需要单独一轮审查，本节不做任何推测。

---

### D1 — Railway 文件系统是临时的，而 prediction ledger 是本地 SQLite

| 项 | 内容 |
|---|---|
| **严重度** | 阻断部署（Blocker for production deploy） |
| **类型** | 状态持久化 |
| **精确位置** | `RS/src/api.rs:834`（`root.join("state/prediction_ledger.sqlite3")`）、`:838`（`PredictionLedger::open`）、`:4196`、`:4212`；CLI 默认路径 `RS/src/bin/quantctl.rs:154, 203, 226, 456, 476, 480`（`data/state/prediction_ledger.sqlite3`）；`RS/Dockerfile:30-31` 只 `mkdir` 了 `/app/data/{live/options,state,reports}`；`RS/Cargo.toml:21-45` **没有任何 postgres driver**（只有 `rusqlite = "0.38"` 在 `:34`）；`RS/railway.json` 未声明任何 volume |

**最小复现**：部署 → 产生若干 pending prediction → `railway up` 重新部署 → `/api/v1/predictor/settlements`（`RS/src/api.rs:182, 4205`）返回空。

**为什么有影响**：`/app/data/state` 与 `/app/data/live` 里的 JSONL spool 和 pending ledger 每次 redeploy 全部丢失。而 `RS/src/api.rs:893-936` 的门控要求 `settled >= minimum_settled` 且 `minimum_settled >= 250`——**一个会被周期性清零的账本永远攒不到 250 条已结算预测**，也就是说这条 promotion 门在当前部署形态下**结构上不可能被满足**。

**最小修复**（短期 a，正解 b）
```diff
# a) 短期：挂 Railway Volume 到 /app/data，并在 railway.json 里显式声明
 {
   "deploy": {
     "healthcheckPath": "/health",
+    "volumes": [{ "mountPath": "/app/data" }],
     "numReplicas": 1
   }
 }
```
b) 正解：把 normalized record 与 prediction ledger 落 PostgreSQL（`DEPLOY.railway.md:11` 已经把 Postgres 列进服务拓扑，但 crate 连 driver 都没有）。在 b 完成之前，这个服务**只适合作为研究用只读 API 部署**，不要用它承载任何有状态的实时预测记录。

**必须新增的测试**：容器重启后 pending ledger 可恢复的集成测试——写入 N 条 pending、重启进程、断言 `pending_forecasts()`（`RS/src/live.rs:688`）仍返回 N 条。这条测试**目前不存在**。

**阻塞 promotion**：是（它让 `settled >= 250` 这道门永久无法通过）。

---

### D2 — `massive-check` 一个门控同时覆盖 equity 与 options 权限

| 项 | 内容 |
|---|---|
| **严重度** | 高 |
| **类型** | 可用性耦合 |
| **精确位置** | `RS/container-entrypoint.sh:46-54`（`if quantctl live massive-check; then` 之后才同时拉起 `massive-model` 与 `massive-options-watch`） |

**最小复现**：账号只有 SIP（equity）而无 OPRA（options）权限 → `massive-check` 失败 → **equity 实时模型也不启动**，日志只有一行 `SIP/OPRA readiness failed`（`:53`）。

**为什么有影响**：一个 options 权限问题会让整个实时 equity 路径静默停摆，而 `/health` 仍然返回 200（quantd 本身活着）。这直接压低可用率，而可用率是 promotion 证据的一部分。

**最小修复**
```diff
--- a/axio7-model-review/source/quant_engine_rs/container-entrypoint.sh
+++ b/axio7-model-review/source/quant_engine_rs/container-entrypoint.sh
-if quantctl --config "$config" live massive-check \
-  --output data/live/massive_readiness.json; then
-  quantctl --config "$config" live massive-model &
-  model_pid=$!
-  quantctl --config "$config" live massive-options-watch &
-  options_pid=$!
-else
-  echo "SIP/OPRA readiness failed; live model/watchers were not started" >&2
-fi
+if quantctl --config "$config" live equity-check \
+  --output data/live/equity_readiness.json; then
+  quantctl --config "$config" live massive-model &
+  model_pid=$!
+else
+  echo "SIP readiness failed; live equity model was not started" >&2
+fi
+if quantctl --config "$config" live options-check \
+  --output data/live/options_readiness.json; then
+  quantctl --config "$config" live massive-options-watch &
+  options_pid=$!
+else
+  echo "OPRA readiness failed; options watcher was not started" >&2
+fi
```
前置依赖：`equity-check` / `options-check` 两个子命令需要在 `RS/src/data/readiness.rs` 里实现——**该文件当前是 stub**，所以本项被 B1 阻塞。

**必须新增的测试**：两个 readiness fixture（equity OK / options FAIL 与反之），断言只有对应的子进程被拉起。

**阻塞 promotion**：否，但阻塞"可用率数字可信"。

---

### D3 — `numReplicas: 1` 是正确性约束，而 ledger 没有幂等键来解除它

| 项 | 内容 |
|---|---|
| **严重度** | 中（当前无害，但是一条硬扩展天花板） |
| **类型** | 并发 / 数据完整性 |
| **精确位置** | `RS/railway.json`（`"numReplicas": 1`）；理由记在 `RS/DEPLOY.railway.md:29-32`；写入点 `RS/src/bin/quantctl.rs:2615-2616`（`prediction_ledger.append_prediction(contract)`）与 `:2619-2620`（`live::settle_pending`）；结算实现 `RS/src/live.rs:670-796` |

**最小复现**：把 `numReplicas` 调到 2 → 两个副本订阅同一路 feed、重复写 ledger、重复结算同一批到期预测。

**为什么有影响**：这不是省钱选项而是正确性选项，但它把这条约束隐藏在一个 JSON 数字里——任何人为了扛流量调大它就会污染预测记录。约束应该在**代码里**表达，而不是靠一份部署文档。

**最小修复**：在 ledger 表上加 per-prediction 幂等键（`UNIQUE(symbol, as_of, horizon, model_version)`），`append_prediction` 改为 `INSERT ... ON CONFLICT DO NOTHING` 并返回是否新增；`settle_pending` 用同样的方式对结算去重。做到之后 `numReplicas` 才可以放开。在此之前，至少在 `railway.json` 旁边加一条 CI 断言：`numReplicas` 不等于 1 即失败。

**必须新增的测试**：并发写入测试——两个 writer 同时 `append_prediction` 同一份 contract，断言 ledger 里只有一行。

**阻塞 promotion**：否。

---

### D4 — 部署文档与代码不一致：`DEPLOY.railway.md` 声称 pending 不自动结算，但实时循环里已经在结算

| 项 | 内容 |
|---|---|
| **严重度** | 中（交接包自洽性） |
| **类型** | 文档漂移 |
| **精确位置** | `RS/DEPLOY.railway.md:58-59`（"pending prediction 不会自动结算 …… 目前写入后没有在同一个 live loop 里结算"）与实际代码 `RS/src/bin/quantctl.rs:2619-2620`（`let settlements = live::settle_pending(&prediction_ledger, &finalized_output)?;`，就在同一个 live loop 内、`append_prediction` 之后 4 行） |

**最小复现**：并排读 `DEPLOY.railway.md:58-59` 与 `quantctl.rs:2615-2626`。

**为什么有影响**：这是外部审查者会最先读的文件（`DEPLOY.railway.md:48` 标题就叫"仍然阻塞生产部署的问题"）。一条已经不成立的阻塞项会误导审查者的优先级排序，也会让他们怀疑同一份文档里**其它三条**（D1/D2/D3，那三条是真的）的可信度。

**最小修复**
```diff
--- a/axio7-model-review/source/quant_engine_rs/DEPLOY.railway.md
+++ b/axio7-model-review/source/quant_engine_rs/DEPLOY.railway.md
-3. **pending prediction 不会自动结算。** 到期的预测需要一个 causal settlement 循环，
-   目前写入后没有在同一个 live loop 里结算。重启后 pending ledger 能否恢复也未验证。
+3. **重启后 pending ledger 能否恢复未验证。** 结算本身已经在实时循环里做了
+   （`src/bin/quantctl.rs:2619` 调用 `live::settle_pending`），但那依赖进程内
+   持续存活的 SQLite 文件；在第 1 条（临时文件系统）解决之前，重启后
+   pending 是否可恢复没有任何测试覆盖，见 `src/live.rs:670-796`。
```

**必须新增的测试**：同 D1 的重启恢复测试。

**阻塞 promotion**：否，但阻塞交接。

---

### D5 — 镜像里没有冻结 artifact，也没有 `models/` 目录；缺失时静默降级为 `UNAVAILABLE`

| 项 | 内容 |
|---|---|
| **严重度** | 中 |
| **类型** | 部署完整性 / 静默降级 |
| **精确位置** | `RS/src/api.rs:3385-3392`（`model_contract_projection` 读 `root.join("models/frozen_predictor_latest.json")`，用 `.ok().and_then(...).unwrap_or_else(\|\| json!({"status":"UNAVAILABLE"}))`）；`RS/Dockerfile:30` 只创建了 `/app/data/{live/options,state,reports}`，**没有** `models/`；`RS/Dockerfile:20-27` 只 COPY 了 `configs`、`risk_policy.yaml`、entrypoint，没有 COPY 任何 artifact |

**最小复现**：从 clean checkout 构建镜像并启动 → 请求 model contract 端点 → 得到 `{"status":"UNAVAILABLE"}`，容器健康、日志无异常。

**为什么有影响**：模型 artifact 如何进入运行中的容器，在整个交接包里**没有被任何文件定义**（既不在 Dockerfile 里，也不在 `railway.json` 里，也不在 `DEPLOY.railway.md` 的环境变量表 `:40-46` 里）。而 `.ok()...unwrap_or_else` 让缺失变成一个安静的降级而不是启动失败。审查者无法判断"线上跑的到底是哪个 artifact"。

**最小修复**
```diff
--- a/axio7-model-review/source/quant_engine_rs/Dockerfile
+++ b/axio7-model-review/source/quant_engine_rs/Dockerfile
-    && mkdir -p /app/data/live/options /app/data/state /app/data/reports \
-    && chown -R axio:axio /app/data/live /app/data/state /app/data/reports
+    && mkdir -p /app/data/live/options /app/data/state /app/data/reports /app/data/models \
+    && chown -R axio:axio /app/data/live /app/data/state /app/data/reports /app/data/models
```
并在 `container-entrypoint.sh` 的自检段之后加一道显式门控：若 `AXIO_REQUIRE_FROZEN_ARTIFACT=1` 而 `data/models/frozen_predictor_latest.json` 不存在，则 `exit 74` 而不是让 API 带着 `UNAVAILABLE` 上线。artifact 的分发路径（挂 volume / 启动时从对象存储拉取 / 随镜像 COPY 一个显式跟踪的 `seed/` 目录，参见 `Dockerfile:26` 里已有的建议）必须在 `DEPLOY.railway.md` 里写死。

**必须新增的测试**：CI 里的容器冒烟测试——启动镜像、断言 `/health` 通过**且** model contract 端点的 `status` 不是 `UNAVAILABLE`（在挂载了 fixture artifact 的前提下）。

**阻塞 promotion**：否，但阻塞"线上模型可追溯"。

---

## 5. 架构收敛建议

### 5.1 三套源码的定位与管辖

当前三棵树的关系在文档里是错的（`MODEL_SOURCE_MAP.zh-CN.md:13` 把 Rust 与 Python 的 analog 实现写在同一行，当成一个模型），这直接导致了 M3。建议把边界写死为**单向流水线**，并在 `PROJECT_CONTRACT.md` 里固化：

```
intraday_quant (Python)        quant_engine_rs (Rust)          web (TypeScript)
研究 / 训练 / 标签构造   ──►    生产推理 / 实时 / API      ──►   展示 / 鉴权 / 路由
产出：冻结 artifact JSON        消费：artifact；产出：证据信封     消费：证据信封
不常驻部署（CI job 或研究机）   Railway 唯一常驻服务             Railway 前端服务
```

三条硬规则：
1. **Python 不得包含任何会被拿来当"生产模型证据"的推理实现。** 要么调 Rust（见 5.3），要么明确标注为研究玩具并移出 `config.models`（`PY/configs/default.yaml:20`）。
2. **Rust 不得包含训练循环之外的研究报表逻辑。** 目前 `RS/src/engine/regime_competition.rs` 的唯一调用方是离线 CLI 子命令（`RS/src/bin/quantctl.rs:2794-2814`），它属于研究侧；应迁到独立的 `research` feature gate 下，避免研究代码的缺陷（M4/M5）被误读成生产缺陷。
3. **artifact 是唯一的跨语言接口。** schema 版本化（仓库里已有这个习惯，如 `RS/src/engine/l1_order_flow.rs:7` 的 `L1_ORDER_FLOW_SCHEMA_VERSION`），任何字段变更走版本号，两侧各有一个反序列化测试。

### 5.2 C++：退役，保留为只读参考

**结论：退役。** 依据：
- 规模很小且不在生产路径上：真实源码只有 `CPP/include/axio/quant_os.hpp`（417 行）、`CPP/src/quant_os.cpp`（1600 行）、`CPP/tests/test_main.cpp`（243 行）、三个 `apps/*/main.cpp`。
- **从未被构建过**：`CMakeLists.txt:18` 的 `SQLite3::SQLite3` 会在 generate 阶段失败（B4），而这个错误在 configure 阶段不报错——说明这棵树从未进过任何自动化。
- 它与 Rust 树的功能是重叠的：`apps/axiod`、`apps/quantctl`、`apps/moomoo_adapter` 三个入口在 Rust 侧分别对应 `RS/src/bin/quantd.rs`、`RS/src/bin/quantctl.rs` 和 Moomoo bridge。
- 保留成本不为零：`CMakeLists.txt:28-30` 开着 `-Werror -Wall -Wextra -Wpedantic -Wconversion -Wshadow`，一旦接入 CI，一棵从未编译过的 1600 行 C++ 会产生大量需要处理的告警，而这些工作对 promotion 决定没有任何贡献。

**执行方式**：先合并 B4 的修复并让 CI 的 `cpp` job 跑通**一次**（证明它确实能构建、`ctest` 确实能过），把结果记录在案，然后把整棵树移到 `axio7-model-review/reference-docs/legacy-cpp/` 并在 `README.md` 标注"历史参考实现，不参与构建，不接受变更"。**不要直接删除**——它是理解早期设计意图的唯一材料。如果 C++ 树里有 Rust 侧没有的能力（需要逐个 `apps/*/main.cpp` 核对后确认），先把该能力迁到 Rust 再退役。

### 5.3 跨语言 golden test 怎么建

这是 M3（train-serve skew）唯一的结构性解药。三层：

**第 0 层——固定夹具（先做，成本最低）**
在 `axio7-model-review/golden/` 下 check-in 纯文本夹具，两侧共用：
```
golden/analog_kernel/
  states.csv        # N 行 × 12 列，列名与 RS/src/analog_engine/mod.rs:10-40 的 FEATURE_NAMES 完全一致
  outcomes.csv      # terminal_return / mfe / mae / label_available_at
  query.csv         # 若干查询点（含 timestamp、session_date、regime 后验）
  config.json       # k=40, bandwidth_multiplier=0.9, metric=ShrinkageMahalanobis,
                    # covariance_shrinkage=0.20, minimum_regime_similarity=0.90 ...
  expected.json     # expected_return / win_probability / uncertainty，由 Rust 侧生成并 check-in
```
夹具必须**刻意包含病态样本**，让它同时充当 §3 的回归测试：一个 MAD 为 0 的常量特征（M6）、一组距离高度集中的候选（M7）、一段跨越 390 根 bar 周期边界的训练集（M8）。

**第 1 层——Rust 侧生成 + 断言**
新增 `quantctl golden analog --fixture golden/analog_kernel --output expected.json` 子命令；Rust 测试读 `expected.json` 并断言当前实现与之在 1e-12 内一致（防止 Rust 自己漂移）。

**第 2 层——Python 侧消费**
Python 测试**不再自己实现**核回归，而是通过子进程调用 `quantctl golden analog`（或 FFI）取结果，与 `expected.json` 断言 1e-9 内一致。CI 的 `python` job 依赖 `rust` job 的产物。

**为什么这个顺序**：第 0+1 层单靠 Rust 就能落地，不需要等 M3 的架构决定；一旦第 2 层接上，M3 的 (a) 方案（Python 调 Rust）就已经完成了 90%，而 (b) 方案（降级为研究玩具）也有了一个可执行的判据——如果 Python 实现无法通过第 2 层，它就没有资格出现在 `config.models` 里。

**CI 门**：`golden/expected.json` 的任何变更必须伴随一条说明变更原因的 commit message，并在 PR 里单独 review。artifact 数值漂移不应该能悄悄通过。

### 5.4 TypeScript 边界划在哪

`RS/DEPLOY.railway.md:9-12` 已经把 `web`（Next.js 前端 / API gateway）列为独立服务。边界应该划在**证据信封（EvidenceEnvelope）**上，规则如下：

**TS 侧允许做的**：
- 渲染 `RS/src/api.rs` 返回的 `EvidenceEnvelope` / `ModelContract` / `Settlements`（端点见 `api.rs:182`、`:3378-3383`、`:4205`）
- 用户鉴权、会话、路由、限流
- 纯展示层的排序、筛选、分页
- 对 Rust 已经算好的数字做**格式化**（单位、小数位、时区显示）

**TS 侧禁止做的（硬规则）**：
- 任何数值计算：不得在 TS 里算 edge、算 Sharpe、算概率、算仓位、算 z-score
- 任何阈值判断：`ood_score > 1.0`（`RS/src/analog_engine/mod.rs:1381`）、熵门（`RS/src/allocation.rs:456`）、`settled >= 250`（`RS/src/api.rs:935-936`）这类判定必须由 Rust 输出布尔/枚举，TS 只负责显示
- 任何 no-trade 理由的推导：`no_trade_reasons`（`RS/src/predictor.rs:2178-2196`）必须整体由 Rust 给出，TS 不得增删。**特别注意 `predictor.rs:2193` 无条件 push 的 `RESEARCH_ONLY_NO_TRADE`——前端不得以任何形式过滤掉这一条**，否则界面会把研究候选呈现为可交易信号。
- 直接读 SQLite / parquet / artifact JSON：TS 只经由 HTTP 访问 quantd

**执行手段**：在 `RS/src/api.rs` 的响应类型上生成 TS 类型定义（`ts-rs` 或手写 schema + 校验），前端的 lint 规则禁止在渲染层出现算术运算符作用于模型字段。这一条不是洁癖——M3 的教训就是"同一个概念存在两份实现"必然发散，TS 是第三个最容易复制阈值逻辑的地方。

---

## 6. 建议的修复顺序

标注 `‖` 的条目彼此之间可并行；同一编号内部是严格串行。

### 阶段 0：让仓库可被验证（无此阶段，后面全部无意义）
| 顺序 | 项 | 依赖 |
|---|---|---|
| 0.1 | **B2** `.gitignore` 修复（合并 `fix/handoff-buildable`） | 无 |
| 0.2 | **B1** 恢复 `RS/src/data/`、`PY/.../data/`、`PY/.../reports/` 的**真实实现**，删除 stub | 0.1（否则再次被吞） |
| 0.3 | **B6** CI 接入（五个 job） | 0.1 |
| 0.3 ‖ | **B4** CMake target 名（合并已有修复） | 无 |
| 0.3 ‖ | **B5** torch 依赖声明 | 无 |
| 0.4 | **B3** `l1_order_flow.rs:179` 硬化 + 编译期类型锁定 | 0.2（必须在真实模块上验证，不是在 stub 上） |
| 0.5 | **门禁**：`cargo test --locked` 在 clean checkout 上全绿，286 个测试首次真正运行 | 0.2 + 0.3 + 0.4 |

> **0.5 之前不要动 §3 的任何一条。** 所有数值修复都需要能跑的测试来验证，在 crate 编译不过的情况下改 HMM 只是在盲改。

### 阶段 1：数值正确性地基（必须先于任何模型选择工作）
| 顺序 | 项 | 依赖 | 说明 |
|---|---|---|---|
| 1.1 | **M1** `emission` 改 log 空间 + `normalize` 返回 `Err` | 0.5 | 它是 M2 的动力来源、M4/M5 打分不可比的放大器，必须最先修 |
| 1.2 ‖ | **M4** 家族竞争加 Jacobian 项 + 基线移出 `max_by` | 0.5 | 与 1.1 同文件族但不同函数，可并行改、串行合 |
| 1.2 ‖ | **M5** HSMM 发射重复计入 + `log_sum_exp` 全 `-inf` 返回 `-inf` | 0.5 | 同上 |
| 1.3 | **回归门**：M1 要求的两条一致性测试 + M4 的尺度不变性 + M5 的 D=1 归约恒等式，三者同时通过 | 1.1 + 1.2 | 这三条测试互相验证：D=1 的 HSMM、gaussian_hmm、单状态 DiagonalGaussian 必须三方一致 |

### 阶段 2：模型选择（必须在阶段 1 之后，因为它消费阶段 1 的分数）
| 顺序 | 项 | 依赖 |
|---|---|---|
| 2.1 | **M9** restart 初始化改真随机播种（种子为 restart 的纯函数） | 1.3 |
| 2.2 | 在 `GaussianHmm` 上新增并序列化 state occupancy（`em_step` 已有 `state_weight`，只是没保存） | 1.3 |
| 2.3 | **M2** 四份 argmax 拷贝合并为 `select_state_count`，加占用率淘汰 + 1-SE 规则 | 2.1 + 2.2 |
| 2.4 | 扩展候选网格重新跑全部 9 个 artifact，验证**存在内部极优**（当前 9/9 单调递增） | 2.3 |

> 关键提醒：M2 的四处拷贝包括容易被漏掉的 `RS/src/bin/quantctl.rs:811-825`（walk-forward fold 路径）。修复必须一次覆盖四处，否则 fold 路径会保留旧行为并产生自相矛盾的报告。

### 阶段 3：analog kernel 与训练-服务一致性（可与阶段 1/2 并行，不同子系统）
| 顺序 | 项 | 依赖 |
|---|---|---|
| 3.1 ‖ | **M6** MAD 相对下限 + 收缩改向相关结构（fail-closed） | 0.5 |
| 3.2 ‖ | **M8** OOD 标定走同一条过滤链 + 确定性洗牌替代 `step_by` | 0.5 |
| 3.3 ‖ | **M7** 相对行列式判据 + 杠杆上限（或直接删字段） | 0.5 |
| 3.4 | §5.3 第 0+1 层 golden 夹具（含 M6/M7/M8 的病态样本） | 3.1 + 3.2 + 3.3 |
| 3.5 | **M3** 决策：(a) Python 调 Rust ‖ (b) 从 `config.models` 移除 + 修正 `MODEL_SOURCE_MAP.zh-CN.md:13` 与 `01-model-algorithm-inventory.md:73-133` | 3.4 |
| 3.6 | **M12** Python 标签成熟守卫（若选 (a) 则本条自动消失；若选 (b) 则至少删掉 `analog_kernel.py:27` 那句错误注释并加测试） | 3.5 |

### 阶段 4：部署（与阶段 1~3 完全并行，不同人可同时推进）
| 顺序 | 项 | 依赖 |
|---|---|---|
| 4.1 ‖ | **D4** 修正 `DEPLOY.railway.md:58-59` 的过期描述 | 无（纯文档，五分钟） |
| 4.2 ‖ | **D5** Dockerfile 创建 `models/` + artifact 分发路径写进文档 + 缺失时 fail-closed | 无 |
| 4.3 | **D1** 挂 Volume 到 `/app/data`（短期）→ 落 PostgreSQL（正解） | 4.2 |
| 4.4 | **D2** `massive-check` 拆成 `equity-check` / `options-check` | **0.2**（需要真实的 `readiness.rs`） |
| 4.5 | **D3** ledger 幂等键，之后才谈放开 `numReplicas` | 4.3 |

### 阶段 5：防御性纵深（无阻塞，随时可做）
| 顺序 | 项 | 依赖 |
|---|---|---|
| 5.1 ‖ | **M11** EM 单调性硬守卫（`regime.rs` + `gmm.rs:165-169` 两处） | 1.3（修 M1 之后单调性才应当真正成立） |
| 5.2 ‖ | **M10** fit 循环后重算似然再算 BIC（对齐 `gmm.rs:157-170`） | 0.5 |
| 5.3 | §5.2 C++ 退役（先让 CI 的 `cpp` job 通过一次留档，再移到 `reference-docs/legacy-cpp/`） | 0.3 |
| 5.4 | §5.4 TS 边界规则写进 `PROJECT_CONTRACT.md` + 生成 TS 类型定义 | 无 |

### 关键路径
`0.1 → 0.2 → 0.5 → 1.1 → 1.3 → 2.2 → 2.3 → 2.4`。阶段 3 和阶段 4 只在 `0.5`（阶段 3）和 `0.2`（4.4 一项）上与主链交汇，其余全部可并行。若只有一个人，按 `阶段 0 → 阶段 1 → 阶段 2 → 阶段 3 → 阶段 4 → 阶段 5` 串行；若有三个人，建议分工为「阶段 0+1+2（数值）」「阶段 3（analog + golden）」「阶段 4+5.3+5.4（部署 + 架构收敛）」。