#!/usr/bin/env python3
"""Generate a fail-closed regular-session AXIO7 production acceptance seal.

The script queries the private Rust API from inside the quantd container so the
research token never appears in the host command line or output. It requires
two identical production-readiness snapshots around an immutable-publication
archive, validates all nine symbols, verifies external artifact pins, binds the
clean source commit and image IDs, and atomically writes a SHA-256 component
manifest.

This is an integrity receipt, not a digital signature and not evidence of model
accuracy, market-data rights beyond the pinned rights receipt, or permission to
place orders.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import re
import shlex
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
from datetime import datetime, time as wall_time, timezone
from pathlib import Path, PurePosixPath
from typing import Any, Iterable
from urllib.parse import urlsplit
from zoneinfo import ZoneInfo


SCHEMA_VERSION = "axio.production-acceptance.v1"
READINESS_SCHEMA_VERSION = "axio.production_readiness.v2"
REQUIRED_SYMBOLS = (
    "SPY",
    "QQQ",
    "NVDA",
    "AAPL",
    "MU",
    "SOXX",
    "NBIS",
    "BE",
    "IGV",
)
REQUIRED_SYMBOL_SET = set(REQUIRED_SYMBOLS)
REQUIRED_HORIZONS = {5, 15, 30, 60}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
IMAGE_ID_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
CONTAINER_ID_RE = re.compile(r"^[0-9a-f]{64}$")
PUBLIC_HOST_RE = re.compile(
    r"^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+"
    r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$"
)
REQUIRED_RUNTIME_SERVICES = ("quantd", "web", "caddy", "monitor-scheduler")


class SealError(RuntimeError):
    """Expected fail-closed acceptance failure."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SealError(message)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def require_regular_tree(path: Path, name: str) -> None:
    require(
        path.is_dir() and not path.is_symlink(),
        f"{name} is missing or is not a real directory",
    )
    for child in path.rglob("*"):
        require(not child.is_symlink(), f"{name} contains a symbolic link")


def validate_private_attestation_storage(
    private_directory: Path,
    attestation_path: Path,
    *,
    required: bool,
) -> None:
    directory_stat = private_directory.stat(follow_symlinks=False)
    require(
        stat.S_ISDIR(directory_stat.st_mode)
        and not private_directory.is_symlink(),
        "private owner-attestation directory is not a real directory",
    )
    if os.name == "posix":
        require(
            stat.S_IMODE(directory_stat.st_mode) == 0o700,
            "private owner-attestation directory mode must be 0700",
        )

    entries = list(private_directory.iterdir())
    expected_entries = [attestation_path] if required else []
    require(
        entries == expected_entries,
        "private owner-attestation directory has an unexpected file set",
    )
    if not required:
        return

    file_stat = attestation_path.stat(follow_symlinks=False)
    require(
        stat.S_ISREG(file_stat.st_mode)
        and not attestation_path.is_symlink()
        and file_stat.st_nlink == 1,
        "private owner-attestation artifact must be one regular, unlinked file",
    )
    if os.name == "posix":
        require(
            stat.S_IMODE(file_stat.st_mode) == 0o600,
            "private owner-attestation artifact mode must be 0600",
        )


def read_dotenv_value(path: Path, key: str) -> str | None:
    value: str | None = None
    prefix = f"{key}="
    with path.open("r", encoding="utf-8") as stream:
        for raw_line in stream:
            line = raw_line.rstrip("\r\n")
            if line.startswith(prefix):
                value = line[len(prefix) :]
    return value


def canonical_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False).encode("utf-8")
        + b"\n"
    )


def run_command(
    command: list[str],
    *,
    cwd: Path | None = None,
    environment: dict[str, str] | None = None,
    binary: bool = False,
) -> bytes | str:
    result = subprocess.run(
        command,
        cwd=cwd,
        env=environment,
        check=False,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=not binary,
    )
    if result.returncode != 0:
        display = " ".join(shlex.quote(part) for part in command)
        raise SealError(
            f"command failed with exit {result.returncode}: {display}; "
            "captured stderr was suppressed to avoid leaking runtime configuration"
        )
    return result.stdout


def parse_json_bytes(raw: bytes | str, name: str) -> dict[str, Any]:
    try:
        value = json.loads(raw)
    except (TypeError, json.JSONDecodeError) as error:
        raise SealError(f"{name} is not valid JSON") from error
    require(isinstance(value, dict), f"{name} must be a JSON object")
    return value


def read_pinned_json(path: Path, expected_sha256: str, name: str) -> dict[str, Any]:
    raw = path.read_bytes()
    require(
        sha256_bytes(raw) == expected_sha256,
        f"host {name} changed after container pin verification",
    )
    return parse_json_bytes(raw, name)


def parse_timestamp(raw: Any, field: str) -> datetime:
    require(isinstance(raw, str) and raw, f"{field} is missing")
    normalized = raw[:-1] + "+00:00" if raw.endswith("Z") else raw
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as error:
        raise SealError(f"{field} is not an ISO-8601 timestamp") from error
    require(parsed.tzinfo is not None, f"{field} has no timezone")
    return parsed.astimezone(timezone.utc)


def normalize_public_origin(raw: str) -> str:
    require(isinstance(raw, str) and raw, "public origin is missing")
    require(
        not any(character.isspace() or ord(character) < 32 or ord(character) == 127 for character in raw),
        "public origin contains whitespace or control characters",
    )
    try:
        parsed = urlsplit(raw)
        port = parsed.port
    except ValueError as error:
        raise SealError("public origin is malformed") from error
    require(parsed.scheme == "https", "public origin must use HTTPS")
    require(
        parsed.username is None and parsed.password is None,
        "public origin must not contain credentials",
    )
    require(
        not parsed.query and not parsed.fragment,
        "public origin must not contain a query or fragment",
    )
    require(
        parsed.path in ("", "/"),
        "public origin must not contain a non-root path",
    )
    require(port in (None, 443), "public origin must use the default HTTPS port")
    hostname = (parsed.hostname or "").lower()
    require(
        PUBLIC_HOST_RE.fullmatch(hostname) is not None,
        "public origin hostname is invalid",
    )
    return f"https://{hostname}"


def validate_public_health(
    health: dict[str, Any],
    *,
    expected_commit: str,
    checked_at: datetime,
    max_age_seconds: int = 60,
) -> dict[str, Any]:
    environment = health.get("env")
    require(isinstance(environment, dict), "public health environment is missing")
    require(
        environment.get("deployment") == expected_commit,
        "public health deployment does not match the release commit",
    )
    observed_at = parse_timestamp(health.get("ts"), "public health ts")
    age_seconds = (checked_at - observed_at).total_seconds()
    require(
        -5 <= age_seconds <= max_age_seconds,
        "public health response timestamp is stale or implausibly future-dated",
    )
    return {
        "source_commit": expected_commit,
        "observed_at": observed_at.isoformat().replace("+00:00", "Z"),
        "checked_at": checked_at.isoformat().replace("+00:00", "Z"),
    }


def probe_public_health(
    public_origin: str,
    *,
    expected_commit: str,
    environment: dict[str, str],
) -> dict[str, Any]:
    endpoint = "/api/health"
    raw = run_command(
        [
            "curl",
            "--fail",
            "--silent",
            "--show-error",
            "--proto",
            "=https",
            "--tlsv1.2",
            "--connect-timeout",
            "10",
            "--max-time",
            "30",
            "--write-out",
            "\n%{http_code}",
            f"{public_origin}{endpoint}",
        ],
        environment=environment,
    )
    body, separator, status_code = str(raw).rpartition("\n")
    require(
        separator == "\n" and status_code == "200",
        "public health endpoint did not return HTTP 200",
    )
    checked_at = datetime.now(timezone.utc)
    health = parse_json_bytes(body, "public health")
    validated = validate_public_health(
        health,
        expected_commit=expected_commit,
        checked_at=checked_at,
    )
    return {
        "origin": public_origin,
        "endpoint": endpoint,
        "verified": True,
        "tls_verified": True,
        **validated,
    }


