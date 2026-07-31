# AXIO7 single-VM deployment

This target runs the public Next.js application, the private Rust research
service, the five-minute monitor scheduler, and automatic HTTPS on one Linux
VM. It works on AWS EC2 and ordinary ARM64/AMD64
VPS hosts. The Rust service is private to the Docker network; only Caddy exposes
ports 80 and 443.

## VM requirements

- Ubuntu 24.04 or Debian 12;
- 1 GB RAM plus 2 GB swap for the verified prebuilt-image runtime;
- 4 GB RAM minimum, and 8 GB preferable, only when building images on the VM;
- 20 GB free disk for the application runtime, before adding market archives;
- Docker Engine with Compose v2;
- inbound TCP 80/443 and UDP 443 allowed;
- an A/AAAA record for `AXIO7_DOMAIN` pointing to the VM.

The local CUDA GPU is for offline training. The production HMM, deterministic
scanners, and Rust inference service do not require a server GPU. Next.js
shares the Rust container's private network namespace, while `quantd` remains
bound to loopback; Caddy cannot reach the Rust control port directly.

This shared-network-namespace topology is the explicit deployment decision for
the control plane. Direct Railway deployment is unsupported and the container
entrypoint exits with status 78 when Railway environment identifiers are
present. Do not bind `quantd` to `0.0.0.0` or place a generic reverse proxy in
front of it: the kill switch and paper-control routes require a future audited
TLS/mTLS gateway before any non-loopback deployment is eligible.

The Compose contract fixes `quantd` at one replica. The entrypoint also takes a
nonblocking `flock` lease at `data/state/quantd.instance.lock` on `quant-state`,
so an accidental `docker compose --scale quantd=...` override fails closed
before a second process opens the ledger. `quant-state` persists the prediction
ledger and registry metadata, while `quant-live` persists live receipts across
container recreation. Before an upgrade, quiesce all writers and back up the
complete state/live volume pair, including SQLite and its WAL, the immutable
runtime bind directories, Caddy state, protected configuration, and exact image
IDs for every Compose service. `scripts/production-release-backup.sh` performs
that operation without
printing or sourcing `.env.server`. Horizontal scaling remains prohibited until
the ledger has a shared database and an audited multi-writer lease.

## Deploy

Clone the repository on the VM, then:

```sh
cd Axio7/infra/single-vm
test -z "$(git -C ../.. status --porcelain)"
release_commit="$(git -C ../.. rev-parse HEAD)"
export GIT_COMMIT="$release_commit"

bash prepare-runtime.sh
# Fill the required server values, GIT_COMMIT, independent secrets, and
# externally generated artifact pins. Never print the populated file.

# Install authorized immutable release inputs at these exact ignored paths:
# runtime/quant-normalized/market_bars.csv
# runtime/quant-manifests/...
# runtime/quant-rights/market_data_rights_receipt.json
# runtime/quant-evidence/databento_technical_entitlement_latest.json
# runtime/private-rights-evidence/account_owner_attestation.json
# runtime/quant-promotion/predictor_promotion_latest.json
# runtime/quant-promotion/evidence/...
# runtime/quant-calibration/probability_calibration_latest.json

chmod 0700 runtime/private-rights-evidence
if test -f runtime/private-rights-evidence/account_owner_attestation.json; then
  chmod 0600 runtime/private-rights-evidence/account_owner_attestation.json
fi

bash prepare-runtime.sh --check-env
docker compose --env-file .env.server build --pull
docker compose --env-file .env.server up -d --no-build --pull never
bash verify-runtime.sh
```

Both application images carry
`org.opencontainers.image.revision=$GIT_COMMIT`. A blank commit makes Compose
configuration fail before a build. Run Compose from this directory: copying
`compose.yaml` elsewhere changes its `../..` build context and can compile stale
source.

The private release inputs are host-mounted read-only:

- `quant-rights` must contain an authorized
  `axio.market_data_rights.v2` receipt. Its exact file hash is independently
  supplied through `AXIO7_MARKET_DATA_RIGHTS_RECEIPT_SHA256`.
