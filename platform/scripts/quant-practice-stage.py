"""Stage only chapter-practice display assets over a verified retained Leo release."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import urllib.request


SCHEMA = "leo-quant-practice-stage/v1"
OVERLAY = ("desk.js", "desk.css")
PREFIX = "app/research-desk/"
LIVE_GUARDS = (
    "app/research-desk/desk.js", "app/research-desk/desk.css",
    "app/research-desk/data/model-atlas.json", "app/research-desk/index.html",
    "app/research-desk/strategy-config.json", "app/jev/jev.js", "app/jev/jev.css", "logo.png",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def save(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def manifest(root: Path, exclude_assets: bool = False) -> dict[str, str]:
    require(root.is_dir(), f"Missing release directory: {root}")
    paths = []
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root)
        require(not path.is_symlink(), f"Release symlink is unsupported: {relative}")
        if path.is_file() and not (exclude_assets and relative.parts[0] == "assets"):
            paths.append(path)
    with ThreadPoolExecutor(max_workers=8) as pool:
        hashes = list(pool.map(sha, paths))
    return {path.relative_to(root).as_posix(): value for path, value in zip(paths, hashes)}


def verify_live(origin: str, assets: dict[str, str]) -> dict[str, str]:
    def check(path: str) -> tuple[str, str]:
        request = urllib.request.Request(
            origin.rstrip("/") + "/" + path,
            headers={"User-Agent": "LeoQuantPracticeRelease/1.0", "Cache-Control": "no-cache"},
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            digest = hashlib.sha256(response.read()).hexdigest()
            require(response.status == 200 and digest == assets[path],
                    f"Live baseline changed; review the latest release before staging: {path}")
            return path, digest
    with ThreadPoolExecutor(max_workers=6) as pool:
        return dict(pool.map(check, LIVE_GUARDS))


def baseline(base: Path) -> tuple[dict[str, str], dict[str, str], dict[str, str]]:
    require((base / ".open-next/worker.js").is_file(), "Base has no retained OpenNext Worker")
    receipt = load(base / "stage-receipt.json")
    require(receipt.get("schema") in {"leo-model-atlas-stage/v1", SCHEMA}
            and receipt.get("status") == "deployed-and-verified", "Base needs a verified deployment receipt")
    config = load(base / "wrangler.jsonc")
    require(config.get("name") == "leo" and config.get("main") == "features/research-desk/worker-entry.mjs",
            "Base is not the retained Leo Worker")
    require(config.get("workers_dev") is True and config.get("preview_urls") is False,
            "Base must explicitly preserve workers.dev and disable preview URLs")
    require({route.get("pattern") for route in config.get("routes", [])}
            >= {"axio7.com", "www.axio7.com"}, "Base lacks the existing custom domains")
    require({service.get("binding") for service in config.get("services", [])}
            >= {"PUBLIC_MARKET_MAP", "SHORTLIST_FEED", "EVENT_RADAR", "JEV_ASSESSMENT"},
            "Base lacks existing service bindings")
    assets = load(base / "assets-manifest.json")
    backend = load(base / "backend-manifest.json")
    require(manifest(base / ".open-next/assets") == assets, "Base assets differ from their saved manifest")
    require(manifest(base / ".open-next", True) == backend, "Base backend differs from its saved manifest")
    require(len(backend) == 2583, "Unexpected backend inventory; review before staging")
    atlas = load(base / ".open-next/assets/app/research-desk/data/model-atlas.json")
    require(atlas.get("schemaVersion") == "astra-model-atlas.v1"
            and atlas.get("dataMode") == "frozen_candidate_parameters_not_live"
            and atlas.get("executionEnabled") is False and atlas.get("predictionEnabled") is False,
            "Base atlas must retain its historical, non-executing display contract")
    return assets, backend, manifest(base / "features")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, required=True, help="Verified current deployment directory")
    parser.add_argument("--stage", type=Path, required=True, help="Fresh stage, or this script's pristine prepared baseline")
    parser.add_argument("--build", type=Path, help="Final public/app/research-desk build directory")
    parser.add_argument("--prepare-only", action="store_true", help="Copy and verify baseline without any build overlay")
    parser.add_argument("--origin", default="https://leo.axio7.workers.dev", help="Origin for current live asset guards")
    args = parser.parse_args()
    base, stage = args.base.resolve(), args.stage.resolve()
    require(base != stage and base not in stage.parents and stage not in base.parents,
            "Stage must be a separate release directory outside the base")
    require(args.prepare_only or args.build is not None, "--build is required unless --prepare-only is used")
    assets, backend, routing = baseline(base)
    live = verify_live(args.origin, assets)
    receipt_path = stage / "stage-receipt.json"
    if stage.exists():
        require(receipt_path.is_file(), "Existing stage has no preparation receipt; nothing was overwritten")
        receipt = load(receipt_path)
        require(receipt.get("schema") == SCHEMA and receipt.get("status") == "prepared-baseline"
                and receipt.get("source") == str(base), "Stage is not this script's pristine prepared baseline")
        require(manifest(stage / ".open-next/assets") == assets, "Prepared stage assets changed")
        require(manifest(stage / ".open-next", True) == backend, "Prepared stage backend changed")
    else:
        stage.mkdir(parents=True)
        for directory in (".open-next", "features"):
            shutil.copytree(base / directory, stage / directory)
        for name in ("wrangler.jsonc", "backend-manifest.json", "assets-manifest.json"):
            shutil.copy2(base / name, stage / name)
        save(stage / "baseline-assets-manifest.json", assets)
    require(manifest(stage / "features") == routing, "Worker routing changed")
    require(sha(stage / "wrangler.jsonc") == sha(base / "wrangler.jsonc"), "Worker configuration changed")
    require(manifest(stage / ".open-next/assets") == assets, "Copied assets differ")
    require(manifest(stage / ".open-next", True) == backend, "Copied backend differs")
    receipt = {
        "schema": SCHEMA, "createdAt": datetime.now(timezone.utc).isoformat(),
        "status": "prepared-baseline", "source": str(base), "origin": args.origin,
        "backendUnchanged": True, "backendFileCount": len(backend),
        "workerConfigurationUnchanged": True, "workerRoutingUnchanged": True,
        "existingDomainsAndBindingsUnchanged": True,
        "liveBaselineHashes": live, "changedAssets": [], "addedAssets": [], "removedAssets": [],
        "executionEnabled": False, "predictionEnabled": False,
    }
    if not args.prepare_only:
        build = args.build.resolve()
        require(build != stage and stage not in build.parents, "Build must be outside the stage")
        for name in OVERLAY:
            require((build / name).is_file() and not (build / name).is_symlink(), f"Missing or linked build asset: {name}")
        for name in OVERLAY:
            shutil.copy2(build / name, stage / ".open-next/assets" / PREFIX / name)
        after = manifest(stage / ".open-next/assets")
        changed = [path for path in after if path in assets and after[path] != assets[path]]
        added = [path for path in after if path not in assets]
        removed = [path for path in assets if path not in after]
        allowed = {PREFIX + name for name in OVERLAY}
        require(set(changed) <= allowed and not added and not removed, "Overlay changed unrelated assets")
        require(all(after.get(path) == value for path, value in assets.items() if path not in allowed),
                "An unrelated asset changed, including the model atlas, homepage, or public configuration")
        require(manifest(stage / ".open-next", True) == backend, "Frozen backend changed")
        require(manifest(stage / "features") == routing, "Worker routing changed")
        require(sha(stage / "wrangler.jsonc") == sha(base / "wrangler.jsonc"), "Worker configuration changed")
        receipt.update(status="prepared-not-deployed", changedAssets=changed, addedAssets=added,
                       removedAssets=removed, unrelatedAssetsUnchanged=True,
                       build=str(build), unchangedAssetCount=len(assets) - len(changed),
                       atlasUnchanged=True)
        save(stage / "assets-manifest.json", after)
    save(receipt_path, receipt)
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()
