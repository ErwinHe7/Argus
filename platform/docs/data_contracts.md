# Data contracts and Nasdaq boundary

`Bar` requires symbol, UTC open/close time, OHLC, volume, finalized flag, source, source version, availability time and lineage hash. `Quote` requires symbol, bid/ask, sizes, event/availability time, sequence and scope.

The Nasdaq adapter decodes the official QBBO 2.1 quotation message: 6-byte nanoseconds-after-midnight timestamp, 8-byte symbol, four-decimal prices and displayed sizes. The result is `NASDAQ_BBO`, meaning the best quote in the Nasdaq execution system. It is not consolidated U.S. NBBO.

To use it, supply a licensed raw QBBO capture and session date:

```powershell
.\scripts\quantctl.ps1 data nasdaq-qbbo --capture C:\licensed\qbbo.bin --date 2026-07-20
```

No licensed capture or Nasdaq transport endpoint is currently configured. Historical research therefore uses the existing Massive consolidated stock aggregates. SPX requires a licensed index source. Executable SPXW backtests require historical OPRA/Cboe bid/ask quotes, sizes, quote times, contract metadata, expiry, strike, call/put, multiplier and underlying price. Without those fields the system reports `NOT_EXECUTED_NO_OPRA_NBBO`.
