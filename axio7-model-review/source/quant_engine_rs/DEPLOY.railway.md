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
| `AXIO_QUANT_HOST` | **不要设成非 loopback 地址**，见下节。默认 `127.0.0.1` |
| `AXIO_QUANT_CONFIG` | 默认 `configs/production.yaml` |
| `RUST_LOG` | 默认 `axio_quant_engine=info,tower_http=info` |

## 最重要的一条：这个服务目前在设计上不可对外暴露

`src/config.rs:659-663`：

```rust
let server_ip = IpAddr::from_str(&self.server.host)?;
if !server_ip.is_loopback() {
    bail!("quant control plane must remain loopback-only until TLS/mTLS is implemented");
}
```

`src/bin/quantd.rs:32-38` 里 `--host` 覆盖配置后立刻 `validate()`，所以传任何
非 loopback 地址的结果不是「监听不到」，而是 **quantd 每次启动直接退出**。
`configs/production.yaml` 里两处 `host` 也都是 `127.0.0.1`。

这是**刻意设的安全门禁**，不是疏忽 —— 控制面有 kill switch（`POST /api/v1/risk/kill`）
和 paper trading 控制，鉴权只有一个静态 header token（`x-research-token`，
`src/api.rs:91`），在没有 TLS/mTLS 之前不允许离开 loopback 是合理的。

而 Railway 的边缘路由需要容器监听非 loopback 地址才能转发流量。
**两者直接冲突。**三个选项：

| 选项 | 做法 | 代价 |
|---|---|---|
| A. 不暴露 | 只作为同容器内部服务，GUI/前端也跑在同一个容器里访问 127.0.0.1 | 最安全；但 Railway 上等于没有对外服务 |
| B. 实现 TLS/mTLS | 落地 mTLS 后有意识地放宽 `validate()` 的门禁 | 正解，但是真实工作量 |
| C. 容器内反代 | 加一个 nginx/socat 绑 `0.0.0.0:$PORT` 转发到 `127.0.0.1:8001` | **会静默绕过一道刻意的安全控制**。Railway 边缘到容器这一跳没有 TLS。需要所有者明确拍板，不要默认这么干 |

在做出选择之前，不要把这个服务标成「可部署」。

## 另一个会导致崩溃循环的问题

`quantctl massive-model` 的两个默认路径都在被 gitignore 的 `data/` 下
（`src/bin/quantctl.rs:139-141`）：

- `--historical-bars data/normalized/market_bars.csv`
- `--universe-registry data/models/universe/registry.json`

镜像里没有这两个文件。配合本文件配套的子进程监督改动，结果是：
massive-model 启动失败 → PID 1 以 72 退出 → Railway 重启 → 再次失败，
直到撞上 `restartPolicyMaxRetries: 10` 后彻底停止。

监督逻辑本身是对的（把静默故障变成响亮故障），但**必须先解决这两个文件的
供给问题**：要么挂 Volume 并在首次部署时灌入，要么改成从对象存储拉取，
要么把 registry 放进一个被显式跟踪的路径随镜像分发。
在此之前不要开 live 子进程。

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