- `quant-evidence` may contain the private, sanitized
  `databento_technical_entitlement_latest.json` receipt required by an
  `ACCOUNT_OWNER_ATTESTATION` rights receipt. It is mounted read-only and does
  not replace the separate rights receipt or the live-stream readiness gates.
- `private-rights-evidence` contains the signed
  `account_owner_attestation.json` for that owner-attested path. It is mode
  `0700` on preparation and its sole optional file must be mode `0600` with one
  hard link. It is included in checksum-sealed backup/rollback and hash-bound
  by sealed acceptance to `evidence_artifact_sha256`. It is never mounted into
  a container or copied into an acceptance bundle; the acceptance receipt
  records only its SHA-256. Because the backup archive necessarily contains
  the recoverable private bytes, keep backup storage access-controlled and
  encrypted at rest.
- `quant-promotion` contains the v2 registry and its bound forward-shadow
  evidence. `MODEL_PROMOTION_REGISTRY_SHA256` pins the registry bytes and
  `MODEL_PROMOTION_ENTRY_SHA256_PINS` independently pins every
  `SYMBOL@MODEL_SHA256` entry.
- `quant-calibration` contains the promoted v2 registry. Its fixed container
  path and exact hash are supplied through
  `AXIO_PROBABILITY_CALIBRATION_ARTIFACT` and
  `AXIO_PROBABILITY_CALIBRATION_SHA256`.
- The nine frozen model artifacts come from the commit-bound quantd image.
  Docker initializes the release-specific
  `axio7_quant-models-$GIT_COMMIT` volume from that image and mounts it
  read-only. Never reuse that volume name for another commit.

Empty or invalid release directories do not authorize publication. Rust
readiness remains blocked; no product page, generic vendor URL, API key, or
legacy license-reference environment variable can substitute for the pinned
receipts.

The canonical production configuration supervises Databento equities inside
`quantd`; the process exits if that long-running supervisor terminates instead
of leaving a falsely healthy API behind. Massive child workers are off by
default (`AXIO_START_MASSIVE_WORKERS=false`). An explicitly Massive deployment
must supply readable immutable historical bars, a frozen-universe registry,
and the persistent ledger path before enabling those workers; the entrypoint
then monitors every child and terminates the container if any child exits.

The append-only PostgreSQL live archiver runs as the private `postgres` and
`market-archive` Compose services documented in
`../market-data/postgres/README.md`. PostgreSQL publishes no host port. Its
data directory lives under `runtime/market-data/postgres` on the dedicated
market-data volume; the archiver receives the SQLite source read-only and a
server-only database password. `MARKET_DATABASE_URL` remains an optional
managed-TLS override for a later RDS migration. The exact rights scope and
pinned rights-receipt hash are mandatory, and archive activation never
upgrades the underlying data license.

From the Windows development machine, the ignored server environment can be
prepared without printing or committing secrets:

```powershell
.\scripts\prepare-single-vm-env.ps1
```

That helper preserves production-only values already present in its output,
but it does not create or authorize Databento rights, model promotion,
calibration, normalized-data, or commit pins. On a new VM, start from
`.env.server.example` through `prepare-runtime.sh` and populate every required
external value explicitly.

For an existing production environment, bind the preserved server secrets to
the exact release commit and the already generated owner-attested evidence
without printing or rewriting unrelated values:

```powershell
.\scripts\bind-production-release-env.ps1 `
  -EnvPath infra/single-vm/.env.server `
  -GitCommit (git rev-parse HEAD) `
  -RightsReceiptPath infra/single-vm/runtime/quant-rights/market_data_rights_receipt.json `
  -TechnicalEntitlementReceiptPath infra/single-vm/runtime/quant-evidence/databento_technical_entitlement_latest.json `
  -OwnerAttestationPath infra/single-vm/runtime/private-rights-evidence/account_owner_attestation.json