def is_regular_session_clock(value: datetime) -> bool:
    eastern = value.astimezone(ZoneInfo("America/New_York"))
    if eastern.weekday() >= 5:
        return False
    return wall_time(9, 30) <= eastern.time().replace(tzinfo=None) <= wall_time(16, 0)


def readiness_fingerprint(receipt: dict[str, Any]) -> str:
    forecasts = receipt.get("forecasts")
    require(isinstance(forecasts, list), "readiness forecasts are missing")
    projection = {
        "status": receipt.get("status"),
        "public_realtime_research_ready": receipt.get(
            "public_realtime_research_ready"
        ),
        "market_data": receipt.get("market_data"),
        "artifacts": receipt.get("artifacts"),
        "forecasts": [
            {
                "symbol": row.get("symbol"),
                "live_inference": row.get("live_inference"),
                "artifact_present": row.get("artifact_present"),
                "validation_status": row.get("validation_status"),
                "freshness": row.get("freshness"),
                "horizon_coverage": row.get("horizon_coverage"),
                "calibration": row.get("calibration"),
                "promotion_registry_matches": row.get(
                    "promotion_registry_matches"
                ),
                "ledger_backed": row.get("ledger_backed"),
                "ready": row.get("ready"),
            }
            for row in forecasts
            if isinstance(row, dict)
        ],
    }
    return sha256_bytes(canonical_json_bytes(projection))


def validate_readiness(
    receipt: dict[str, Any],
    *,
    capture_time: datetime,
    max_cutoff_skew_seconds: int,
) -> list[dict[str, Any]]:
    require(
        receipt.get("schema_version") == READINESS_SCHEMA_VERSION,
        "unsupported production-readiness schema",
    )
    require(receipt.get("status") == "READY", "production readiness is not READY")
    require(
        receipt.get("public_realtime_research_ready") is True,
        "public realtime research is not ready",
    )

    market_data = receipt.get("market_data")
    require(isinstance(market_data, dict), "market-data readiness is missing")
    require(
        str(market_data.get("selected_provider", "")).lower() == "databento",
        "selected market-data provider is not Databento",
    )
    require(
        str(market_data.get("selected_product", "")).upper() == "EQUS.MINI",
        "selected market-data product is not EQUS.MINI",
    )
    require(market_data.get("live_enabled") is True, "live market data is disabled")
    rights = market_data.get("public_use_rights")
    require(isinstance(rights, dict), "public-use rights readiness is missing")
    require(
        rights.get("status") == "READY"
        and rights.get("reason")
        in ("VERIFIED", "OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT"),
        "the pinned public-use rights receipt has no accepted evidence basis",
    )
    require(
        market_data.get("provider_entitlement") == "READY",
        "provider technical entitlement is not ready",
    )
    require(
        market_data.get("stream_freshness") == "FRESH"
        and market_data.get("feed_freshness") == "FRESH",
        "stream or all-symbol feed freshness is not FRESH",
    )

    artifacts = receipt.get("artifacts")
    require(isinstance(artifacts, dict), "artifact readiness is missing")
    require(
        artifacts.get("promotion_registry_present") is True
        and artifacts.get("promotion_registry_status") == "ACTIVE_PINNED",
        "v2 promotion registry is not active and independently pinned",
    )
    require(
        artifacts.get("calibration_registry_present") is True
        and artifacts.get("calibration_registry_status") == "PROMOTED",
        "v2 calibration registry is not promoted",
    )
    require(
        artifacts.get("prediction_ledger_present") is True,
        "append-only prediction ledger is unavailable",
    )

    forecasts = receipt.get("forecasts")
    require(isinstance(forecasts, list), "forecast readiness rows are missing")
    require(len(forecasts) == len(REQUIRED_SYMBOLS), "readiness must contain nine rows")
    require(
        all(isinstance(row, dict) for row in forecasts),
        "forecast readiness contains a non-object row",
    )
    by_symbol = {str(row.get("symbol", "")).upper(): row for row in forecasts}
    require(
        len(by_symbol) == len(forecasts) and set(by_symbol) == REQUIRED_SYMBOL_SET,
        "forecast readiness does not contain the exact nine-symbol universe",
    )

    cutoffs: list[datetime] = []
    summaries: list[dict[str, Any]] = []
    for symbol in REQUIRED_SYMBOLS:
        row = by_symbol[symbol]
        live = row.get("live_inference")
        require(isinstance(live, dict), f"{symbol} live-inference readiness is missing")
        require(
            row.get("ready") is True
            and live.get("ready") is True
            and live.get("required") is True
            and live.get("status_available") is True,
            f"{symbol} is not fully ready",
        )
        require(
            live.get("status") == "PUBLISHED"
            and live.get("stage") == "PUBLISHED"
            and live.get("reason_code") is None,
            f"{symbol} is not in the PUBLISHED lifecycle state",
        )
        require(
            live.get("status_freshness") == "FRESH",
            f"{symbol} inference status is not fresh",
        )
        require(
            live.get("context_blockers") == [],
            f"{symbol} has causal-context blockers",
        )
        require(
            live.get("forecast_committed") is True
            and live.get("receipt_committed") is True
            and live.get("ledger_persisted") is True,
            f"{symbol} publication transaction is incomplete",
        )
        require(
            row.get("artifact_present") is True
            and row.get("validation_status") == "PASSED"
            and row.get("freshness") == "FRESH"
            and row.get("horizon_coverage") == "COMPLETE"
            and row.get("calibration") == "PROMOTED"
            and row.get("promotion_registry_matches") is True
            and row.get("ledger_backed") is True,
            f"{symbol} model/promotion/calibration contract is incomplete",
        )

        cutoff = parse_timestamp(live.get("cutoff"), f"{symbol}.cutoff")
        latest_input = parse_timestamp(
            live.get("latest_input_available_at"),
            f"{symbol}.latest_input_available_at",
        )
        require(
            cutoff <= capture_time and latest_input <= capture_time,
            f"{symbol} contains a future causal timestamp",
        )
        require(
            is_regular_session_clock(cutoff),
            f"{symbol} cutoff is outside the US regular-session clock",
        )
        compute_ms = live.get("compute_ms")
        end_to_end_ms = live.get("end_to_end_ms")
        budget_ms = live.get("budget_ms")
        require(
            isinstance(compute_ms, int)
            and isinstance(end_to_end_ms, int)
            and isinstance(budget_ms, int)
            and 0 <= compute_ms <= end_to_end_ms <= budget_ms,
            f"{symbol} latency is missing, negative, or outside budget",
        )
        cutoffs.append(cutoff)
        summaries.append(
            {
                "symbol": symbol,
                "cutoff": cutoff.isoformat().replace("+00:00", "Z"),
                "latest_input_available_at": latest_input.isoformat().replace(
                    "+00:00", "Z"
                ),
                "compute_ms": compute_ms,
                "end_to_end_ms": end_to_end_ms,
                "budget_ms": budget_ms,
                "horizons_minutes": sorted(REQUIRED_HORIZONS),
                "publication_state": "PUBLISHED",
                "execution_enabled": False,
            }
        )

    skew = int((max(cutoffs) - min(cutoffs)).total_seconds())
    require(
        skew <= max_cutoff_skew_seconds,
        f"nine-symbol cutoff skew {skew}s exceeds {max_cutoff_skew_seconds}s",
    )
    return summaries


