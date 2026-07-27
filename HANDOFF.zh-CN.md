# 交接文档

接手这个仓库前先读完本文件。

**最后更新**：2026-07-26
**对应分支**：`fix/handoff-buildable`（10 个提交，基于 `agent/axio7-model-review` tip `8d18b73`）

---

## 0. 一句话现状

`main` 上的交接包**编译不过、测试跑不了**。根因是 `.gitignore` 的目录名规则吞掉了三个源码包。`fix/handoff-buildable` 修好了构建，但被吞掉的**真实代码仍然只有仓库所有者手上有** —— 分支上补的是全部 `unimplemented!()` 的诊断 stub。

在动任何模型代码之前，先做第 3 节的两件事。

---

## 1. ⚠️ 最重要的一条：仓库里现在有假代码

`fix/handoff-buildable` 往这三个位置写入了 **stub**，它们能编译、能通过类型检查，但**任何调用都会 panic 或 raise**：

| 路径 | 语言 | 状态 |
|---|---|---|
| `axio7-model-review/source/quant_engine_rs/src/data/` | Rust | 10 个子模块全部 `unimplemented!()` |
| `axio7-model-review/source/intraday_quant/src/intraday_quant/data/` | Python | 全部 `NotImplementedError` |
| `axio7-model-review/source/intraday_quant/src/intraday_quant/reports/` | Python | 全部 `NotImplementedError` |

每个文件顶部都有 `STUB` 标记和说明。

**恢复原始实现时，必须先整目录删除 stub，再放入真实代码。**不要逐文件覆盖 —— stub 里有一些原模块可能没有的类型名（见第 4 节），残留下来会造成难查的重复定义或语义漂移。

```bash
rm -rf axio7-model-review/source/quant_engine_rs/src/data
rm -rf axio7-model-review/source/intraday_quant/src/intraday_quant/data
rm -rf axio7-model-review/source/intraday_quant/src/intraday_quant/reports
# 然后放入真实实现
```

---

## 2. 已经修好的（10 个提交）

| 提交 | 内容 | 验证方式 |
|---|---|---|
| `4778a9e` | `.gitignore` 根因修复 + 守卫脚本 + CI | `scripts/check-no-ignored-sources.sh` 双向验证：恢复旧规则准确抓出 9 个源码文件，新规则下无误报 |
| `6ea987c` | C++ `SQLite3::SQLite3` → `SQLite::SQLite3` | GCC 13 `-Werror -Wconversion -Wshadow` 零警告，11/11 测试通过 |
| `a92259e` | torch 声明为 optional extra `neural` | — |
| `d2721ca` | 子进程监督 + 删掉必然失败的 `COPY data` + `railway.json` + 部署文档 | — |
| `fe98dea` | Python 诊断 stub（2 包 7 文件） | 23 passed / 5 skipped / 3 failed（3 个失败全部是 stub） |
| `92fa1a3` | Rust 诊断 stub（10 子模块 620 行） | 见下 |
| `3df6111` | 标注 `OPTION_CHAIN_SCHEMA_VERSION` 不可恢复 | — |
| `b3eb5eb` | **修正**：入口脚本 host 默认值改回 loopback | 见第 6 节 |
| `e231369` | 多智能体审查的完整修复方案 | — |
| `77aace6` | Grafana GUI（配置全部 file-provisioned） | 端到端验证，见 `axio7-model-review/tools/README.md` |

### 修复后的实测（Rust 1.97.1 x86_64-pc-windows-gnu）

```
cargo fmt --check                          通过
cargo clippy --all-targets -- -D warnings  零警告
cargo test --lib                           256 passed / 0 failed
cargo test --bin quantctl                    8 passed / 0 failed
cargo test --test core                      11 passed / 1 failed
```

Python：`23 passed / 5 skipped / 3 failed`
C++：`11 / 11 passed`

**所有失败项都只是撞到 stub，没有一个是真实代码缺陷。**

- Rust 唯一失败 `csv_requires_offset_deduplicates_and_rejects_bad_rows` panic 于 `MarketBarCsvImporter::import`
- Python 3 个失败是 `clean_bars` / `ingest` / `theory_performance_audit`
- Python 5 个 skip 全部来自 `test_cuda_challenger.py` 找不到 torch

对照 README 声称的 `286 lib / 8 CLI / 12 integration`：**CLI 的 8 和集成的 12 完全吻合**，lib 少 30 个 —— 那 30 个单元测试写在被删掉的 `src/data/` 里，随目录一起丢失。

---

## 3. 接手后要做的前两件事

### 3.1 补回三个源码包

只有仓库所有者的完整工作树上有。补回后：

```bash
bash scripts/check-no-ignored-sources.sh   # 确认新代码不会再被 gitignore 吞掉
cd axio7-model-review/source/quant_engine_rs && cargo test
cd ../intraday_quant && python -m pytest --basetemp .pytest-tmp -p no:cacheprovider
```

Rust lib 测试数应该从 256 回到 286。若不是，说明还有东西没补齐。

### 3.2 让 CI 跑起来