```

The helper validates all three artifacts and their nested hashes, preserves
every unrelated environment value, forces all automatic-execution flags
false, and atomically replaces the ignored environment file.

`verify-runtime.sh` is a container-parity check only: it confirms that web can
reach the private Rust service, both images carry the expected commit, all
nine frozen artifacts are loaded with no failures, and automatic execution is
false. It may pass while customer publication is correctly blocked. Only the
sealed regular-session acceptance below can establish publishable readiness.

Caddy requests and renews TLS automatically after DNS reaches the VM. Verify:

```sh
curl --fail https://axio7.com/
docker compose --env-file .env.server logs --tail 100 quantd
docker compose --env-file .env.server logs --tail 100 monitor-scheduler
```

The quantd container healthcheck calls loopback-only `/health` so a provider
outage cannot prevent the website, Paddle purchase actions, or fail-closed
recovery guidance from starting. `verify-runtime.sh` separately requires
`/ready`, which checks the live provider supervisor without putting the
research token in host process arguments or logs. Public publication readiness
remains the strict authenticated `/api/v1/system/readiness` contract and is
required by the sealed acceptance helper.

## Upgrade backup and rollback

### One-time migration from the flat legacy deployment

The existing `/opt/axio7` host may predate the commit-bound checkout layout:
`compose.yaml`, `Caddyfile`, `.env.server`, and `runtime/` are directly under
that directory, and the running web/quantd images have no
`org.opencontainers.image.revision` label. The canonical backup helper
correctly refuses that state. Do not weaken its revision check.

Securely copy both one-time helpers from `scripts/` to one owner-only directory
on the VM. First prove the observed four-service topology without changing a
service or image:

```sh
sudo bash /root/axio7-migration-tools/production-legacy-flat-migration-backup.sh \
  --deployment-dir /opt/axio7 \
  --backup-root /mnt/axio7-migration-backup \
  --preflight-only
```

Use a separate encrypted backup filesystem with enough free space for the
runtime tree and four named volumes; never place the backup root inside
`/opt/axio7`, its runtime tree, or Docker's data root. After the read-only
preflight passes, run the backup with the explicit outage acknowledgement:

```sh
sudo bash /root/axio7-migration-tools/production-legacy-flat-migration-backup.sh \
  --deployment-dir /opt/axio7 \
  --backup-root /mnt/axio7-migration-backup \
  --confirm-legacy-quiesce
```

This bridge accepts only the exact legacy `axio7` project: one running
`quantd`, `web`, `caddy`, and `monitor-scheduler`; the four
fixed `quant-state`, `quant-live`, `caddy-data`, and `caddy-config` volumes;
the exact observed runtime/release binds; and absent web/quantd revision
labels. It
verifies that all three execution gates are false, records the full container
and image IDs for every service, adds recovery tags for all four images, and
stops all four services. It then archives the complete detached volumes
together—including every SQLite database and any `-wal`, `-shm`, or journal
file—the approved runtime trees, and the exact flat configuration. Archive
paths, member types, directory sets, file checksums, and a full extraction
preflight must all pass before the bundle is sealed. Success intentionally
leaves the legacy deployment stopped for cutover.

The mode-`0700` bundle contains the recoverable `.env.server`, Caddy private
state, and possibly the private owner attestation. Keep its parent directory
access-controlled and encrypted at rest. Do not delete the recovery image
tags, their exact image IDs, or the bundle until the canonical deployment and
rollback have both been verified.

If cutover fails, first stop every container in the `axio7` Compose project,
then use the restore helper copied into the sealed bundle:

```sh
sudo bash \
  /mnt/axio7-migration-backup/legacy-flat-YYYYMMDDTHHMMSSZ/restore-legacy-flat.sh \
  --deployment-dir /opt/axio7 \
  --backup-dir \
    /mnt/axio7-migration-backup/legacy-flat-YYYYMMDDTHHMMSSZ \
  --confirm-legacy-restore
