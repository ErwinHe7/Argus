#!/usr/bin/env python3
"""AXIO7 fixture API —— 一个只用于驱动 GUI 的假后端。

这不是 quantd。真实的 quantd 目前跑不起来：src/data/ 整个数据接入层
没有进入交付快照（见 review-package/REMEDIATION-PLAN.zh-CN.md 的 B1），
fix/handoff-buildable 分支上补的是全 unimplemented!() 的 stub。

本服务的作用是让 Grafana 之类的外部 GUI 有一个形状正确的后端可以对接，
从而在真实数据接入层恢复之前就能把面板搭好、验证交互。

数据来源分两类，响应里每个对象都带 `_source` 字段标注：
  "artifact"  —— 从仓库里真实的 model-artifacts zip 读出来的，未经修改
  "synthetic" —— 为了让面板有东西可画而生成的假数据

任何 synthetic 字段都不得被当作系统行为的证据。

用法：
    python server.py --port 8001 --token <至少32字符的token>

鉴权与 quantd 一致（src/api.rs:74-102）：除 /health 外，所有请求需要
`x-research-token` 头，值与 INTRADAY_QUANT_TOKEN 一致。
"""

from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import pathlib
import random
import zipfile
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REPO_ROOT = pathlib.Path(__file__).resolve().parents[3]
ARTIFACT_ZIP = (
    REPO_ROOT
    / "axio7-model-review"
    / "model-artifacts"
    / "axio7-candidate-artifacts-2026-07-26.zip"
)

# 面板需要确定性的假数据，否则每次刷新都跳。用固定种子。
RNG = random.Random(20260726)

REGIME_LABELS = [
    "LOW_VOL_DRIFT",
    "LOW_VOL_CHOP",
    "EXPANSION",
    "TREND_UP",
    "TREND_DOWN",
    "COMPRESSION",
    "SHOCK",
    "REVERSION",
]


def load_registry() -> list[dict]:
    """从仓库里真实的 artifact zip 读取 universe registry。"""
    if not ARTIFACT_ZIP.exists():
        raise SystemExit(f"artifact zip not found: {ARTIFACT_ZIP}")
    with zipfile.ZipFile(ARTIFACT_ZIP) as archive:
        # 这个 zip 用反斜杠做路径分隔符（违反 ZIP 规范 APPNOTE 4.4.17.1），
        # 所以不能直接按 "universe/registry.json" 取，要两种都试。
        names = archive.namelist()
        target = next(
            (n for n in names if n.replace("\\", "/").endswith("universe/registry.json")),
            None,
        )
        if target is None:
            raise SystemExit("registry.json not found inside the artifact zip")
        raw = archive.read(target).decode("utf-8")
        sizes = {
            n.replace("\\", "/").rsplit("/", 1)[-1]: archive.getinfo(n).file_size
            for n in names
        }
    registry = json.loads(raw)
    for entry in registry["entries"]:
        entry["_artifact_bytes"] = sizes.get(f"{entry['public_symbol']}.frozen.json")
    return registry["entries"]


ENTRIES = load_registry()


def now() -> datetime:
    return datetime.now(timezone.utc)


def iso(moment: datetime) -> str:
    return moment.replace(microsecond=0).isoformat().replace("+00:00", "Z")


def regime_posterior(symbol: str) -> list[float]:
    """K=8 的后验分布。synthetic —— 真实后验需要实时特征，而数据层不在包里。"""
    seed = int(hashlib.sha256(symbol.encode()).hexdigest()[:8], 16)
    local = random.Random(seed)
    weights = [local.random() ** 2 for _ in range(8)]
    total = sum(weights)
    return [round(w / total, 4) for w in weights]


