from __future__ import annotations

import re
import tomllib
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _requirement_names(requirements: list[str]) -> set[str]:
    return {
        re.split(r"[\s<>=!~;\[]", requirement, maxsplit=1)[0].lower()
        for requirement in requirements
    }


def test_torch_is_declared_only_in_neural_extra() -> None:
    project = tomllib.loads((PROJECT_ROOT / "pyproject.toml").read_text("utf-8"))[
        "project"
    ]

    base_dependencies = _requirement_names(project["dependencies"])
    neural_dependencies = _requirement_names(
        project["optional-dependencies"]["neural"]
    )

    assert "torch" not in base_dependencies
    assert "torch" in neural_dependencies


def test_readme_explains_how_to_resolve_missing_torch() -> None:
    readme = (PROJECT_ROOT / "README.md").read_text("utf-8")

    assert ".[dev,neural]" in readme
    assert "ModuleNotFoundError: No module named 'torch'" in readme
