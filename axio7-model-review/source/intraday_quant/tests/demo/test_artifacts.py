from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from intraday_quant.demo.artifacts import build_bundle, content_hash, write_fixture
from intraday_quant.demo.contracts import (
    Manifest,
    ModelCard,
    SessionArtifact,
    SessionIndexArtifact,
    SummaryArtifact,
)


def bundle_bytes(root: Path) -> dict[str, bytes]:
    return {
        str(path.relative_to(root)): path.read_bytes()
        for path in sorted(root.rglob("*.json"))
    }


def run_cli(*arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, "-m", "intraday_quant.demo.cli", *arguments],
        check=False,
        capture_output=True,
        text=True,
    )


def test_canonical_hash_ignores_dictionary_insertion_order() -> None:
    """Fails if semantically identical JSON objects receive different artifact hashes."""
    left = {"b": 2, "a": 1}
    right = {"a": 1, "b": 2}
    assert content_hash(left) == content_hash(right)


def test_bundle_is_byte_stable_with_fixed_generation_time(
    tmp_path: Path, sample_parquet: Path
) -> None:
    """Fails if model fitting, ordering, or JSON encoding changes bytes between builds."""
    first = tmp_path / "first"
    second = tmp_path / "second"
    stamp = datetime(2026, 8, 19, 12, tzinfo=timezone.utc)
    build_bundle(sample_parquet, first, stamp)
    build_bundle(sample_parquet, second, stamp)
    assert bundle_bytes(first) == bundle_bytes(second)


def test_cli_fails_closed_for_missing_input(tmp_path: Path) -> None:
    """Fails if a bad build can publish a manifest or report success."""
    result = run_cli(
        "build",
        "--input",
        str(tmp_path / "missing.parquet"),
        "--output",
        str(tmp_path / "out"),
    )
    assert result.returncode != 0
    assert "does not exist" in result.stderr
    assert not (tmp_path / "out" / "manifest.json").exists()


def test_manifest_hashes_the_written_index_and_index_hashes_each_session(
    tmp_path: Path, sample_parquet: Path
) -> None:
    """Fails if any reference hash is computed before final serialization."""
    output = tmp_path / "bundle"
    manifest = build_bundle(
        sample_parquet,
        output,
        datetime(2026, 8, 19, 12, tzinfo=timezone.utc),
    )
    index_path = output / manifest.session_index.path
    assert hashlib.sha256(index_path.read_bytes()).hexdigest() == manifest.session_index.sha256
    index = SessionIndexArtifact.model_validate_json(index_path.read_bytes())
    assert index.artifact_sha256 == manifest.artifact_sha256
    for entry in index.sessions:
        assert hashlib.sha256((output / entry.path).read_bytes()).hexdigest() == entry.sha256


def test_bundle_files_validate_and_share_one_artifact_hash(
    tmp_path: Path, sample_parquet: Path
) -> None:
    """Fails if an independently fetched artifact is invalid or belongs to another build."""
    output = tmp_path / "bundle"
    manifest = build_bundle(
        sample_parquet,
        output,
        datetime(2026, 8, 19, 12, tzinfo=timezone.utc),
    )
    summary = SummaryArtifact.model_validate_json((output / "summary.json").read_bytes())
    model_card = ModelCard.model_validate_json((output / "model-card.json").read_bytes())
    index = SessionIndexArtifact.model_validate_json(
        (output / "sessions" / "index.json").read_bytes()
    )
    sessions = [
        SessionArtifact.model_validate_json((output / entry.path).read_bytes())
        for entry in index.sessions
    ]

    assert Manifest.model_validate_json((output / "manifest.json").read_bytes()) == manifest
    assert index.sessions
    assert {
        manifest.artifact_sha256,
        summary.artifact_sha256,
        model_card.artifact_sha256,
        index.artifact_sha256,
        *(session.provenance.artifact_sha256 for session in sessions),
    } == {manifest.artifact_sha256}
    assert {session.session_date for session in sessions} == {
        entry.date for entry in index.sessions
    }


def test_fixture_is_only_the_fixed_visibly_labeled_session(tmp_path: Path) -> None:
    """Fails if fixture mode can masquerade as historical output or drift in scope."""
    output = tmp_path / "fixture"
    manifest = write_fixture(output)
    index = SessionIndexArtifact.model_validate_json(
        (output / "sessions" / "index.json").read_bytes()
    )
    session = SessionArtifact.model_validate_json(
        (output / "sessions" / "2026-07-24.json").read_bytes()
    )

    assert set(bundle_bytes(output)) == {
        "manifest.json",
        "model-card.json",
        "sessions/2026-07-24.json",
        "sessions/index.json",
        "summary.json",
    }
    assert manifest.status == "UI_FIXTURE"
    assert session.status == "UI_FIXTURE"
    assert [entry.date.isoformat() for entry in index.sessions] == ["2026-07-24"]
    assert session.session_date.isoformat() == "2026-07-24"
    assert session.rows


def test_cli_build_prints_compact_machine_readable_receipt(
    tmp_path: Path, sample_parquet: Path
) -> None:
    """Fails if automation cannot parse provenance and coverage from a successful build."""
    output = tmp_path / "bundle"
    result = run_cli(
        "build",
        "--input",
        str(sample_parquet),
        "--output",
        str(output),
        "--generated-at",
        "2026-08-19T12:00:00Z",
    )

    assert result.returncode == 0, result.stderr
    receipt = json.loads(result.stdout)
    manifest = Manifest.model_validate_json((output / "manifest.json").read_bytes())
    assert receipt == {
        "artifact_sha256": manifest.artifact_sha256,
        "output": str(output),
        "rows": manifest.quality.source_rows,
        "sessions": manifest.split.test_sessions,
        "source_sessions": 40,
        "source_sha256": manifest.dataset_sha256,
    }
    assert result.stdout.count("\n") == 1


def test_cli_schemas_exports_the_versioned_contract_set(tmp_path: Path) -> None:
    """Fails if the CLI cannot refresh all browser-validation schemas."""
    output = tmp_path / "contracts" / "spy-price-demo" / "v1"
    result = run_cli("schemas", "--output", str(output))

    assert result.returncode == 0, result.stderr
    assert {path.name for path in output.iterdir()} == {
        "manifest.schema.json",
        "model-card.schema.json",
        "session-index.schema.json",
        "session.schema.json",
        "summary.schema.json",
    }
