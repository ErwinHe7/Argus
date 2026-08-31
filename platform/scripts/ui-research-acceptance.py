"""Browser acceptance for AXIO7's paid research result surface.

The Next.js test harness renders the production AxioChat component. Browser
network interception supplies a deterministic, fail-closed Rust-shaped
envelope; no vendor, model-promotion, billing, or broker state is simulated.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

from playwright.sync_api import Route, sync_playwright


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / ".artifacts" / "ui-research-acceptance"
BASE_URL = os.environ.get("AXIO7_ACCEPTANCE_BASE_URL", "http://127.0.0.1:3107")


def research_response(chinese: bool) -> dict:
    locale = "zh-CN" if chinese else "en-US"
    answer = (
        "本次请求没有生成实时预测。模型工件已加载，但共同截止时点的输入尚未完整。"
        if chinese
        else "No live forecast was generated. Model artifacts loaded, but point-in-time inputs were incomplete at the common cutoff."
    )
    query = {
        "version": "axio.market-query.v2",
        "intent": "forecast",
        "setup_type": "model_forecast",
        "symbols": ["SPX"],
        "limit": 1,
        "filters": {
            "require_realtime": True,
            "include_historical": False,
            "max_data_age_seconds": 120,
            "max_dte": 45,
        },
    }
    envelope = {
        "schema_version": "axio.evidence-envelope.v1",
        "request_id": "browser-acceptance-0001",
        "query_sha256": "a" * 64,
        "response_sha256": "b" * 64,
        "generated_at": "2026-07-28T15:31:01Z",
        "observation_cutoff": "2026-07-28T15:31:00Z",
        "status": "DATA_UNAVAILABLE",
        "query": query,
        "candidates": [],
        "exclusions": [],
        "historical": [],
        "data_blockers": [
            "SPX:AWAITING_FIRST_FINALIZED_LIVE_FORECAST",
            "SPX:CONTEXT_INCOMPLETE:UUP",
        ],
        "readiness": {
            "model": {"state": "ready", "code": "EXACT_ARTIFACTS_LOADED"},
            "feed": {"state": "ready", "code": "LICENSED_FEED_STREAMING"},
            "context": {"state": "blocked", "code": "CONTEXT_INCOMPLETE"},
            "inference": {"state": "waiting", "code": "AWAITING_CONTEXT"},
            "publication": {
                "state": "waiting",
                "code": "AWAITING_FIRST_FINALIZED_LIVE_FORECAST",
            },
        },
        "model_contract": {
            "candidate_status": "CANDIDATE_NOT_PROMOTED",
            "universe_registry_status": "CANDIDATE_ARTIFACTS_NOT_PROMOTED",
            "target_artifacts": [{"public_symbol": "SPX", "model_symbol": "SPY"}],
        },
        "research_only_policy": {
            "automatic_order_execution": False,
            "investment_advice": False,
        },
        "caveats": [
            "No candidate is an order, personalized recommendation, or guaranteed outcome.",
            "A neutral model forecast is atomic across every configured horizon; if any requested horizon is absent, duplicated, stale, or incompatible, the complete result is withheld.",
        ],
    }
    return {
        "answer": answer,
        "forecast": {
            "generatedAt": envelope["generated_at"],
            "model": "AXIO7 Native Quant Engine",
            "horizon": "all_configured_horizons",
            "assets": [],
            "sources": [],
            "evidence": [],
            "disclaimer": (
                "Impersonal whole-market statistical research only. Scores are not probabilities unless explicitly labeled as calibrated; no output is an order, personalized recommendation, or guaranteed outcome."
            ),
            "research": envelope,
            "compilerNotes": [],
        },
        "conversation": {
            "mode": "quant_research",
            "knowledge_version": "axio.model-knowledge.v1",
            "llm_role": "deterministic_fallback",
            "locale": locale,
        },
    }


def route_api(route: Route) -> None:
    request = route.request
    if request.url.endswith("/api/quant/research/status"):
        route.fulfill(
            status=200,
            content_type="application/json",
            body=json.dumps(
                {
                    "connected": True,
                    "modelStatus": "LOADED",
                    "requestedModelCount": 9,
                    "loadedModelCount": 9,
                    "failedModelCount": 0,
                    "liveForecastReady": False,
                    "readiness": {
                        "model": {"state": "ready"},
                        "feed": {"state": "ready"},
                        "context": {"state": "not_checked"},
                        "inference": {"state": "not_checked"},
                        "publication": {"state": "not_checked"},
                    },
                }
            ),
        )
        return
    if request.url.endswith("/api/monitors"):
        route.fulfill(
            status=200,
            content_type="application/json",
            body=json.dumps({"monitors": []}),
        )
        return
    if request.url.endswith("/api/ask"):
        body = request.post_data_json or {}
        question = str(body.get("query", ""))
        route.fulfill(
            status=200,
            content_type="application/json",
            body=json.dumps(research_response(any("\u3400" <= c <= "\u9fff" for c in question))),
        )
        return
    route.continue_()


def assert_min_font(page, selector: str, minimum_px: float) -> None:
    size = page.locator(selector).first.evaluate(
        "(node) => Number.parseFloat(getComputedStyle(node).fontSize)"
    )
    assert size >= minimum_px, f"{selector} rendered at {size}px, expected >= {minimum_px}px"


def run() -> None:
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    console_errors: list[str] = []

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1440, "height": 1000})
        page.on(
            "console",
            lambda message: console_errors.append(message.text)
            if message.type == "error"
            else None,
        )
        page.route("**/api/**", route_api)
        page.goto(f"{BASE_URL}/acceptance/research")
        page.wait_for_load_state("networkidle")

        composer = page.get_by_label("Your market research question")
        if composer.count() == 0:
            page.screenshot(path=str(ARTIFACTS / "reconnaissance-failure.png"), full_page=True)
            raise AssertionError(
                "acceptance composer missing after networkidle; "
                f"title={page.title()!r} url={page.url!r} "
                f"body={page.locator('body').inner_text()[:1000]!r}"
            )
        composer.fill("SPX")
        composer.press("Enter")
        page.get_by_text("AXIO7 interpreted query", exact=True).wait_for()
        page.get_by_text("No live forecast was generated for this request.", exact=True).wait_for()
        page.get_by_text("SPX → SPY (price/volume and VWAP proxy)", exact=True).wait_for()
        page.get_by_role("button", name="Retry live").wait_for()
        page.get_by_role("button", name="View readiness").wait_for()
        page.get_by_role("button", name="Set up historical replay").wait_for()
        page.get_by_role("button", name="Change assumptions").wait_for()
        page.get_by_text("Deterministic fallback explanation", exact=True).wait_for()
        assert page.get_by_text("PARTIAL", exact=True).count() == 0
        assert_min_font(page, "[class*='readinessStrip'] b", 11)
        assert_min_font(page, "[class*='readinessStrip'] small", 10)
        assert_min_font(page, "[class*='interpretedQuery'] > p", 10)
        page.wait_for_timeout(350)
        page.screenshot(path=str(ARTIFACTS / "desktop-en.png"), full_page=True)

        mobile = browser.new_page(viewport={"width": 390, "height": 844})
        mobile.on(
            "console",
            lambda message: console_errors.append(message.text)
            if message.type == "error"
            else None,
        )
        mobile.route("**/api/**", route_api)
        mobile.goto(f"{BASE_URL}/acceptance/research")
        mobile.wait_for_load_state("networkidle")
        mobile_composer = mobile.get_by_label("Your market research question")
        mobile_composer.fill("预测 SPX")
        mobile_composer.press("Enter")
        mobile.get_by_text("AXIO7 对查询的解释", exact=True).wait_for()
        mobile.get_by_text("本次请求没有生成实时预测。", exact=True).wait_for()
        mobile.wait_for_timeout(350)
        mobile.screenshot(path=str(ARTIFACTS / "mobile-zh.png"), full_page=True)
        mobile.get_by_role("button", name="设置历史回放").click()
        assert "先让我明确选择" in mobile_composer.input_value()
        mobile.screenshot(
            path=str(ARTIFACTS / "mobile-recovery-zh.png"), full_page=True
        )

        scanner = browser.new_page(viewport={"width": 1280, "height": 900})
        scanner.on(
            "console",
            lambda message: console_errors.append(message.text)
            if message.type == "error"
            else None,
        )
        scanner.route("**/api/**", route_api)
        scanner.goto(f"{BASE_URL}/quant/scanner")
        scanner.wait_for_load_state("networkidle")
        scanner.get_by_text("排名暂未公开：验证仍在进行", exact=True).wait_for()
        assert scanner.get_by_text("40%", exact=True).count() == 2
        scanner.get_by_text("20%", exact=True).wait_for()
        scanner.get_by_text("自动执行始终关闭。", exact=False).wait_for()
        assert scanner.get_by_text("看多倾向最强", exact=False).count() == 0
        scanner.screenshot(path=str(ARTIFACTS / "factor-shadow-zh.png"), full_page=True)

        browser.close()

    benign = [
        message
        for message in console_errors
        if "favicon" not in message.lower()
    ]
    assert not benign, f"browser console errors: {benign}"
    print(
        json.dumps(
            {
                "status": "PASS",
                "desktop": str(ARTIFACTS / "desktop-en.png"),
                "mobile": str(ARTIFACTS / "mobile-zh.png"),
                "mobile_recovery": str(ARTIFACTS / "mobile-recovery-zh.png"),
                "factor_shadow": str(ARTIFACTS / "factor-shadow-zh.png"),
                "console_errors": benign,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    run()