def tar_member_bytes(bundle: tarfile.TarFile, name: str) -> bytes:
    try:
        member = bundle.getmember(name)
    except KeyError as error:
        raise SealError(f"publication bundle is missing {name}") from error
    require(member.isfile(), f"publication bundle member is not a file: {name}")
    stream = bundle.extractfile(member)
    require(stream is not None, f"cannot read publication bundle member: {name}")
    return stream.read()


def validate_publication_bundle(
    bundle_bytes: bytes,
    readiness: dict[str, Any],
) -> tuple[list[dict[str, Any]], dict[str, str]]:
    try:
        bundle = tarfile.open(fileobj=io.BytesIO(bundle_bytes), mode="r:gz")
    except tarfile.TarError as error:
        raise SealError("immutable-publication bundle is not a valid gzip tar") from error

    with bundle:
        members = bundle.getmembers()
        require(members, "immutable-publication bundle is empty")
        for member in members:
            path = PurePosixPath(member.name)
            require(
                not path.is_absolute() and ".." not in path.parts,
                "immutable-publication bundle contains an unsafe member path",
            )

        readiness_rows = {
            str(row["symbol"]).upper(): row
            for row in readiness["forecasts"]
            if isinstance(row, dict) and "symbol" in row
        }
        publication_summaries: list[dict[str, Any]] = []
        member_hashes: dict[str, str] = {}

        for symbol in REQUIRED_SYMBOLS:
            lower = symbol.lower()
            status_name = (
                "databento_inference_status.json"
                if symbol == "SPY"
                else f"databento_inference_status_{lower}.json"
            )
            receipt_name = f"databento_inference_receipt_{lower}_latest.json"
            status_bytes = tar_member_bytes(bundle, status_name)
            receipt_bytes = tar_member_bytes(bundle, receipt_name)
            status = parse_json_bytes(status_bytes, f"{symbol} inference status")
            receipt = parse_json_bytes(receipt_bytes, f"{symbol} inference receipt")
            member_hashes[status_name] = sha256_bytes(status_bytes)
            member_hashes[receipt_name] = sha256_bytes(receipt_bytes)

            live = readiness_rows[symbol]["live_inference"]
            require(
                status.get("model_symbol") == symbol
                and status.get("status") == "PUBLISHED"
                and status.get("stage") == "PUBLISHED"
                and status.get("reason_code") is None,
                f"{symbol} archived status is not PUBLISHED",
            )
            require(
                status.get("execution_enabled") is False
                and status.get("forecast_committed") is True
                and status.get("receipt_committed") is True
                and status.get("ledger_persisted") is True,
                f"{symbol} archived status is unsafe or incomplete",
            )
            require(
                status.get("cutoff") == live.get("cutoff")
                and status.get("latest_input_available_at")
                == live.get("latest_input_available_at")
                and status.get("compute_ms") == live.get("compute_ms")
                and status.get("end_to_end_ms") == live.get("end_to_end_ms")
                and status.get("budget_ms") == live.get("budget_ms"),
                f"{symbol} archived status does not match the readiness snapshot",
            )

            require(
                str(receipt.get("provider", "")).lower() == "databento"
                and str(receipt.get("dataset", "")).upper() == "EQUS.MINI"
                and receipt.get("model_symbol") == symbol,
                f"{symbol} receipt provider/dataset/model identity is invalid",
            )
            require(
                receipt.get("execution_enabled") is False
                and receipt.get("ledger_persisted") is True,
                f"{symbol} receipt is execution-enabled or not ledger-backed",
            )
            require(
                receipt.get("latest_input_available_at")
                == live.get("latest_input_available_at"),
                f"{symbol} receipt causal availability does not match readiness",
            )
            require(
                isinstance(receipt.get("end_to_end_ms"), int)
                and isinstance(receipt.get("budget_ms"), int)
                and 0 <= receipt["end_to_end_ms"] <= receipt["budget_ms"],
                f"{symbol} receipt violates its latency budget",
            )
            prediction_ids = receipt.get("prediction_ids")
            require(
                isinstance(prediction_ids, list)
                and len(prediction_ids) == len(REQUIRED_HORIZONS)
                and len(set(prediction_ids)) == len(REQUIRED_HORIZONS)
                and all(isinstance(value, str) and value for value in prediction_ids),
                f"{symbol} receipt does not contain four unique prediction IDs",
            )
            forecast_sha256 = str(receipt.get("forecast_sha256", "")).lower()
            require(
                SHA256_RE.fullmatch(forecast_sha256) is not None,
                f"{symbol} receipt forecast SHA-256 is invalid",
            )
            envelopes = receipt.get("source_envelopes")
            require(
                isinstance(envelopes, list)
                and len(envelopes) > 0
                and receipt.get("source_envelope_count") == len(envelopes),
                f"{symbol} receipt has no complete source-envelope set",
            )

            prefix = f"databento_publications/{lower}/"
            matches: list[tuple[str, bytes, dict[str, Any]]] = []
            for member in members:
                if not member.isfile() or not member.name.startswith(prefix):
                    continue
                raw = tar_member_bytes(bundle, member.name)
                publication = parse_json_bytes(raw, f"{symbol} immutable publication")
                embedded_receipt = publication.get("receipt")
                if (
                    isinstance(embedded_receipt, dict)
                    and embedded_receipt.get("forecast_sha256") == forecast_sha256
                    and embedded_receipt.get("model_symbol") == symbol
                ):
                    matches.append((member.name, raw, publication))

            require(
                len(matches) == 1,
                f"{symbol} must have exactly one immutable publication matching its latest receipt",
            )
            publication_name, publication_bytes, publication = matches[0]
            forecast_json = publication.get("forecast_json")
            require(
                isinstance(forecast_json, str)
                and sha256_bytes(forecast_json.encode("utf-8")) == forecast_sha256,
                f"{symbol} immutable publication forecast bytes do not match the receipt",
            )
            require(
                publication.get("model_symbol") == symbol
                and publication.get("receipt") == receipt,
                f"{symbol} immutable publication is not bound to the archived receipt",
            )
            member_hashes[publication_name] = sha256_bytes(publication_bytes)
            publication_summaries.append(
                {
                    "symbol": symbol,
                    "publication_member": publication_name,
                    "publication_sha256": member_hashes[publication_name],
                    "forecast_sha256": forecast_sha256,
                    "prediction_id_count": len(prediction_ids),
                    "ledger_persisted": True,
                    "execution_enabled": False,
                }
            )

    return publication_summaries, dict(sorted(member_hashes.items()))


def compose_api_json(compose: list[str], endpoint: str, environment: dict[str, str]) -> dict[str, Any]:
    command = (
        'set -eu; '
        'clean_token="$(printf %s "$INTRADAY_QUANT_TOKEN" | tr -d "\\r\\n")"; '
        'test "$clean_token" = "$INTRADAY_QUANT_TOKEN"; '
        'printf "X-Research-Token: %s\\n" "$clean_token" | '
        'curl --fail --silent --show-error --header @- '
        f"http://127.0.0.1:8001{endpoint}"
    )
    raw = run_command(
        compose + ["exec", "-T", "quantd", "sh", "-lc", command],
        environment=environment,
    )
    return parse_json_bytes(raw, endpoint)


