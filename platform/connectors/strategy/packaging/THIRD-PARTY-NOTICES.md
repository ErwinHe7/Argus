# Third-party software in this development bundle

This is a local development build of proprietary Leo connector and quantitative
engine code. It is not a public release authorization. The bundle includes
CPython, Python libraries and a PyInstaller bootloader, and statically linked Rust
dependencies. OpenD is a separate vendor installation and is not redistributed.

`licenses/CPython-LICENSE.txt` contains the applicable Python license and bundled
notices. `licenses/python/` preserves available dependency license, copying,
notice and author files; `python-dependencies.json` records installed versions.
`licenses/rust/` and `rust-dependencies.json` record the source lockfile inventory
and locally available crate notices. The lockfile includes target-specific
packages that may not be linked into this host's binaries. Any missing notices
are listed in `native-build-receipt.json` outside the bundle and require release
review. Do not infer legal clearance from an inventory.

For the Windows development build created on 2026-09-07, CPython 3.12.14 is
collected from a dedicated dependency virtual environment using the installed
Codex primary runtime 26.905.11957 as its base. The base Python DLL has a valid
OpenAI OpCo, LLC Authenticode signature. This provenance does not mean Leo's
connector, SDK executable, MSI, or ZIP is signed by OpenAI. Only CPython and its
collected dependencies are included; the Codex application and other runtime
tools are not copied. The native receipt identifies the exact interpreter and
hashes. A generally distributed release must rebuild using an approved Python
distribution and complete its third-party notice review.

Sources: [Python license](https://docs.python.org/3/license.html),
[PyInstaller license and bootloader exception](https://pyinstaller.org/en/stable/license.html),
[moomoo SDK source](https://github.com/MoomooOpen/py-moomoo-api).
