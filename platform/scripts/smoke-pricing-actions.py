from pathlib import Path
import re

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[1]
SCREENSHOT = ROOT / "outputs" / "pricing-actions-restored.png"


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 1440, "height": 1000})
    browser_errors: list[str] = []
    page.on("pageerror", lambda error: browser_errors.append(str(error)))

    page.goto("http://localhost:3000/pricing", wait_until="networkidle")

    assert page.get_by_role(
        "heading", name="Choose your research membership."
    ).is_visible()
    actions = page.get_by_role("link", name=re.compile("Sign in to subscribe"))
    assert actions.count() == 3

    expected_plans = ["starter", "pro", "advanced"]
    for index, plan in enumerate(expected_plans):
        action = actions.nth(index)
        assert action.is_visible()
        assert action.get_attribute("href") == f"https://axio7.com/pricing?plan={plan}"

    assert not browser_errors, browser_errors
    SCREENSHOT.parent.mkdir(parents=True, exist_ok=True)
    page.screenshot(path=str(SCREENSHOT), full_page=True)

    with page.expect_navigation(wait_until="domcontentloaded") as navigation:
        actions.first.click()
    assert navigation.value is not None and navigation.value.ok
    assert page.url == "https://axio7.com/pricing?plan=starter"

    browser.close()

print(f"pricing actions verified; screenshot={SCREENSHOT}")
