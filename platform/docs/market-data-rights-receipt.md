# Market-data rights receipt

AXIO7 separates feed authentication from permission to use the same data in a
customer-facing model product. A working API key proves technical entitlement
to a feed; a provider product page describes a general offering. Neither one
proves that the AXIO7 legal entity and account hold the required model-input,
customer-display, or derived-output publication rights.

The production Rust service therefore requires an account-specific, privately
reviewed v2 receipt at:

```text
quant_engine_rs/data/rights/market_data_rights_receipt.json
```

The file is deliberately ignored by Git. It is an attestation and hash
manifest, not a copy of the underlying agreement. Never put API keys, tokens,
account or license numbers, contract text, email bodies, signed URLs, or
private evidence artifacts in the receipt. Store the executed agreement,
order confirmation, or vendor correspondence in the approved private legal
evidence store and put only its SHA-256 digest in the receipt.

Use this exact schema:

```json
{
  "schema_version": "axio.market_data_rights.v2",
  "provider": "databento",
  "product": "EQUS.MINI",
  "legal_entity": "Exact subscribing or licensed legal entity",
  "plan_name": "Exact active provider plan",
  "plan_status": "ACTIVE",
  "permitted_uses": {
    "model_input": true,
    "customer_external_display": true,
    "derived_output_publication": true,
    "raw_data_redistribution": false
  },
  "evidence_kind": "EXECUTED_AGREEMENT",
  "evidence_artifact_sha256": "64-lowercase-hex-digest-of-private-evidence",
  "account_license_reference_sha256": "64-lowercase-hex-one-way-account-binding",
  "official_terms_url": "https://databento.com/legal/terms-of-use",
  "official_product_url": "https://databento.com/stocks",
  "official_evidence_url": "https://databento.com/support/tickets/non-secret-rights-reference",
  "valid_from": "2026-01-01T00:00:00Z",
  "valid_until": "2027-01-01T00:00:00Z",
  "issuer": "Vendor or venue that issued the evidence",
  "reviewer": "Authorized internal rights reviewer",
  "issued_at": "2025-12-31T00:00:00Z",
  "reviewed_at": "2026-07-28T20:00:00Z",
  "review_due_at": "2026-10-28T20:00:00Z"
}
```

The URL values above illustrate the required shape; use the actual official
provider URLs reviewed for the account. The official terms URL must resolve
under the selected provider's domain to a legal, terms, policy, licensing, or
agreement path. `official_product_url` must resolve to an official product,
dataset, stock, or equity page. For vendor-issued evidence,
`official_evidence_url` must be a direct official agreement, order,
confirmation, license, entitlement, rights, case, or support-ticket reference.
A homepage, pricing page, dataset page, blog post, or other generic product URL
does not qualify as vendor-issued account evidence. URLs must use HTTPS with a
real path and no query, fragment, embedded credentials, nonstandard port, IP
address, or secret.

`evidence_kind` must be exactly one of:

- `EXECUTED_AGREEMENT`
- `ORDER_CONFIRMATION`
- `VENDOR_WRITTEN_CONFIRMATION`
- `ACCOUNT_OWNER_ATTESTATION` (the separate, constrained path below)

`legal_entity`, `plan_name`, and `plan_status` must describe the same account
or license bound by the evidence. `plan_status` must be `ACTIVE`. Generate
`account_license_reference_sha256` with an approved one-way hashing process
over a domain-separated provider/product/account-or-license reference plus a
private random salt or pepper. Keep the source reference and salt outside the
receipt and source tree. The account-binding digest, evidence digest, and
receipt digest must all be different.

Raw-data redistribution is deliberately denied in the normal receipt. If a
separate authorization explicitly grants it, set
`permitted_uses.raw_data_redistribution` to `true` and add a distinct support
object:

```json
{
  "raw_data_redistribution_support": {
    "evidence_kind": "VENDOR_WRITTEN_CONFIRMATION",
    "evidence_artifact_sha256": "different-64-hex-private-evidence-digest",
    "official_evidence_url": "https://databento.com/support/tickets/non-secret-redistribution-reference"
  }
}
```