def publication_tar_command() -> str:
    status_files = [
        "databento_inference_status.json",
        *[
            f"databento_inference_status_{symbol.lower()}.json"
            for symbol in REQUIRED_SYMBOLS
            if symbol != "SPY"
        ],
    ]
    receipt_files = [
        f"databento_inference_receipt_{symbol.lower()}_latest.json"
        for symbol in REQUIRED_SYMBOLS
    ]
    members = [
        "databento_stream_status.json",
        *status_files,
        *receipt_files,
        "databento_publications",
    ]
    quoted = " ".join(shlex.quote(member) for member in members)
    return (
        "set -eu; "
        "test -d /app/data/live/databento_publications; "
        f"tar -C /app/data/live -czf - {quoted}"
    )


def capture_consistent_state(
    compose: list[str],
    environment: dict[str, str],
    *,
    attempts: int,
) -> tuple[dict[str, Any], bytes]:
    last_error: Exception | None = None
    for attempt in range(1, attempts + 1):
        try:
            before = compose_api_json(
                compose, "/api/v1/system/readiness", environment
            )
            bundle = run_command(
                compose
                + [
                    "exec",
                    "-T",
                    "quantd",
                    "sh",
                    "-lc",
                    publication_tar_command(),
                ],
                environment=environment,
                binary=True,
            )
            require(isinstance(bundle, bytes), "publication capture returned text")
            after = compose_api_json(compose, "/api/v1/system/readiness", environment)
            require(
                readiness_fingerprint(before) == readiness_fingerprint(after),
                "readiness changed while immutable publications were captured",
            )
            validate_publication_bundle(bundle, after)
            return after, bundle
        except SealError as error:
            last_error = error
            if attempt < attempts:
                time.sleep(1)
    raise SealError(
        f"could not capture one consistent nine-symbol publication generation "
        f"after {attempts} attempts: {last_error}"
    )


def parse_artifact_manifest(raw: str) -> dict[str, str]:
    manifest: dict[str, str] = {}
    for line in raw.splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})\s+(.+)", line.strip())
        require(match is not None, "artifact hash manifest contains an invalid line")
        digest, raw_path = match.groups()
        path = raw_path.removeprefix("/app/")
        require(
            not path.startswith("/") and ".." not in PurePosixPath(path).parts,
            "artifact hash manifest contains an unsafe path",
        )
        require(path not in manifest, "artifact hash manifest contains a duplicate path")
        manifest[path] = digest
    require(manifest, "artifact hash manifest is empty")
    return dict(sorted(manifest.items()))


def validate_rights_evidence_binding(
    rights_receipt: dict[str, Any],
    artifact_manifest: dict[str, str],
    technical_receipt_path: Path,
    private_owner_attestation_path: Path,
    *,
    readiness_reason: Any,
) -> tuple[str | None, str | None]:
    if rights_receipt.get("evidence_kind") != "ACCOUNT_OWNER_ATTESTATION":
        require(
            readiness_reason == "VERIFIED",
            "vendor-evidence rights do not have VERIFIED readiness",
        )
        return None, None

    require(
        readiness_reason == "OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT",
        "owner-attested rights have the wrong readiness evidence basis",
    )
    expected_attestation_sha256 = rights_receipt.get(
        "evidence_artifact_sha256"
    )
    require(
        isinstance(expected_attestation_sha256, str)
        and SHA256_RE.fullmatch(expected_attestation_sha256.lower()) is not None,
        "owner-attested rights have an invalid private-attestation hash",
    )
    expected_attestation_sha256 = expected_attestation_sha256.lower()
    require(
        private_owner_attestation_path.is_file()
        and not private_owner_attestation_path.is_symlink(),
        "private owner-attestation artifact is missing",
    )
    require(
        sha256_file(private_owner_attestation_path)
        == expected_attestation_sha256,
        "private owner-attestation artifact differs from the rights-receipt pin",
    )
    owner_attestation = rights_receipt.get("owner_attestation")
    require(
        isinstance(owner_attestation, dict),
        "owner-attested rights are missing owner_attestation",
    )
    expected_sha256 = owner_attestation.get(
        "technical_entitlement_receipt_sha256"
    )
    require(
        isinstance(expected_sha256, str)
        and SHA256_RE.fullmatch(expected_sha256.lower()) is not None,
        "owner-attested rights have an invalid technical-receipt hash",
    )
    expected_sha256 = expected_sha256.lower()
    require(
        technical_receipt_path.is_file()
        and not technical_receipt_path.is_symlink(),
        "owner-attested technical-entitlement receipt is missing",
    )
    observed_sha256 = sha256_file(technical_receipt_path)
    require(
        observed_sha256 == expected_sha256,
        "technical-entitlement receipt differs from the owner-attestation pin",
    )
    require(
        artifact_manifest.get(
            "data/evidence/databento_technical_entitlement_latest.json"
        )
        == expected_sha256,
        "container technical-entitlement receipt differs from its owner-attestation pin",
    )
    require(
        not any(
            "private-rights-evidence" in PurePosixPath(path).parts
            for path in artifact_manifest
        ),
        "private owner-attestation artifact must not be mounted in the container",
    )
    return expected_sha256, expected_attestation_sha256


def image_receipt(
    compose: list[str],
    service: str,
    expected_commit: str,
    environment: dict[str, str],
) -> dict[str, Any]:
    image_id = str(
        run_command(
            compose + ["images", "-q", service],
            environment=environment,
        )
    ).strip().splitlines()
    require(len(image_id) == 1, f"cannot resolve one image for {service}")
    require(
        IMAGE_ID_RE.fullmatch(image_id[0]) is not None,
        f"{service} image ID is not a content-addressed SHA-256",
    )
    inspect_raw = run_command(
        ["docker", "image", "inspect", image_id[0]],
        environment=environment,
    )
    try:
        inspected = json.loads(inspect_raw)
    except json.JSONDecodeError as error:
        raise SealError(f"cannot parse {service} image metadata") from error
    require(
        isinstance(inspected, list)
        and len(inspected) == 1
        and isinstance(inspected[0], dict),
        f"unexpected {service} image metadata",
    )
    item = inspected[0]
    labels = item.get("Config", {}).get("Labels") or {}
    require(
        labels.get("org.opencontainers.image.revision") == expected_commit,
        f"{service} image revision label does not match the clean checkout",
    )
    repo_digests = item.get("RepoDigests") or []
    require(
        isinstance(repo_digests, list)
        and all(isinstance(value, str) for value in repo_digests),
        f"{service} image repo digests are malformed",
    )
    return {
        "image_id": image_id[0],
        "source_commit_label": expected_commit,
        "repo_digests": sorted(repo_digests),
        "created": item.get("Created"),
        "os": item.get("Os"),
        "architecture": item.get("Architecture"),
    }


