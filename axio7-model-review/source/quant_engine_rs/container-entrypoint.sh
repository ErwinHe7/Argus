#!/bin/sh
set -eu

if [ -z "${INTRADAY_QUANT_TOKEN:-}" ] || [ "${#INTRADAY_QUANT_TOKEN}" -lt 32 ]; then
  echo "INTRADAY_QUANT_TOKEN must contain at least 32 characters" >&2
  exit 64
fi

port="${PORT:-8001}"
# 保持 loopback。不要改成 0.0.0.0。
#
# src/config.rs:659-663 有一道刻意的门禁：
#     if !server_ip.is_loopback() {
#         bail!("quant control plane must remain loopback-only until TLS/mTLS is implemented");
#     }
# 而 src/bin/quantd.rs:32-38 是 --host 覆盖配置后立刻 validate()。
# 所以传任何非 loopback 地址都会让 quantd 每次启动直接退出，不是「监听不到」
# 而是「起不来」。
#
# 这意味着：在 TLS/mTLS 落地之前，这个服务在设计上就不可对外暴露。
# 部署选项与取舍见 DEPLOY.railway.md。
host="${AXIO_QUANT_HOST:-127.0.0.1}"
config="${AXIO_QUANT_CONFIG:-configs/production.yaml}"
supervise_interval="${AXIO_SUPERVISE_INTERVAL_SECONDS:-5}"

quantd --config "$config" --host "$host" --port "$port" &
api_pid=$!
model_pid=""
options_pid=""

cleanup() {
  [ -z "$options_pid" ] || kill "$options_pid" 2>/dev/null || true
  [ -z "$model_pid" ] || kill "$model_pid" 2>/dev/null || true
  kill "$api_pid" 2>/dev/null || true
  wait "$api_pid" 2>/dev/null || true
}
trap cleanup INT TERM EXIT

attempt=0
until curl --fail --silent "http://127.0.0.1:${port}/health" >/dev/null; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 60 ] || ! kill -0 "$api_pid" 2>/dev/null; then
    echo "quantd failed to become healthy" >&2
    exit 70
  fi
  sleep 1
done

# The readiness command contains no order path. If the configured account lacks
# SIP/OPRA entitlement, the API remains online for historical research and
# returns DATA_UNAVAILABLE for live scans.
#
# 已知未解决问题（需要 data 模块补齐后才能安全修复）：这一个 massive-check 同时
# 覆盖 equity 与 options 权限，任一不满足就连 equity 模型也不启动。拆分为
# equity-check / options-check 两个独立门控之后，这里应改成分别 gate 两个子进程。
if quantctl --config "$config" live massive-check \
  --output data/live/massive_readiness.json; then
  quantctl --config "$config" live massive-model &
  model_pid=$!
  quantctl --config "$config" live massive-options-watch &
  options_pid=$!
else
  echo "SIP/OPRA readiness failed; live model/watchers were not started" >&2
fi

# 子进程监督。
#
# 修复前这里是 `wait "$api_pid"`：只等 API 进程。massive-model 或
# massive-options-watch 崩溃时容器仍然存活、/health 仍然返回 200，实时模型
# 已经停了但编排平台看到的是健康状态，故障完全静默。
#
# 现在任一被监督的子进程退出都会让 PID 1 以非零码退出，交给平台重启整个容器。
# 用轮询而不是 `wait -n`：后者不在 POSIX sh 里，Debian 的 /bin/sh 是 dash，
# 不能依赖它存在。
supervised_exit() {
  echo "$1 exited; failing the container so the platform restarts it" >&2
  exit "$2"
}

while :; do
  kill -0 "$api_pid" 2>/dev/null || supervised_exit "quantd" 71
  if [ -n "$model_pid" ]; then
    kill -0 "$model_pid" 2>/dev/null || supervised_exit "massive-model" 72
  fi
  if [ -n "$options_pid" ]; then
    kill -0 "$options_pid" 2>/dev/null || supervised_exit "massive-options-watch" 73
  fi
  sleep "$supervise_interval"
done