The separate evidence digest and URL must differ from the primary evidence.
Do not include `raw_data_redistribution_support` when redistribution is false.

The receipt is eligible only from `valid_from` through `valid_until`.
`issued_at` must not follow `reviewed_at`; the review must occur during the
validity window and no later than the server clock. `review_due_at` must follow
the review, remain inside the validity window, and must not have passed.

Offline training lineage and production publication use the same v2 parser,
account binding, evidence, URL, and clock checks. The training gate requires
`model_input: true` but does not independently require customer display or
derived-output publication. The production website gate requires all three.
Consequently, a model-input-only receipt may authorize a training dataset
without authorizing any customer-visible result.

## Account-owner attestation path

`ACCOUNT_OWNER_ATTESTATION` records the account owner's assertion. It is
**not** Databento-issued evidence, vendor confirmation, or legal advice. It is
eligible only when the owner supplies a signed and dated private attestation,
the exact account and subscription identity bindings, and an independently
captured technical-entitlement receipt that was fresh when the attestation was
signed. The public readiness reason remains
`OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT` so the evidence basis cannot be
mistaken for `VERIFIED` vendor evidence.

Do not copy the following placeholders into production. Replace them only from
the subscribing account's private records; this repository does not contain or
create a real identity, signature, account reference, or subscription
reference.

```json
{
  "schema_version": "axio.market_data_rights.v2",
  "provider": "databento",
  "product": "EQUS.MINI",
  "legal_entity": "<exact-account-holder-legal-entity>",
  "plan_name": "<exact-active-plan-name>",
  "plan_status": "ACTIVE",
  "permitted_uses": {
    "model_input": true,
    "customer_external_display": true,
    "derived_output_publication": true,
    "raw_data_redistribution": false
  },
  "evidence_kind": "ACCOUNT_OWNER_ATTESTATION",
  "evidence_artifact_sha256": "<sha256-of-signed-owner-attestation>",
  "account_license_reference_sha256": "<domain-separated-account-license-hash>",
  "official_terms_url": "https://databento.com/legal/terms-of-use",
  "official_product_url": "https://databento.com/stocks",
  "owner_attestation": {
    "issuer_role": "ACCOUNT_OWNER",
    "signed_at": "<signature-time-in-utc>",
    "account_identity_sha256": "<domain-separated-account-identity-hash>",
    "subscription_reference_kind": "OWNER_DEFINED_NOT_VENDOR_ID",
    "subscription_identity_sha256": "<domain-separated-subscription-identity-hash>",
    "technical_entitlement_receipt_sha256": "<sha256-of-exact-technical-receipt-bytes>"
  },
  "valid_from": "<rights-start-in-utc>",
  "valid_until": "<rights-expiry-or-renewal-review-boundary-in-utc>",
  "issuer": "<actual-account-owner-or-authorized-representative>",
  "reviewer": "<actual-authorized-internal-reviewer>",
  "issued_at": "<same-instant-as-owner-attestation-signed-at>",
  "reviewed_at": "<completed-review-time-in-utc>",
  "review_due_at": "<next-review-time-in-utc>"
}
```

For this path:

- Omit `official_evidence_url`; including it would falsely imply an official
  vendor evidence reference and fails closed.
- The signed attestation must state the exact provider, product, legal entity,
  active plan, four scope booleans, account/subscription bindings, and
  validity/review clocks represented by the receipt.
- `issuer_role` must be exactly `ACCOUNT_OWNER`. `issuer` must identify the
  actual signer and must not claim to be Databento or use a Databento domain.
- The account, subscription, account/license, signed-artifact, technical
  receipt, and pinned rights-receipt hashes must be valid, domain-separated,
  and pairwise distinct.
- `subscription_reference_kind` must be exactly `VENDOR_SUBSCRIPTION_ID` or
  `OWNER_DEFINED_NOT_VENDOR_ID`. Use the latter when the provider exposes no
  subscription ID. The kind is included in the subscription hash domain, so a
  local reference cannot later be relabeled as vendor-issued.
