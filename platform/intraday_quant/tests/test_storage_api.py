from pathlib import Path

from fastapi.testclient import TestClient

from intraday_quant.api.app import create_app
from intraday_quant.storage.repository import ResearchRepository


def test_repository_creates_queryable_run(tmp_path: Path, config):
    repository = ResearchRepository(tmp_path / "research.duckdb")
    run_id = repository.create_run("synthetic", config)
    run = repository.get_run(run_id)
    assert run is not None
    assert run["status"] == "queued"
    assert run["evidence_tier"] == "synthetic_validation"
    assert run["config"]["target"] == "SPX"


def test_api_health_and_mathematical_contract(tmp_path: Path):
    app = create_app(tmp_path / "api.duckdb", bootstrap=False)
    with TestClient(app) as client:
        health = client.get("/health")
        assert health.status_code == 200
        assert health.json()["status"] == "ok"
        specification = client.get("/api/v1/model/specification")
        assert specification.status_code == 200
        assert "score" in specification.json()["selection"]
        assert client.get("/api/v1/overview").json()["status"] == "empty"
