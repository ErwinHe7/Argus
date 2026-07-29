"""Browser smoke test for the public AXIO7 native-research chat."""

import os
from pathlib import Path

from playwright.sync_api import sync_playwright


BASE_URL = os.environ.get("AXIO7_SMOKE_BASE_URL", "http://127.0.0.1:3104").rstrip("/")
MOCK_MODEL_STATUS = os.environ.get("AXIO7_SMOKE_MOCK_STATUS") == "1"
SCREENSHOT = Path(
    os.environ.get(
        "AXIO7_SMOKE_SCREENSHOT",
        Path.home() / "AppData/Local/Temp/axio7-research-chat-e2e.png",
    )
)


def main() -> None:
    console_errors: list[str] = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        page = browser.new_page(
            viewport={"width": 1440, "height": 1000},
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/138.0.0.0 Safari/537.36"
            ),
        )
        page.on(
            "console",
            lambda message: console_errors.append(message.text)
            if message.type == "error"
            else None,
        )
        if MOCK_MODEL_STATUS:
            page.route(
                "**/api/quant/research/status",
                lambda route: route.fulfill(
                    status=200,
                    content_type="application/json",
                    body=(
                        '{"connected":true,"code":"CONNECTED","runtime":"rust",'
                        '"universeStatus":"CONFIGURED_RESEARCH_UNIVERSE",'
                        '"execution":"DISABLED","modelStatus":"LOADED",'
                        '"requestedModelCount":9,"loadedModelCount":9,'
                        '"failedModelCount":0}'
                    ),
                ),
            )
        page.goto(BASE_URL, wait_until="networkidle")
        page.get_by_role(
            "heading", name="What market condition would you like to research?"
        ).wait_for()
        if MOCK_MODEL_STATUS:
            status_response_code = 200
            status = {
                "connected": True,
                "modelStatus": "LOADED",
                "requestedModelCount": 9,
                "loadedModelCount": 9,
                "failedModelCount": 0,
            }
        else:
            status_response = page.request.get(
                f"{BASE_URL}/api/quant/research/status"
            )
            status_response_code = status_response.status
            status = status_response.json()
        if status_response_code != 200 or not status.get("connected"):
            raise RuntimeError(f"model runtime is not connected: {status}")
        if (
            status.get("modelStatus") != "LOADED"
            or status.get("requestedModelCount", 0) < 1
            or status.get("loadedModelCount") != status.get("requestedModelCount")
            or status.get("failedModelCount") != 0
        ):
            raise RuntimeError(f"model runtime receipt is incomplete: {status}")

        question_input = page.get_by_label("Your market research question")
        question_input.click()
        question_input.press_sequentially("nvda")
        page.get_by_role("button", name="Send question").wait_for(state="visible")
        with page.expect_response(
            lambda response: response.url.endswith("/api/ask"), timeout=120_000
        ) as response_info:
            page.get_by_role("button", name="Send question").click()
        response = response_info.value
        if response.status != 200:
            raise RuntimeError(
                f"/api/ask returned {response.status}: {response.text()[:1000]}"
            )
        page.wait_for_timeout(2_000)
        if page.get_by_text("Rust quant engine connected", exact=True).count() == 0:
            raise RuntimeError(
                "research evidence card was not rendered; "
                f"response={response.text()[:1200]} body={page.locator('body').inner_text()[:1600]}"
            )
        page.get_by_text("Result withheld", exact=True).first.wait_for()
        page.get_by_text("Model runtime contract", exact=True).wait_for()
        page.get_by_text("Reproducibility contract", exact=True).wait_for()
        page.get_by_text("Model runtime contract", exact=True).click()
        page.get_by_text("Rust inference backend", exact=True).wait_for()
        page.screenshot(path=str(SCREENSHOT), full_page=True)
        browser.close()
    if console_errors:
        raise RuntimeError(f"browser console errors: {console_errors}")
    print(f"PASS screenshot={SCREENSHOT}")


if __name__ == "__main__":
    main()
