# U.S. listing directory

This feature ingests the two official Nasdaq Trader symbol directories into an
ignored local catalog. It adds listing identity and search; it does not download
quotes, extend a trained model's accepted symbol universe, infer S&P 500 membership,
or establish which instruments a broker lets a particular account trade.

```powershell
node --import tsx scripts/market-universe-refresh.ts
node --import tsx --test scripts/market-universe.test.ts
```

The refresh writes `.quant-runtime/market-universe/catalog.json` only after both
sources pass validation. Raw directory files are stored by SHA-256 in the same
ignored folder. Refresh failure leaves the previous artifact intact, and the
server rejects an expired artifact. No request-time vendor access or paid source
is introduced. A deployment must provision its own catalog storage/refresh before
the directory is available there; this local filesystem is not a cloud datastore.

`loadMarketUniverse()` is server-only. `searchMarketUniverse()` searches the
validated entries and returns bounded pagination. `NASDAQ` filters the listing
venue, not Nasdaq-100 membership. `non_etf` includes preferred shares, warrants,
units, rights and other listed instruments because the directory has no dependable
common-stock-only classification. Native ACT, Nasdaq and CQS symbols are retained;
do not pass them directly to brokers without contract resolution.

The source footer preserves its unzoned creation time verbatim. Expiry is seven
days after midnight UTC on the oldest source creation date, a conservative
calendar-date ceiling that is not reset by downloading an old file again. This
directory is not point-in-time historical membership or a trading-status feed.

Sources:

- [Nasdaq symbol directory field definitions](https://www.nasdaqtrader.com/trader.aspx?id=symboldirdefs)
- [Nasdaq-listed securities](https://www.nasdaqtrader.com/dynamic/SymDir/nasdaqlisted.txt)
- [Other exchange-listed securities](https://www.nasdaqtrader.com/dynamic/SymDir/otherlisted.txt)
- [Nasdaq Equity Trade Journal definitions](https://www.nasdaqtrader.com/content/home/help/ETJdl.pdf), identifying exchange code M as NYSE Texas

For actual research coverage, use validated fresh symbol-specific Rust Market Map
snapshots and their provenance. Directory inclusion alone must never show a symbol
as analyzed or eligible for a calibrated model.
