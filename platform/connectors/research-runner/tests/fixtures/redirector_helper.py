"""Explicit orphan fault injection for the isolated Windows process fixtures."""
import os
import subprocess
import sys


def detach_runtime():
    if os.environ.get("LEO_RESEARCH_SMOKE_DETACH") != "1":
        return
    environment = dict(os.environ)
    environment.pop("LEO_RESEARCH_SMOKE_DETACH", None)
    # Keep argv (including original venv path) identical while detaching the base
    # interpreter. It survives its launcher and any intermediate redirector exit.
    child = subprocess.Popen(
        sys.orig_argv,
        executable=sys._base_executable,
        env=environment,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        close_fds=True,
        creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP,
    )
    raise SystemExit(child.wait())
