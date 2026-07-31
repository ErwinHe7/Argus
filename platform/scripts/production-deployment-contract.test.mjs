import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

const compose = read('infra/single-vm/compose.yaml');
const environmentExample = read('infra/single-vm/.env.server.example');
const quantdDockerfile = read('infra/single-vm/quantd.Dockerfile');
const marketArchiveDockerfile = read('infra/single-vm/market-archive.Dockerfile');
const quantdDockerignore = read('infra/single-vm/quantd.Dockerfile.dockerignore');
const webDockerfile = read('Dockerfile');
const rootDockerignore = read('.dockerignore');
const prepareRuntime = read('infra/single-vm/prepare-runtime.sh');
const verifyRuntime = read('infra/single-vm/verify-runtime.sh');
const backup = read('scripts/production-release-backup.sh');
const rollback = read('scripts/production-release-rollback.sh');
const acceptance = read('scripts/seal-nine-symbol-acceptance.py');
const deploymentReadme = read('infra/single-vm/README.md');

test('single-VM build binds both images to an explicit clean commit', () => {
  const buildArgMatches = compose.match(/GIT_COMMIT:\s*\$\{GIT_COMMIT:\?[^}]+\}/g) ?? [];
  assert.equal(buildArgMatches.length, 3);
  assert.match(compose, /image:\s*axio7-quantd:\$\{GIT_COMMIT:\?/);
  assert.match(compose, /image:\s*axio7-web:\$\{GIT_COMMIT:\?/);
  assert.match(compose, /image:\s*axio7-market-archive:\$\{GIT_COMMIT:\?/);
  assert.match(quantdDockerfile, /LABEL org\.opencontainers\.image\.revision=\$GIT_COMMIT/);
  assert.match(webDockerfile, /LABEL org\.opencontainers\.image\.revision=\$GIT_COMMIT/);
  assert.match(marketArchiveDockerfile, /LABEL org\.opencontainers\.image\.revision=\$GIT_COMMIT/);
  assert.match(quantdDockerfile, /test "\$\{#GIT_COMMIT\}" -eq 40/);
  assert.match(webDockerfile, /test "\$\{#GIT_COMMIT\}" -eq 40/);
  assert.match(quantdDockerfile, /ARG GIT_COMMIT=WORKTREE_UNCOMMITTED/);
  assert.match(webDockerfile, /ARG GIT_COMMIT=WORKTREE_UNCOMMITTED/);
  assert.match(marketArchiveDockerfile, /ARG GIT_COMMIT=WORKTREE_UNCOMMITTED/);
  assert.match(environmentExample, /^GIT_COMMIT=$/m);
});

test('PostgreSQL archive stays private, append-only, and revision-bound', () => {
  const postgresService = compose.split('\n  postgres:')[1].split('\n  market-archive:')[0];
  const archiveService = compose.split('\n  market-archive:')[1].split('\n  ibkr-gateway:')[0];
  assert.doesNotMatch(postgresService, /^\s+ports:/m);
  assert.match(postgresService, /POSTGRES_INITDB_ARGS:\s*--data-checksums/);
  assert.match(postgresService, /runtime\/market-data\/postgres:\/var\/lib\/postgresql\/data/);
  assert.match(postgresService, /pg_isready -U axio7 -d axio7_market/);
  assert.match(archiveService, /runtime\/market-data:\/archive:ro/);
  assert.match(archiveService, /--watch-interval-seconds/);
  assert.match(archiveService, /AXIO7_MARKET_DATA_RIGHTS_RECEIPT_SHA256/);
  assert.match(archiveService, /read_only:\s*true/);
  assert.match(marketArchiveDockerfile, /COPY --chown=axio:axio intraday_quant\/src \.\/src/);
  assert.match(rootDockerignore, /^!intraday_quant\/src\/\*\*$/m);
  assert.match(environmentExample, /^MARKET_POSTGRES_PASSWORD=$/m);
  assert.match(verifyRuntime, /market_data\.live_archive_receipts/);
});

test('private release artifacts are injected through read-only runtime mounts', () => {
  for (const mount of [
    './runtime/quant-rights:/app/data/rights:ro',
    './runtime/quant-promotion:/app/data/promotion:ro',
    './runtime/quant-calibration:/app/data/calibration:ro',
    './runtime/quant-evidence:/app/data/evidence:ro',
    './runtime/quant-manifests:/app/data/manifests:ro',
    './runtime/quant-normalized:/app/data/normalized:ro',
    'quant-models:/app/data/models/universe:ro',
  ]) {
    assert.ok(compose.includes(mount), `missing read-only mount ${mount}`);
  }
  assert.doesNotMatch(
    compose,
    /private-rights-evidence/,
    'the signed owner attestation must never be mounted into a container',
  );
  assert.match(
    quantdDockerfile,
    /ln -sfn \.\.\/promotion\/predictor_promotion_latest\.json/,
  );
  assert.match(
    quantdDockerfile,
    /for artifact in SPX QQQ NVDA AAPL MU SOXX NBIS BE IGV/,
  );
  assert.match(quantdDockerfile, /chmod -R a-w \/app\/data\/models/);
  assert.match(quantdDockerignore, /^quant_engine_rs\/data\/rights$/m);
  for (const ignored of [
    'quant_engine_rs/data/rights',
    'quant_engine_rs/data/evidence',
    'quant_engine_rs/data/promotion',
    'quant_engine_rs/data/calibration',
    'infra/single-vm/runtime',
  ]) {
    assert.match(rootDockerignore, new RegExp(`^${ignored}$`, 'm'));
    assert.match(quantdDockerignore, new RegExp(`^${ignored}$`, 'm'));
  }
  assert.match(compose, /name:\s*axio7_quant-models-\$\{GIT_COMMIT:\?/);
});

test('rights, promotion, and calibration pins reach only the Rust service', () => {
  for (const variable of [
    'AXIO7_MARKET_DATA_RIGHTS_RECEIPT_SHA256',
    'MODEL_PROMOTION_REGISTRY_SHA256',
    'MODEL_PROMOTION_ENTRY_SHA256_PINS',
    'AXIO_PROBABILITY_CALIBRATION_ARTIFACT',
    'AXIO_PROBABILITY_CALIBRATION_SHA256',
  ]) {
    assert.match(compose, new RegExp(`\\b${variable}:`));
    assert.match(environmentExample, new RegExp(`^${variable}=`, 'm'));
  }
  const webService = compose.split('\n  web:')[1].split('\n  monitor-scheduler:')[0];
  assert.doesNotMatch(
    webService,
    /AXIO7_MARKET_DATA_RIGHTS_RECEIPT_SHA256|MODEL_PROMOTION_ENTRY_SHA256_PINS|AXIO_PROBABILITY_CALIBRATION_SHA256/,
  );
});

test('container liveness keeps the site up while release gates stay explicit', () => {
  const quantdService = compose.split('\n  quantd:')[1].split('\n  ibkr-gateway:')[0];
  assert.match(quantdService, /http:\/\/127\.0\.0\.1:8001\/health/);
  assert.match(quantdDockerfile, /\$\{PORT\}\/health/);
  assert.match(verifyRuntime, /fetchJson\('\/ready'\)/);
  assert.match(verifyRuntime, /\/health liveness check/);
  assert.match(acceptance, /\/api\/v1\/system\/readiness/);
});

test('all automatic execution switches remain hard-disabled', () => {
  assert.match(compose, /LIVE_EXECUTION_ENABLED:\s*"false"/);
  assert.match(compose, /BROKER_LIVE_ENABLED:\s*"false"/);
  assert.match(compose, /ANOMALY_LIVE_ORDER_ENABLED:\s*"false"/);
  assert.match(acceptance, /ensure_execution_disabled/);
  assert.match(verifyRuntime, /automatic_execution_enabled === false/);
});

test('runtime preparation and parity verification cover the exact frozen universe', () => {
  for (const artifact of ['SPX', 'QQQ', 'NVDA', 'AAPL', 'MU', 'SOXX', 'NBIS', 'BE', 'IGV']) {
    assert.match(prepareRuntime, new RegExp(`\\b${artifact}\\b`));
  }
  assert.match(prepareRuntime, /runtime\/quant-rights/);
  assert.match(prepareRuntime, /runtime\/quant-evidence/);
  assert.match(prepareRuntime, /runtime\/private-rights-evidence/);
  assert.match(prepareRuntime, /runtime\/quant-promotion\/evidence/);
  assert.match(prepareRuntime, /runtime\/quant-calibration/);
  assert.match(prepareRuntime, /\.env\.server GIT_COMMIT must equal/);
  assert.match(verifyRuntime, /requested_artifact_count === 9/);
  assert.match(verifyRuntime, /loaded_artifact_count === 9/);
  assert.match(verifyRuntime, /failed_artifact_count === 0/);
  assert.match(verifyRuntime, /org\.opencontainers\.image\.revision/);
});

test('backup and rollback require explicit destructive-operation confirmations', () => {
  assert.match(backup, /--confirm-quiesce/);
  assert.match(backup, /services_left_stopped/);
  assert.match(backup, /flock -n 9/);
  assert.match(backup, /preflighting every archive before sealing/);
  assert.match(backup, /runtime_tree_matches_manifest/);
  assert.match(backup, /private-rights-evidence/);
  assert.match(backup, /directory mode must be 0700/);
  assert.match(backup, /mode-0600 regular file/);
  assert.match(
    backup,
    /Compose must never mount the private owner-attestation directory/,
  );
  assert.doesNotMatch(backup, /ps --status running --services \|\| true/);
  assert.doesNotMatch(
    backup,
    /^\s*(?:docker compose|"\$\{compose\[@\]\}")\s+down\b/m,
  );
  assert.match(rollback, /--confirm-restore/);
  assert.match(rollback, /pre-rollback-/);
  assert.match(rollback, /fully extracting release archives into isolated staging/);
  assert.match(rollback, /quant-state\.before-rollback\.tgz/);
  assert.match(rollback, /\.env\.server\.current/);
  assert.match(rollback, /compose\.current\.yaml/);
  assert.match(rollback, /Caddyfile\.current/);
  assert.match(rollback, /current_quantd_revision.*current_commit/s);
  assert.match(rollback, /rollback_quantd_revision.*source_commit/s);
  assert.match(rollback, /attempt_emergency_recovery/);
  assert.match(rollback, /recovery_attempted/);
  assert.match(rollback, /recovery_succeeded/);
  assert.match(rollback, /trap 'on_signal 143 TERM' TERM/);
  assert.match(rollback, /flock -n 9/);
  assert.match(rollback, /stop_project_writers_by_label/);
  assert.match(rollback, /runtime_tree_matches_manifest/);
  assert.match(rollback, /private-rights-evidence/);
  assert.match(rollback, /runtime archive contains a link or special member/);
  assert.match(rollback, /directory mode must be 0700/);
  assert.match(rollback, /mode-0600 regular file/);
  assert.match(
    rollback,
    /saved Compose must never mount the private owner-attestation directory/,
  );
  assert.match(
    rollback,
    /current Compose must never mount the private owner-attestation directory/,
  );
  assert.match(rollback, /all_service_image_ids_verified/);
  assert.match(rollback, /read_only_model_universe_matches_image/);
  assert.doesNotMatch(rollback, /ps --status running --services[^\n]*\|\| true/);
  assert.match(rollback, /--wait --wait-timeout 180/);
  assert.match(rollback, /monitor-scheduler/);
  assert.ok(
    rollback.indexOf('fully extracting release archives into isolated staging')
      < rollback.indexOf('quiescing current production writers'),
  );
  assert.ok(
    rollback.indexOf('emergency_sealed=true')
      < rollback.indexOf('restoring the preflighted persistent volume set'),
  );
  assert.match(rollback, /mountpoint -q \/target/);
});

test('sealed acceptance is exact-nine, regular-session, and checksum-bound', () => {
  for (const symbol of ['SPY', 'QQQ', 'NVDA', 'AAPL', 'MU', 'SOXX', 'NBIS', 'BE', 'IGV']) {
    assert.match(acceptance, new RegExp(`"${symbol}"`));
  }
  assert.match(acceptance, /axio\.production-acceptance\.v1/);
  assert.match(acceptance, /axio\.market_data_rights\.v2/);
  assert.match(acceptance, /OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT/);
  assert.match(acceptance, /data\/evidence\/databento_technical_entitlement_latest\.json/);
  assert.match(acceptance, /private_owner_attestation_sha256/);
  assert.match(acceptance, /private_owner_attestation_contents_recorded/);
  assert.match(acceptance, /read_pinned_json/);
  assert.match(acceptance, /validate_quantd_mounts/);
  assert.match(acceptance, /validate_no_private_bind_mounts/);
  assert.match(acceptance, /label=com\.docker\.compose\.project=axio7/);
  assert.match(acceptance, /private owner-attestation directory mode must be 0700/);
  assert.match(acceptance, /quantd_exact_mount_set_verified/);
  assert.match(acceptance, /private_owner_attestation_unmounted/);
  assert.match(acceptance, /raw_mounts_recorded/);
  assert.match(acceptance, /axio\.model-promotion-registry\.v2/);
  assert.match(acceptance, /axio\.probability_calibration\.v2/);
  assert.match(acceptance, /readiness_fingerprint\(before\) == readiness_fingerprint\(after\)/);
  assert.match(acceptance, /SHA256_COMPONENT_MANIFEST/);
  assert.match(acceptance, /live-publication-bundle\.tgz/);
  assert.match(acceptance, /execution_enabled"\s*:\s*False/);
  assert.match(acceptance, /--public-origin/);
  assert.match(acceptance, /normalize_public_origin/);
  assert.match(acceptance, /public_origin.*\/api\/health/s);
  assert.match(acceptance, /environment\.get\("deployment"\) == expected_commit/);
  assert.match(
    acceptance,
    /"postgres",[\s\S]*"market-archive",[\s\S]*"caddy"/,
  );
  assert.match(acceptance, /health_status == "healthy"/);
  assert.match(acceptance, /image_id == expected_image_id/);
  assert.match(acceptance, /read_dotenv_value\(env_file, "GIT_COMMIT"\) == expected_commit/);
  assert.match(acceptance, /--proto",\s*"=https"/);
  assert.match(acceptance, /status_code == "200"/);
  assert.doesNotMatch(acceptance, /--insecure/);
  assert.match(acceptance, /curl --fail --silent --show-error --header @-/);
  assert.doesNotMatch(
    acceptance,
    /curl[^'\n]*\$INTRADAY_QUANT_TOKEN/,
  );
  assert.doesNotMatch(acceptance, /broker_order_route_added/);
  assert.doesNotMatch(deploymentReadme, /No container exposes an order endpoint/);
  assert.doesNotMatch(acceptance, /skip[_-]session|force[_-]ready|allow[_-]stale/i);
});
