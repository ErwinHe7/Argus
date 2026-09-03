# AXIO7 日内量化研究终端：使用说明

## 它是什么

这是一个本地优先的 Web 研究软件，不是需要手工输入命令才能看结果的纯终端。

- 浏览器前端：Next.js，负责数据状态、当前历史相似形态、时间桶效应、回测指标、交易和拒绝记录。
- 后端与模型：Rust/Axum，负责数据校验、点时特征、历史相似搜索、统计模型、回测和 SQLite 运行注册表。
- 原始数据库：Massive JSON 分块永久保存；标准化一分钟主表为 CSV；运行元数据进入 SQLite。
- 当前执行层：SPY underlying 回测。没有真实 SPXW NBBO 时不生成期权可成交收益。

## 一键打开

在项目根目录运行：

```powershell
npm run quant:open
```

浏览器地址：<http://127.0.0.1:3000/quant/intraday>

后端健康检查：<http://127.0.0.1:8001/health>

关闭：

```powershell
npm run quant:stop
```

## 首次两年数据同步

`MASSIVE_API_KEY` 放在项目根目录 `.env.local` 后运行：

```powershell
cd quant_engine_rs
.\target\release\quantctl.exe data massive-sync `
  --from 2024-07-18 --to 2026-07-18 `
  --symbols SPY,QQQ,IWM,TLT,HYG,UUP,GLD `
  --output data/normalized/market_bars.csv
```

免费层五次请求/分钟，完整同步约需一小时。原始分块存在时会自动复用，可中断后重跑。

同步完成后在网页选择 `Massive real stock aggregates`，点击 `Run experiment`。

## 日常使用

开盘前或收盘后增量更新：

```powershell
cd quant_engine_rs
.\target\release\quantctl.exe data massive-poll --lookback-days 3
```

然后打开网页并点击 `Run experiment`。页面重点：

1. `真实数据接入`：Key、标准化主表、manifest 状态。
2. `当前状态历史形态提示`：最新可用一分钟状态在 5/15/30/60 分钟预测窗下的方向概率和 NO TRADE。
3. `第 N 个 5 分钟 K 线反转审计`：训练/验证/测试分离后的时段规律。
4. `当前状态最相似的历史分钟`：与当前 30 分钟代表状态同一 5 分钟时段的过去案例、随后收益、MFE/MAE 和距离。
5. `OOS trade blotter`：下一分钟成交、成本和退出原因。

## 前后端位置

- 前端页面：`app/quant/intraday/page.tsx`
- 前端控制台：`components/quant/IntradayResearchConsole.tsx`
- Next 到 Rust 网关：`app/api/quant/intraday/[...path]/route.ts`
- Rust API：`quant_engine_rs/src/api.rs`
- Massive 数据端：`quant_engine_rs/src/data/massive.rs`
- 特征：`quant_engine_rs/src/engine/features.rs`
- 时间桶统计：`quant_engine_rs/src/engine/effects.rs`
- 相似历史：`quant_engine_rs/src/engine/analog.rs`
- 模型：`quant_engine_rs/src/engine/models.rs`
- 回测：`quant_engine_rs/src/engine/backtest.rs`

当前研究对象是SPY作为SPX可交易代理。QQQ/IWM/HYG与TLT/UUP只用于大盘风险确认和轮动状态；半导体股票不再是默认研究范围。所有对齐均以当时已经存在的时间戳为准，缺失数据不会用0伪装。

## 当前真实数据基线（不是盈利声明）

截至 2026-07-17 的第一轮 Massive 核心数据验证覆盖 501 个交易日、1,521,361 条 SPY/QQQ/SOXX/IWM 分钟记录。未经测试集回看调参的 OOS 基线产生 28 笔交易，净收益 -3.34%、胜率 14.29%、Profit Factor 0.22、最大回撤 -3.55%。这个结果说明当前假设没有通过，不代表真实盈利能力；软件保留负结果，目的是继续科学筛选，而不是包装曲线。

机器可读报告：`quant_engine_rs/data/reports/massive_core_latest.json`。网页是同一 Rust 运行注册表的可视化界面。

## 部署位置

第一阶段部署在本机，原因是免费个人数据授权、API Key 和数 GB 原始数据不适合直接放进 Vercel Serverless。

生产部署建议：

- Next.js 前端：现有 Vercel 项目，或与后端一起部署。
- Rust 服务、定时同步和持久化数据：AWS EC2/Lightsail 单机加加密磁盘。
- `INTRADAY_QUANT_API_URL` 指向 Rust 私有服务地址。
- 对外部署前必须确认 Massive 数据授权是否允许服务器端展示；不得公开重新分发原始行情。

当前本机部署已经可以完整使用；云部署需要目标云账户、域名和密钥管理权限后再执行。
