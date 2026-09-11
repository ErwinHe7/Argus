"""Read-only broker prerequisite checks; never authenticate or submit an order.

Only fixed loopback ports and Windows broker uninstall records are inspected.
An open TCP port does not establish a broker identity, session, or paper account.
No broker configuration, profiles, credential stores, logs, or balances are read.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import importlib.metadata
import json
import platform
import socket
import sys

LINKS = {
    "moomoo": "https://www.moomoo.com/download/OpenAPI",
    "moomooSetup": "https://openapi.moomoo.com/moomoo-api-doc/en/quick/opend-base.html",
    "ibkr": "https://download2.interactivebrokers.com/portal/clientportal.gw.zip",
    "ibkrSetup": "https://www.interactivebrokers.com/campus/trading-lessons/launching-and-authenticating-the-gateway/",
    "ibkr-tws": "https://www.interactivebrokers.com/en/trading/tws.php",
    "ibkr-twsSetup": "https://www.interactivebrokers.com/campus/trading-lessons/installing-configuring-tws-for-the-api/",
}
PORTS = {"moomoo": (11111,), "ibkr": (5000,), "ibkr-tws": (7497, 4002)}
SDK_REQUIREMENTS = {"moomoo-api": "10.10.7008", "exchange-calendars": "4.11.2"}


def classify_program(name):
    normalized = name.casefold().strip()
    if "opend" in normalized and ("moomoo" in normalized or "futu" in normalized or normalized == "opend"):
        return "moomoo-opend"
    if normalized == "moomoo":
        return "moomoo-desktop"
    if normalized in ("trader workstation", "ib gateway"):
        return "ibkr-gateway"
    return None


def windows_programs():
    if sys.platform != "win32":
        return {"status": "not_checked_on_this_platform", "programs": []}
    import winreg
    entries = []
    for hive, branch in (
        (winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Uninstall"),
        (winreg.HKEY_LOCAL_MACHINE, r"Software\Microsoft\Windows\CurrentVersion\Uninstall"),
        (winreg.HKEY_LOCAL_MACHINE, r"Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
    ):
        try:
            with winreg.OpenKey(hive, branch) as uninstall:
                for index in range(winreg.QueryInfoKey(uninstall)[0]):
                    try:
                        with winreg.OpenKey(uninstall, winreg.EnumKey(uninstall, index)) as item:
                            name = str(winreg.QueryValueEx(item, "DisplayName")[0])
                            kind = classify_program(name)
                            if kind:
                                try:
                                    version = str(winreg.QueryValueEx(item, "DisplayVersion")[0])
                                except OSError:
                                    version = None
                                entries.append({"kind": kind, "name": name, "version": version})
                    except OSError:
                        continue
        except OSError:
            continue
    return {"status": "checked_windows_uninstall_records_only", "programs": entries}


def probe_port(port):
    if port not in {p for values in PORTS.values() for p in values}:
        raise ValueError("only_documented_paper_gateway_ports_are_checked")
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.5):
            return {"host": "127.0.0.1", "port": port, "status": "tcp_listener_present_identity_unverified"}
    except OSError:
        return {"host": "127.0.0.1", "port": port, "status": "no_tcp_listener_observed"}


def sdk_versions():
    result = []
    for name, expected in SDK_REQUIREMENTS.items():
        try:
            observed = importlib.metadata.version(name)
        except importlib.metadata.PackageNotFoundError:
            observed = None
        result.append({"package": name, "requiredVersion": expected, "installedVersion": observed,
                       "status": "pinned_version_present" if observed == expected else "missing_or_different_version"})
    return result


def next_step(broker, listeners):
    listening = any(p["status"] == "tcp_listener_present_identity_unverified" for p in listeners)
    if broker == "moomoo":
        if not listening:
            return "Install OpenD separately from the moomoo desktop app, sign in locally, and use 127.0.0.1:11111. Then run Leo account discovery."
        return "A loopback service is present. Run Leo account discovery to verify an active U.S. SIMULATE account; connection alone does not authorize trading."
    if broker == "ibkr":
        if not listening:
            return "Install the Client Portal Gateway and Java. Configure local-only access and verified TLS, start the gateway, then sign into a paper account at https://localhost:5000. TWS is a different gateway."
        return "A loopback service is present. Verify its TLS certificate and use Leo account discovery to verify isPaper=true. A port number is not proof of the account environment."
    if not listening:
        return "Optional TWS inspection: open TWS or IB Gateway, select Paper Trading, sign in, and enable the socket API for localhost. Use TWS paper port 7497 or Gateway paper port 4002. This is separate from Client Portal execution."
    return "A loopback service is present. TWS socket inspection is separate from the Client Portal execution adapter; an IBKR port number is not proof of the account environment."


def report(programs=None, probe=probe_port, versions=sdk_versions):
    brokers = []
    for broker, ports in PORTS.items():
        listeners = [probe(port) for port in ports]
        brokers.append({"broker": broker, "listeners": listeners, "authenticated": "not_checked",
                        "paperAccount": "not_checked", "tradingAuthorized": False,
                        "nextStep": next_step(broker, listeners), "downloadUrl": LINKS[broker],
                        "setupUrl": LINKS[broker + "Setup"]})
    return {"schemaVersion": "leo.broker-readiness.v1", "observedAt": datetime.now(timezone.utc).isoformat(),
            "platform": {"system": platform.system(), "machine": platform.machine(), "python": platform.python_version()},
            "installedPrograms": programs if programs is not None else windows_programs(),
            "sdkDependencies": versions(), "brokers": brokers,
            "limitations": ["No broker requests, credentials, account identifiers, balances, positions, or orders were accessed.",
                            "Uninstall records may omit portable installations. A missing listener can also mean a custom port.",
                            "Run the packaged sidecar self-check separately; SDK metadata does not establish import or runtime compatibility."]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="Print a structured, credential-free report.")
    args = parser.parse_args()
    result = report()
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print("Leo broker prerequisites — no broker account was accessed")
        for broker in result["brokers"]:
            print(f"\n{broker['broker']}: {broker['nextStep']}")
            print(broker["downloadUrl"])
        print("\nRun with --json for exact checks. Paper identity, user mandate and reconciliation remain required.")


if __name__ == "__main__":
    main()
