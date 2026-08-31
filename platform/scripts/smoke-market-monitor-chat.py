"""Browser smoke test for AXIO7's research-monitor chat UI."""

from __future__ import annotations

import json
import os
from pathlib import Path

from playwright.sync_api import Route, sync_playwright


BASE_URL = os.environ.get("AXIO7_BASE_URL", "http://127.0.0.1:3104")
MOCK_API = os.environ.get("AXIO7_SMOKE_MOCK_API", "true").lower() == "true"
SCREENSHOT = (
    Path.home()
    / "AppData/Local/Temp"
    / (
        "axio7-market-monitor-chat-e2e.png"
        if MOCK_API
        else "axio7-market-monitor-hosted.png"
    )
)


def monitor(status: str = "active") -> dict[str, object]:
    return {
        "id": "15d08202-1b2d-4c90-9a06-b910dbbd7a6e",
        "title": "Momentum · QQQ, NVDA, AAPL +1",
        "source_question": "Monitor upside momentum in QQQ, NVDA, AAPL and MU.",
        "query": {
            "version": "axio.market-query.v1",
            "intent": "scan",
            "setup_type": "momentum",
            "symbols": ["QQQ", "NVDA", "AAPL", "MU"],
            "horizon_minutes": 15,
            "limit": 10,
            "filters": {
                "direction": "up",
                "require_realtime": True,
                "include_historical": False,
                "max_data_age_seconds": 120,
                "max_dte": 14,
            },
        },
        "status": status,
        "cadence_minutes": 5,
        "next_run_at": "2026-07-25T14:35:00.000Z",
        "last_run_at": "2026-07-25T14:30:00.000Z",
        "last_result_status": "AVAILABLE",
        "last_error": None,
        "last_triggered_at": None,
        "consecutive_failures": 0,
        "created_at": "2026-07-25T14:00:00.000Z",
        "updated_at": "2026-07-25T14:30:00.000Z",
        "latest_event": None,
    }


def main() -> None:
    console_errors: list[str] = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        page = browser.new_page(
            viewport={"width": 1440, "height": 1000},
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/149.0.0.0 Safari/537.36"
            ),
        )
        page.on(
            "console",
            lambda message: console_errors.append(message.text)
            if message.type == "error"
            else None,
        )

        guest_api = page.request.get(
            f"{BASE_URL}/api/monitors", timeout=120_000
        )
        if guest_api.status != 401:
            raise RuntimeError(
                "The monitor API did not reach its authenticated route; "
                f"status={guest_api.status} body={guest_api.text()[:500]}"
            )

        if MOCK_API:
            def monitors_route(route: Route) -> None:
                if route.request.method == "PATCH":
                    body = json.loads(route.request.post_data or "{}")
                    route.fulfill(
                        status=200,
                        content_type="application/json",
                        body=json.dumps({"monitor": monitor(body["status"])}),
                    )
                    return
                route.fulfill(
                    status=200,
                    content_type="application/json",
                    body=json.dumps({"monitors": [monitor()]}),
                )

            page.route("**/api/monitors**", monitors_route)
            page.route(
                "**/api/ask",
                lambda route: route.fulfill(
                    status=200,
                    content_type="application/json",
                    body=json.dumps(
                        {
                            "answer": (
                                "Monitor created. The deterministic rule will "
                                "check completed five-minute bars."
                            ),
                            "monitor": {
                                "requested": True,
                                "status": "CREATED",
                                "message": (
                                    "Monitor created. AXIO7 will evaluate "
                                    "finalized data every 5 minutes."
                                ),
                                "monitor": monitor(),
                            },
                        }
                    ),
                ),
            )

        response = page.goto(BASE_URL, wait_until="networkidle")
        if response is None or not response.ok:
            raise RuntimeError("AXIO7 homepage did not load.")
        page.get_by_role(
            "heading", name="What would you like to predict or monitor?"
        ).wait_for()

        if MOCK_API:
            page.get_by_text(
                "Momentum · QQQ, NVDA, AAPL +1", exact=True
            ).wait_for()
            page.get_by_role("button", name="Pause Momentum").click()
            page.get_by_role("button", name="Resume Momentum").wait_for()
        else:
            page.get_by_text("Sign in to save monitors", exact=True).wait_for()

        page.get_by_label("Your prediction question").fill(
            "Monitor upside momentum in QQQ, NVDA, AAPL and MU every five minutes."
        )
        page.get_by_role("button", name="Send question").click()
        page.get_by_text(
            "Monitor created" if MOCK_API else "Sign in required", exact=True
        ).wait_for(timeout=120_000)
        if MOCK_API:
            page.get_by_text(
                "momentum · QQQ, NVDA, AAPL, MU · every 5 min", exact=True
            ).wait_for()
        else:
            page.get_by_text(
                "The immediate scan is unavailable because the native "
                "realtime research service is not connected.",
                exact=False,
            ).wait_for()
        page.screenshot(path=str(SCREENSHOT), full_page=True)
        browser.close()

    blocking_errors = [
        message
        for message in console_errors
        if not (
            not MOCK_API
            and "Failed to load resource" in message
            and "status of 401" in message
        )
    ]
    if blocking_errors:
        raise RuntimeError(f"browser console errors: {blocking_errors}")
    print(f"PASS screenshot={SCREENSHOT}")


if __name__ == "__main__":
    main()