```

Restore verifies the complete checksum allow-list, archive paths and types,
full extracted manifests, saved Compose/Caddy configuration, disabled
execution gates, and every local recovery tag/image-ID binding before
overwriting anything. It first creates a separate mode-`0700`
`pre-legacy-restore-*` emergency snapshot of the current flat files, runtime,
and all four volumes. It restores only the fixed four volume names, retags the
exact legacy images, and starts with `--no-build --pull never`; it cannot
silently rebuild from the stale flat build contexts. A failure after
replacement begins stops every AXIO7 container it can resolve and reports the
retained emergency and preflight paths for operator recovery. Neither helper
prunes images or volumes.

This one-time bridge is only for entering the commit-bound release layout.
Every subsequent release must use the canonical helper below.

### Commit-bound releases

Run the backup helper from the clean, currently deployed checkout before
switching the `current` path to a candidate. `GIT_COMMIT`, both running OCI
revision labels, and that checkout's `HEAD` must be identical. This captures
the old Compose and Caddy files before replacing them. The normalized hash must
be the exact hash bound by the model release; for the current nine artifacts it is
`ef9a80712ac2b57489c563efade124c76f06e563320b69aafe23a5d8f2bd92eb`.

```sh
bash ../../scripts/production-release-backup.sh \
  --compose-dir /opt/axio7/current/infra/single-vm \
  --backup-root /opt/axio7/backups \
  --expected-normalized-sha256 \
    ef9a80712ac2b57489c563efade124c76f06e563320b69aafe23a5d8f2bd92eb \
  --confirm-quiesce
```

The helper leaves quantd, web, the scheduler, and Caddy stopped for cutover.
Do not run `docker compose down -v`, rename the `axio7` Compose project, or
replace the existing runtime bind paths. After making the clean candidate
commit current, build from this directory and start only the already-built
images:

```sh
export GIT_COMMIT="$(git -C ../.. rev-parse HEAD)"
exec 9>runtime/.production-release.lock
flock -n 9 || { echo "another release operation is active" >&2; exit 1; }
docker compose --env-file .env.server config --quiet
docker compose --env-file .env.server build --pull
docker compose --env-file .env.server up -d --no-build --pull never
bash verify-runtime.sh
flock -u 9
```

Backup and rollback acquire the same lock themselves. Hold it across every
manual build/cutover command as shown; this prevents a concurrent backup or
rollback from racing service and volume attachment checks.

If rollback is required, restore the exact old image pair and the matching
state/live/WAL/runtime/Caddy set together:

```sh
bash ../../scripts/production-release-rollback.sh \
  --compose-dir /opt/axio7/current/infra/single-vm \
  --backup-dir /opt/axio7/backups/release-YYYYMMDDTHHMMSSZ-COMMIT \
  --confirm-restore
```

Rollback verifies every checksum and old-image revision, fully extracts all
release archives into isolated staging storage, and only then stops writers.
Before overwrite it checksum-seals the current environment, Compose/Caddy
configuration, exact image IDs and revision labels, all runtime artifacts, and all
four current volumes. A failure after replacement begins triggers a
best-effort automatic restore of that emergency set. Success requires
quantd/web liveness health, Caddy, the scheduler, and the IBKR gateway running,
the exact old image ID for every Compose service, and a read-only
model-universe manifest matching the old quantd image. It never restores the
SQLite main file independently of its WAL.
The emergency directory and displaced runtime directories remain available
for operator recovery. The prior image IDs must still exist locally; until a
signed remote image registry is added, host/image loss remains an external
recovery blocker.

## Nine-symbol production acceptance

During a genuine US regular session, with all nine symbols freshly published,
run:

```sh
python3 ../../scripts/seal-nine-symbol-acceptance.py \
  --compose-dir "$PWD" \
  --output-root /opt/axio7/acceptance \
  --public-origin https://axio7.com \
  --expected-commit "$GIT_COMMIT" \
  --expected-normalized-sha256 \
    ef9a80712ac2b57489c563efade124c76f06e563320b69aafe23a5d8f2bd92eb
```

The helper takes two identical readiness snapshots around an archive of the
per-symbol status, receipt, and immutable publication files. It requires
`SPY`, `QQQ`, `NVDA`, `AAPL`, `MU`, `SOXX`, `NBIS`, `BE`, and `IGV`, all four
5/15/30/60-minute horizons, promoted calibration, independently pinned
promotion, verified v2 rights, complete ledger commits, fresh causal inputs,
bounded cutoff skew, and all execution flags false. An owner-attested rights
receipt additionally requires both the host-only signed attestation to match
the rights receipt's `evidence_artifact_sha256` and the fresh sanitized
technical-entitlement file to match the nested technical hash and the
container artifact manifest. The private attestation contents never enter the
container or acceptance bundle. Acceptance also inspects the effective
running mounts: quantd must have the exact expected read-only artifact bind
set and no running Compose container may bind the private directory or an
ancestor of it. It binds:

- clean source commit and both OCI image IDs/revision labels;
- Compose, Caddy, host/container production-config hashes;
- exact normalized data, manifest, model, promotion evidence, calibration,
  and rights hashes;
- the sanitized readiness/universe/live responses and immutable publication
  bundle;
- a fresh, trusted-TLS `https://axio7.com/api/health` response for the same
  commit, the local Caddy domain/config hash, exact running quantd/web image
  IDs, healthy quantd/web containers, and running Caddy/scheduler containers.

