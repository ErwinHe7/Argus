"""Read-only Linux unit rendering check; no user manager mutation or service start."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile


def main() -> None:
    if not sys.platform.startswith("linux"):
        raise SystemExit("Run this check with native Linux Python")
    platform = Path(__file__).resolve().parents[3]
    script = platform / "connectors/research-runner/deployment/install-shortlist-service.sh"
    with tempfile.TemporaryDirectory(prefix="leo VPS unit ") as temporary:
        root = Path(temporary)
        config = root / "shortlist config.json"
        config.write_text(json.dumps({
            "schemaVersion": "astra-shortlist-service-config.v1",
            "input": str(root / "inputs/desk.json"), "calendar": None,
            "state_dir": str(root / "private"), "public_dir": str(root / "published"),
            "interval_seconds": 30,
        }), encoding="utf-8")
        before = sorted(root.iterdir())
        rendered = subprocess.run(["bash", str(script), "--dry-run", str(platform), sys.executable, str(config)],
                                  check=True, text=True, capture_output=True)
        if before != sorted(root.iterdir()):
            raise AssertionError("Dry-run mutated configuration or state directories")
        if "127.0.0.1:3119" in rendered.stdout or "User=root" in rendered.stdout:
            raise AssertionError("Shortlist service unexpectedly gained an HTTP or root identity")
        unit = root / "leo-shortlist.service"
        unit.write_text(rendered.stdout, encoding="utf-8")
        checked = subprocess.run(["systemd-analyze", "--user", "verify", str(unit)], text=True, capture_output=True)
        if checked.returncode:
            raise AssertionError(checked.stderr)
        environment = root / 'private publisher.env'
        environment.write_text('LEO_SHORTLIST_PUBLISH_TOKEN=fixture-only-never-uploaded\n', encoding='utf-8')
        environment.chmod(0o600)
        protected = subprocess.run(["bash", str(script), "--dry-run", str(platform), sys.executable, str(config), str(environment)],
                                   check=True, text=True, capture_output=True)
        if 'fixture-only-never-uploaded' in protected.stdout or 'EnvironmentFile=' not in protected.stdout:
            raise AssertionError('EnvironmentFile value exposed or file binding missing')
        unit.write_text(protected.stdout, encoding='utf-8')
        subprocess.run(["systemd-analyze", "--user", "verify", str(unit)], check=True, capture_output=True)
        environment.chmod(0o644)
        rejected = subprocess.run(["bash", str(script), "--dry-run", str(platform), sys.executable, str(config), str(environment)],
                                  text=True, capture_output=True)
        if rejected.returncode == 0 or 'chmod 600' not in rejected.stderr:
            raise AssertionError('World-readable EnvironmentFile was accepted')
        print(json.dumps({"platform": sys.platform, "python": sys.version.split()[0],
                          "checks": ["actual-config-validator", "paths-with-spaces", "dry-run-no-mutation",
                                     "systemd-analyze-verify", "private-environment-file-no-content-exposure",
                                     "world-readable-environment-file-rejected"], "servicesStarted": 0, "unitsInstalled": 0}))


if __name__ == "__main__":
    main()
