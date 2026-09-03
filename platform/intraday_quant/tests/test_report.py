from intraday_quant.reports.report import _market_baseline_narrative


def test_market_baseline_narrative_reports_verified_grid_as_available() -> None:
    narrative = _market_baseline_narrative(
        "available_from_verified_point_in_time_grid"
    )

    assert "provides a descriptive full-market unconditional baseline" in narrative
    assert "unavailable from candidate-only artifacts" not in narrative
    assert "neither baseline is promotion evidence" in narrative


def test_market_baseline_narrative_fails_closed_for_rejected_grid() -> None:
    narrative = _market_baseline_narrative(
        "point_in_time_grid_supplied_but_failed_or_insufficient"
    )

    assert "failed its contract or coverage threshold" in narrative
    assert "no full-market unconditional baseline is published" in narrative


def test_market_baseline_narrative_keeps_candidate_only_scope_explicit() -> None:
    narrative = _market_baseline_narrative(
        "not_available_from_candidate_only_label_artifact"
    )

    assert "unavailable from candidate-only artifacts" in narrative
