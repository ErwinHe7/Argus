# Moomoo official Quote runtime

These Windows x64 runtime files were built on 2026-07-21 from the user's
official `MMAPI4CPP_10.9.6908.7z` package with Visual Studio 2022 (v143) and
protobuf 3.21.5, which is the version required by the generated SDK headers.

The bridge is quote-only. Its runtime path creates `MMAPI::CreateQotApi()` and
subscribes to US `Basic`, `Ticker`, and `K_1M` for SPY, QQQ, IWM, SOXX, TLT,
HYG, UUP, and GLD; it does not construct, connect,
unlock, or call the Trade API. It writes SDK callbacks as JSON Lines to stdout
for the Rust supervisor.

SHA-256:

- `moomoo_quote_bridge.exe`: `6D63DEB49E254CCBBDBA932A4DDF99D44D602750CBFBE44D15272E88EDA6C383`
- `APIChannel.dll`: `4B689544C418E221B384BC0CBD08713F56EEC7C0AEFC9DD7F2D44A88CA2C19EB`

The DLL is vendor runtime code and must remain beside the executable. OpenD
must be logged in and listening only on `127.0.0.1:11111`.
