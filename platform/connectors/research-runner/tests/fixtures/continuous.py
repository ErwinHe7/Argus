"""Process-control fixture only. It neither calculates nor downloads market data."""
import argparse
import json
from pathlib import Path
import time

parser = argparse.ArgumentParser()
parser.add_argument("action", choices=["run", "pause", "resume", "status", "stop"])
parser.add_argument("--config", required=True)
args = parser.parse_args()
config = json.loads(Path(args.config).read_text(encoding="utf-8-sig"))
state = Path(config["state_dir"])
state.mkdir(parents=True, exist_ok=True)
if args.action == "run":
    from .redirector_helper import detach_runtime
    detach_runtime()
    import msvcrt
    with (state / "runner.lock").open("a+b") as lock:
        if lock.tell() == 0:
            lock.write(b"\0")
            lock.flush()
        lock.seek(0)
        msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
        while not (state / "SHUTDOWN").exists():
            (state / "heartbeat.fixture").write_text(str(time.time()), encoding="utf-8")
            time.sleep(0.05)
elif args.action == "pause":
    (state / "STOP").touch()
elif args.action == "resume":
    (state / "STOP").unlink(missing_ok=True)
elif args.action == "stop":
    (state / "SHUTDOWN").touch()
else:
    print(json.dumps({"heartbeat_at": (state / "heartbeat.fixture").read_text(), "paused": (state / "STOP").exists()}))
