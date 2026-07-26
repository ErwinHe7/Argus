# 在 Railway 上部署 quantd

`railway.json` 不支持注释，配置为什么这么写记在这里。

## 服务拓扑

| Railway 服务 | 内容 | 来源 |
|---|---|---|
| `quantd` | Rust 生产推理 API + 实时子进程 | 本目录 Dockerfile |
| `web` | Next.js 前端 / API gateway | 另一个仓库或目录 |
| Postgres | normalized record + prediction ledger | Railway plugin |
| Redis | 可选，编排缓存 | Railway plugin |

Python (`intraday_quant`) **不是 Railway 服务**。它是离线训练与 artifact 导出，
应该跑在 CI job 或研究机上，产出冻结 artifact 后再交给 quantd 加载。
把训练进程常驻部署既没有意义，也会让 Railway 的内存账单毫无必要地翻倍。

设置服务时，Root Directory 必须指到 `axio7-model-review/source/quant_engine_rs`。
仓库里有三种语言，Nixpacks 的自动探测会误判，务必显式用 Dockerfile builder。

## 每一项配置的理由

**`healthcheckPath: /health`** —— Dockerfile 里的 `HEALTHCHECK` 指令 Railway 完全不读，
它只用自己的 HTTP 健康检查。不在这里声明的话，容器起没起来平台无从判断。

**`healthcheckTimeout: 120`** —— 入口脚本要先等 `quantd` 自检通过（最多 60 次 1 秒轮询），
再跑 `massive-check`，然后才拉起两个实时子进程。默认超时会在冷启动时误杀。

**`numReplicas: 1`** —— 这条是正确性要求，不是省钱。
`quantd` 会订阅实时行情并写 pending prediction ledger。
两个副本会重复订阅同一路 feed、重复写 ledger、重复结算同一批到期预测，
在 ledger 加上 per-prediction 幂等键之前，扩副本会直接污染预测记录。

**`restartPolicyType: ON_FAILURE`** —— 配合已修复的 `container-entrypoint.sh`：
任一实时子进程退出，PID 1 会以非零码退出（71/72/73），平台据此重启整个容器。
修复前入口脚本只 `wait` API 进程，子进程崩溃是完全静默的。

## 必须设置的环境变量

| 变量 | 说明 |
|---|---|
| `INTRADAY_QUANT_TOKEN` | 入口脚本强制要求，至少 32 字符，少于 32 直接 exit 64 |
| `PORT` | Railway 自动注入，不要手动设 |
| `AXIO_QUANT_HOST` | 不要设。默认已改为 `0.0.0.0`；设成 `127.0.0.1` 会让服务从外部不可达 |
| `AXIO_QUANT_CONFIG` | 默认 `configs/production.yaml` |
| `RUST_LOG` | 默认 `axio_quant_engine=info,tower_http=info` |

## 仍然阻塞生产部署的问题

1. **文件系统是临时的。** `/app/data/live`、`/app/data/state` 写的 JSONL spool 和
   pending ledger 每次 redeploy 全部丢失。要么挂 Railway Volume 到 `/app/data`，
   要么先把「normalized record 持续写 PostgreSQL」这条技术债还掉 —— 后者是正解，
   crate 目前连 postgres driver 都没有。在此之前不要把它当成可靠的生产服务。

2. **equity / options readiness 仍然耦合。** `massive-check` 一个命令同时覆盖两种权限，
   options 权限缺失会连 equity 模型一起不启动。需要拆成两个独立门控。

3. **pending prediction 不会自动结算。** 到期的预测需要一个 causal settlement 循环，
   目前写入后没有在同一个 live loop 里结算。重启后 pending ledger 能否恢复也未验证。

在 1 和 3 解决之前，这个服务只适合作为**研究用只读 API** 部署，
不要用它承载任何有状态的实时预测记录。
