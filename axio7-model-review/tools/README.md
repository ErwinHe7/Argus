# AXIO7 外挂 GUI（Grafana）

给 `quantd` 的 63 个 REST 端点套一个开源 GUI。整套配置从文件 provision，
不需要在界面上点任何东西。

## 为什么是 Grafana + Infinity，而不是 Appsmith / ToolJet

决定性约束是 **CORS**：`quant_engine_rs/src/api.rs` 从未挂过 `CorsLayer`
（`tower-http` 的 `cors` feature 在 `Cargo.toml:42` 开着但全仓库没有使用）。
任何在浏览器里直接发请求的 GUI 都会被同源策略拦掉。

Infinity 数据源是**服务端拉取** —— 请求从 Grafana 后端发出，不经过浏览器，
因此不受 CORS 约束。Appsmith 和 ToolJet 的服务端代理同样能绕开，
但它们的应用定义只能在各自的可视化编辑器里搭，没法像这里一样交付一份
可复现的配置文件。

次要原因：`config.rs:659-663` 强制 loopback，所以 GUI 必须和 `quantd`
跑在同一台机器/同一个网络命名空间里。Grafana 单进程、免 Docker、
Windows 有独立发行版，是这个约束下最轻的选择。

## 目录

```
tools/
├── fixture-api/server.py          假后端。不是 quantd。
└── grafana/
    ├── provisioning/
    │   ├── datasources/axio7.yaml Infinity 数据源 + x-research-token 头
    │   └── dashboards/axio7.yaml  仪表板 provider
    └── dashboards/
        └── axio7-control-plane.json
```

## fixture-api 是什么，不是什么

**不是 quantd。** 真实的 `quantd` 现在跑不起来：`src/data/` 整个数据接入层
没有进入交付快照（见 `review-package/REMEDIATION-PLAN.zh-CN.md` 的 B1）。

`server.py` 的作用是给 GUI 一个形状正确的后端，让面板能先搭好、交互能先验证，
等真实数据层恢复后把 Grafana 数据源的 URL 指向真 `quantd` 即可，仪表板不用改。

它的响应里每个对象都带 `_source` 字段：

- `"artifact"` —— 从仓库里真实的 `model-artifacts/axio7-candidate-artifacts-2026-07-26.zip`
  读出来的，未经修改。universe registry、9 个 symbol、promotion_status、
  training_cutoff、model_hash 都是真的。
- `"synthetic"` —— 为了让面板有东西可画而生成的。regime 后验、预测台账、
  实时状态全部属于这一类。

**任何 `synthetic` 字段都不得被当作系统行为的证据。**

## 跑起来

```bash
python axio7-model-review/tools/fixture-api/server.py --port 8001 --token <32+字符>
```

```bash
GF_PATHS_PROVISIONING=<repo>/axio7-model-review/tools/grafana/provisioning \
AXIO7_DASHBOARDS_PATH=<repo>/axio7-model-review/tools/grafana/dashboards \
GF_AUTH_ANONYMOUS_ENABLED=true GF_AUTH_ANONYMOUS_ORG_ROLE=Admin \
grafana-server --homepath <grafana安装目录>
```

然后 http://127.0.0.1:3000/d/axio7-control-plane

需要两个插件：

```bash
grafana-cli plugins install yesoreyeram-infinity-datasource
grafana-cli plugins install volkovlabs-form-panel
```

## 仪表板设计

主视图是 **fail-closed 闸门链**，不是收益曲线。这套系统的核心信息是
「现在你被允许相信什么」，而不是「赚了多少」——
`predictor.rs:2193` 对每个 forecast 无条件写入 `RESEARCH_ONLY_NO_TRADE`，
9/9 个模型 `CANDIDATE_NOT_PROMOTED`，校准 `UNAVAILABLE_FAIL_CLOSED`。
把这些放在最显眼的位置，才不会让人误读成一个可交易系统。

闸门按执行顺序排列，第一个 `BLOCKED` 之后的闸门标 `UNREACHABLE` ——
不是「通过」，是「上游已经拦住、根本没跑到」。

## 已验证 / 未完成

**已验证**（端到端，Grafana → Infinity → fixture）：

- 闸门链 6 行，状态色映射正确
- Universe 表 9 行，全部 K=8 / CANDIDATE_NOT_PROMOTED / UNAVAILABLE_FAIL_CLOSED
- 「已晋升模型」正确显示 0
- 预测台账 27 行，PENDING / SETTLED 色分
- Symbol 模板变量筛选实时生效（9 行 → 3 行）
- 30 秒自动刷新

**未完成**：四个 POST 按钮（KILL / RESUME / PAPER START / PAPER STOP）
面板能渲染，但**提交不生效**。`volkovlabs-form-panel` 的 `elements`
配置项 schema 与本仓库里手写的不一致，该插件设计上是在 Grafana 的面板
编辑器里配置的。

两条出路：

1. 在 Grafana 里打开这四个面板的编辑器，手动配一个表单元素和 request，
   然后 **Save dashboard → 导出 JSON 覆盖回本目录**，这样配置仍然是可复现的；
2. 操作面单独交给 Appsmith（Apache 2.0），Grafana 只做只读监控。

POST 端点本身是通的，已直接验证：

```bash
curl -X POST -H "x-research-token: <token>" http://127.0.0.1:8001/api/v1/risk/kill
# {"outcome": "KILL_SWITCH_ENGAGED", ...}  且 /live/status 的 kill_switch 变为 true
```

## 指向真 quantd 时要改什么

1. `provisioning/datasources/axio7.yaml` 的 `url` 改成 quantd 地址
2. `secureJsonData.httpHeaderValue1` 换成真实 `INTRADAY_QUANT_TOKEN`，
   并改用 `$__env{}` 或 Grafana secret，**不要 check-in 明文**
   （当前文件里是 fixture 用的假 token，无安全价值）
3. 检查各面板的 `root_selector` 与 `columns` 是否与真实响应结构一致 ——
   fixture 是按 `api.rs` 的调用点反推的，不保证逐字段吻合