`.github/workflows/ci.yml` 已经写好但从未在真实 CI 上运行过。它从 clean checkout 构建三套源码并构建 Docker 镜像 —— 这是唯一能从结构上杜绝"本地能过、仓库里过不了"的手段。

---

## 4. Stub 的签名来源（补代码时的对照表）

分两类，每个类型上方的注释里都写了：

**精确还原**（有完整结构体字面量为证，字段集不会错）：

| 类型 | 来源 |
|---|---|
| `RealtimeStockTapeEvent`（26 字段） | `src/engine/l1_order_flow.rs:283-310` 测试里的完整字面量 |
| `DataCapabilityReport`（22 字段） | `src/predictor.rs:2890-2912` 测试里的完整字面量 |
| `MaterializeRequest`（13 字段） | `src/bin/quantctl.rs:1681-1694` 完整字面量 |
| `FileImportReport` | `tests/core.rs:160-163` 的断言 |

**从调用点反推**（原类型很可能更宽，类型名多半是猜的）：其余全部。特别是这些名字纯属编造，原模块几乎肯定叫别的：`CapabilityAudit`、`DataDoctorReport`、`ArtifactEntry`、`FusionSnapshot`、`ContextAuditReport`、`CostEstimate`、`DownloadReceipt`、`MaterializeReceipt`、`StoreCoverage`、`MassiveStatus`、`MassiveSyncReceipt`、`FiveDaySamplePlan`、`OptionChainCoverage`、`RealtimeEntitlementReport`。

### 已知的地雷

**`OPTION_CHAIN_SCHEMA_VERSION` 的字符串值不可恢复。**它只被比较、从不打印，包里也没随附样本 artifact。原值恢复前，任何真实 chain artifact 都会在 `api.rs:1489`、`market_query.rs:1070`、`quantctl.rs:586` 三处 schema 门控上被拒，报 `OPTION_CHAIN_SCHEMA_INCOMPATIBLE`。属 fail-closed 不会出错误结果，但极容易被误判成数据问题。

**原 `reports/` 包比引用面更大。**`service.py:147` 读取 `reports/hypothesis_event_audit.csv`，但仓库里没有任何模块生产它。stub 只重建了被 import 到的那部分。

**`registry.json` 里 `artifact_path` 用 Windows 反斜杠**（`data/models/universe\SPX.frozen.json`），Linux 容器里会找不到文件。

**artifact zip 用反斜杠做路径分隔符**，违反 ZIP 规范 APPNOTE 4.4.17.1。Linux/macOS 上 `unzip` 会解出字面带反斜杠的文件名而不是目录树，`SHA256SUMS.txt` 里的正斜杠路径对不上。

---

## 5. 不要重复走的弯路

**`l1_order_flow.rs:179` 的 `TimeDelta` 类型错误是级联，不是独立 bug。**

`cutoff - latest.event_at <= max_age` 报 `expected DateTime, found TimeDelta`。成因是 `RealtimeStockTapeEvent` 无法解析 → `Quote<'a>` 结构体被污染 → 字段访问退化成 error type → 编译器在 `DateTime` 的两个 `Sub` impl 之间选错。补上 stub 后该错误自动消失，**那一行代码本身是正确的**。

两条独立路径（探针实验 + 独立契约推断）都复现了这一结论。在 `data` 恢复之前"修"这一行会引入真正的 bug。

---

## 6. 部署：一条被误判过的结论

**这个服务在 TLS/mTLS 落地之前，设计上就不可对外暴露。**

`config.rs:659-663`：

```rust
if !server_ip.is_loopback() {
    bail!("quant control plane must remain loopback-only until TLS/mTLS is implemented");
}
```

`quantd.rs:32-38` 在 `--host` 覆盖之后立刻 `validate()`。所以传 `0.0.0.0` 的结果不是"监听不到"，而是**进程起不来**。

本分支曾一度把入口脚本默认值改成 `0.0.0.0`（提交 `d2721ca`），那是**错的**，已在 `b3eb5eb` 修正。这是刻意的安全门禁：控制面带 kill switch 和 paper trading 控制，鉴权只有一个静态 header token。

而 Railway 边缘路由要求容器监听非 loopback —— **两者直接冲突**。三个选项及取舍见 `axio7-model-review/source/quant_engine_rs/DEPLOY.railway.md`，其中"容器内反代"会静默绕过一道刻意的安全控制，需要所有者明确拍板，不应默认采用。

其余部署阻塞项（同一文档）：文件系统临时导致 ledger 每次 redeploy 全丢；`massive-check` 一个门控同时覆盖 equity 与 options 权限；`numReplicas` 只能是 1（正确性约束，ledger 没有幂等键）；`massive-model` 的两个默认路径都在 `data/` 下、镜像里没有，配合子进程监督会造成崩溃循环。

---

## 7. 模型侧待处理

完整报告：`axio7-model-review/review-package/REMEDIATION-PLAN.zh-CN.md`

**覆盖范围声明**：多智能体审查共产出 **109 条 finding**，其中 **48 条经过对抗性核实**（38 条通过、10 条被证伪），**其余 61 条未经核实** —— 工作流里每路核实上限设为 8 条。报告只写入核实通过的条目。未核实的 61 条不代表不存在，只代表没验过。