def parse_runtime_service_state(
    service: str,
    raw: str,
    *,
    expected_image_id: str | None = None,
) -> dict[str, Any]:
    fields = raw.strip().split("|")
    require(len(fields) == 6, f"{service} runtime state is malformed")
    (
        container_id,
        image_id,
        running_raw,
        restarting_raw,
        dead_raw,
        health_status,
    ) = fields
    require(
        CONTAINER_ID_RE.fullmatch(container_id) is not None,
        f"{service} container ID is invalid",
    )
    require(
        IMAGE_ID_RE.fullmatch(image_id) is not None,
        f"{service} running image ID is invalid",
    )
    require(
        running_raw in ("true", "false")
        and restarting_raw in ("true", "false")
        and dead_raw in ("true", "false"),
        f"{service} runtime booleans are invalid",
    )
    running = running_raw == "true"
    restarting = restarting_raw == "true"
    dead = dead_raw == "true"
    require(
        running and not restarting and not dead,
        f"{service} is not stably running",
    )
    if service in ("quantd", "web"):
        require(
            health_status == "healthy",
            f"{service} liveness healthcheck is not healthy",
        )
    require(
        health_status in ("none", "starting", "healthy", "unhealthy"),
        f"{service} health status is invalid",
    )
    if expected_image_id is not None:
        require(
            image_id == expected_image_id,
            f"{service} running image differs from the sealed image",
        )
    return {
        "container_id": container_id,
        "image_id": image_id,
        "running": running,
        "restarting": restarting,
        "dead": dead,
        "health_status": health_status,
    }


def inspect_runtime_services(
    compose: list[str],
    environment: dict[str, str],
    *,
    expected_image_ids: dict[str, str],
) -> dict[str, dict[str, Any]]:
    states: dict[str, dict[str, Any]] = {}
    inspect_format = (
        "{{.Id}}|{{.Image}}|{{.State.Running}}|{{.State.Restarting}}|"
        "{{.State.Dead}}|"
        "{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}"
    )
    for service in REQUIRED_RUNTIME_SERVICES:
        raw_ids = str(
            run_command(
                compose + ["ps", "-q", service],
                environment=environment,
            )
        ).strip().splitlines()
        require(len(raw_ids) == 1, f"cannot resolve exactly one {service} container")
        raw_state = str(
            run_command(
                ["docker", "inspect", "--format", inspect_format, raw_ids[0]],
                environment=environment,
            )
        )
        states[service] = parse_runtime_service_state(
            service,
            raw_state,
            expected_image_id=expected_image_ids.get(service),
        )
    return states


def parse_container_mounts(raw: str, name: str) -> list[dict[str, Any]]:
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as error:
        raise SealError(f"{name} mount inspection is not valid JSON") from error
    require(isinstance(value, list), f"{name} mount inspection is not a list")
    require(
        all(isinstance(mount, dict) for mount in value),
        f"{name} mount inspection contains a non-object entry",
    )
    return value


def paths_overlap(first: Path, second: Path) -> bool:
    try:
        first.relative_to(second)
        return True
    except ValueError:
        pass
    try:
        second.relative_to(first)
        return True
    except ValueError:
        return False


def validate_no_private_bind_mounts(
    mounts: list[dict[str, Any]],
    *,
    private_directory: Path,
) -> None:
    private_directory = private_directory.resolve(strict=True)
    for mount in mounts:
        if mount.get("Type") != "bind":
            continue
        source = mount.get("Source")
        require(
            isinstance(source, str) and source,
            "Compose bind mount has no source",
        )
        try:
            resolved_source = Path(source).resolve(strict=True)
        except OSError as error:
            raise SealError("Compose bind mount source cannot be resolved") from error
        require(
            not paths_overlap(resolved_source, private_directory),
            "private owner-attestation storage is mounted into a container",
        )


def validate_quantd_mounts(
    mounts: list[dict[str, Any]],
    *,
    runtime: Path,
    expected_commit: str,
) -> None:
    expected_binds = {
        "/app/data/normalized": (runtime / "quant-normalized").resolve(strict=True),
        "/app/data/manifests": (runtime / "quant-manifests").resolve(strict=True),
        "/app/data/rights": (runtime / "quant-rights").resolve(strict=True),
        "/app/data/evidence": (runtime / "quant-evidence").resolve(strict=True),
        "/app/data/promotion": (runtime / "quant-promotion").resolve(strict=True),
        "/app/data/calibration": (runtime / "quant-calibration").resolve(strict=True),
    }
    expected_volumes = {
        "/app/data/live": ("axio7_quant-live", True),
        "/app/data/state": ("axio7_quant-state", True),
        "/app/data/models/universe": (
            f"axio7_quant-models-{expected_commit}",
            False,
        ),
    }
    expected_destinations = set(expected_binds) | set(expected_volumes)
    observed_destinations: set[str] = set()

    for mount in mounts:
        destination = mount.get("Destination")
        require(
            isinstance(destination, str)
            and destination in expected_destinations
            and destination not in observed_destinations,
            "quantd has an unexpected or duplicate mount destination",
        )
        observed_destinations.add(destination)
        if destination in expected_binds:
            require(
                mount.get("Type") == "bind" and mount.get("RW") is False,
                f"quantd bind mount is not read-only: {destination}",
            )
            source = mount.get("Source")
            require(
                isinstance(source, str) and source,
                f"quantd bind mount source is missing: {destination}",
            )
            try:
                resolved_source = Path(source).resolve(strict=True)
            except OSError as error:
                raise SealError(
                    f"quantd bind mount source cannot be resolved: {destination}"
                ) from error
            require(
                resolved_source == expected_binds[destination],
                f"quantd bind mount source is unexpected: {destination}",
            )
        else:
            expected_name, expected_rw = expected_volumes[destination]
            require(
                mount.get("Type") == "volume"
                and mount.get("Name") == expected_name
                and mount.get("RW") is expected_rw,
                f"quantd named-volume mount is unexpected: {destination}",
            )

    require(
        observed_destinations == expected_destinations,
        "quantd mount set is incomplete",
    )


def verify_runtime_mount_isolation(
    compose: list[str],
    environment: dict[str, str],
    *,
    runtime: Path,
    private_attestation_directory: Path,
    expected_commit: str,
) -> None:
    quantd_ids = str(
        run_command(
            compose + ["ps", "-q", "quantd"],
            environment=environment,
        )
    ).strip().splitlines()
    require(
        len(quantd_ids) == 1
        and CONTAINER_ID_RE.fullmatch(quantd_ids[0]) is not None,
        "cannot resolve one quantd container for mounts",
    )
    quantd_mounts = parse_container_mounts(
        str(
            run_command(
                [
                    "docker",
                    "inspect",
                    "--format",
                    "{{json .Mounts}}",
                    quantd_ids[0],
                ],
                environment=environment,
            )
        ).strip(),
        "quantd",
    )
    validate_quantd_mounts(
        quantd_mounts,
        runtime=runtime,
        expected_commit=expected_commit,
    )

    project_ids = str(
        run_command(
            [
                "docker",
                "ps",
                "-q",
                "--filter",
                "label=com.docker.compose.project=axio7",
            ],
            environment=environment,
        )
    ).strip().splitlines()
    require(
        project_ids
        and len(project_ids) == len(set(project_ids))
        and all(CONTAINER_ID_RE.fullmatch(value) is not None for value in project_ids),
        "cannot resolve the running Compose container set for mount isolation",
    )
    for container_id in project_ids:
        mounts = parse_container_mounts(
            str(
                run_command(
                    [
                        "docker",
                        "inspect",
                        "--format",
                        "{{json .Mounts}}",
                        container_id,
                    ],
                    environment=environment,
                )
            ).strip(),
            "Compose container",
        )
        validate_no_private_bind_mounts(
            mounts,
            private_directory=private_attestation_directory,
        )


