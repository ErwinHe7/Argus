"""Select one local broker adapter for a connector process; no inbound server."""
from __future__ import annotations

import argparse
import sys


def main():
    selector = argparse.ArgumentParser(add_help=False)
    selector.add_argument("--broker", choices=("moomoo", "ibkr-gateway"), default="moomoo")
    choice, remaining = selector.parse_known_args()
    original = sys.argv
    sys.argv = [original[0], *remaining]
    try:
        if choice.broker == "moomoo":
            from paper_sdk import main as run
        else:
            from ibkr_gateway import main as run
        run()
    finally:
        sys.argv = original


if __name__ == "__main__":
    main()
