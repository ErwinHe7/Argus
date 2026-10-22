from copy import deepcopy
from hashlib import sha256
from pathlib import Path
import json
import math
import unittest

from intraday_quant.model_atlas import build_atlas, model_view

PLATFORM = Path(__file__).resolve().parents[2]
QUANT_ROOT = PLATFORM / "quant_engine_rs"
REGISTRY_PATH = QUANT_ROOT / "data/models/universe/registry.json"


class ModelAtlasTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.registry_bytes = REGISTRY_PATH.read_bytes()
        cls.registry = json.loads(cls.registry_bytes)
        cls.entry = next(entry for entry in cls.registry["entries"] if entry["public_symbol"] == "SPX")
        cls.artifact_bytes = (QUANT_ROOT / "data/models/universe/SPX.frozen.json").read_bytes()
        cls.artifact = json.loads(cls.artifact_bytes)

    def view(self, entry=None, artifact=None):
        return model_view(entry or self.entry, artifact or self.artifact, self.artifact_bytes, "quant_engine_rs/data/models/universe/SPX.frozen.json")

    def test_exports_every_registered_model_bound_to_its_exact_bytes(self):
        atlas = build_atlas(self.registry, self.registry_bytes, QUANT_ROOT)
        self.assertEqual([model["symbol"] for model in atlas["models"]], self.registry["requested_public_symbols"])
        self.assertEqual(atlas["registrySha256"], sha256(self.registry_bytes).hexdigest())
        self.assertIs(atlas["predictionEnabled"], False)
        self.assertIs(atlas["executionEnabled"], False)
        for model in atlas["models"]:
            path = PLATFORM / model["lineage"]["artifactPath"]
            self.assertEqual(model["lineage"]["artifactFileSha256"], sha256(path.read_bytes()).hexdigest())
            self.assertEqual(len(model["regimes"]), model["hmm"]["states"])
            self.assertAlmostEqual(sum(regime["timeShare"] for regime in model["regimes"]), 1, places=3)

    def test_derived_values_match_the_frozen_parameters(self):
        view = self.view()
        hmm, shadow = self.artifact["hmm"], self.artifact["short_horizon_model"]
        for state, regime in enumerate(view["regimes"]):
            persistence = hmm["transition"][state][state]
            self.assertAlmostEqual(regime["meanStayMinutes"], 5 / (1 - persistence), places=0)
            self.assertAlmostEqual(regime["driftBpPerMinute"], shadow["diffusion_states"][state]["drift_per_minute"] * 1e4, places=4)
            self.assertAlmostEqual(regime["volatilityBpPerSqrtMinute"], shadow["diffusion_states"][state]["volatility_per_sqrt_minute"] * 1e4, places=3)
            kappa = shadow["vwap_residual_ou_states"][state]["kappa_per_minute"]
            self.assertAlmostEqual(regime["ou"]["halfLifeMinutes"], math.log(2) / kappa, places=1)
        self.assertEqual(view["selection"]["selectedStates"], 12)
        self.assertTrue(view["selection"]["atBoundary"])
        self.assertFalse(view["kernel"]["metricWeightsFitted"])
        self.assertEqual(view["kernel"]["analogRows"], len(self.artifact["analog_engine"]["train_indices"]))

    def test_disabled_ou_layer_has_no_half_life(self):
        artifact = deepcopy(self.artifact)
        artifact["short_horizon_model"]["vwap_residual_ou_enabled"] = False
        artifact["short_horizon_model"]["vwap_residual_ou_rejection_reasons"] = ["OU_NOT_MEAN_REVERTING"]
        view = self.view(artifact=artifact)
        self.assertTrue(all(regime["ou"] is None for regime in view["regimes"]))
        self.assertEqual(view["shadow"]["ouRejectionReasons"], ["OU_NOT_MEAN_REVERTING"])

    def test_mismatched_promoted_or_unknown_artifacts_fail_closed(self):
        cases = [
            ("registry hash", lambda entry, artifact: entry.update(model_hash="0" * 64)),
            ("training cutoff", lambda entry, artifact: entry.update(training_cutoff="2026-07-23T20:00:00Z")),
            ("promotion", lambda entry, artifact: entry.update(promotion_status="PROMOTED")),
            ("calibration", lambda entry, artifact: artifact.update(calibration_ref="calibration.json")),
            ("feature schema", lambda entry, artifact: artifact.update(feature_schema_version="unknown")),
            ("selection", lambda entry, artifact: artifact["regime_selection"].update(selected_state_count=8)),
            ("shadow states", lambda entry, artifact: artifact["short_horizon_model"].update(state_count=11)),
            ("transition", lambda entry, artifact: artifact["hmm"]["transition"][0].append(0.0)),
            ("non-finite", lambda entry, artifact: artifact["short_horizon_model"]["diffusion_states"][0].update(drift_per_minute=float("nan"))),
        ]
        for name, mutate in cases:
            with self.subTest(name):
                entry, artifact = deepcopy(self.entry), deepcopy(self.artifact)
                mutate(entry, artifact)
                with self.assertRaises(ValueError):
                    self.view(entry, artifact)

    def test_execution_enabled_registry_is_rejected(self):
        registry = {**self.registry, "execution_enabled": True}
        with self.assertRaises(ValueError):
            build_atlas(registry, self.registry_bytes, QUANT_ROOT)


if __name__ == "__main__":
    unittest.main()