def verify_caddy_binding(
    compose: list[str],
    environment: dict[str, str],
    *,
    public_origin: str,
    host_caddyfile_sha256: str,
) -> dict[str, Any]:
    hostname = urlsplit(public_origin).hostname
    require(hostname is not None, "normalized public hostname is missing")
    caddy_domain_raw = str(
        run_command(
            compose
            + [
                "exec",
                "-T",
                "caddy",
                "sh",
                "-ec",
                'test -n "$AXIO7_DOMAIN"; printf %s "$AXIO7_DOMAIN"',
            ],
            environment=environment,
        )
    )
    require(
        caddy_domain_raw == caddy_domain_raw.strip(),
        "Caddy domain contains surrounding whitespace",
    )
    caddy_domain = caddy_domain_raw.lower()
    require(
        PUBLIC_HOST_RE.fullmatch(caddy_domain) is not None,
        "Caddy domain is invalid",
    )
    require(caddy_domain == hostname, "Caddy domain differs from the public origin")
    container_hash = str(
        run_command(
            compose
            + [
                "exec",
                "-T",
                "caddy",
                "sh",
                "-ec",
                "sha256sum /etc/caddy/Caddyfile | awk '{print $1}'",
            ],
            environment=environment,
        )
    ).strip()
    require(
        SHA256_RE.fullmatch(container_hash) is not None,
        "container Caddyfile hash is invalid",
    )
    require(
        container_hash == host_caddyfile_sha256,
        "container Caddyfile differs from the clean checkout",
    )
    return {
        "domain": caddy_domain,
        "host_caddyfile_sha256": host_caddyfile_sha256,
        "container_caddyfile_sha256": container_hash,
        "hashes_match": True,
    }


def ensure_execution_disabled(compose: list[str], environment: dict[str, str]) -> None:
    command = (
        'test "$LIVE_EXECUTION_ENABLED" = "false"; '
        'test "$BROKER_LIVE_ENABLED" = "false"; '
        'test "$ANOMALY_LIVE_ORDER_ENABLED" = "false"; '
        'printf disabled'
    )
    output = run_command(
        compose + ["exec", "-T", "web", "sh", "-ec", command],
        environment=environment,
    )
    require(str(output).strip() == "disabled", "web execution gates are not disabled")


def verify_external_pins(
    compose: list[str], environment: dict[str, str]
) -> dict[str, str]:
    command = r'''
set -eu
rights=data/rights/market_data_rights_receipt.json
promotion=data/models/predictor_promotion_latest.json
calibration=data/calibration/probability_calibration_latest.json
test "$AXIO_PROBABILITY_CALIBRATION_ARTIFACT" = "$calibration"
test -n "$MODEL_PROMOTION_ENTRY_SHA256_PINS"
rights_hash="$(sha256sum "$rights" | awk '{print $1}')"
promotion_hash="$(sha256sum "$promotion" | awk '{print $1}')"
calibration_hash="$(sha256sum "$calibration" | awk '{print $1}')"
test "$(printf %s "$AXIO7_MARKET_DATA_RIGHTS_RECEIPT_SHA256" | tr A-F a-f)" = "$rights_hash"
test "$(printf %s "$MODEL_PROMOTION_REGISTRY_SHA256" | tr A-F a-f)" = "$promotion_hash"
test "$(printf %s "$AXIO_PROBABILITY_CALIBRATION_SHA256" | tr A-F a-f)" = "$calibration_hash"
entry_pins_hash="$(printf %s "$MODEL_PROMOTION_ENTRY_SHA256_PINS" | sha256sum | awk '{print $1}')"
printf 'rights=%s\npromotion=%s\ncalibration=%s\nentry_pins_value=%s\n' \
  "$rights_hash" "$promotion_hash" "$calibration_hash" "$entry_pins_hash"
'''.strip()
    output = str(
        run_command(
            compose + ["exec", "-T", "quantd", "sh", "-ec", command],
            environment=environment,
        )
    )
    values: dict[str, str] = {}
    for line in output.splitlines():
        key, separator, value = line.partition("=")
        require(separator == "=" and key, "pin verification returned invalid output")
        require(SHA256_RE.fullmatch(value) is not None, f"{key} pin hash is invalid")
        values[key] = value
    require(
        set(values)
        == {"rights", "promotion", "calibration", "entry_pins_value"},
        "pin verification returned an incomplete hash set",
    )
    return values


def validate_universe(receipt: dict[str, Any]) -> None:
    require(
        receipt.get("status") == "CONFIGURED_RESEARCH_UNIVERSE",
        "research universe is not configured",
    )
    require(receipt.get("execution") == "DISABLED", "research universe enables execution")
    targets = receipt.get("targets")
    require(isinstance(targets, list) and len(targets) == 9, "universe target count is not nine")
    runtime = receipt.get("model_runtime")
    require(isinstance(runtime, dict), "model-runtime receipt is missing")
    require(
        runtime.get("schema_version") == "axio.model-runtime-receipt.v1"
        and runtime.get("status") == "LOADED"
        and runtime.get("requested_artifact_count") == 9
        and runtime.get("loaded_artifact_count") == 9
        and runtime.get("failed_artifact_count") == 0,
        "the exact nine frozen model artifacts are not loaded",
    )
    require(
        runtime.get("automatic_execution_enabled") is False,
        "model runtime unexpectedly enables automatic execution",
    )
    rows = runtime.get("symbols")
    require(isinstance(rows, list) and len(rows) == 9, "model-runtime symbol rows are incomplete")
    require(
        {str(row.get("model_symbol", "")).upper() for row in rows if isinstance(row, dict)}
        == REQUIRED_SYMBOL_SET
        and all(
            isinstance(row, dict)
            and row.get("status") == "LOADED"
            and row.get("reason_code") is None
            for row in rows
        ),
        "model-runtime rows are not the exact loaded nine-symbol set",
    )


def write_file(path: Path, content: bytes) -> None:
    with path.open("xb") as stream:
        stream.write(content)
        stream.flush()
        os.fsync(stream.fileno())
    path.chmod(0o600)


def parse_arguments(argv: Iterable[str]) -> argparse.Namespace:
    script_path = Path(__file__).resolve()
    repo_root = script_path.parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--compose-dir",
        type=Path,
        default=repo_root / "infra" / "single-vm",
        help="single-VM Compose directory",
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        default=Path("/opt/axio7/acceptance"),
        help="absolute directory that will receive the atomic sealed bundle",
    )
    parser.add_argument(
        "--expected-commit",
        required=True,
        help="exact 40-character clean source commit used for both images",
    )
    parser.add_argument(
        "--expected-normalized-sha256",
        required=True,
        help="exact immutable market_bars.csv SHA-256 bound by the model release",
    )
    parser.add_argument(
        "--public-origin",
        default="https://axio7.com",
        help="canonical HTTPS origin whose public /api/health must serve this release",
    )
    parser.add_argument(
        "--max-cutoff-skew-seconds",
        type=int,
        default=120,
        help="maximum allowed spread across the nine finalized-bar cutoffs",
    )
    parser.add_argument(
        "--capture-attempts",
        type=int,
        default=3,
        help="bounded retries if a publication advances during capture",
    )
    return parser.parse_args(list(argv))


