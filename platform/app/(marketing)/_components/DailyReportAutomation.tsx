'use client';

import { useState } from 'react';
import {
  Activity,
  ArrowRight,
  CalendarClock,
  Check,
  Clipboard,
  DatabaseZap,
  FileText,
  Gauge,
  ShieldCheck,
} from 'lucide-react';
import Link from 'next/link';

const DAILY_REPORT_PROMPT = `你是一名专业的美股市场日报分析师、宏观策略分析师和科技成长股研究员。

请你每天纽约时间早上 8:00，为我生成一份完整的《美股收盘日报》。

报告语言：中文。
报告风格：专业、清晰、数据驱动、适合投资复盘和次日交易计划。
报告目标：帮助我快速理解昨夜美股发生了什么、市场为什么涨跌、资金在买什么卖什么、哪些板块/个股出现异动、接下来应该关注哪些风险和机会。

请务必使用最新数据，优先参考权威来源，包括但不限于：
CNBC、Reuters、Bloomberg、MarketWatch、WSJ、Investing、Yahoo Finance、Barchart、Koyfin、TradingView、Finviz、FactSet、Nasdaq、公司 IR 官网、SEC 文件、FedWatch、FRED、美国财政部、CME、EIA 等。

如果数据存在冲突，请说明不同来源的差异，并优先采用更权威/更实时的数据。
所有关键事实、重要数据、公司新闻、财报数据、宏观数据都需要注明来源或链接。
不要编造数据。如果某项数据暂时无法获取，请明确写“暂无可靠数据”。

请按照以下结构生成日报：

美股收盘日报｜YYYY-MM-DD

0. 今日一句话总结
用 3-5 句话概括昨夜美股最重要的变化：大盘是上涨、下跌还是震荡；驱动因素是宏观、财报、AI 主线、利率、地缘、油价、美元，还是板块轮动；资金是 risk-on 还是 risk-off；市场宽度是改善还是恶化；今天最值得关注的主线是什么。最后给出一句简洁判断：今日市场状态。

1. 大盘表现总览
请列出 Dow Jones、S&P 500、Nasdaq Composite、Nasdaq 100 / QQQ、Russell 2000 / IWM、SOX 半导体指数、VIX 的收盘点位、涨跌幅、日内高低点、成交量变化和技术状态。说明标普和纳指是否创历史新高/阶段新高/跌破关键均线，纳指是否明显强于标普，小盘是否跑赢或跑输，半导体是否继续领先，VIX 是否反映避险情绪升温。

2. 盘中走势复盘
用时间线复盘盘前、开盘、午盘、尾盘和盘后。解释当天涨跌的核心原因：利率驱动、财报驱动、AI 主线驱动，或是否出现 sell the news、buy the dip、short squeeze、rotation。

3. 宏观环境
3.1 美债收益率：列出 2Y、10Y、30Y、2Y-10Y 利差、10Y-30Y 利差的最新水平、日变化、市场含义。分析 10Y 是否接近 4.5%、4.6%、4.7% 等关键压力位，长端利率是否压制科技估值，收益率曲线陡峭化还是扁平化，债市在交易通胀、财政赤字、降息预期变化还是避险。
3.2 Fed 降息预期：列出 CME FedWatch 对下一次 FOMC 降息/不降息概率，年内市场预期降息次数，与前一日相比是否变化，是否有 Fed 官员讲话影响市场。
3.3 美元、黄金、原油、比特币：列出 DXY、黄金、WTI、Brent、比特币、以太坊的最新价格、涨跌幅和含义。解释美元、实际利率、油价、加密货币对风险偏好的影响。
3.4 当日重要经济数据：覆盖 CPI、PPI、PCE、非农、初请失业金、零售销售、ISM PMI、JOLTS、消费者信心、房地产数据、财政部拍卖结果等。每项包含实际值、预期值、前值和市场解读。

4. 板块表现
列出 S&P 500 十一个板块：信息技术 XLK、通信服务 XLC、可选消费 XLY、金融 XLF、工业 XLI、医疗保健 XLV、必需消费 XLP、能源 XLE、公用事业 XLU、材料 XLB、房地产 XLRE 的当日涨跌幅、近 5 日、近 1 月、跑赢/跑输标普和主要驱动。说明最强/最弱板块，成长/价值、周期/防御是否占优，是否出现高切低或 AI 硬件向软件、能源、电力、光通信、工业、金融等方向轮动。

5. 主题与风格表现
覆盖半导体 SMH/SOXX、软件 IGV、网络安全 CIBR/HACK、云计算 CLOU/WCLD、AI/自动化 BOTZ/AIQ、光通信/光模块、数据中心/电力、核电/SMR、储能、小盘成长 IWO、小盘价值 IWN、等权标普 RSP、大盘成长 QQQ/SCHG、大盘价值 VTV。判断 AI 硬件是否仍是主线，软件股是否补涨，半导体是否利好钝化，小盘是否参与，等权指数是否跑赢市值加权指数，市场是扩散行情还是少数权重股拉指数。

6. 市场宽度与参与度
6.1 均线参与度：统计 S&P 500、Nasdaq 100、Nasdaq Composite、NYSE、Russell 2000 高于 20/50/100/200 日均线比例并解读。判断 20 日参与度是否过热或恐慌，50 日参与度是否高于 50%，100/200 日参与度是否说明中期趋势健康，指数上涨是否有宽度支持，是否出现指数创新高但参与度下降的背离。
6.2 涨跌家数、新高新低：列出 NYSE 和 Nasdaq 上涨家数、下跌家数、涨跌比、52 周新高、52 周新低、新高-新低差值。判断市场是普涨还是结构性上涨，科技股内部是否健康，新低数量是否异常增加。
6.3 其他市场内部指标：如可获取，补充 Advance/Decline Line、McClellan Oscillator、Put/Call Ratio、VIX term structure、VVIX、MOVE Index、High Yield Spread、Investment Grade Spread、成交量、上涨成交量/下跌成交量比例。

7. 技术面分析
分析 SPY、QQQ、IWM、SMH、IGV、XLK、XLC、XLY 的当前价格、20/50/100/200 日线、RSI、MACD/趋势、关键支撑、关键压力。说明是否远离 20 日线或 50 日线，是否超买/超卖，是否放量滞涨、假突破，哪些位置不能破，哪些压力位突破后打开上行空间。

8. 重点个股新闻与异动
8.1 大型科技七巨头：NVDA、MSFT、AAPL、GOOGL、AMZN、META、TSLA 的涨跌幅、原因、技术位置、后续关注。判断七巨头是集体上涨还是分化，谁拉动指数、谁拖累指数，是否有监管、财报、产品、AI、反垄断、评级或目标价变化。
8.2 AI 硬件/半导体：覆盖 NVDA、AMD、AVGO、MRVL、MU、TSM、ASML、ARM、INTC、QCOM、SMCI、DELL、HPE、ANET、CLS、VRT、COHR、LITE、AAOI、TSEM、SIVE 等。说明涨跌原因、订单、评级、产业新闻、板块联动、拥挤度、sell the news、资金是否从 GPU 切向光通信、电力、软件。
8.3 软件/SaaS/AI 应用：覆盖 CRM、NOW、SNOW、ORCL、ADBE、PANW、CRWD、DDOG、NET、MDB、PLTR、APP、TEAM、WDAY、INTU、SHOP 等。说明软件是否跑赢大盘，AI 替代 SaaS 叙事是否缓解，AI Agent、数据云、工作流平台是否有新催化。
8.4 AI 电力/数据中心/能源基础设施：覆盖 CEG、VST、NRG、ETN、PWR、GEV、VRT、FLNC、OKLO、SMR、BE、NEE、SO、DUK、APLD、IREN、CORZ 等。说明数据中心电力链、核电、天然气、储能、电网设备、液冷、电力基础设施是否强势，是否有监管、订单、融资、并购、政策催化。
8.5 其他显著异动：列出财报后大涨大跌、盘后异动、分析师上调/下调、并购、SEC 调查、管理层变动、回购/增发、空头报告、指引变化。

9. 财报日历与财报解读
9.1 昨夜已公布财报的重点公司：列出收入、EPS、是否 beat、指引、盘后反应、核心解读。重点说明收入、EPS、毛利率、运营利润率、自由现金流、RPO、ARR、订单、backlog、云收入、AI 相关收入、管理层指引、股价反应和财报质量是否一致。
9.2 接下来 1-3 个交易日重要财报：列出日期、公司、市场关注点和可能影响板块，特别关注 NVDA、AVGO、AMD、MRVL、MU、TSM、ASML、CRM、NOW、SNOW、ORCL、ADBE、PANW、CRWD、GOOGL、MSFT、AMZN、META、AAPL、TSLA、VRT、ANET、DELL、SMCI、COHR、LITE、AAOI、CEG、VST、FLNC、OKLO 等。

10. 机构观点与资金流
整理华尔街大行策略观点、标普/纳指目标点位调整、AI、半导体、软件、能源、电力、金融等板块观点变化、重点股票评级上调/下调、ETF 资金流向、期权异动、大宗交易、内部人交易、回购公告。用表格列出机构/来源、观点、涉及资产、市场影响。

11. 板块轮动判断
判断当前市场处于 AI 硬件主升浪、AI 硬件高位震荡、AI 硬件利好钝化、软件补涨/估值修复、高切低、风险资产全面 risk-on、防御性 risk-off、宽度扩散、指数强内部弱、普跌恐慌、超跌反弹中的哪一种。明确回答资金流入哪里、流出哪里，AI 主线是否健康，半导体是否领先，软件是否相对走强，小盘是否参与，防御板块是否异动，当前更像趋势延续还是阶段性顶部震荡。

12. 我的重点关注股观察
每天额外跟踪：
核心科技/AI：NVDA、AMD、AVGO、MRVL、GOOGL、MSFT、META、AMZN、ORCL
软件：CRM、NOW、SNOW、ADBE、PANW、CRWD、PLTR、DDOG、NET
光通信/AI 互连：LITE、COHR、AAOI、TSEM、SIVE、MRVL、AVGO、ANET
AI 电力/数据中心基础设施：FLNC、OKLO、VST、CEG、ETN、VRT、PWR、GEV、APLD、IREN
对每只股票输出：股票、当日涨跌、当前趋势、关键新闻、支撑位、压力位、我的判断。判断标签使用：继续强势、高位震荡、短线过热、回踩支撑、破位风险、等财报催化、利好兑现、低位修复、需要观察。

13. 明日交易计划/观察清单
13.1 宏观观察：10Y 美债收益率关键位置、美元指数方向、油价/黄金/VIX、Fed 官员讲话、经济数据。
13.2 大盘观察：SPY、QQQ 关键支撑/压力，SMH 是否继续强于 QQQ，IGV 是否开始跑赢，IWM 是否参与。
13.3 板块观察：AI 硬件是否继续领涨，软件是否补涨，金融/工业/能源是否轮动，防御板块是否走强，市场宽度是否改善。
13.4 个股观察：列出 10-20 只明天最值得关注的股票并说明原因。

14. 风险提示
列出当前市场最大风险：美债收益率继续上行、通胀预期反弹、Fed 降息预期下降、地缘风险、油价冲击、AI 硬件 sell the news、半导体高位拥挤、软件财报不及预期、市场宽度恶化、信用利差扩大、VIX 异动、重要个股财报风险、政策/监管风险、美元走强压制风险资产。判断风险维度：宏观利率、市场宽度、AI 拥挤度、财报风险、地缘风险、技术面、流动性。风险等级使用：低/中/中高/高。

15. 最终结论
按以下格式总结：
今日市场结论：用 3-5 句话总结。
当前市场阶段：强趋势上涨、高位震荡、健康回调、板块轮动、风险偏好下降、普跌恐慌、超跌反弹中选择一个。
我的操作倾向：用中性语言给出观察，不构成投资建议。说明是否适合追高、是否适合逢低、是否应该等待财报、是否应该控制仓位、哪些板块更值得关注、哪些板块需要谨慎。
最值得关注的 5 个信号：列出明天最重要的 5 个观察信号。`;