def models_payload() -> dict:
    rows = []
    for entry in ENTRIES:
        posterior = regime_posterior(entry["public_symbol"])
        dominant = max(range(8), key=lambda i: posterior[i])
        rows.append(
            {
                "_source": "artifact",
                "public_symbol": entry["public_symbol"],
                "model_symbol": entry["model_symbol"],
                "price_symbol": entry.get("price_symbol"),
                "target_status": entry.get("target_status"),
                "promotion_status": entry["promotion_status"],
                "model_version": entry["model_version"],
                "model_hash_short": entry["model_hash"][:12],
                "training_cutoff": entry["training_cutoff"],
                "artifact_bytes": entry.get("_artifact_bytes"),
                "sde_present": entry.get("short_horizon_sde_present"),
                # 以下为 synthetic
                "state_count": 8,
                "state_count_max_tested": 8,
                "selection_warning": "BEST_VALIDATION_SCORE_IS_AT_MAXIMUM_TESTED_K",
                "calibration_status": "UNAVAILABLE_FAIL_CLOSED",
                "dominant_regime": REGIME_LABELS[dominant],
                "dominant_regime_probability": posterior[dominant],
                "regime_posterior": posterior,
                "tradable": False,
            }
        )
    return {"models": rows, "generated_at": iso(now())}


def gates_payload() -> dict:
    """fail-closed 闸门链。第一个 BLOCKED 之后的全部不可达。"""
    chain = [
        ("1", "DATA_ENTITLEMENT", "BLOCKED", "MASSIVE_SIP_OPRA_ENTITLEMENT_UNAVAILABLE"),
        ("2", "DATA_FRESHNESS", "UNREACHABLE", "upstream gate blocked"),
        ("3", "ARTIFACT_INTEGRITY", "PASS", "13/13 sha256 matched against SHA256SUMS.txt"),
        ("4", "PROBABILITY_CALIBRATION", "BLOCKED", "UNAVAILABLE_FAIL_CLOSED"),
        ("5", "MODEL_PROMOTION", "BLOCKED", "9/9 CANDIDATE_NOT_PROMOTED"),
        ("6", "TRADE_AUTHORIZATION", "BLOCKED", "RESEARCH_ONLY_NO_TRADE (predictor.rs:2193)"),
    ]
    return {
        "_source": "artifact+synthetic",
        "gates": [
            {"order": order, "gate": gate, "status": status, "detail": detail}
            for order, gate, status, detail in chain
        ],
        "first_blocker": "DATA_ENTITLEMENT",
        "generated_at": iso(now()),
    }


def predictions_payload() -> dict:
    rows = []
    base = now()
    for index, entry in enumerate(ENTRIES):
        for horizon in (5, 15, 30):
            created = base - timedelta(minutes=horizon + index * 3)
            matured = created + timedelta(minutes=horizon)
            settled = matured < base
            rows.append(
                {
                    "_source": "synthetic",
                    "symbol": entry["public_symbol"],
                    "horizon_minutes": horizon,
                    "created_at": iso(created),
                    "matures_at": iso(matured),
                    "state": "SETTLED" if settled else "PENDING",
                    "win_probability": round(0.42 + RNG.random() * 0.16, 4),
                    "expected_return_bps": round(RNG.uniform(-9, 9), 2),
                    "uncertainty_bps": round(RNG.uniform(14, 46), 2),
                    "no_trade_reasons": [
                        "RESEARCH_ONLY_NO_TRADE",
                        "OOS_PROBABILITY_CALIBRATION_NOT_PROMOTED",
                    ],
                }
            )
    return {"predictions": rows, "generated_at": iso(now())}


def readiness_payload() -> dict:
    return {
        "_source": "synthetic",
        "readiness": {
            "status": "DATA_UNAVAILABLE",
            "missing_requirements": [
                "MASSIVE_SIP_REALTIME_ENTITLEMENT",
                "OPRA_POINT_IN_TIME_NBBO",
                "PROMOTED_CALIBRATION_ARTIFACT",
                "POSTGRES_NORMALIZED_RECORD_SINK",
            ],
        },
        "credentials": {
            "MASSIVE_API_KEY": False,
            "DATABENTO_API_KEY": False,
            "INTRADAY_QUANT_TOKEN": True,
        },
        "generated_at": iso(now()),
    }


