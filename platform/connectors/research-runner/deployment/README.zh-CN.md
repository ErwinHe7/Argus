# 把选股程序放到 VPS，让网站一直更新

选股与回测的重复计算由普通程序执行，不调用大模型，所以运行这些循环不消耗 AI token。网站展示程序输出的候选股票、筛选条件、原因和更新时间。VPS、存储和行情源仍可能收费。

目前选股程序已在本机运行，并通过经过认证的接口持续发布到网站。网站地址是 https://leo.axio7.workers.dev/ ，结果接收接口是 https://leo-shortlist-feed.axio7.workers.dev/publication 。尚未购买或连接任何 VPS；在迁移完成之前，本机必须保持运行才能继续发布新结果。

请使用 `deployment/dist/leo-vps-source-20260908-v3.zip`。v1、v2 是保留的先前构建，不是最终安装包。v3 包含经过真实 Cloudflare 请求验证的 `LeoShortlistPublisher/1.0` 请求标识，解决 Python 默认请求标识被边缘规则拒绝的问题。当前名单仍只有 5 只股票和 3 只基金，观察截止日为 2026 年 9 月 4 日；程序运行不等于行情已经更新。

## 先买哪一种

可以选择 DigitalOcean 的 **Basic → Regular → 2 GiB / 1 vCPU / 50 GiB → $12/月**，系统选 **Ubuntu 24.04 LTS x64**。这是少量股票、日线筛选和轻量定时计算的起点，不是已验证的大规模回测配置。税费、备份、额外流量、行情订阅另计，以下单页为准。[DigitalOcean 官方价格](https://www.digitalocean.com/pricing/droplets)

在供应商网站创建 Droplet 时选择 SSH key 登录，把自己电脑的 **公钥** 添加进去。私钥、登录密码和券商密码不要发到聊天中。服务器创建后，部署需要它的 IP 或 SSH 主机别名，以及登录用户名；还需要能通过本机 SSH 登录的授权。[DigitalOcean 官方初始化说明](https://docs.digitalocean.com/products/droplets/getting-started/recommended-droplet-setup/)

下方脚本准备好后，安装步骤仍需在实际服务器执行。没有服务器目标时，不能把“准备好”写成“已部署”。

## 三个程序分别负责什么

| 程序 | 工作 | 输出 | 默认权限 |
|---|---|---|---|
| `leo-shortlist` | 读取已取得的市场快照，按明确的技术条件生成候选名单 | 公开的 `current.json` | 不能交易，不调用 AI |
| `leo-research` | 对合格历史数据运行既有 Rust 回测和敏感性检查 | 私有回测记录、验证结果 | 不能交易，不调用 AI |
| `leo-research-monitor` | 显示研究心跳、问题和暂停状态 | 仅本机 3119 端口 | 不向公网开放 |

选股标准是可解释的技术筛选，不是估值结论或收益保证。每个候选必须同时显示实际触发的条件、数据日期、覆盖范围和局限。名单只覆盖输入数据中的股票，不会伪装成全市场扫描。没有合格候选时，应显示没有候选。

**这些服务会观察输入文件变化，不会自行获取新的行情。** 持续更新需要另一个已授权的数据采集任务按原数据合同原子写入新快照。TradingView 图表嵌入不能直接当作原始行情 API；不能把昨天的文件重新盖上今天日期。

## 从当前电脑导出安装源码包

在 Windows PowerShell 运行，输出目录和文件名可以自行改动：

```powershell
$platform = 'C:\Users\Hj\Desktop\Leo Roar\Argus\platform'
$python = "$platform\.quant-runtime\strategy-research-venv\Scripts\python.exe"
& $python "$platform\connectors\research-runner\deployment\build_source_bundle.py" `
  --output 'C:\Users\Hj\Desktop\Leo Roar\deliverables\leo-vps-source.zip'
```

构建器只收录明确允许的源码、日历、系统服务模板和界面资源；不收录 `.env`、账户、浏览器会话、历史行情、交易状态、Windows 虚拟环境、`.exe` 或整个脏工作目录。文件已存在时会拒绝覆盖。随包生成 SHA-256 收据，包内每个源文件另有哈希清单。这是开发源码包，没有签名、预装依赖或已完成的 Linux 原生构建证明。

把包通过 SSH 传到已授权的服务器，再解压到一个新的私有目录；示例中的 `leo-vps` 是你实际配置的 SSH 别名，不是当前已存在的主机：

```powershell
scp 'C:\Users\Hj\Desktop\Leo Roar\deliverables\leo-vps-source.zip' leo-vps:~/
ssh leo-vps
```

在 VPS 上使用普通研究用户。先按供应商的初始化流程完成 SSH 登录，并确认 Python 3.11 以上及系统 `tzdata` 可用。Ubuntu 24.04 的 Python 满足版本要求。默认选股安装使用无 pip 的隔离环境，无需下载 Python 包；可选回测环境还需 `python3-venv` 提供的 ensurepip。

```bash
umask 077
mkdir -p "$HOME/leo-release"
python3 -m zipfile -e "$HOME/leo-vps-source.zip" "$HOME/leo-release"
cd "$HOME/leo-release/platform"
bash connectors/research-runner/deployment/prepare-runtime.sh "$PWD"
```

默认只准备无第三方 Python 依赖的选股程序，不安装或启动任何服务。脚本先核对源码哈希，再建立本机虚拟环境。不要把 Windows 的虚拟环境或可执行文件直接复制到 Linux。

## 让选股程序开机运行

复制包内 `connectors/research-runner/shortlist-config.example.json` 到私有配置目录，换成这台服务器上的绝对路径。`input` 指向真正的市场快照；`state_dir` 存私有心跳和控制状态；`public_dir` 只存可公开的名单。三个位置须分开，公共目录不能包含原始输入或私有状态。

配置完成后，先生成一次检查结果，再准备服务：

```bash
platform="$HOME/leo-release/platform"
config="$HOME/.config/leo/shortlist.json"
export PYTHONPATH="$platform/intraday_quant/src"
"$platform/.research-venv/bin/python" -m intraday_quant.shortlist_service run --config "$config" --once
bash "$platform/connectors/research-runner/deployment/install-shortlist-service.sh" --dry-run \
  "$platform" "$platform/.research-venv/bin/python" "$config"
bash "$platform/connectors/research-runner/deployment/install-shortlist-service.sh" \
  "$platform" "$platform/.research-venv/bin/python" "$config"
systemctl --user cat leo-shortlist.service
systemctl --user start leo-shortlist.service
systemctl --user status leo-shortlist.service
journalctl --user -u leo-shortlist.service -n 30 --no-pager
```

安装器不覆盖已有的不同服务文件，也不自动启动、开机启用或改变防火墙。确认结果和心跳后再开启开机运行：

```bash
systemctl --user enable leo-shortlist.service
loginctl enable-linger "$USER"
loginctl show-user "$USER" -p Linger
```

`enable-linger` 让用户服务在退出 SSH 后继续运行，并在开机时启动用户服务管理器；服务器政策可能要求管理员授权。`Restart=on-failure` 提供进程崩溃恢复，不能修复缺少行情或无效配置。[systemd 官方 lingering 说明](https://github.com/systemd/systemd/blob/main/man/loginctl.xml)

## 接回现有网站

现有 `leo.axio7.workers.dev` 和应用路由保留。合适的分工是：**VPS 计算 → 受限结果发布 → 现有网站读取并展示**。Cloudflare Workers 的 `node:child_process` 是不能执行底层操作的 stub，现有 Python/Rust 常驻进程不能原样塞进静态网站 Worker。[Cloudflare 官方兼容性说明](https://developers.cloudflare.com/workers/runtime-apis/nodejs/#non-functional-stub-modules)

公开只允许固定的 `current.json`（以及确需时的 `shortlist.json`、`status.json`），它们应包含数据来源、观察时间、发布心跳、名单和明确局限。不能暴露原始行情目录、SQLite 状态、源配置、监控暂停接口或任意文件路径。页面必须区分“发布服务活着”和“行情已经更新”，断线保留上次结果并标记过时。

选股服务可通过配置里的 `publish_url` 向单独的 HTTPS 接收端上传名单。上传令牌只从进程环境变量 `LEO_SHORTLIST_PUBLISH_TOKEN` 读取，不放入 JSON 配置或前端代码；没有 `publish_url` 时保持本地运行。接收端限定格式、大小、更新时间与上传权限，网站读取结果的地址由发布接收端配置。服务器上的上传地址、令牌和网站绑定仍需要实际配置；不能把源码包当作已完成的线上接通证明。

若要让 systemd 读取上传令牌，可在服务器私有目录中手动创建权限为 `600` 的 `publisher.env`，内容仅为环境变量赋值。不要把令牌贴进聊天、命令历史或公开目录。安装器可接收第四个参数指向这个文件；它只核对路径、所有者和权限，不读取或输出令牌：

```bash
bash "$platform/connectors/research-runner/deployment/install-shortlist-service.sh" --dry-run \
  "$platform" "$platform/.research-venv/bin/python" "$config" "$HOME/.config/leo/publisher.env"
```

新服务安装时去掉 `--dry-run` 即可；若已有不同配置的同名 unit，安装器会保留并拒绝覆盖，需先停止服务并人工审阅更改。网站仍不能暴露研究控制接口。私人 3119 监控面板始终只绑定 `127.0.0.1`，通过 SSH 转发访问即可：

```bash
ssh -N -L 127.0.0.1:3119:127.0.0.1:3119 leo-vps
```

## 可选：同时安装历史研究服务

只做选股不需要编译 Rust。要跑规范里的回测，先安装 Rust 1.88 以上及本机编译依赖，再运行：

```bash
bash connectors/research-runner/deployment/prepare-runtime.sh "$PWD" --with-research
```

脚本以单编译任务构建 `strategy-lab`，并安装所需 Pydantic。2 GiB 机器可能不足以编译整个 Rust crate；可在兼容的 Ubuntu x64 构建机编译并校验产物后传入，或临时使用更大构建机，不需要为了运行轻量选股永久购买更大机器。尚未在实际 VPS 验证这个构建。

已有 `connectors/research-runner/linux/install-user-service.sh` 为研究与私有监控准备独立服务，不会替换选股服务。详细安装、暂停、关停、重启和备份命令见 [研究服务运行说明](../README.md)。合格历史数据、正确调整方式、交易日历和费用假设仍是回测条件，不够时必须拒绝输出看似精确的收益。

## 停止与恢复

```bash
systemctl --user stop leo-shortlist.service
systemctl --user disable leo-shortlist.service  # 不再随开机自动启动
```

通过 CLI `pause` 留下的 STOP 标记在重启后仍有效；通过 CLI `stop` 留下的 SHUTDOWN 标记在普通重启后仍保留。只有确认进程已经停止，且确实要人工重新启动时，才清除这份配置对应状态目录下的 SHUTDOWN，然后启动服务。不要删除 SQLite、日志或锁文件来绕过运行中的进程。升级使用新源码目录，先停止旧进程，保留原始输入与状态，再按新路径准备服务。

这套源码不包含券商实盘下单服务。模拟交易连接器及其安全凭据存储是另一项部署；Linux 无桌面 VPS 不能直接假设已有可解锁的 Secret Service。当前没有启用真实资金交易。