def main(argv: Iterable[str]) -> int:
    arguments = parse_arguments(argv)
    expected_commit = arguments.expected_commit.lower()
    expected_normalized_sha256 = arguments.expected_normalized_sha256.lower()
    public_origin = normalize_public_origin(arguments.public_origin)
    require(COMMIT_RE.fullmatch(expected_commit) is not None, "expected commit is invalid")
    require(
        SHA256_RE.fullmatch(expected_normalized_sha256) is not None
        and expected_normalized_sha256 != "0" * 64,
        "expected normalized-data SHA-256 is invalid",
    )
    require(
        0 <= arguments.max_cutoff_skew_seconds <= 300,
        "max cutoff skew must be between 0 and 300 seconds",
    )
    require(
        1 <= arguments.capture_attempts <= 5,
        "capture attempts must be between one and five",
    )

    compose_dir = arguments.compose_dir.resolve(strict=True)
    repo_root = (compose_dir / ".." / "..").resolve(strict=True)
    output_root = arguments.output_root.resolve(strict=False)
    require(output_root.is_absolute() and output_root != Path("/"), "unsafe output root")
    env_file = compose_dir / ".env.server"
    compose_file = compose_dir / "compose.yaml"
    caddy_file = compose_dir / "Caddyfile"
    production_config = repo_root / "quant_engine_rs" / "configs" / "production.yaml"
    runtime = compose_dir / "runtime"
    normalized_csv = runtime / "quant-normalized" / "market_bars.csv"
    manifests = runtime / "quant-manifests"
    rights_receipt = runtime / "quant-rights" / "market_data_rights_receipt.json"
    technical_entitlement_receipt = (
        runtime
        / "quant-evidence"
        / "databento_technical_entitlement_latest.json"
    )
    private_owner_attestation = (
        runtime
        / "private-rights-evidence"
        / "account_owner_attestation.json"
    )
    promotion_registry = (
        runtime / "quant-promotion" / "predictor_promotion_latest.json"
    )
    promotion_evidence = runtime / "quant-promotion" / "evidence"
    calibration_registry = (
        runtime / "quant-calibration" / "probability_calibration_latest.json"
    )

    require_regular_tree(runtime, "runtime root")
    for tree, name in (
        (runtime / "quant-normalized", "normalized-data runtime"),
        (manifests, "manifest runtime"),
        (runtime / "quant-rights", "rights runtime"),
        (runtime / "quant-evidence", "technical-evidence runtime"),
        (
            runtime / "private-rights-evidence",
            "private owner-attestation runtime",
        ),
        (runtime / "quant-promotion", "promotion runtime"),
        (runtime / "quant-calibration", "calibration runtime"),
    ):
        require_regular_tree(tree, name)

    for required_file in (
        env_file,
        compose_file,
        caddy_file,
        production_config,
        normalized_csv,
        rights_receipt,
        promotion_registry,
        calibration_registry,
    ):
        require(required_file.is_file(), f"required file is missing: {required_file.name}")
    require(
        manifests.is_dir() and any(path.is_file() for path in manifests.rglob("*")),
        "immutable manifest directory is missing or empty",
    )
    require(
        promotion_evidence.is_dir()
        and any(path.is_file() for path in promotion_evidence.rglob("*")),
        "forward-shadow evidence directory is missing or empty",
    )

    process_environment = os.environ.copy()
    process_environment["GIT_COMMIT"] = expected_commit
    observed_commit = str(
        run_command(
            ["git", "-C", str(repo_root), "rev-parse", "HEAD"],
            environment=process_environment,
        )
    ).strip()
    require(observed_commit == expected_commit, "checkout does not match expected commit")
    require(
        read_dotenv_value(env_file, "GIT_COMMIT") == expected_commit,
        ".env.server GIT_COMMIT does not match the expected commit",
    )
    worktree = str(
        run_command(
            ["git", "-C", str(repo_root), "status", "--porcelain"],
            environment=process_environment,
        )
    )
    require(not worktree.strip(), "release checkout is dirty")

    observed_normalized_sha256 = sha256_file(normalized_csv)
    require(
        observed_normalized_sha256 == expected_normalized_sha256,
        "normalized market_bars.csv does not match the release hash",
    )

    compose = [
        "docker",
        "compose",
        "--project-directory",
        str(compose_dir),
        "--env-file",
        str(env_file),
    ]
    run_command(
        compose + ["config", "--quiet"],
        environment=process_environment,
    )

    now = datetime.now(timezone.utc)
    require(
        is_regular_session_clock(now),
        "acceptance may run only during the US regular-session clock",
    )
    ensure_execution_disabled(compose, process_environment)
    pin_hashes = verify_external_pins(compose, process_environment)
    quantd_image = image_receipt(
        compose, "quantd", expected_commit, process_environment
    )
    web_image = image_receipt(compose, "web", expected_commit, process_environment)

    readiness, publication_bundle = capture_consistent_state(
        compose,
        process_environment,
        attempts=arguments.capture_attempts,
    )
    capture_time = datetime.now(timezone.utc)
    forecast_summaries = validate_readiness(
        readiness,
        capture_time=capture_time,
        max_cutoff_skew_seconds=arguments.max_cutoff_skew_seconds,
    )
    publication_summaries, publication_member_hashes = (
        validate_publication_bundle(publication_bundle, readiness)
    )

    universe = compose_api_json(
        compose, "/api/v1/research/universe", process_environment
    )
    validate_universe(universe)
    live_status = compose_api_json(compose, "/api/v1/live/status", process_environment)

    artifact_command = r'''
set -eu
for root in data/models data/manifests data/evidence data/promotion data/calibration data/rights; do
  test -d "$root"
done
test "$(readlink data/models/predictor_promotion_latest.json)" = \
  "../promotion/predictor_promotion_latest.json"
test -z "$(find data/models data/manifests data/evidence data/promotion data/calibration data/rights \
  -type l ! -path data/models/predictor_promotion_latest.json -print -quit)"
find data/models data/manifests data/evidence data/promotion data/calibration data/rights \
  -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum
'''.strip()
    artifact_manifest_raw = str(
        run_command(
            compose
            + ["exec", "-T", "quantd", "sh", "-ec", artifact_command],
            environment=process_environment,
        )
    )
    artifact_manifest = parse_artifact_manifest(artifact_manifest_raw)
    require(
        artifact_manifest.get("data/rights/market_data_rights_receipt.json")
        == pin_hashes["rights"],
        "container rights artifact does not match its verified pin",
    )
    require(
        artifact_manifest.get(
            "data/promotion/predictor_promotion_latest.json"
        )
        == pin_hashes["promotion"],
        "container promotion registry does not match its verified pin",
    )
    require(
        artifact_manifest.get(
            "data/calibration/probability_calibration_latest.json"
        )
        == pin_hashes["calibration"],
        "container calibration registry does not match its verified pin",
    )

    container_config_hash_raw = str(
        run_command(
            compose
            + [
                "exec",
                "-T",
                "quantd",
                "sh",
                "-ec",
                "sha256sum /app/configs/production.yaml | awk '{print $1}'",
            ],
            environment=process_environment,
        )
    ).strip()
    require(
        SHA256_RE.fullmatch(container_config_hash_raw) is not None,
        "container production-config hash is invalid",
    )
    host_production_config_sha256 = sha256_file(production_config)
    require(
        container_config_hash_raw == host_production_config_sha256,
        "container production config differs from the clean checkout",
    )

    promotion_value = read_pinned_json(
        promotion_registry,
        pin_hashes["promotion"],
        "promotion registry",
    )
    require(
        promotion_value.get("schema_version")
        == "axio.model-promotion-registry.v2",
        "mounted promotion registry is not v2",
    )
    promotion_entries = promotion_value.get("entries")
    require(
        isinstance(promotion_entries, list)
        and len(promotion_entries) == 9
        and {
            str(entry.get("symbol", "")).upper()
            for entry in promotion_entries
            if isinstance(entry, dict)
        }
        == REQUIRED_SYMBOL_SET
        and promotion_value.get("execution_enabled") is False,
        "mounted promotion registry is not the exact execution-disabled nine-symbol set",
    )

    calibration_value = read_pinned_json(
        calibration_registry,
        pin_hashes["calibration"],
        "calibration registry",
    )
    require(
        calibration_value.get("schema_version") == "axio.probability_calibration.v2",
        "mounted calibration registry is not v2",
    )
    rights_value = read_pinned_json(
        rights_receipt,
        pin_hashes["rights"],
        "rights receipt",
    )
    require(
        rights_value.get("schema_version") == "axio.market_data_rights.v2",
        "mounted market-data rights receipt is not v2",
    )
    validate_private_attestation_storage(
        private_owner_attestation.parent,
        private_owner_attestation,
        required=(
            rights_value.get("evidence_kind") == "ACCOUNT_OWNER_ATTESTATION"
        ),
    )
    rights_readiness = readiness.get("market_data", {}).get(
        "public_use_rights", {}
    )
    require(
        isinstance(rights_readiness, dict),
        "public-use rights readiness is missing at seal time",
    )
    (
        technical_entitlement_sha256,
        private_owner_attestation_sha256,
    ) = validate_rights_evidence_binding(
        rights_value,
        artifact_manifest,
        technical_entitlement_receipt,
        private_owner_attestation,
        readiness_reason=rights_readiness.get("reason"),
    )

    host_caddyfile_sha256 = sha256_file(caddy_file)
    public_https = probe_public_health(
        public_origin,
        expected_commit=expected_commit,
        environment=process_environment,
    )
    caddy_binding = verify_caddy_binding(
        compose,
        process_environment,
        public_origin=public_origin,
        host_caddyfile_sha256=host_caddyfile_sha256,
    )
    runtime_services = inspect_runtime_services(
        compose,
        process_environment,
        expected_image_ids={
            "quantd": str(quantd_image["image_id"]),
            "web": str(web_image["image_id"]),
        },
    )
    verify_runtime_mount_isolation(
        compose,
        process_environment,
        runtime=runtime,
        private_attestation_directory=private_owner_attestation.parent,
        expected_commit=expected_commit,
    )

    output_root.mkdir(parents=True, exist_ok=True, mode=0o700)
    output_root.chmod(0o700)
    seal_time = datetime.now(timezone.utc)
    stamp = seal_time.strftime("%Y%m%dT%H%M%SZ")
    final_name = f"nine-symbol-{stamp}-{expected_commit[:12]}"
    final_dir = output_root / final_name
    require(not final_dir.exists(), "acceptance output already exists")
    staging_path = Path(
        tempfile.mkdtemp(prefix=".nine-symbol-staging-", dir=output_root)
    )
    staging_path.chmod(0o700)

    try:
        components: dict[str, bytes] = {
            "production-readiness.json": canonical_json_bytes(readiness),
            "research-universe.json": canonical_json_bytes(universe),
            "live-status.json": canonical_json_bytes(live_status),
            "live-publication-bundle.tgz": publication_bundle,
            "artifact-manifest.json": canonical_json_bytes(artifact_manifest),
            "publication-member-hashes.json": canonical_json_bytes(
                publication_member_hashes
            ),
            "public-https.json": canonical_json_bytes(public_https),
            "caddy-binding.json": canonical_json_bytes(caddy_binding),
            "runtime-services.json": canonical_json_bytes(runtime_services),
        }
        component_hashes: dict[str, str] = {}
        for name, content in components.items():
            write_file(staging_path / name, content)
            component_hashes[name] = sha256_bytes(content)

        receipt = {
            "schema_version": SCHEMA_VERSION,
            "status": "SEALED_READY",
            "sealed_at": seal_time.isoformat().replace("+00:00", "Z"),
            "session": {
                "timezone": "America/New_York",
                "regular_session_clock_verified": True,
                "live_freshness_verified": True,
                "maximum_cutoff_skew_seconds": arguments.max_cutoff_skew_seconds,
            },
            "source": {
                "commit": expected_commit,
                "clean_checkout": True,
            },
            "images": {
                "quantd": quantd_image,
                "web": web_image,
            },
            "configuration": {
                "compose_yaml_sha256": sha256_file(compose_file),
                "caddyfile_sha256": host_caddyfile_sha256,
                "production_yaml_sha256": host_production_config_sha256,
                "container_production_yaml_sha256": container_config_hash_raw,
                "server_environment_contents_recorded": False,
            },
            "public_https": public_https,
            "caddy": caddy_binding,
            "runtime_services": runtime_services,
            "runtime_mount_policy": {
                "quantd_exact_mount_set_verified": True,
                "private_owner_attestation_unmounted": True,
                "raw_mounts_recorded": False,
            },
            "market_data": {
                "provider": "databento",
                "product": "EQUS.MINI",
                "normalized_market_bars_sha256": observed_normalized_sha256,
                "rights_receipt_schema_version": "axio.market_data_rights.v2",
                "rights_receipt_sha256": pin_hashes["rights"],
                "rights_pin_verified": True,
                "rights_evidence_basis": rights_readiness.get("reason"),
                "technical_entitlement_receipt_sha256": (
                    technical_entitlement_sha256
                ),
                "private_owner_attestation_sha256": (
                    private_owner_attestation_sha256
                ),
                "private_owner_attestation_contents_recorded": False,
                "all_symbol_stream_and_feed_fresh": True,
            },
            "promotion": {
                "schema_version": "axio.model-promotion-registry.v2",
                "registry_sha256": pin_hashes["promotion"],
                "entry_pin_value_sha256": pin_hashes["entry_pins_value"],
                "entry_count": len(promotion_entries),
                "active_pinned": True,
            },
            "calibration": {
                "schema_version": "axio.probability_calibration.v2",
                "registry_sha256": pin_hashes["calibration"],
                "promoted": True,
            },
            "publication": {
                "required_symbols": list(REQUIRED_SYMBOLS),
                "required_horizons_minutes": sorted(REQUIRED_HORIZONS),
                "forecasts": forecast_summaries,
                "immutable_publications": publication_summaries,
                "all_ledger_backed": True,
            },
            "component_sha256": dict(sorted(component_hashes.items())),
            "integrity_seal": {
                "kind": "SHA256_COMPONENT_MANIFEST",
                "digitally_signed": False,
                "meaning": (
                    "Integrity binding only; does not independently prove model "
                    "accuracy, legal rights, or operator identity."
                ),
            },
            "execution": {
                "automatic_execution_enabled": False,
                "disabled_gates_verified": [
                    "LIVE_EXECUTION_ENABLED",
                    "BROKER_LIVE_ENABLED",
                    "ANOMALY_LIVE_ORDER_ENABLED",
                ],
            },
        }
        receipt_bytes = canonical_json_bytes(receipt)
        write_file(staging_path / "acceptance-receipt.json", receipt_bytes)
        receipt_sha256 = sha256_bytes(receipt_bytes)
        write_file(
            staging_path / "acceptance-receipt.sha256",
            f"{receipt_sha256}  acceptance-receipt.json\n".encode("ascii"),
        )

        checksum_lines = []
        for path in sorted(staging_path.iterdir(), key=lambda item: item.name):
            if path.is_file():
                checksum_lines.append(f"{sha256_file(path)}  {path.name}\n")
        write_file(
            staging_path / "SHA256SUMS",
            "".join(checksum_lines).encode("ascii"),
        )
        os.replace(staging_path, final_dir)
    except Exception:
        if staging_path.exists() and staging_path.parent == output_root:
            shutil.rmtree(staging_path)
        raise

    print(f"sealed acceptance receipt: {final_dir}")
    print(f"acceptance receipt sha256: {receipt_sha256}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except SealError as error:
        print(f"acceptance blocked: {error}", file=sys.stderr)
        raise SystemExit(1)