def live_payload() -> dict:
    return {
        "_source": "synthetic",
        "feed": "MASSIVE",
        "connected": False,
        "entitlement": "UNAVAILABLE",
        "reason": "MASSIVE_REALTIME_NOT_READY",
        "last_event_at": None,
        "sequence_gaps": 0,
        "spool_backend": "JSONL",
        "postgres_sink": False,
        "generated_at": iso(now()),
    }


ROUTES = {
    "/api/v1/models": models_payload,
    "/api/v1/system/readiness": gates_payload,
    "/api/v1/data/readiness": readiness_payload,
    "/api/v1/predictions/current": predictions_payload,
    "/api/v1/live/status": live_payload,
}

ACTIONS = {
    "/api/v1/risk/kill": "KILL_SWITCH_ENGAGED",
    "/api/v1/risk/resume": "KILL_SWITCH_RELEASED",
    "/api/v1/paper/start": "PAPER_SESSION_STARTED",
    "/api/v1/paper/stop": "PAPER_SESSION_STOPPED",
}

STATE = {"kill_switch": False, "paper_running": False}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "axio7-fixture"

    def log_message(self, fmt, *args):  # noqa: A002 - stdlib signature
        print(f"  {self.command} {self.path} -> {args[1] if len(args) > 1 else ''}")

    def _send(self, status: int, body: dict) -> None:
        payload = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        # quantd 目前没有 CorsLayer；这里刻意保持一致，好让人看到跨源 GUI
        # 为什么连不上。要放开就改这里，同时也要改 src/api.rs。
        self.end_headers()
        self.wfile.write(payload)

    def _authorized(self) -> bool:
        provided = self.headers.get("x-research-token", "")
        return hmac.compare_digest(provided, self.server.token)  # type: ignore[attr-defined]

    def do_GET(self) -> None:  # noqa: N802 - stdlib signature
        path = self.path.split("?", 1)[0]
        if path == "/health":
            self._send(200, {"status": "ok", "service": "axio7-fixture"})
            return
        if not self._authorized():
            self._send(401, {"detail": "invalid research control token"})
            return
        handler = ROUTES.get(path)
        if handler is None:
            self._send(404, {"detail": f"no fixture for {path}"})
            return
        body = handler()
        if path == "/api/v1/live/status":
            body["kill_switch"] = STATE["kill_switch"]
            body["paper_running"] = STATE["paper_running"]
        self._send(200, body)

    def do_POST(self) -> None:  # noqa: N802 - stdlib signature
        path = self.path.split("?", 1)[0]
        if not self._authorized():
            self._send(401, {"detail": "invalid research control token"})
            return
        length = int(self.headers.get("Content-Length") or 0)
        if length:
            self.rfile.read(length)
        outcome = ACTIONS.get(path)
        if outcome is None:
            self._send(404, {"detail": f"no fixture for {path}"})
            return
        if path == "/api/v1/risk/kill":
            STATE["kill_switch"] = True
        elif path == "/api/v1/risk/resume":
            STATE["kill_switch"] = False
        elif path == "/api/v1/paper/start":
            STATE["paper_running"] = True
        elif path == "/api/v1/paper/stop":
            STATE["paper_running"] = False
        self._send(200, {"_source": "synthetic", "outcome": outcome, "at": iso(now())})


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8001)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--token", required=True, help="至少 32 字符，与 quantd 规则一致")
    args = parser.parse_args()
    if len(args.token) < 32:
        raise SystemExit("token must contain at least 32 characters")

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    server.token = args.token  # type: ignore[attr-defined]
    print(f"axio7 fixture API on http://{args.host}:{args.port}")
    print(f"  registry loaded from {ARTIFACT_ZIP.name}: {len(ENTRIES)} symbols")
    print(f"  routes: {', '.join(sorted(ROUTES))}")
    print(f"  actions: {', '.join(sorted(ACTIONS))}")
    server.serve_forever()


if __name__ == "__main__":
    main()