- All three derived-product scopes must be `true`, including when the receipt
  is checked by offline training. `raw_data_redistribution` must be `false`,
  and `raw_data_redistribution_support` must be absent.
- `signed_at` must equal `issued_at`, occur within the validity window, and not
  follow the completed review. The active-plan, validity, and review clocks
  are checked on every use.

Generate the technical receipt with the secret-safe capture described in
`docs/databento-technical-entitlement-receipt.md`. The validator reads the
exact private file at:

```text
quant_engine_rs/data/evidence/databento_technical_entitlement_latest.json
```

It verifies the receipt's exact schema, Databento provider, `EQUS.MINI`
dataset, `ohlcv-1m` range, three pinned official metadata endpoints, 2xx
statuses, nonzero response hashes, and byte-for-byte SHA-256 binding. Relative
to `owner_attestation.signed_at` (which must equal `issued_at`), its
`captured_at` must fall within the preceding 24 hours and may be no more than
five minutes later to tolerate bounded clock skew. This is point-in-time
signing evidence, not a rolling runtime freshness clock, so a valid owner
attestation does not require daily regeneration or re-signing. A missing,
changed, malformed, stale-at-signing, future-at-signing, wrong-provider,
wrong-product, or wrong-endpoint technical receipt blocks the owner-attested
path.

The technical receipt establishes only that the credential could access the
specified Databento metadata surface at capture time. It does not itself prove
commercial rights or live-feed freshness. The rights receipt's active-plan,
`valid_from`, `valid_until`, and `review_due_at` clocks continue to be checked
against current server time on every use. Production separately and
continuously requires the authenticated entitled real-time stream, fresh
completed bars, complete context, promoted model/calibration artifacts, and
ledger-backed forecast checks.

### Safe owner-attestation generator

`scripts/create-owner-market-data-rights-receipt.ps1` creates the private
handle-signed attestation, copies the exact sanitized technical receipt into
the deployment runtime, and commits the v2 rights receipt last. Before it
writes the runtime artifacts, it stages the exact bytes and runs
`quantctl data validate-market-data-rights`, which calls the same Rust parser
used by training and production readiness.

The utility never reads a market-data credential. It requires the operator to
pass the exact owner, legal entity, active plan, account reference,
subscription reference, scope booleans, signature/review clocks, and official
URLs. Raw redistribution must be explicitly passed as `$false`; any other
value is rejected. Account and subscription references are converted in
memory to salted, domain-separated hashes and are never serialized or printed.

Build the validator and capture fresh technical evidence first:

```powershell
Push-Location quant_engine_rs
cargo build --locked --bin quantctl
Pop-Location

powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File .\scripts\capture-databento-technical-entitlement.ps1
```

Load the exact private account and subscription references from the approved
secret store into process variables so their values do not appear in command
history. Then run the generator. Every angle-bracketed value below is a
required operator input; do not infer or invent it:

```powershell
$accountReference = <read-exact-account-reference-from-private-store>
$subscriptionReference = <read-exact-subscription-reference-from-private-store>

$result = & .\scripts\create-owner-market-data-rights-receipt.ps1 `
  -OwnerHandle "<authenticated-account-owner-handle>" `
  -OwnerSignature "<same-authenticated-account-owner-handle>" `
  -LegalEntity "<exact-subscribing-legal-entity>" `
  -PlanName "<exact-active-plan-name>" `
  -PlanStatus ACTIVE `
  -AccountReference $accountReference `
  -SubscriptionReference $subscriptionReference `
  -SubscriptionReferenceKind OWNER_DEFINED_NOT_VENDOR_ID `
  -ModelInputPermitted $true `
  -CustomerExternalDisplayPermitted $true `
  -DerivedOutputPublicationPermitted $true `
  -RawDataRedistributionPermitted $false `
  -AttestedAt "<UTC-signature-time>" `
  -ValidFrom "<UTC-rights-start>" `
  -ValidUntil "<UTC-rights-expiry-or-renewal-boundary>" `
  -ReviewerHandle "<actual-authorized-reviewer>" `
  -ReviewedAt "<UTC-completed-review-time>" `
  -ReviewDueAt "<UTC-next-review-time>" `
  -OfficialTermsUrl "https://databento.com/legal/terms-of-use" `
  -OfficialProductUrl "https://databento.com/stocks" |
  ConvertFrom-Json

$env:AXIO7_MARKET_DATA_RIGHTS_RECEIPT_SHA256 = $result.rights_receipt_sha256
```