const REPORT_SECTIONS = [
  ['00', '一句话总结', 'risk-on / risk-off, 宽度, 主线'],
  ['01', '大盘总览', '指数、VIX、半导体、小盘'],
  ['03', '宏观环境', '美债、FedWatch、美元、油金'],
  ['06', '市场宽度', '均线参与度、新高新低、A/D'],
  ['08', '个股异动', '七巨头、AI 硬件、软件、电力'],
  ['09', '财报日历', 'beat、指引、盘后反应'],
  ['11', '轮动判断', '主线健康度、资金流向'],
  ['15', '最终结论', '阶段、仓位观察、5 个信号'],
] as const;

const SOURCE_ROWS = [
  ['Macro', 'CME FedWatch / FRED / Treasury / EIA'],
  ['Tape', 'Nasdaq / Yahoo Finance / Barchart / TradingView'],
  ['News', 'Reuters / CNBC / Bloomberg / WSJ / MarketWatch'],
  ['Filings', 'SEC / company IR / earnings calendars'],
] as const;

const WATCHLIST = [
  'NVDA',
  'AVGO',
  'MSFT',
  'GOOGL',
  'SMH',
  'IGV',
  'VRT',
  'CEG',
  'LITE',
  'COHR',
] as const;

export function DailyReportAutomation() {
  const [copied, setCopied] = useState(false);

  async function copyPrompt() {
    try {
      await navigator.clipboard.writeText(DAILY_REPORT_PROMPT);
    } catch {
      const textArea = document.createElement('textarea');
      textArea.value = DAILY_REPORT_PROMPT;
      textArea.setAttribute('readonly', 'true');
      textArea.style.position = 'fixed';
      textArea.style.opacity = '0';
      document.body.appendChild(textArea);
      textArea.select();
      document.execCommand('copy');
      document.body.removeChild(textArea);
    }

    setCopied(true);
    window.setTimeout(() => setCopied(false), 1800);
  }

  return (
    <section className="r-sec daily-brief-section" id="daily-brief">
      <div className="r-sec-in daily-brief-shell">
        <div className="daily-brief-copy sr">
          <div className="r-s-lbl">Codex scheduled research</div>
          <h2 className="daily-brief-title">
            每天 8:00，
            <span>交付一份美股收盘日报。</span>
          </h2>
          <p className="daily-brief-lede">
            把 Codex 定时任务变成一位中文美股早会分析师：宏观、指数、板块轮动、市场宽度、AI 主线、财报与明日交易计划全部按来源审计输出。
          </p>

          <div className="daily-brief-actions">
            <button type="button" className="daily-copy-button" onClick={copyPrompt}>
              {copied ? <Check aria-hidden="true" /> : <Clipboard aria-hidden="true" />}
              <span>{copied ? '提示词已复制' : '复制完整提示词'}</span>
            </button>
            <Link href="/market" className="daily-brief-link">
              <span>打开策略控制台</span>
              <ArrowRight aria-hidden="true" />
            </Link>
          </div>

          <div className="daily-brief-metrics" aria-label="Daily report operating profile">
            <div>
              <CalendarClock aria-hidden="true" />
              <strong>08:00 NY</strong>
              <span>纽约时间自动运行</span>
            </div>
            <div>
              <DatabaseZap aria-hidden="true" />
              <strong>15 sections</strong>
              <span>从宏观到个股闭环</span>
            </div>
            <div>
              <ShieldCheck aria-hidden="true" />
              <strong>Source-first</strong>
              <span>关键事实必须带来源</span>
            </div>
          </div>

          <p className="daily-brief-disclaimer">
            输出用于复盘与观察，不构成投资建议；任何缺失数据必须明确标注“暂无可靠数据”。
          </p>
        </div>

        <div className="daily-brief-console sr sr-d2" aria-label="US market daily brief preview">
          <div className="daily-console-top">
            <div>
              <span className="daily-console-eyebrow">US CLOSE REPORT</span>
              <h3>美股收盘日报｜YYYY-MM-DD</h3>
            </div>
            <span className="daily-console-status">
              <Activity aria-hidden="true" />
              audited
            </span>
          </div>

          <div className="daily-topic-strip" aria-label="Tracked topics">
            {WATCHLIST.map((ticker, index) => (
              <span key={`${ticker}-${index}`}>{ticker}</span>
            ))}
          </div>

          <div className="daily-report-grid">
            {REPORT_SECTIONS.map(([number, title, body]) => (
              <div key={number} className="daily-report-row">
                <span>{number}</span>
                <strong>{title}</strong>
                <p>{body}</p>
              </div>
            ))}
          </div>

          <div className="daily-source-ledger">
            <div className="daily-ledger-title">
              <FileText aria-hidden="true" />
              <span>source ledger</span>
            </div>
            {SOURCE_ROWS.map(([group, sources]) => (
              <div key={group} className="daily-source-row">
                <strong>{group}</strong>
                <span>{sources}</span>
              </div>
            ))}
          </div>

          <div className="daily-risk-band">
            <Gauge aria-hidden="true" />
            <span>Risk table: 宏观利率 / 市场宽度 / AI 拥挤度 / 财报风险 / 流动性</span>
          </div>
        </div>
      </div>
    </section>
  );
}
