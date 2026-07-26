import pandas as pd

from intraday_quant.reports.theory_audit import theory_performance_audit


def test_theory_audit_distinguishes_win_rate_and_payoff():
    trades = pd.DataFrame({
        "setup": ["weak_anomaly"] * 4,
        "net_return": [-0.01, -0.01, -0.01, 0.05],
    })
    audit = theory_performance_audit(trades).set_index("setup")
    row = audit.loc["ALL"]
    assert row["win_rate"] == 0.25
    assert row["payoff_ratio"] == 5.0
    assert row["expectancy"] > 0
    assert row["verdict"] == "insufficient_sample"

