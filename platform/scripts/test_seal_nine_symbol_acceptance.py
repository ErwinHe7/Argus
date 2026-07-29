from __future__ import annotations

import hashlib
import importlib.util
import io
import json
import os
import tarfile
import tempfile
import unittest
from copy import deepcopy
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch


MODULE_PATH = Path(__file__).with_name("seal-nine-symbol-acceptance.py")
SPEC = importlib.util.spec_from_file_location("acceptance_seal", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
SEAL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SEAL)


def timestamp(minute: int = 59) -> str:
    return f"2026-07-28T14:{minute:02d}:00Z"


def readiness() -> dict:
    forecasts = []
    for symbol in SEAL.REQUIRED_SYMBOLS:
        forecasts.append(
            {
                "symbol": symbol,
                "live_inference": {
                    "required": True,
                    "status_available": True,
                    "status": "PUBLISHED",
                    "stage": "PUBLISHED",
                    "reason_code": None,
                    "status_freshness": "FRESH",
                    "cutoff": timestamp(),
                    "latest_input_available_at": "2026-07-28T14:59:01Z",
                    "compute_ms": 4,
                    "end_to_end_ms": 5,
                    "budget_ms": 5_000,
                    "context_blockers": [],
                    "forecast_committed": True,
                    "receipt_committed": True,
                    "ledger_persisted": True,
                    "ready": True,
                },
                "artifact_present": True,
                "validation_status": "PASSED",
                "freshness": "FRESH",
                "horizon_coverage": "COMPLETE",
                "calibration": "PROMOTED",
                "promotion_registry_matches": True,
                "ledger_backed": True,
                "ready": True,
            }
        )
    return {
        "schema_version": "axio.production_readiness.v2",
        "status": "READY",
        "public_realtime_research_ready": True,
        "market_data": {
            "selected_provider": "databento",
            "selected_product": "EQUS.MINI",
            "live_enabled": True,
            "public_use_rights": {"status": "READY", "reason": "VERIFIED"},
            "provider_entitlement": "READY",
            "stream_freshness": "FRESH",
            "feed_freshness": "FRESH",
        },
        "artifacts": {
            "promotion_registry_present": True,
            "promotion_registry_status": "ACTIVE_PINNED",
            "calibration_registry_present": True,
            "calibration_registry_status": "PROMOTED",
            "prediction_ledger_present": True,
        },
        "forecasts": forecasts,
    }


def add_tar_member(bundle: tarfile.TarFile, name: str, value: object) -> bytes:
    raw = json.dumps(value, separators=(",", ":")).encode()
    info = tarfile.TarInfo(name)
    info.size = len(raw)
    bundle.addfile(info, io.BytesIO(raw))
    return raw


def publication_bundle(receipt: dict) -> bytes:
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode="w:gz") as bundle:
        add_tar_member(bundle, "databento_stream_status.json", {"status": "CONNECTED"})
        for row in receipt["forecasts"]:
            symbol = row["symbol"]
            lower = symbol.lower()
            live = row["live_inference"]
            forecast_json = json.dumps(
                {"symbol": symbol, "horizons": [5, 15, 30, 60]},
                separators=(",", ":"),
            )
            forecast_sha = hashlib.sha256(forecast_json.encode()).hexdigest()
            inference_receipt = {
                "schema_version": "axio.databento-inference-receipt.v3",
                "generated_at": "2026-07-28T14:59:02Z",
                "published_at": "2026-07-28T14:59:02Z",
                "end_to_end_ms": 5,
                "budget_ms": 5_000,
                "provider": "databento",
                "dataset": "EQUS.MINI",
                "data_source": "LIVE",
                "model_symbol": symbol,
                "model_hash": "a" * 64,
                "forecast_path": f"reports/{lower}.json",
                "forecast_sha256": forecast_sha,
                "prediction_ids": [f"{symbol}-{horizon}" for horizon in [5, 15, 30, 60]],
                "latest_input_available_at": live["latest_input_available_at"],
                "required_context_symbols": ["SPY"],
                "max_context_skew_ms": 1_000,
                "source_envelope_count": 1,
                "source_envelopes_sha256": "b" * 64,
                "source_envelopes": [{"symbol": symbol}],
                "cutoff_source_envelopes": [{"symbol": symbol}],
                "cutoff_context_observations": [],
                "ledger_persisted": True,
                "execution_enabled": False,
            }
            status = {
                "schema_version": "axio.databento-inference-status.v3",
                "observed_at": "2026-07-28T14:59:02Z",
                "model_symbol": symbol,
                "status": "PUBLISHED",
                "stage": "PUBLISHED",
                "reason_code": None,
                "cutoff": live["cutoff"],
                "latest_input_available_at": live["latest_input_available_at"],
                "compute_ms": live["compute_ms"],
                "end_to_end_ms": live["end_to_end_ms"],
                "budget_ms": live["budget_ms"],
                "context_blockers": [],
                "forecast_committed": True,
                "receipt_committed": True,
                "ledger_persisted": True,
                "execution_enabled": False,
            }
            status_name = (
                "databento_inference_status.json"
                if symbol == "SPY"
                else f"databento_inference_status_{lower}.json"
            )
            add_tar_member(bundle, status_name, status)
            add_tar_member(
                bundle,
                f"databento_inference_receipt_{lower}_latest.json",
                inference_receipt,
            )
            add_tar_member(
                bundle,
                f"databento_publications/{lower}/publication.json",
                {
                    "schema_version": "axio.immutable-forecast-publication.v1",
                    "publication_id": f"{symbol}-publication",
                    "published_at": "2026-07-28T14:59:02Z",
                    "model_symbol": symbol,
                    "forecast_json": forecast_json,
                    "receipt": inference_receipt,
                },
            )
    return output.getvalue()


