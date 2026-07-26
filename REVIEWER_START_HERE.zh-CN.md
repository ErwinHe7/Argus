# 审查者从这里开始

这不是一个只含 Markdown 的说明包。模型实现、测试和当前未晋升的冻结
artifact 都在本仓库的 `agent/axio7-model-review` 分支中，可以直接修改代码并
向草稿 PR #1 推送提交。

## 最短阅读顺序

1. `MODEL_SOURCE_MAP.zh-CN.md`：每个模型对应的准确源码文件、用途和状态。
2. `axio7-model-review/review-package/03-review-brief-and-checklist.md`：
   P0/P1/P2 审查和修复任务。
3. `axio7-model-review/review-package/04-evidence-index.md`：关键实现位置。
4. `axio7-model-review/source/`：Rust、Python、C++ 可编辑源码和测试。
5. `axio7-model-review/model-artifacts/axio7-candidate-artifacts-2026-07-26.zip`：
   9 个未晋升候选 artifact 及 legacy 对照；解压后查看。

## 哪些内容可以直接改

- 生产推理、实时验证、HMM、Baum–Welch、kernel、SDE/OU：
  `axio7-model-review/source/quant_engine_rs/`
- 离线训练、walk-forward、传统模型、TCN/MoE、校准：
  `axio7-model-review/source/intraday_quant/`
- Native research/HMM/Logistic/OMS 对照：
  `axio7-model-review/source/quant_core_cpp/`

冻结 artifact 是生成结果，不应手工修改参数或 SHA。算法修复后应重新训练、
验证、导出新 artifact，并在独立校准和 promotion 通过前保持
`CANDIDATE_NOT_PROMOTED`。

## 本地开始

```powershell
git clone https://github.com/ErwinHe7/Argus.git
Set-Location Argus
git switch agent/axio7-model-review
```

Rust：

```powershell
Push-Location axio7-model-review/source/quant_engine_rs
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
Pop-Location
```

Python：

```powershell
Push-Location axio7-model-review/source/intraday_quant
python -m pytest --basetemp .pytest-tmp -p no:cacheprovider
Pop-Location
```

C++（需要 CMake）：

```powershell
cmake -S axio7-model-review/source/quant_core_cpp -B axio7-model-review/source/quant_core_cpp/build
cmake --build axio7-model-review/source/quant_core_cpp/build
ctest --test-dir axio7-model-review/source/quant_core_cpp/build --output-on-failure
```

## 数据边界

仓库没有上传历史/实时市场观测、数据库、Parquet、JSONL、API key 或 `.env`。
artifact 压缩包包含模型参数、训练 lineage hash 和 analog 训练索引，不包含
历史行情行。需要做数据级复现时，应通过有权限的 point-in-time 数据源接入同一
份 normalized record、Rust feature engine 和 frozen inference path。

