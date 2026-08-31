# Databento technical entitlement receipt

`scripts/capture-databento-technical-entitlement.ps1` captures a narrow,
API-level receipt for the Databento `EQUS.MINI` historical metadata surface. It
answers only whether the process credential could authenticate, see the
dataset, see the `ohlcv-1m` schema, and obtain a non-empty entitled range for
that schema at the capture time.

This is **not** the private market-data rights receipt described in
`docs/market-data-rights-receipt.md`. In particular, it does not establish:

- customer-facing display rights;
- model-input or derived-output publication rights;
- raw or historical data redistribution rights;
- a live subscription acknowledgement, live-feed freshness, or coverage;
- the subscribing legal entity, plan status, agreement, or effective dates.

Public publication must therefore remain fail-closed unless the separate,
account-bound market-data rights receipt and all runtime freshness and
publication gates pass.

## Capture

Provide `DATABENTO_API_KEY` to the PowerShell process through the approved
secret manager or server environment. Do not put it on the command line or in
a checked-in file. Then run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\capture-databento-technical-entitlement.ps1
```

The default output is:

```text
quant_engine_rs/data/evidence/databento_technical_entitlement_latest.json
```

That path and interrupted-write temporary files are ignored by Git. An
alternate private destination can be supplied with `-OutputPath`. The script
refuses any destination named `market_data_rights_receipt.json` so this
technical artifact cannot overwrite the separate rights gate. The script
does not touch the destination until all three calls and semantic checks pass,
then stages and atomically replaces the receipt in the same directory. A
failed call, invalid JSON response, missing dataset/schema, invalid range, or
failed staging write leaves the last successful receipt unchanged.

The credential is read only from the process `DATABENTO_API_KEY` environment
variable. HTTP Basic is constructed in memory with the key as username and an
empty password. Redirects are disabled, the origin is pinned to
`https://hist.databento.com:443`, TLS 1.2 certificate validation and revocation
checks remain enabled, each request has a bounded timeout, and only 2xx
`application/json` responses under the size limit are accepted.

The official endpoints are:

- `GET https://hist.databento.com/v0/metadata.list_datasets`
- `GET https://hist.databento.com/v0/metadata.list_schemas?dataset=EQUS.MINI`
- `GET https://hist.databento.com/v0/metadata.get_dataset_range?dataset=EQUS.MINI`

Databento documents the HTTP RPC surface and Basic authentication at
<https://databento.com/docs/api-reference-historical/basics/authentication?historical=http&live=http>.
The dataset-range method is documented at
<https://databento.com/docs/api-reference-historical/metadata/metadata-get-dataset-range>.

## Persisted contract

The receipt uses schema
`axio.databento_technical_entitlement.v1`. It contains only:

- receipt status, provider, product, dataset, and UTC capture time;
- for each endpoint: host, path without its query, HTTP status, and SHA-256 of
  the exact response bytes;
- `entitled: true`;
- the dataset range and the validated `ohlcv-1m` range.

It never stores the API key, Basic header, account data, response body, query
string, signed URL, plan, or license data. Response fixtures under
`scripts/fixtures/databento-technical-entitlement/` are synthetic parser tests
only and are not entitlement evidence.

Run the offline contract test with:

```powershell
node --test .\scripts\databento-technical-entitlement-contract.test.mjs
```

When the separate account-owner rights basis is appropriate, bind the exact
receipt bytes with the safe operator workflow in
`docs/market-data-rights-receipt.md`. That workflow copies this sanitized
receipt into the ignored single-VM runtime and validates the combined rights
receipt through the production Rust parser. For that owner-attested path,
technical-receipt freshness is evaluated relative to the attestation signature
time, not as a rolling live-feed heartbeat; current rights/review clocks and
live provider/feed freshness remain separate runtime gates. It does not upgrade
this technical receipt into vendor-issued licensing evidence.