三个互相独立的 P0：

**M1 — HMM 发射概率在线性空间计算并硬钳到 `1e-300`**（`engine/regime.rs:214-223`）
单时刻对数似然被囚禁在 `[-690.776, +14.746]`，下界有限而上界为正。同仓库内有正确的 log 空间对照实现（`regime_competition.rs:223-245`、`tvtp_regime.rs:399-406`）。

**M2 — 状态数是留出对数似然的裸 argmax，无复杂度惩罚无占用率约束**（同一条规则**四份拷贝**：`regime_competition.rs:399-424`、`predictor.rs:820-846`、`quantctl.rs:3121-3143`、`quantctl.rs:773`）
这是 9/9 artifact 全部落在 K=8 的机械成因。**修复前必须先把四份拷贝合并成一个函数**，否则必然漏掉一处（尤其 `quantctl.rs:773` 那份在 walk-forward fold 路径上）。

两个常见误诊要纠正：`1e-12` 容差不是成因（实际差距高十个数量级）；改用 BIC 也救不了（3 万样本下惩罚项被淹没）。解药是占用率下限 + 扩展候选网格。

**M3 — Rust 与 Python 的 analog kernel 是两个不同的估计量**
在标准化、度量、特征集、带宽、权重、邻居筛选、k 值、`median_return` 加权八个维度上全不相同。**这份交接包里唯一的定量回测证据，度量的不是会上线的那个模型。**

### 边界说明

`predictor.rs:2193` 对每个 forecast **无条件** push `RESEARCH_ONLY_NO_TRADE`，`:2185` 另有 OOS 校准门控。上述缺陷**当前不会驱动任何真实订单**，它们损害的是"该不该 promote"这个判断本身的可信度。

---

## 8. 架构收敛

三套源码定死成**单向流水线**并写进 `PROJECT_CONTRACT.md`：

```
Python 研究/训练 ──► 冻结 artifact ──► Rust 生产推理/实时 ──► 证据信封 ──► TypeScript 展示
```

- Python 不得包含任何会被当作"生产模型证据"的推理实现
- Rust 不得包含训练循环之外的研究报表逻辑（`regime_competition.rs` 应挪到 `research` feature gate 下）
- artifact 是唯一的跨语言接口
- **C++ 退役但不删**：先让 CI 的 cpp job 跑通一次留档，再整棵树移到 `reference-docs/legacy-cpp/` 标注"不参与构建"
- **跨语言 golden test 是 M3 唯一的结构性解药**，三层落地方案见修复方案第 5.3 节
- **TS 边界划在证据信封上**：禁止任何数值计算、阈值判断、no-trade 理由推导。特别是 `RESEARCH_ONLY_NO_TRADE` 前端不得以任何形式过滤掉

---

## 9. 环境

复现本分支验证结果需要：

| 工具 | 版本 | 备注 |
|---|---|---|
| Rust | 1.97.1 | 本次用的是 `x86_64-pc-windows-gnu`；Windows 上没有 MSVC 时用 GNU toolchain |
| Python | 3.13.7 | `pyproject.toml` 要求 `>=3.11` |
| CMake | 3.29 | Windows 上可用 Strawberry Perl 自带的 |
| C 编译器 | GCC 13.2 | `rusqlite` 的 `bundled` feature 和 `ring` 都需要 |
| SQLite3 dev | 3.53.4 | Windows 上可从 sqlite.org 下 amalgamation 自行编一个静态库 |
| OpenSSL | 3.3.0 | Strawberry Perl 自带 |

Windows 上跑 `ctest` 会报 `0xc0000139`（`STATUS_ENTRYPOINT_NOT_FOUND`）—— 那是 MinGW 运行时 DLL 不在 PATH 上，不是代码问题。把 `C:\Strawberry\c\bin` 加进 PATH 后直接运行测试二进制即可。

---

## 10. GUI

`axio7-model-review/tools/` 下有一套 Grafana 配置，全部 file-provisioned。

选型的决定性约束是 **CORS**：`api.rs` 从未挂过 `CorsLayer`（`tower-http` 的 cors feature 在 `Cargo.toml:42` 开着但全仓库没有使用），任何在浏览器里直接发请求的 GUI 都会被同源策略拦掉。Infinity 数据源是服务端拉取，不经过浏览器。

`tools/fixture-api/server.py` **不是 quantd** —— 真实 quantd 因 `src/data/` 缺失跑不起来。fixture 从仓库真实 artifact zip 读 universe registry，响应中每个对象带 `_source` 字段区分 `artifact` 与 `synthetic`。**任何 `synthetic` 字段都不得被当作系统行为的证据。**

已验证与未完成的清单见 `axio7-model-review/tools/README.md`。简言之：8 个只读面板全部端到端验证通过；4 个 POST 按钮能渲染但提交不生效（`volkovlabs-form-panel` 的 `elements` schema 与手写配置不一致），POST 端点本身已直接验证可用。
