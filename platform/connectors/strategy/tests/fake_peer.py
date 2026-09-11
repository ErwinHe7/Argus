"""Subprocess fixture only: no SDK, account access, credential, or network."""
import json
import sys
from datetime import datetime, timezone, timedelta
import hashlib
from zoneinfo import ZoneInfo

mode, log = sys.argv[1:3]
mode, _, fixed_clock = mode.partition("@")
for line in sys.stdin:
    request = json.loads(line)
    with open(log, "a", encoding="utf-8") as output:
        output.write(json.dumps(request) + "\n")
    operation = request["operation"]
    if operation == "market":
        now = datetime.fromisoformat(fixed_clock) if fixed_clock else datetime.now(timezone.utc)
        result = {"quote": {"symbol": "SPY", "observed_at": now.isoformat(), "bid": "90", "ask": "90.01", "market_open": True, "source": "synthetic_fixture"}, "evaluation": None}
        if mode in ("evaluate", "entry"):
            dates = [now.date() - timedelta(days=i) for i in range(480, 1, -1) if (now.date() - timedelta(days=i)).weekday() < 5][-240:]
            bars = [{"session_date": str(day), "open_at": datetime(day.year, day.month, day.day, 9, 30, tzinfo=ZoneInfo("America/New_York")).isoformat(), "close_at": datetime(day.year, day.month, day.day, 16, tzinfo=ZoneInfo("America/New_York")).isoformat(), "available_at": now.isoformat(),
                     "open": "100", "high": "105", "low": "98", "close": str(100 + index % 4), "volume": 1000000} for index, day in enumerate(dates)]
            result["quote"].update(bid="110", ask="110.01")
            if mode == "entry":
                bars[-1].update(close="70", low="68")
                result["entry_session"] = str(now.date())
                result["quote"].update(bid="70", ask="70.01")
            result["evaluation"] = {"history_mode": "current_observed_snapshot", "bars": bars, "evidence": {"source": "synthetic_fixture", "dataset_sha256": hashlib.sha256(json.dumps(bars).encode()).hexdigest(), "calendar_source": "synthetic_weekdays_not_actual_calendar", "adjustment_verified": True, "coverage_verified": True, "availability_verified": False, "classification": "synthetic_fixture", "license_scope": "personal_research"}}
    elif operation == "cancel":
        result = {"cancel_requested": True, "terminal": False}
    elif operation == "place":
        intent = request["intent"]
        result = {"error": "synthetic_timeout", "submission_attempted": True} if mode == "unknown" else {
            "id": "fake-exit", "client_id": intent["client_id"], "symbol": intent["symbol"], "side": intent["side"],
            "quantity": intent["quantity"], "filled_quantity": intent["quantity"], "average_fill_price": intent["limit_price"] if intent["side"] == "BUY" else "90", "status": "FILLED_ALL", "terminal": True}
    else:
        result = {"error": "fixture_operation_unsupported"}
    print(json.dumps(result), flush=True)
