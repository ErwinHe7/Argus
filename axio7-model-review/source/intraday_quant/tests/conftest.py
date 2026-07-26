from pathlib import Path

import pytest

from intraday_quant.config import load_config


@pytest.fixture
def config():
    return load_config(Path(__file__).parents[1] / "configs" / "default.yaml")