class AcceptanceSealTests(unittest.TestCase):
    def test_public_origin_normalizes_only_canonical_https(self) -> None:
        self.assertEqual(
            SEAL.normalize_public_origin("https://AXIO7.com:443/"),
            "https://axio7.com",
        )
        invalid_origins = (
            "http://axio7.com",
            "https://user:secret@axio7.com",
            "https://axio7.com/path",
            "https://axio7.com?query=1",
            "https://axio7.com#fragment",
            "https://axio7.com:8443",
            "https://axio7.com/\n",
        )
        for origin in invalid_origins:
            with self.subTest(origin=origin), self.assertRaises(SEAL.SealError):
                SEAL.normalize_public_origin(origin)

    def test_public_health_binds_commit_and_fresh_timestamp(self) -> None:
        checked_at = datetime(2026, 7, 28, 15, 0, tzinfo=timezone.utc)
        expected_commit = "a" * 40
        value = {
            "ts": checked_at.isoformat().replace("+00:00", "Z"),
            "env": {"deployment": expected_commit},
        }
        observed = SEAL.validate_public_health(
            value,
            expected_commit=expected_commit,
            checked_at=checked_at,
        )
        self.assertEqual(observed["source_commit"], expected_commit)

        mismatched = deepcopy(value)
        mismatched["env"]["deployment"] = "b" * 40
        with self.assertRaises(SEAL.SealError):
            SEAL.validate_public_health(
                mismatched,
                expected_commit=expected_commit,
                checked_at=checked_at,
            )

        stale = deepcopy(value)
        stale["ts"] = (checked_at - timedelta(minutes=2)).isoformat()
        with self.assertRaises(SEAL.SealError):
            SEAL.validate_public_health(
                stale,
                expected_commit=expected_commit,
                checked_at=checked_at,
            )

    def test_public_probe_requires_http_200_without_insecure_tls(self) -> None:
        expected_commit = "a" * 40
        response = json.dumps(
            {
                "ts": datetime.now(timezone.utc).isoformat(),
                "env": {"deployment": expected_commit},
            }
        )
        with patch.object(SEAL, "run_command", return_value=f"{response}\n200") as run:
            observed = SEAL.probe_public_health(
                "https://axio7.com",
                expected_commit=expected_commit,
                environment={},
            )
        command = run.call_args.args[0]
        self.assertEqual(observed["tls_verified"], True)
        self.assertNotIn("--insecure", command)
        self.assertIn("=https", command)

        with patch.object(SEAL, "run_command", return_value=f"{response}\n302"):
            with self.assertRaises(SEAL.SealError):
                SEAL.probe_public_health(
                    "https://axio7.com",
                    expected_commit=expected_commit,
                    environment={},
                )

    def test_runtime_state_is_sanitized_and_fail_closed(self) -> None:
        container_id = "1" * 64
        image_id = f"sha256:{'2' * 64}"
        state = SEAL.parse_runtime_service_state(
            "quantd",
            f"{container_id}|{image_id}|true|false|false|healthy",
            expected_image_id=image_id,
        )
        self.assertEqual(
            set(state),
            {
                "container_id",
                "image_id",
                "running",
                "restarting",
                "dead",
                "health_status",
            },
        )
        for malformed in (
            f"{container_id}|{image_id}|true|true|false|healthy",
            f"{container_id}|{image_id}|true|false|false|unhealthy",
        ):
            with self.subTest(malformed=malformed), self.assertRaises(SEAL.SealError):
                SEAL.parse_runtime_service_state(
                    "quantd",
                    malformed,
                    expected_image_id=image_id,
                )

    def test_runtime_inspection_rejects_multiple_service_containers(self) -> None:
        with patch.object(
            SEAL,
            "run_command",
            return_value=f"{'1' * 64}\n{'2' * 64}\n",
        ):
            with self.assertRaises(SEAL.SealError):
                SEAL.inspect_runtime_services(
                    ["docker", "compose"],
                    {},
                    expected_image_ids={},
                )

    def test_quantd_mounts_are_exact_and_private_storage_is_unmounted(self) -> None:
        expected_commit = "a" * 40
        with tempfile.TemporaryDirectory() as directory:
            runtime = Path(directory) / "runtime"
            for name in (
                "quant-normalized",
                "quant-manifests",
                "quant-rights",
                "quant-evidence",
                "quant-promotion",
                "quant-calibration",
                "private-rights-evidence",
            ):
                (runtime / name).mkdir(parents=True)
            binds = {
                "/app/data/normalized": "quant-normalized",
                "/app/data/manifests": "quant-manifests",
                "/app/data/rights": "quant-rights",
                "/app/data/evidence": "quant-evidence",
                "/app/data/promotion": "quant-promotion",
                "/app/data/calibration": "quant-calibration",
            }
            mounts = [
                {
                    "Type": "bind",
                    "Source": str(runtime / source),
                    "Destination": destination,
                    "RW": False,
                }
                for destination, source in binds.items()
            ]
            mounts.extend(
                [
                    {
                        "Type": "volume",
                        "Name": "axio7_quant-live",
                        "Destination": "/app/data/live",
                        "RW": True,
                    },
                    {
                        "Type": "volume",
                        "Name": "axio7_quant-state",
                        "Destination": "/app/data/state",
                        "RW": True,
                    },
                    {
                        "Type": "volume",
                        "Name": f"axio7_quant-models-{expected_commit}",
                        "Destination": "/app/data/models/universe",
                        "RW": False,
                    },
                ]
            )
            SEAL.validate_quantd_mounts(
                mounts,
                runtime=runtime,
                expected_commit=expected_commit,
            )
            SEAL.validate_no_private_bind_mounts(
                mounts,
                private_directory=runtime / "private-rights-evidence",
            )
            with self.assertRaises(SEAL.SealError):
                SEAL.validate_no_private_bind_mounts(
                    [
                        {
                            "Type": "bind",
                            "Source": str(runtime),
                            "Destination": "/unexpected",
                            "RW": False,
                        }
                    ],
                    private_directory=runtime / "private-rights-evidence",
                )

    def test_private_storage_and_pinned_json_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            private_directory = root / "private-rights-evidence"
            private_directory.mkdir(mode=0o700)
            private_directory.chmod(0o700)
            attestation = private_directory / "account_owner_attestation.json"
            attestation.write_bytes(b"private-canary")
            attestation.chmod(0o600)
            SEAL.validate_private_attestation_storage(
                private_directory,
                attestation,
                required=True,
            )

            outside_link = root / "attestation-hardlink"
            os.link(attestation, outside_link)
            with self.assertRaises(SEAL.SealError):
                SEAL.validate_private_attestation_storage(
                    private_directory,
                    attestation,
                    required=True,
                )

            outside_link.unlink()
            pinned_path = root / "rights.json"
            pinned_bytes = b'{"schema_version":"axio.market_data_rights.v2"}\n'
            pinned_path.write_bytes(pinned_bytes)
            expected_sha256 = hashlib.sha256(pinned_bytes).hexdigest()
            parsed = SEAL.read_pinned_json(
                pinned_path,
                expected_sha256,
                "rights receipt",
            )
            self.assertEqual(
                parsed["schema_version"],
                "axio.market_data_rights.v2",
            )
            pinned_path.write_bytes(pinned_bytes + b" ")
            with self.assertRaises(SEAL.SealError):
                SEAL.read_pinned_json(
                    pinned_path,
                    expected_sha256,
                    "rights receipt",
                )

    def test_exact_nine_ready_rows_pass(self) -> None:
        summaries = SEAL.validate_readiness(
            readiness(),
            capture_time=datetime(2026, 7, 28, 15, 0, tzinfo=timezone.utc),
            max_cutoff_skew_seconds=120,
        )
        self.assertEqual([row["symbol"] for row in summaries], list(SEAL.REQUIRED_SYMBOLS))

    def test_one_unpromoted_row_fails_closed(self) -> None:
        value = readiness()
        value["forecasts"][3]["calibration"] = "UNPROMOTED"
        with self.assertRaises(SEAL.SealError):
            SEAL.validate_readiness(
                value,
                capture_time=datetime(2026, 7, 28, 15, 0, tzinfo=timezone.utc),
                max_cutoff_skew_seconds=120,
            )

    def test_owner_attested_rights_require_hash_bound_technical_evidence(self) -> None:
        value = readiness()
        value["market_data"]["public_use_rights"]["reason"] = (
            "OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT"
        )
        SEAL.validate_readiness(
            value,
            capture_time=datetime(2026, 7, 28, 15, 0, tzinfo=timezone.utc),
            max_cutoff_skew_seconds=120,
        )

        content = b'{"schema_version":"axio.databento_technical_entitlement.v1"}\n'
        digest = hashlib.sha256(content).hexdigest()
        attestation_content = (
            b'{"schema_version":"axio.account_owner_attestation.v1"}\n'
        )
        attestation_digest = hashlib.sha256(attestation_content).hexdigest()
        rights = {
            "evidence_kind": "ACCOUNT_OWNER_ATTESTATION",
            "evidence_artifact_sha256": attestation_digest,
            "owner_attestation": {
                "technical_entitlement_receipt_sha256": digest,
            },
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "databento_technical_entitlement_latest.json"
            attestation_path = (
                Path(directory) / "account_owner_attestation.json"
            )
            path.write_bytes(content)
            attestation_path.write_bytes(attestation_content)
            observed = SEAL.validate_rights_evidence_binding(
                rights,
                {
                    "data/evidence/databento_technical_entitlement_latest.json": digest,
                },
                path,
                attestation_path,
                readiness_reason="OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT",
            )
            self.assertEqual(observed, (digest, attestation_digest))

            path.write_bytes(content + b" ")
            with self.assertRaises(SEAL.SealError):
                SEAL.validate_rights_evidence_binding(
                    rights,
                    {
                        "data/evidence/databento_technical_entitlement_latest.json": digest,
                    },
                    path,
                    attestation_path,
                    readiness_reason="OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT",
                )

            path.write_bytes(content)
            attestation_path.write_bytes(attestation_content + b" ")
            with self.assertRaises(SEAL.SealError):
                SEAL.validate_rights_evidence_binding(
                    rights,
                    {
                        "data/evidence/databento_technical_entitlement_latest.json": digest,
                    },
                    path,
                    attestation_path,
                    readiness_reason=(
                        "OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT"
                    ),
                )

    def test_cutoff_skew_fails_closed(self) -> None:
        value = readiness()
        value["forecasts"][-1]["live_inference"]["cutoff"] = timestamp(55)
        with self.assertRaises(SEAL.SealError):
            SEAL.validate_readiness(
                value,
                capture_time=datetime(2026, 7, 28, 15, 0, tzinfo=timezone.utc),
                max_cutoff_skew_seconds=120,
            )

    def test_immutable_bundle_binds_all_nine_latest_receipts(self) -> None:
        value = readiness()
        summaries, hashes = SEAL.validate_publication_bundle(
            publication_bundle(value), value
        )
        self.assertEqual(len(summaries), 9)
        self.assertEqual(len([name for name in hashes if "publications/" in name]), 9)

    def test_execution_enabled_receipt_fails_closed(self) -> None:
        value = readiness()
        raw = publication_bundle(value)
        source = tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz")
        rewritten = io.BytesIO()
        with source, tarfile.open(fileobj=rewritten, mode="w:gz") as target:
            for member in source.getmembers():
                stream = source.extractfile(member)
                assert stream is not None
                content = stream.read()
                if member.name == "databento_inference_receipt_spy_latest.json":
                    receipt = json.loads(content)
                    receipt["execution_enabled"] = True
                    content = json.dumps(receipt, separators=(",", ":")).encode()
                    member = deepcopy(member)
                    member.size = len(content)
                target.addfile(member, io.BytesIO(content))
        with self.assertRaises(SEAL.SealError):
            SEAL.validate_publication_bundle(rewritten.getvalue(), value)


if __name__ == "__main__":
    unittest.main()
