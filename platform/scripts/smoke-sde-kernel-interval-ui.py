"""Browser-level UI contract smoke with explicitly routed mock API responses.

This verifies rendering and client-side semantics only. It is not a live
quant_engine_rs gateway, entitlement, freshness, or market-data E2E test.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from playwright.sync_api import Route, sync_playwright


ROOT = Path(__file__).resolve().parents[1]
BASE_URL = os.environ.get("AXIO7_SMOKE_URL", "http://127.0.0.1:3000").rstrip("/")
OVERVIEW_SCREENSHOT = ROOT / ".quant-runtime" / "sde-kernel-overview-ui.png"
PROMOTED_SCREENSHOT = ROOT / ".quant-runtime" / "promoted-binary-up-ui.png"
ANALOG_SCREENSHOT = ROOT / ".quant-runtime" / "sde-kernel-analog-ui.png"
MOBILE_SCREENSHOT = ROOT / ".quant-runtime" / "market-emotion-mobile-ui.png"
OVERVIEW_SCREENSHOT.parent.mkdir(parents=True, exist_ok=True)


def probability_interval(estimate: float) -> dict[str, object]:
    return {
        "estimate": estimate,
        "lower": max(0.0, estimate - 0.10),
        "upper": min(1.0, estimate + 0.10),
        "confidence_level": 0.95,
        "effective_sample_size": 30.0,
        "method": "wilson_score",
        "status": "EXPLORATORY_UNCALIBRATED_EFFECTIVE_SAMPLE_WILSON",
        "semantics": (
            "UNCALIBRATED_KERNEL_WEIGHTED_HISTORICAL_FREQUENCY_95_PERCENT_"
            "ESTIMATE_INTERVAL_USING_KISH_EFFECTIVE_SAMPLE_SIZE"
        ),
    }


def sde_interval(mass: float, lower: float, upper: float) -> dict[str, object]:
    return {
        "probability_mass": mass,
        "lower_log_return": lower,
        "upper_log_return": upper,
        "method": "GAUSSIAN_MOMENT_MATCHED_FROM_FIRST_TWO_MOMENTS",
        "status": "UNCALIBRATED_RESEARCH_ONLY_GAUSSIAN_MOMENT_MATCHED",
        "semantics": (
            "MODEL_IMPLIED_UNCALIBRATED_RESEARCH_ONLY; "
            "NOT_A_CONFIDENCE_GUARANTEE; JUMP_COMPONENT_EXCLUDED_FROM_TAILS"
        ),
    }


def market_emotion_payload(symbol: str) -> dict[str, object]:
    chase = symbol == "QQQ"
    dominant = "CHASE_LIKE" if chase else "STRESS_LIKE"
    raw_index = 68.0 if chase else 74.0
    runner_up = "ATTENTION_SHOCK_LIKE" if chase else "CROWDING_LIKE"
    scores = (
        [
            {"regime": "CHASE_LIKE", "raw_score": 68.0},
            {"regime": "ATTENTION_SHOCK_LIKE", "raw_score": 58.0},
            {"regime": "CROWDING_LIKE", "raw_score": 52.0},
        ]
        if chase
        else [
            {"regime": "STRESS_LIKE", "raw_score": 74.0},
            {"regime": "CROWDING_LIKE", "raw_score": 61.0},
            {"regime": "ATTENTION_SHOCK_LIKE", "raw_score": 55.0},
        ]
    )
    for score in scores:
        score["calibrated_probability"] = None
    return {
        "schema_version": "axio.behavioral-state.v3",
        "availability": "PARTIAL_PRICE_FLOW_ONLY",
        "observation_cutoff": "2026-07-26T14:30:00Z",
        "decision_as_of": "2026-07-26T14:30:02Z",
        "latest_input_available_at": "2026-07-26T14:30:02Z",
        "input_availability_status": "VERIFIED_PROVIDER_AVAILABILITY",
        "source_scope": "MOOMOO_OPEND:smoke",
        "behavioral_regime": {
            "dominant": dominant,
            "runner_up": runner_up,
            "raw_scores": scores,
            "score_margin": raw_index - float(scores[1]["raw_score"]),
            "status": "RAW_MARKET_RESPONSE_SCENARIO_NOT_CALIBRATED",
        },
        "market_emotion_proxy": {
            "schema_version": "axio.market-emotion-proxy.v1",
            "publication_status": "AVAILABLE_PARTIAL_PRICE_FLOW_PROXY",
            "measurement_target": "AGGREGATE_MARKET_RESPONSE_PATTERNS",
            "measurement_semantics": (
                "MARKET_DERIVED_PROXY_NOT_DIRECT_HUMAN_PSYCHOLOGY"
            ),
            "dominant_market_response_pattern": dominant,
            "raw_compatibility_index": raw_index,
            "score_margin": raw_index - float(scores[1]["raw_score"]),
            "units": "RAW_COMPATIBILITY_INDEX_0_100",
            "as_of": "2026-07-26T14:30:02Z",
            "source_scope": "MOOMOO_OPEND:smoke",
            "price_flow_feature_coverage_ratio": 1.0,
            "required_domain_coverage_ratio": 0.2,
            "calibrated_probability": None,
            "not_probability": True,
            "affects_decision": False,
            "reason_codes": [],
        },
        "price_flow_feature_coverage_ratio": 1.0,
        "required_domain_coverage_ratio": 0.2,
        "affects_decision": False,
        "warnings": [
            "NO_DIRECT_HUMAN_PSYCHOLOGY_OBSERVATION",
            "RAW_INDICES_AND_REGIME_SCORES_ARE_NOT_CALIBRATED_PROBABILITIES",
        ],
    }


def forecast_payload(symbol: str) -> dict[str, object]:
    payload: dict[str, object] = {
        "status": "IMPERSONAL_MARKET_RESEARCH",
        "forecast_contract_version": "4.4",
        "generated_at": "2026-07-26T14:30:20Z",
        "behavioral_state_layer": market_emotion_payload(symbol),
        "prediction_layer": [
            {
                "prediction_id": f"smoke-{symbol}-60",
                "symbol": symbol,
                "horizon_minutes": 60,
                "label_end": "2026-07-26T15:30:00Z",
                "reference_price": 600.0,
                "reference_price_source": "SMOKE_RUST_FIELD",
                "expected_return": 0.02,
                "expected_price": None,
                "return_definition": (
                    "NEXT_1M_OPEN_TO_HORIZON_CLOSE_SIMPLE_RETURN"
                ),
                "current_close_reference_scenario_expected_price": 612.0,
                "current_close_reference_scenario_basis": (
                    "FINALIZED_CURRENT_1M_CLOSE_TIMES_ONE_PLUS_"
                    "NEXT_1M_OPEN_TO_HORIZON_CLOSE_SIMPLE_RETURN"
                ),
                "current_close_reference_scenario_status": (
                    "REFERENCE_SCENARIO_ONLY_NOT_LABEL_ALIGNED_PRICE_FORECAST"
                ),
                "current_close_reference_scenario_semantics": (
                    "ARITHMETIC_CURRENT_CLOSE_REFERENCE_SCENARIO; "
                    "NOT_AN_EXPECTED_EXECUTABLE_OR_LABEL_ALIGNED_PRICE"
                ),
                "p_up": None,
                "p_flat": None,
                "p_down": None,
                "raw_analog_up_frequency": 0.55,
                "raw_analog_flat_frequency": 0.20,
                "raw_analog_down_frequency": 0.25,
                "calibrated_probability_up": None,
                "probability_calibration": {
                    "status": "CALIBRATION_ARTIFACT_UNAVAILABLE",
                    "eligible_for_probability_use": False,
                    "calibrated_probability_up": None,
                    "calibrated_probability_up_interval": None,
                    "method": None,
                },
                "kernel_regression": {
                    "status": "AVAILABLE",
                    "feature_dimension_count": 12,
                    "selected_dimensions": [
                        "ret_1m",
                        "ret_5m",
                        "ret_15m",
                        "vwap_distance",
                        "realized_volatility",
                        "normalized_range",
                        "volume_zscore",
                        "rvol",
                        "session_range_position",
                        "cross_asset_breadth",
                        "slope_15m",
                        "minute_of_session",
                    ],
                    "metric": "shrinkage_mahalanobis",
                    "kernel": "GAUSSIAN_RBF_ADAPTIVE_BANDWIDTH_NADARAYA_WATSON",
                    "bandwidth": 1.25,
                    "neighbor_count": 50,
                    "effective_sample_size": 30.0,
                    "minimum_effective_sample_size": 20.0,
                    "nadaraya_watson_expected_return": 0.02,
                    "local_linear_intercept": 0.018,
                    "direction_event_threshold_return": 0.0003,
                    "direction_probability_intervals": {
                        "up": probability_interval(0.55),
                        "flat": probability_interval(0.20),
                        "down": probability_interval(0.25),
                    },
                    "probability_status": (
                        "EXPLORATORY_UNCALIBRATED_EFFECTIVE_SAMPLE_WILSON"
                    ),
                    "probability_semantics": (
                        "RAW_HISTORICAL_FREQUENCIES_NOT_PROMOTED_PROBABILITIES"
                    ),
                },
                "outcome_prediction_intervals": [
                    {
                        "probability_mass": 0.80,
                        "lower_return": -0.01,
                        "upper_return": 0.03,
                        "lower_price": None,
                        "upper_price": None,
                        "current_close_reference_scenario_lower_price": 594.0,
                        "current_close_reference_scenario_upper_price": 618.0,
                        "current_close_reference_scenario_basis": (
                            "FINALIZED_CURRENT_1M_CLOSE_TIMES_ONE_PLUS_"
                            "NEXT_1M_OPEN_TO_HORIZON_CLOSE_SIMPLE_RETURN"
                        ),
                        "current_close_reference_scenario_status": (
                            "REFERENCE_SCENARIO_ONLY_NOT_LABEL_ALIGNED_PRICE_FORECAST"
                        ),
                        "current_close_reference_scenario_semantics": (
                            "ARITHMETIC_CURRENT_CLOSE_REFERENCE_SCENARIO; "
                            "NOT_AN_EXPECTED_EXECUTABLE_OR_LABEL_ALIGNED_PRICE"
                        ),
                        "method": "KERNEL_WEIGHTED_HISTORICAL_ANALOG_QUANTILES",
                        "status": "UNCALIBRATED_EMPIRICAL_CONDITIONAL_RANGE",
                        "semantics": "NOT_A_CONFORMAL_INTERVAL_OR_COVERAGE_GUARANTEE",
                    },
                    {
                        "probability_mass": 0.90,
                        "lower_return": -0.02,
                        "upper_return": 0.04,
                        "lower_price": None,
                        "upper_price": None,
                        "current_close_reference_scenario_lower_price": 588.0,
                        "current_close_reference_scenario_upper_price": 624.0,
                        "current_close_reference_scenario_basis": (
                            "FINALIZED_CURRENT_1M_CLOSE_TIMES_ONE_PLUS_"
                            "NEXT_1M_OPEN_TO_HORIZON_CLOSE_SIMPLE_RETURN"
                        ),
                        "current_close_reference_scenario_status": (
                            "REFERENCE_SCENARIO_ONLY_NOT_LABEL_ALIGNED_PRICE_FORECAST"
                        ),
                        "current_close_reference_scenario_semantics": (
                            "ARITHMETIC_CURRENT_CLOSE_REFERENCE_SCENARIO; "
                            "NOT_AN_EXPECTED_EXECUTABLE_OR_LABEL_ALIGNED_PRICE"
                        ),
                        "method": "KERNEL_WEIGHTED_HISTORICAL_ANALOG_QUANTILES",
                        "status": "UNCALIBRATED_EMPIRICAL_CONDITIONAL_RANGE",
                        "semantics": "NOT_A_CONFORMAL_INTERVAL_OR_COVERAGE_GUARANTEE",
                    },
                ],
                "stochastic_research_layer": {
                    "status": "AVAILABLE_RESEARCH_ONLY_SHADOW_FROZEN_SDE",
                    "model_family": (
                        "MARKOV_SWITCHING_LOG_RETURN_DIFFUSION+"
                        "VWAP_RESIDUAL_OU+MOMENTUM_SHADOW"
                    ),
                    "affects_decision": False,
                    "martingale_audit_status": (
                        "NOT_RUN_UNTIL_APPEND_ONLY_SETTLED_FORWARD_RESIDUALS"
                    ),
                    "probability_semantics": "UNCALIBRATED_SHADOW_DISTRIBUTION",
                    "research_policy": (
                        "RESEARCH_ONLY_FROZEN_SDE_SHADOW; "
                        "REQUIRES_SEPARATE_OOS_PROMOTION"
                    ),
                    "horizon_forecast": {
                        "horizon_minutes": 60,
                        "direction_probabilities": {
                            "p_up": 0.52,
                            "p_flat": 0.18,
                            "p_down": 0.30,
                            "material_move_lower_threshold_log_return": -0.000300045,
                            "material_move_upper_threshold_log_return": 0.000299955,
                            "method": (
                                "GAUSSIAN_MOMENT_MATCHED_FROM_FIRST_TWO_MOMENTS"
                            ),
                            "status": (
                                "UNCALIBRATED_RESEARCH_ONLY_GAUSSIAN_MOMENT_MATCHED"
                            ),
                            "semantics": (
                                "MODEL_IMPLIED_UNCALIBRATED_RESEARCH_ONLY; "
                                "NOT_A_CONFIDENCE_GUARANTEE; "
                                "JUMP_COMPONENT_EXCLUDED_FROM_TAILS"
                            ),
                        },
                        "central_prediction_intervals": [
                            sde_interval(0.80, -0.012, 0.014),
                            sde_interval(0.90, -0.017, 0.019),
                            sde_interval(0.95, -0.021, 0.023),
                        ],
                    },
                },
                "statistical_condition": "POSITIVE_CONDITIONAL_MEAN",
                "calibration_status": "CALIBRATION_ARTIFACT_UNAVAILABLE",
                "epistemic_uncertainty": 0.002,
                "ood_score": 0.35,
                "filtered_state_probabilities": [0.10, 0.20, 0.60, 0.10],
                "predicted_state_probabilities": [0.12, 0.23, 0.52, 0.13],
                "state_entropy": 0.92,
                "decision": {
                    "action": "NO_TRADE",
                    "eligible": False,
                    "no_trade_reasons": [
                        "OOS_PROBABILITY_CALIBRATION_NOT_PROMOTED",
                        "RESEARCH_ONLY_NO_TRADE",
                    ],
                },
            }
        ],
        "unavailable_horizons": [],
        "research_only_policy": {
            "product_scope": "IMPERSONAL_WHOLE_MARKET_STATISTICAL_RESEARCH",
            "execution_instruction": False,
        },
    }
    if symbol == "QQQ":
        prediction_layer = payload["prediction_layer"]
        assert isinstance(prediction_layer, list)
        row = prediction_layer[0]
        assert isinstance(row, dict)
        row.update(
            {
                "expected_return": -0.02,
                "expected_price": None,
                "current_close_reference_scenario_expected_price": 588.0,
                "p_up": 0.42,
                "p_flat": None,
                "p_down": None,
                "calibrated_probability_up": 0.42,
                "published_probability_status": (
                    "PROMOTED_BINARY_UP_ONLY_NO_JOINT_MULTICLASS_CALIBRATION"
                ),
                "statistical_condition": "NEGATIVE_CONDITIONAL_MEAN",
                "calibration_status": "PROMOTED_OOS_CALIBRATION_APPLIED",
                "probability_calibration": {
                    "status": "PROMOTED_OOS_CALIBRATION_APPLIED",
                    "eligible_for_probability_use": True,
                    "calibrated_probability_up": 0.42,
                    "calibrated_probability_up_interval": {
                        "estimate": 0.42,
                        "lower": 0.34,
                        "upper": 0.50,
                        "confidence_level": 0.95,
                        "effective_sample_size": 120.0,
                        "method": "WILSON_SCORE_RELIABILITY_BIN",
                        "status": "PROMOTED_OOS_RELIABILITY_BIN_SAMPLING_INTERVAL",
                        "semantics": (
                            "BINARY_P_UP_OOS_RELIABILITY_BIN_SAMPLING_ERROR_ONLY"
                        ),
                    },
                    "method": "ISOTONIC_OOS_BINARY_UP",
                    "reasons": [],
                },
            }
        )
        kernel = row["kernel_regression"]
        assert isinstance(kernel, dict)
        kernel["nadaraya_watson_expected_return"] = -0.02
        kernel["local_linear_intercept"] = -0.018
    return payload


def analog_payload() -> dict[str, object]:
    row = forecast_payload("SPY")["prediction_layer"][0]
    assert isinstance(row, dict)
    return {
        "status": "AVAILABLE",
        "analog_status": "AVAILABLE",
        "schema_version": "axio.current-analogs.v2",
        "symbol": "SPY",
        "decision_as_of": "2026-07-26T14:30:00Z",
        "horizon_minutes": 60,
        "horizon_label": "60m",
        "neighbor_count": 50,
        "effective_sample_size": 30.0,
        "minimum_effective_sample_size": 20.0,
        "ood_score": 0.35,
        "expected_return": row["expected_return"],
        "expected_price": row["expected_price"],
        "current_close_reference_scenario_expected_price": row[
            "current_close_reference_scenario_expected_price"
        ],
        "current_close_reference_scenario_basis": row[
            "current_close_reference_scenario_basis"
        ],
        "current_close_reference_scenario_status": row[
            "current_close_reference_scenario_status"
        ],
        "current_close_reference_scenario_semantics": row[
            "current_close_reference_scenario_semantics"
        ],
        "return_definition": row["return_definition"],
        "median_return": 0.015,
        "raw_analog_up_frequency": row["raw_analog_up_frequency"],
        "raw_analog_flat_frequency": row["raw_analog_flat_frequency"],
        "raw_analog_down_frequency": row["raw_analog_down_frequency"],
        "calibrated_probability_up": None,
        "probability_calibration": row["probability_calibration"],
        "kernel_regression": row["kernel_regression"],
        "outcome_prediction_intervals": row["outcome_prediction_intervals"],
        "stochastic_research_layer": row["stochastic_research_layer"],
        "analogs": [],
        "diagnostics": {"effective_sample_size": 30.0},
        "sensitivity": [],
        "validation_flags": ["RESEARCH_ONLY_NO_TRADE"],
        "evidence_grade": "FORWARD_SHADOW",
    }


def api_handler(route: Route) -> None:
    parsed = urlparse(route.request.url)
    suffix = parsed.path.split("/api/quant/intraday/", 1)[-1]
    if suffix == "predictor/forecast":
        symbol = parse_qs(parsed.query).get("symbol", ["SPY"])[0].upper()
        payload = forecast_payload(symbol)
    elif suffix == "analogs/current":
        payload = analog_payload()
    elif suffix == "live/status":
        payload = {"status": "CONNECTED_SMOKE", "source": "PLAYWRIGHT_ROUTE"}
    elif suffix == "live/capabilities":
        payload = {"status": "AVAILABLE", "highest_level": "D1"}
    elif suffix == "live/bars":
        payload = {"status": "AVAILABLE", "bars": []}
    else:
        payload = {"status": "AVAILABLE"}
    route.fulfill(
        status=200,
        content_type="application/json; charset=utf-8",
        body=json.dumps(payload, ensure_ascii=False),
    )


console_errors: list[str] = []
request_failures: list[str] = []
with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 1600, "height": 1200})
    page.on(
        "console",
        lambda message: (
            console_errors.append(message.text) if message.type == "error" else None
        ),
    )
    page.on(
        "requestfailed",
        lambda request: request_failures.append(
            f"{request.method} {request.url}: {request.failure}"
        ),
    )
    page.route("**/api/quant/intraday/**", api_handler)
    response = page.goto(
        f"{BASE_URL}/quant/intraday",
        wait_until="domcontentloaded",
        timeout=90_000,
    )
    assert response is not None and response.ok, (
        f"intraday page returned {response.status if response else 'no response'}"
    )
    assert "/quant/intraday" in page.url, f"unexpected redirect: {page.url}"
    try:
        page.wait_for_load_state("networkidle", timeout=15_000)
    except Exception:
        pass
    page.get_by_text("12D kernel evidence vs SDE shadow", exact=True).wait_for(
        timeout=30_000
    )
    body = page.locator("body").inner_text()
    assert "方向概率 withheld" in body, (
        "forecast row did not render after the model-evidence panel became visible:\n"
        f"{body[:4000]}"
    )
    assert "压力释放型" in body, (
        "market emotion proxy did not render:\n"
        f"{body[:4000]}"
    )
    expected_overview = [
        "Market Emotion",
        "RUST · MARKET-RESPONSE PROXY",
        "压力释放型",
        "74/100",
        "NOT A DIRECT PSYCHOLOGY OBSERVATION",
        "方向概率 withheld",
        "Raw Up / Flat / Down 95% Wilson ranges",
        "SDE shadow · uncalibrated",
        "SDE central prediction intervals · 非 confidence / conformal",
        "kernel analogue 中间80%结果范围，非 confidence/conformal",
        "expected_price 被 withheld",
        "Current-close reference scenario",
        "Current-close scenario price range",
        "$612.00",
        "未来 60 分钟：方向概率暂不发布",
    ]
    folded_body = body.casefold()
    for expected in expected_overview:
        assert expected.casefold() in folded_body, f"missing overview text: {expected}"
    assert "$612.12" not in body, "browser reconstructed log-return price"
    assert "Rust complementary allocation" not in body
    assert "Rust expected_price" not in body
    assert page.locator(".quant-intraday-dark").count() == 1
    assert page.locator("footer").count() == 1, "intraday route rendered duplicate footer"
    nav_background = page.locator("header").first.evaluate(
        "(element) => getComputedStyle(element).backgroundColor"
    )
    assert nav_background not in {"rgb(250, 249, 246)", "rgba(250, 249, 246, 0.9)"}, (
        f"quant route retained the light global nav: {nav_background}"
    )
    page.screenshot(path=str(OVERVIEW_SCREENSHOT), full_page=True)
    page.set_viewport_size({"width": 390, "height": 844})
    page.wait_for_timeout(250)
    horizontal_overflow = page.evaluate(
        "() => document.documentElement.scrollWidth - window.innerWidth"
    )
    assert horizontal_overflow <= 1, (
        f"mobile layout has horizontal overflow: {horizontal_overflow}px"
    )
    headline_metrics = page.locator("h1").first.evaluate(
        """(element) => {
            const bounds = element.getBoundingClientRect();
            const style = getComputedStyle(element);
            const ancestors = [];
            let current = element.parentElement;
            while (current && ancestors.length < 8) {
                const currentBounds = current.getBoundingClientRect();
                ancestors.push({
                    tag: current.tagName,
                    className: current.className,
                    clientWidth: current.clientWidth,
                    scrollWidth: current.scrollWidth,
                    left: currentBounds.left,
                    right: currentBounds.right,
                });
                current = current.parentElement;
            }
            return {
                clientWidth: element.clientWidth,
                scrollWidth: element.scrollWidth,
                clientHeight: element.clientHeight,
                scrollHeight: element.scrollHeight,
                left: bounds.left,
                right: bounds.right,
                whiteSpace: style.whiteSpace,
                overflowWrap: style.overflowWrap,
                wordBreak: style.wordBreak,
                ancestors,
            };
        }"""
    )
    assert headline_metrics["scrollWidth"] <= headline_metrics["clientWidth"] + 1, (
        "mobile forecast headline is horizontally clipped: "
        f"{json.dumps(headline_metrics, ensure_ascii=False)}"
    )
    assert headline_metrics["right"] <= 391, (
        "mobile forecast headline extends beyond the viewport: "
        f"{json.dumps(headline_metrics, ensure_ascii=False)}"
    )
    assert headline_metrics["clientHeight"] >= 70, (
        "mobile forecast headline did not reflow onto multiple lines: "
        f"{json.dumps(headline_metrics, ensure_ascii=False)}"
    )
    page.get_by_label("Market Emotion market-response proxy").scroll_into_view_if_needed()
    page.screenshot(path=str(MOBILE_SCREENSHOT), full_page=False)
    page.emulate_media(reduced_motion="reduce")
    ambient_animation = page.locator(".quant-intraday-dark > span").first.evaluate(
        "(element) => getComputedStyle(element).animationName"
    )
    assert ambient_animation == "none", (
        f"reduced-motion did not disable ambient animation: {ambient_animation}"
    )
    page.emulate_media(reduced_motion="no-preference")
    page.set_viewport_size({"width": 1600, "height": 1200})

    page.get_by_role("button", name="QQQ", exact=True).click()
    promoted_headline = (
        "未来 60 分钟：已校准 binary P(up) 42.0%；非整体方向结论"
    )
    page.get_by_text(promoted_headline, exact=True).wait_for(timeout=30_000)
    promoted_body = page.locator("body").inner_text()
    for expected in [
        promoted_headline,
        "BINARY_P_UP_CALIBRATION_PUBLISHED_ONLY",
        "Promoted binary P(up) · Down / Flat 未做联合校准",
        (
            "已校准 binary P(up) 42.0% 可发布，"
            "Down / Flat 与整体方向未联合校准"
        ),
        "非 label-aligned expected price",
        "$588.00",
        "追涨型",
        "68/100",
    ]:
        assert expected.casefold() in promoted_body.casefold(), (
            f"missing promoted binary-up text: {expected}"
        )
    for forbidden in [
        "NEGATIVE_CONDITIONAL_MEAN",
        "Rust 条件均值为负（promoted）",
        "方向概率可发布",
        "bearish（promoted）",
        "bearish promoted",
        "整体方向 promoted",
    ]:
        assert forbidden.casefold() not in promoted_body.casefold(), (
            f"negative conditional branch mislabeled as promoted direction: {forbidden}"
        )
    page.screenshot(path=str(PROMOTED_SCREENSHOT), full_page=True)

    page.get_by_role("button", name="相似环境").click()
    page.get_by_text("未校准历史核频率估计区间", exact=True).wait_for(
        timeout=30_000
    )
    page.get_by_text(
        "REFERENCE_SCENARIO_ONLY_NOT_LABEL_ALIGNED_PRICE_FORECAST",
        exact=True,
    ).wait_for(timeout=30_000)
    analog_body = page.locator("body").inner_text()
    for expected in [
        "Direction probability WITHHELD",
        "Raw Up / Flat / Down 95% Wilson ranges",
        "Kernel analogue outcome intervals",
        "Current-close reference scenario",
        "REFERENCE_SCENARIO_ONLY_NOT_LABEL_ALIGNED_PRICE_FORECAST",
    ]:
        assert expected.casefold() in analog_body.casefold(), (
            f"missing analog text: {expected}\n{analog_body[:6000]}"
        )
    assert "withheld · calibration not promoted" in analog_body

    page.screenshot(path=str(ANALOG_SCREENSHOT), full_page=True)
    browser.close()

blocking_console_errors = [
    message for message in console_errors if "favicon" not in message.lower()
]
blocking_request_failures = [
    failure for failure in request_failures if "net::ERR_ABORTED" not in failure
]
assert not blocking_console_errors, json.dumps(
    blocking_console_errors, ensure_ascii=False, indent=2
)
assert not blocking_request_failures, json.dumps(
    blocking_request_failures, ensure_ascii=False, indent=2
)
print(
    json.dumps(
        {
            "status": "ok",
            "scope": "ROUTED_MOCK_API_UI_CONTRACT_NOT_GATEWAY_E2E",
            "base_url": BASE_URL,
            "overview_screenshot": str(OVERVIEW_SCREENSHOT),
            "promoted_screenshot": str(PROMOTED_SCREENSHOT),
            "analog_screenshot": str(ANALOG_SCREENSHOT),
            "mobile_screenshot": str(MOBILE_SCREENSHOT),
            "console_errors": blocking_console_errors,
            "request_failures": blocking_request_failures,
        },
        ensure_ascii=False,
    )
)
