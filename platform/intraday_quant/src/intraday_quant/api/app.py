from __future__ import annotations

import os
from concurrent.futures import ThreadPoolExecutor
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Literal

from fastapi import Depends, FastAPI, Header, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from intraday_quant.models.specification import model_specification
from intraday_quant.service import PROJECT_DIR, ResearchService
from intraday_quant.storage.repository import ResearchRepository


class RunRequest(BaseModel):
    profile: Literal["synthetic", "yahoo_recent"] = "synthetic"


def _database_path() -> Path:
    configured = os.getenv("INTRADAY_QUANT_DB")
    return Path(configured).resolve() if configured else PROJECT_DIR / "state" / "research.duckdb"


def create_app(database_path: str | Path | None = None, *, bootstrap: bool = True) -> FastAPI:
    repository = ResearchRepository(database_path or _database_path())
    service = ResearchService(repository)
    executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="intraday-research")

    @asynccontextmanager
    async def lifespan(_: FastAPI):
        if bootstrap:
            service.bootstrap_existing()
        yield
        executor.shutdown(wait=False, cancel_futures=False)

    application = FastAPI(
        title="AXIO7 Intraday Quant Research API",
        description="Run registry, DuckDB artifacts, model diagnostics, and historical analog search.",
        version="1.0.0",
        lifespan=lifespan,
    )
    application.add_middleware(
        CORSMiddleware,
        allow_origins=[origin.strip() for origin in os.getenv("INTRADAY_QUANT_CORS", "http://localhost:3000").split(",")],
        allow_credentials=False,
        allow_methods=["GET", "POST"],
        allow_headers=["Content-Type", "X-Research-Token"],
    )
    application.state.repository = repository
    application.state.service = service

    def authorize(x_research_token: str | None = Header(default=None)) -> None:
        required = os.getenv("INTRADAY_QUANT_TOKEN")
        if required and x_research_token != required:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid research token")

    @application.get("/health")
    def health() -> dict[str, object]:
        return {
            "status": "ok",
            "service": "intraday-quant-api",
            "database": str(repository.path),
            "profiles": [item["id"] for item in service.profiles()],
        }

    @application.get("/api/v1/profiles")
    def profiles() -> list[dict[str, object]]:
        return service.profiles()

    @application.get("/api/v1/model/specification")
    def specification(profile: Literal["synthetic", "yahoo_recent"] = "synthetic") -> dict[str, object]:
        return model_specification(service.load_profile(profile))

    @application.get("/api/v1/runs")
    def list_runs(limit: int = Query(default=25, ge=1, le=100)) -> list[dict[str, object]]:
        return repository.list_runs(limit)

    @application.post("/api/v1/runs", status_code=status.HTTP_202_ACCEPTED, dependencies=[Depends(authorize)])
    def start_run(request: RunRequest) -> dict[str, object]:
        try:
            run_id = service.queue(request.profile)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        executor.submit(service.execute, request.profile, run_id)
        return {
            "run_id": run_id,
            "status": "queued",
            "profile": request.profile,
            "poll": f"/api/v1/runs/{run_id}",
        }

    @application.get("/api/v1/runs/{run_id}")
    def get_run(run_id: str) -> dict[str, object]:
        run = repository.get_run(run_id)
        if run is None:
            raise HTTPException(status_code=404, detail="run not found")
        return run

    @application.get("/api/v1/runs/{run_id}/overview")
    def run_overview(run_id: str) -> dict[str, object]:
        try:
            return {**repository.overview(run_id), "model_specification": model_specification()}
        except KeyError as exc:
            raise HTTPException(status_code=404, detail="run not found") from exc

    @application.get("/api/v1/runs/{run_id}/artifacts/{artifact}")
    def artifact_rows(
        run_id: str,
        artifact: Literal["candidates", "trades", "analogs", "diagnostics", "audits"],
        limit: int = Query(default=100, ge=1, le=1_000),
    ) -> list[dict[str, object]]:
        if repository.get_run(run_id) is None:
            raise HTTPException(status_code=404, detail="run not found")
        table = {
            "candidates": "candidate_decisions",
            "trades": "trades",
            "analogs": "analog_cases",
            "diagnostics": "model_diagnostics",
            "audits": "research_audits",
        }[artifact]
        return repository.table_rows(table, run_id, limit)

    @application.get("/api/v1/overview")
    def latest_overview(profile: Literal["synthetic", "yahoo_recent"] | None = None) -> dict[str, object]:
        run = repository.latest_run(profile or "yahoo_recent")
        if run is None:
            return {
                "status": "empty",
                "message": "No completed experiment is registered. Start the synthetic profile first.",
                "profiles": service.profiles(),
                "model_specification": model_specification(),
            }
        return {**repository.overview(str(run["run_id"])), "model_specification": model_specification()}

    return application


app = create_app()
