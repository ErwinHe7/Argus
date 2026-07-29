from __future__ import annotations

import json
import os
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from playwright.sync_api import expect, sync_playwright


ROOT = os.environ.get("AXIO7_SMOKE_ROOT", "http://127.0.0.1:3000").rstrip("/")
RESOLVE_TO = os.environ.get("AXIO7_SMOKE_RESOLVE", "").strip()
VERIFY_OAUTH_INIT = os.environ.get("AXIO7_SMOKE_OAUTH_INIT") == "1"
VERIFY_RESEARCH_QUERY = os.environ.get("AXIO7_SMOKE_RESEARCH") == "1"
VERIFY_CONVERSATION = os.environ.get("AXIO7_SMOKE_CONVERSATION") == "1"
ARTIFACTS = Path("tmp")


def main() -> None:
    ARTIFACTS.mkdir(exist_ok=True)
    console_errors: list[str] = []
    page_errors: list[str] = []
    failed_requests: list[str] = []
    runtime_responses: list[str] = []
    oauth_requests: list[str] = []
    research_receipt = None
    conversation_receipt = None

    with sync_playwright() as playwright:
        launch_args: list[str] = []
        if RESOLVE_TO:
            host = urlparse(ROOT).hostname
            if not host:
                raise AssertionError(f"Cannot resolve smoke-test host from {ROOT}")
            launch_args.append(f"--host-resolver-rules=MAP {host} {RESOLVE_TO}")
        browser = playwright.chromium.launch(headless=True, args=launch_args)
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
        page.on("pageerror", lambda error: page_errors.append(str(error)))
        page.on(
            "requestfailed",
            lambda request: failed_requests.append(
                f"{request.url}: {request.failure}"
            ),
        )
        page.on(
            "response",
            lambda response: runtime_responses.append(
                f"{response.status} {response.url}"
            )
            if "/api/quant/research/status" in response.url
            else None,
        )
        page.on(
            "request",
            lambda request: oauth_requests.append(request.url)
            if "/auth/v1/authorize" in request.url
            or "accounts.google.com" in request.url
            else None,
        )

        page.goto(ROOT, wait_until="networkidle")
        page.get_by_role(
            "heading", name="What would you like to predict or monitor?"
        ).wait_for()
        signin_entry = page.get_by_role("link", name="Sign in to AXIO7")
        signin_entry.wait_for()
        runtime_badge = page.locator("[data-state]")
        runtime_badge.wait_for()
        page.wait_for_timeout(5_000)
        runtime_state = runtime_badge.get_attribute("data-state")
        if runtime_state != "connected":
            raise AssertionError(
                json.dumps(
                    {
                        "runtime_state": runtime_state,
                        "console_errors": console_errors,
                        "page_errors": page_errors,
                        "failed_requests": failed_requests,
                        "runtime_responses": runtime_responses,
                    }
                )
            )
        expect(runtime_badge).to_contain_text("Rust model connected")
        if VERIFY_CONVERSATION:
            conversation_receipt = page.evaluate(
                """async () => {
                    const response = await fetch('/api/ask', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({
                            query: '请解释 AXIO7 的 HMM、随机微分方程和深度学习模型如何协同工作。'
                        })
                    });
                    const payload = await response.json();
                    return {
                        httpStatus: response.status,
                        mode: response.headers.get('x-axio7-conversation-mode'),
                        knowledgeVersion:
                            response.headers.get('x-axio7-knowledge-version'),
                        llmRole: response.headers.get('x-axio7-llm-role'),
                        answerLength: payload?.answer?.length ?? 0,
                        hasChinese: /[\\u3400-\\u9fff]/.test(payload?.answer ?? ''),
                        mentionsRust: /Rust/i.test(payload?.answer ?? ''),
                        error: payload?.error ?? null
                    };
                }"""
            )
            if (
                conversation_receipt["httpStatus"] != 200
                or conversation_receipt["mode"] != "model_knowledge"
                or conversation_receipt["knowledgeVersion"]
                != "axio7.model-knowledge.2026-07-25.v1"
                or conversation_receipt["llmRole"] != "grounded_explainer"
                or conversation_receipt["answerLength"] < 80
                or not conversation_receipt["hasChinese"]
                or not conversation_receipt["mentionsRust"]
                or conversation_receipt["error"] is not None
            ):
                raise AssertionError(
                    f"Unexpected production conversation receipt: "
                    f"{conversation_receipt}"
                )
        if VERIFY_RESEARCH_QUERY:
            research_receipt = page.evaluate(
                """async () => {
                    const response = await fetch('/api/ask', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({
                            query: 'Scan NVDA for 5-minute momentum and VWAP evidence.'
                        })
                    });
                    const payload = await response.json();
                    return {
                        httpStatus: response.status,
                        runtime: response.headers.get('x-axio7-model-runtime'),
                        schema: payload?.forecast?.research?.schema_version ?? null,
                        researchStatus: payload?.forecast?.research?.status ?? null,
                        candidateCount:
                            payload?.forecast?.research?.candidates?.length ?? null,
                        error: payload?.error ?? null
                    };
                }"""
            )
            if research_receipt != {
                "httpStatus": 200,
                "runtime": "rust",
                "schema": "axio.evidence-envelope.v1",
                "researchStatus": "DATA_UNAVAILABLE",
                "candidateCount": 0,
                "error": None,
            }:
                raise AssertionError(
                    f"Unexpected production research receipt: {research_receipt}"
                )
        page.screenshot(path=str(ARTIFACTS / "google-model-home.png"), full_page=True)

        signin_entry.click()
        page.wait_for_url(f"{ROOT}/auth/signin?next=%2F")
        page.wait_for_load_state("networkidle")
        page.get_by_role("button", name="Continue with Google").wait_for()
        page.get_by_role("textbox", name="Email").wait_for()
        page.screenshot(path=str(ARTIFACTS / "google-signin.png"), full_page=True)
        oauth_redirect = None
        if VERIFY_OAUTH_INIT:
            page.get_by_role("button", name="Continue with Google").click()
            page.wait_for_timeout(3_000)
            authorize_urls = [
                value for value in oauth_requests if "/auth/v1/authorize" in value
            ]
            if not authorize_urls:
                raise AssertionError(
                    json.dumps(
                        {
                            "oauth": "authorize_request_missing",
                            "page_url": page.url,
                            "failed_requests": failed_requests,
                        }
                    )
                )
            authorize = urlparse(authorize_urls[-1])
            redirect_values = parse_qs(authorize.query).get("redirect_to", [])
            if not redirect_values:
                raise AssertionError("Supabase authorize request omitted redirect_to")
            oauth_redirect = redirect_values[-1]
            expected_callback = f"{ROOT}/auth/callback?next=%2F"
            if oauth_redirect != expected_callback:
                raise AssertionError(
                    f"OAuth redirect mismatch: {oauth_redirect!r} != {expected_callback!r}"
                )
        browser.close()

    if console_errors:
        raise AssertionError(f"Browser console errors: {console_errors}")

    print(
        json.dumps(
            {
                "home": "passed",
                "signin_entry": "passed",
                "existing_google_oauth": "preserved",
                "oauth_redirect": oauth_redirect,
                "rust_runtime_status": "connected",
                "research_receipt": research_receipt,
                "conversation_receipt": conversation_receipt,
                "console_errors": 0,
            }
        )
    )


if __name__ == "__main__":
    main()
