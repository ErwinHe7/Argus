# IBKR 小盘股动量扫描

`scan.py` 只通过本机 IBKR Client Portal Gateway 扫描美股小盘股，只读，不会下单，也不调用任何交易接口。

## 运行

先启动 IBKR Client Portal Gateway，在浏览器里登录 `https://localhost:5000`。然后在 `platform/` 目录下运行：

```powershell
# 扫描一次
python features/momentum-monitor/ibkr-scanner/scan.py --allow-insecure-loopback-gateway

# 每 60 秒扫描一次，并把完整结果写入 JSON
python features/momentum-monitor/ibkr-scanner/scan.py --allow-insecure-loopback-gateway --every 60 --json $env:TEMP\ibkr-momentum-scan.json

# 查看 IBKR 实际提供的扫描类型和过滤代码
python features/momentum-monitor/ibkr-scanner/scan.py --allow-insecure-loopback-gateway --list-params
```

Gateway 使用自签名证书，所以需要加 `--allow-insecure-loopback-gateway`。该选项只允许连接本机回环地址。需要 Python 3.11+，只用标准库。

## 条件和数据来源

| 条件 | 默认值 | 参数 | IBKR 数据 |
|---|---|---|---|
| 股价 | $1.50–$25 | `--min-price` `--max-price` | 最新价 (31) |
| 涨幅 | ≥ 10% | `--min-change-pct` | 最新价 / 昨收 (7741) − 1 |
| 相对成交量 | ≥ 5 倍 | `--min-relative-volume` | 今日成交量 (7762) / 90 日日均成交量 (7282) |
| 流通股 | < 2,000 万股 | `--max-float-shares` | 市值 (7289) / min(最新价, 昨收) 得出总股本上限 |
| 新闻 | 必须有 | — | IBKR Client Portal 没有新闻接口 |

结果中每项条件标为 `Y` 通过、`N` 不通过或 `?` 无法由 IBKR 验证。只要有一项为 `N` 就排除；`?` 需要手动核对。

- **流通股**：IBKR 不提供流通股数据。流通股不会超过总股本，所以总股本上限低于阈值时判为通过；否则显示 `?`，不做猜测。IBKR 的股本数据可能滞后于近期增发。
- **新闻**：始终为 `?`，请在 TWS 新闻面板手动确认。
- **相对成交量**：没有按交易时段折算，开盘初期数值偏低，属于偏保守的口径。
- **停牌**：IBKR 最新价带 `H` 前缀时，结果会标注 `HALTED`。

## 覆盖范围和拦截规则

- IBKR 扫描器每次最多返回 50 只股票。脚本把价格区间拆成 $1.50–3、3–5、5–10、10–25 分段扫描，可以用 `--band-edges 2,3,4,5,7,10,15` 进一步细分。某段达到 50 只时会提示 `truncated`，表示可能还有遗漏。
- 扫描器只用来生成候选名单。所有条件都会用实时快照重新核对，扫描器的过滤结果不直接采信。
- 延迟行情（6509 不以 `R` 开头）、快照超过 `--max-age-seconds`（默认 120 秒）或价格缺失的股票会标为 `blocked`，不会被当作符合条件。休市时大部分股票会因此被拦截，这是预期行为。
- 扫描范围为 `STK.US.MAJOR`（NYSE/Nasdaq/NYSE American），不含 OTC。

## JSON 输出

`--json` 会写出 `axio7.ibkr.momentum-scan.v1` 格式的结果，包含：数据来源、采集时间、判定时间、所用阈值、各价格段覆盖情况与截断标记、每只股票的原始数值和各条件判定、`blocked` 原因，以及注意事项。页面只需渲染这些字段，不需要再计算。

这只是研究用扫描，符合条件不代表预测或买入建议。

## 测试

```powershell
python -m unittest features/momentum-monitor/ibkr-scanner/test_scan.py scripts/test_ibkr_quote_relay.py
```
