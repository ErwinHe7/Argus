"""Verify an extracted source bundle without importing or executing its sources."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath
import stat
import sys


def verify(platform: Path) -> int:
    platform = platform.resolve(strict=True)
    manifest = json.loads((platform / "SOURCE-MANIFEST.json").read_text(encoding="utf-8"))
    if manifest.get("schemaVersion") != "leo-vps-source-bundle.v1":
        raise ValueError("Unsupported source manifest")
    names = set()
    for entry in manifest["files"]:
        name = entry["path"]
        relative = PurePosixPath(name)
        if relative.is_absolute() or ".." in relative.parts or "\\" in name or ":" in name or name in names:
            raise ValueError("Unsafe or duplicate source path")
        names.add(name)
        path = platform / relative
        if not path.resolve(strict=True).is_relative_to(platform):
            raise ValueError("Source path escapes bundle")
        for ancestor in (path, *path.parents):
            if ancestor == platform:
                break
            if ancestor.is_symlink():
                raise ValueError("Linked source is not permitted")
        info = path.stat()
        if not stat.S_ISREG(info.st_mode) or info.st_size != entry["bytes"]:
            raise ValueError(f"Source size/type differs: {name}")
        if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
            raise ValueError(f"Source hash differs: {name}")
    return len(names)


if __name__ == "__main__":
    root = Path(sys.argv[1]) if len(sys.argv) == 2 else Path(__file__).resolve().parents[3]
    print(f"Verified {verify(root)} source files; this is not a native-build or deployment receipt.")
