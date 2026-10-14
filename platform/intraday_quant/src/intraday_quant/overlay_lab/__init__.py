"""Return-enhancement overlay lab: covered call, collar and protective put backtests. No orders."""
from .engine import ARTIFACT_VERSION, ENGINE_VERSION, MODEL_LABEL, OverlayConfig, OverlaySource, run_overlay
from .report import public_projection, slice_metrics

__all__ = ["ARTIFACT_VERSION", "ENGINE_VERSION", "MODEL_LABEL", "OverlayConfig", "OverlaySource",
           "public_projection", "run_overlay", "slice_metrics"]