Successful output contains only the three private output paths and their three
SHA-256 values. By default the ignored runtime paths are:

```text
infra/single-vm/runtime/private-rights-evidence/account_owner_attestation.json
infra/single-vm/runtime/quant-evidence/databento_technical_entitlement_latest.json
infra/single-vm/runtime/quant-rights/market_data_rights_receipt.json
```

The handle signature records the authenticated owner's explicit act; it is not
a cryptographic vendor signature and is never described as one. If the exact
legal entity, plan, account reference, subscription reference, or review
authority is unknown, stop—the generator intentionally cannot fill or guess
those values.

Before installation:

1. Confirm the selected provider and product exactly match production.
2. Confirm the legal entity, active plan, and account/license binding against
   the private evidence.
3. Confirm all three required public-use classes are expressly covered.
4. Hash the private evidence artifact and independently create the one-way
   account/license binding.
5. Record the official terms and account-specific evidence references.
6. Have an authorized reviewer set the validity and next-review clocks.

After installing the private receipt, pin its exact bytes in the server
environment:

```powershell
$receipt = Resolve-Path "quant_engine_rs/data/rights/market_data_rights_receipt.json"
$digest = (Get-FileHash -Algorithm SHA256 -LiteralPath $receipt).Hash.ToLowerInvariant()
[Environment]::SetEnvironmentVariable(
  "AXIO7_MARKET_DATA_RIGHTS_RECEIPT_SHA256",
  $digest,
  "Process"
)
```

Production infrastructure should set the same environment variable through
its secret/configuration manager, then restart the Rust service. The
`/api/v1/system/readiness` response is ready on this dimension only when
`market_data.public_use_rights.status` is `READY`. Vendor/venue evidence uses
reason `VERIFIED`; the account-owner path deliberately uses
`OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT`. That response exposes only the
decision and reason; it never exposes the legal entity, plan, evidence hashes
or URLs, account or subscription bindings, issuer, reviewer, signature, or
contract content.

The old `AXIO7_PUBLIC_MARKET_DATA_PROVIDER` and
`AXIO7_PUBLIC_MARKET_DATA_LICENSE_REFERENCE` variables remain diagnostic-only;
they cannot authorize publication. Databento's official portal documentation
describes account plan and live-data licensing management:
<https://databento.com/docs/portal>.

## Vendor confirmation request

If the licensing portal does not expose an account-specific document covering
the exact AXIO7 use case, send this request from the subscribing account. Do
not treat an invoice, successful API call, subscription acknowledgement, or
generic product page as a substitute for the written answer.

```text
Subject: Written confirmation of EQUS.MINI rights for AXIO7

Hello Databento Support,

Please provide written confirmation for the active Databento account and legal
entity associated with this email.

For the EQUS.MINI product, please confirm separately whether our active plan
permits each of the following:

1. Use of historical and live OHLCV data as input to internal statistical and
   machine-learning models.
2. Customer-facing display of real-time or derived market research on the
   paid AXIO7 web application.
3. Publication to AXIO7 subscribers of derived model outputs such as market
   regime, direction class, calibrated probability, expected-move interval,
   and supporting statistics.
4. Storage and replay of the licensed data for internal model training,
   validation, audit, and reproducibility.

AXIO7 does not intend to redistribute raw Databento records, API access, bulk
downloads, or a substitute market-data feed. Please also identify any required
attribution, caching limits, reporting obligations, display restrictions,
delayed-data labels, or termination requirements.

Please include the product/plan name, effective or renewal date, and a ticket,
order, or agreement reference that we can retain as account-specific evidence.

Thank you.
```

When Databento replies, retain the original response in the approved private
evidence store, hash the immutable export, and create the v2 receipt from that
evidence. Never commit the response or its private identifiers.
