#!/usr/bin/env bash
# Linux preparation checks only; never calls service start/enable or installs a unit.
set -euo pipefail
umask 077
scripts=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../linux" && pwd -P)
bash -n "$scripts/install-user-service.sh"
test_root=$(mktemp -d --tmpdir 'leo research ops.XXXXXXXX')
platform="$test_root/platform with spaces"
mkdir -p "$platform/intraday_quant/src/intraday_quant/strategy_lab"
touch "$platform/intraday_quant/src/intraday_quant/strategy_lab/continuous.py"
python3 - "$test_root" <<'PY'
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
(root / 'research config.json').write_text(json.dumps({
    'state_dir': str(root / 'private state'), 'engine': '/bin/true'
}), encoding='utf-8')
PY
bash "$scripts/install-user-service.sh" --dry-run "$platform" /usr/bin/python3 "$test_root/research config.json" > "$test_root/rendered.txt"
python3 - "$test_root" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
rendered = (root / 'rendered.txt').read_text(encoding='utf-8')
for section in rendered.split('# Would install ')[1:]:
    target, content = section.split('\n', 1)
    (root / Path(target).name).write_text(content, encoding='utf-8')
assert not (root / 'private state').exists(), 'dry-run created state'
assert len(list(root.glob('*.service'))) == 2, 'expected worker and optional monitor units'
PY
systemd-analyze --user verify "$test_root/leo-research.service" "$test_root/leo-research-monitor.service"
printf 'PASS: Bash syntax, dry-run rendering with spaces, systemd user unit validation, no state creation or service installation. Evidence: %s\n' "$test_root"
