# Calendar export and research journal

The local `intraday_quant.radar` module prepares public research artifacts from
explicitly reviewed calendar observations. It uses only Python's standard
library (and the operating system's IANA timezone database). It does not download
quotes, fetch web pages, call an LLM, or submit orders. The separate hosted
`workers/event-radar` collector owns automatic calendar polling.

The initial reviewed observations are in
`features/research-desk/data/event-radar-seeds.json`; the public wire contract is
`features/research-desk/data/event-radar-contract.md`.

The seed includes a source URL, conservative observation time, review deadline,
and content hash for every source. Manual hashes identify the retained structured
observations, not an original HTML snapshot. Re-exporting the same observations
never updates source freshness. An expired calendar remains a dated reference;
it does not become current because a process is running. The latest initial
verification was September 10, 2026. This small calendar is not full-market
earnings coverage.

## Export

Run from `Argus/platform` with the existing research virtual environment:

```powershell
$env:PYTHONPATH = 'intraday_quant/src'
& .quant-runtime/strategy-research-venv/Scripts/python.exe -m intraday_quant.radar --seeds features/research-desk/data/event-radar-seeds.json --output features/research-desk/data/event-radar.json --once
```

On Linux, use the local Python interpreter:

```sh
PYTHONPATH=intraday_quant/src python3 -m intraday_quant.radar --seeds features/research-desk/data/event-radar-seeds.json --output /home/leo/radar/event-radar.json --once
```

`--watch --state-dir PATH --interval-seconds 1200` re-exports only when local input
or journal content changes. The permitted interval is 300–86400 seconds. It makes
no network calls and therefore does not refresh the official calendar itself.
Create `SHUTDOWN` in that state directory for graceful termination. Invalid input
is logged as an error; the previous output remains intact. The output replacement
is atomic. Do not run competing exporters writing the same output path.

The hosted collector means that calendar polling does not require a VPS. A VPS
can still host the heavier research runner or a separately authenticated broker
connector. Neither is enabled by this calendar module.

## Register a hypothesis before an event

Write the exact hypothesis to a UTF-8 text file, then run:

```sh
PYTHONPATH=intraday_quant/src python3 -m intraday_quant.radar --seeds features/research-desk/data/event-radar-seeds.json --state-dir /home/leo/radar/private --append hypothesis --event bls-cpi-2026-09-11 --statement-file /home/leo/radar/hypothesis.txt
```

The process assigns the registration timestamp under a SQLite write transaction.
It rejects registration at or after the verified event instant. Where only a
date is known, it closes registration at the beginning of that date in Eastern
Time. It rejects stale or failed source verification and events not present in
the manifest. It freezes the exact event revision when the first record is
registered; rescheduled or corrected events need a new identifier while the old
revision remains available for the original journal records.

This is a local research record. The system clock and local storage are controlled
by their owner; a local journal is **not an independently trusted timestamp**.
No public record is created automatically. A server-anchored registration system
and explicit promotion policy are needed before marketing prospective forecast
accuracy. Do not present these records as an independently audited track record.

## Record an observed outcome

After the event, prepare a factual outcome in a text file and supply the original
hypothesis identifier, an allow-listed primary source URL, and the timestamp at
which that source became available:

```sh
PYTHONPATH=intraday_quant/src python3 -m intraday_quant.radar --seeds /home/leo/radar/retained-seeds.json --state-dir /home/leo/radar/private --append outcome --event EVENT_ID --hypothesis-id event-record-00000001 --statement-file /home/leo/radar/outcome.txt --source-url https://www.bls.gov/news.release/cpi.htm --source-available-at VERIFIED_UTC_TIMESTAMP
```

The example placeholders require actual evidence. The module validates the source
host and chronology; an operator must verify the source's contents and timestamp.
It does not infer facts from the URL. It rejects a source availability time before
the event, an availability time after registration, duplicate outcomes, and an
outcome attached to another event's hypothesis. The allowed primary hosts are
explicit in `radar.py`; adding a source is a reviewed code change.

The database uses full synchronous SQLite transactions, update/delete rejection
triggers, immutable event snapshots, and a chained content hash. Concurrent
appends serialize. Corruption, changed event revisions, and a regressed clock
fail validation. These controls detect accidental or partial edits; an owner
with full filesystem access can rebuild a whole journal. Keep private storage
access restricted and back it up along with the retained event manifest.

Exporting with `--state-dir` includes the validated journal. The current public
seed exports **zero hypotheses and zero outcomes**. No probability, hit rate,
or market-return score is computed. Earnings call times are labeled as calls,
never substituted for the first public results-release timestamp.

## Verification

```powershell
$env:PYTHONPATH = 'intraday_quant/src'
& .quant-runtime/strategy-research-venv/Scripts/python.exe -W error::ResourceWarning -m unittest discover -s intraday_quant/tests -p test_radar.py -v
```

These are injected software tests. They are not broker-backed evidence and do
not establish profitable or predictive behavior. The scope covers strict JSON,
primary-source validation, future-data rejection, Eastern-time boundaries,
source freshness preservation, transactional journals, concurrent appends,
frozen event revisions, outcome chronology, and failure retention.
