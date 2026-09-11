"""Build an allowlisted source-only VPS bundle; never copy account/data state."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import stat
import zipfile

PLATFORM = Path(__file__).resolve().parents[3]
EXACT = (
    "AGENTS.md", "quant_engine_rs/Cargo.toml", "quant_engine_rs/Cargo.lock",
    "ledger/schema.sql", "intraday_quant/src/intraday_quant/__init__.py",
    "intraday_quant/src/intraday_quant/shortlist.py",
    "intraday_quant/src/intraday_quant/shortlist_service.py",
    "intraday_quant/src/intraday_quant/iv_lab.py",
    "workers/public-market-map/us-calendar.ts",
    "connectors/research-runner/README.md",
    "connectors/research-runner/shortlist-config.example.json",
    "connectors/research-runner/web/index.html",
    "connectors/research-runner/web/monitor.css",
    "connectors/research-runner/web/monitor.js",
    "public/app/research-desk/inter.ttf", "public/app/research-desk/lion.png",
    "quant_engine_rs/configs/candidates/live-feature-v2-no-uup.yaml",
    "quant_engine_rs/configs/candidates/live-feature-v3-no-uup-no-tlt.yaml",
)
TREES = (
    ("quant_engine_rs/src", ".rs"),
    ("intraday_quant/src/intraday_quant/strategy_lab", ".py"),
    ("connectors/research-runner/linux", ".sh"),
    ("connectors/research-runner/linux", ".service"),
    ("connectors/research-runner/deployment", ".py"),
    ("connectors/research-runner/deployment", ".sh"),
    ("connectors/research-runner/deployment", ".service"),
    ("connectors/research-runner/deployment", ".md"),
)


def sources(platform: Path) -> list[tuple[str, bytes]]:
    platform = platform.resolve(strict=True)
    paths = set(EXACT)
    for folder, suffix in TREES:
        root = platform / folder
        if not root.is_dir():
            raise ValueError(f"Required source directory missing: {folder}")
        paths.update(path.relative_to(platform).as_posix() for path in root.rglob(f"*{suffix}"))
    result = []
    total = 0
    for name in sorted(paths):
        path = platform / name
        # Reject links at every level, including Windows directory junctions.
        for ancestor in (path, *path.parents):
            if ancestor == platform:
                break
            if ancestor.is_symlink() or getattr(ancestor, "is_junction", lambda: False)():
                raise ValueError(f"Linked source path is not permitted: {name}")
        if not path.resolve(strict=True).is_relative_to(platform):
            raise ValueError("Source escapes platform")
        info = path.stat()
        if not stat.S_ISREG(info.st_mode) or info.st_size > 16 * 1024 * 1024:
            raise ValueError(f"Source is not a bounded regular file: {name}")
        content = path.read_bytes()
        total += len(content)
        if total > 128 * 1024 * 1024:
            raise ValueError("Source bundle exceeds 128 MiB")
        result.append((name, content))
    return result


def build(platform: Path, output: Path) -> dict:
    if not output.is_absolute() or output.suffix.lower() != ".zip":
        raise ValueError("Output must be an absolute .zip path")
    if output.exists() or output.with_suffix(".receipt.json").exists():
        raise ValueError("Refusing to overwrite an existing bundle")
    files = sources(platform)
    manifest = {
        "schemaVersion": "leo-vps-source-bundle.v1",
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "kind": "source-only-development-package",
        "nativeBuildVerified": False,
        "containsCredentials": False,
        "containsMarketHistory": False,
        "executionAuthorized": False,
        "files": [{"path": name, "bytes": len(content), "sha256": hashlib.sha256(content).hexdigest()}
                  for name, content in files],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "x", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, content in files:
            archive.writestr(f"platform/{name}", content)
        archive.writestr("platform/SOURCE-MANIFEST.json", json.dumps(manifest, indent=2) + "\n")
    receipt = {"archive": str(output), "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
               "bytes": output.stat().st_size, "files": len(files),
               "kind": manifest["kind"], "containsCredentials": False,
               "containsMarketHistory": False, "nativeBuildVerified": False}
    output.with_suffix(".receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return receipt


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", type=Path, default=PLATFORM)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.platform, args.output), indent=2))