Output is atomically installed with a SHA-256 component manifest. It is an
integrity seal, not a digital signature or evidence of predictive accuracy.
Outside a real regular session, on changing publications, on stale/sparse
context such as an unavailable UUP bar, or on any missing pin, it exits without
creating an accepted receipt. The VM must be able to reach its canonical public
origin directly; broken hairpin routing, stale A/AAAA records, an untrusted TLS
chain, or a redirect fails closed. Scheduler `running` proves process state
only, not that every monitor invocation succeeded.

The scheduler invokes the authenticated market-monitor worker every five
minutes. The route itself skips weekends and times outside the US regular
session window.

## Owner-only IBKR market data

The compose stack includes the official IBKR Client Portal Gateway for
owner-authorized Level 1 snapshots. Its TLS port is published only on VM
loopback, is not routed by Caddy, and is reachable from the Next.js server over
the private Compose network. Set these values in `.env.server`:

```dotenv
IBKR_BASE_URL=https://ibkr-gateway:5000/v1/api
IBKR_MARKET_DATA_ENABLED=true
IBKR_ALLOW_INSECURE_TLS=true
```

After starting the stack, open a tunnel from the operator workstation:

```powershell
ssh -N -L 5000:127.0.0.1:5000 ubuntu@YOUR_VM
```

Then visit `https://localhost:5000`, accept the gateway's local certificate,
and complete the IBKR login and 2FA in the browser. Do not put an IBKR password
or 2FA response in `.env.server`. The authenticated AXIO7 administrator sees
the gateway/session state and an explicitly labeled owner-only snapshot on the
research home page. Other users receive no IBKR data.

This connector does not grant public redistribution rights. The app calls only
market-data endpoints, substitute retail feeds are disabled on the IBKR route,
and every execution environment gate remains false.

## Data activation boundary

An empty `runtime/quant-normalized` directory is valid for a blocked research
service: it answers `DATA_UNAVAILABLE`. It can never produce a sealed
production acceptance receipt. Place only licensed, point-in-time normalized
archives there. Do not publish the current personal/research-only Massive
archive as public-product data.

`MASSIVE_API_KEY` alone is not proof of redistribution rights. Public momentum
and VWAP monitoring requires a provider contract that permits the website's
use. Gamma monitoring additionally requires complete realtime OPRA chains,
contract definitions, timestamped daily open interest, and the appropriate
external-display rights.

When optional Massive workers are enabled, SIP equities and OPRA options use
separate readiness scopes and separate supervised child processes. An OPRA
failure leaves an entitled equities worker available; a SIP failure likewise
does not disable an entitled options watcher. Each failed scope remains
explicitly unavailable rather than receiving delayed or synthetic fallback.

The three live/automatic execution environment gates and each accepted
publication's `execution_enabled=false` value are verified. This runbook does
not assert that paper-control routes are absent.

`DATABENTO_API_KEY` is consumed only by the Rust data service. A cost estimate
does not download data, and every billable historical request still requires
an explicit confirmation and maximum USD cap.

## Verified AWS Free Plan deployment

The production bundle was verified on an AWS EC2 `t3.micro` instance in
`us-east-2` with 1 GB RAM, 2 GB swap, and a 20 GB `gp3` volume. The application
images were built off-host and loaded into Docker, avoiding a memory-intensive
server build. Observed steady-state memory for Caddy, Next.js, the Rust engine,
and the monitor scheduler was under 100 MB in total.

This small runtime does not relax the data-readiness boundary. It can serve the
site and the deterministic Rust API, but public market candidates remain
unavailable until a redistributable realtime feed and a separately validated,
promoted model artifact are configured.
