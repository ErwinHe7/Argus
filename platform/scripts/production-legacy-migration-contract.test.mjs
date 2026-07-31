import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

const backup = read('scripts/production-legacy-flat-migration-backup.sh');
const restore = read('scripts/production-legacy-flat-migration-restore.sh');
const canonicalBackup = read('scripts/production-release-backup.sh');
const runbook = read('infra/single-vm/README.md');

test('legacy bridge is restricted to the exact null-revision flat stack', () => {
  assert.match(backup, /EXPECTED_DEPLOYMENT_DIR="\/opt\/axio7"/);
  assert.match(backup, /this one-time helper is restricted to \/opt\/axio7/);
  for (const service of [
    'quantd',
    'web',
    'caddy',
    'monitor-scheduler',
  ]) {
    assert.match(backup, new RegExp(`\\b${service}\\b`));
  }
  for (const volume of [
    'axio7_quant-state',
    'axio7_quant-live',
    'axio7_caddy-data',
    'axio7_caddy-config',
  ]) {
    assert.match(backup, new RegExp(`\\b${volume}\\b`));
  }
  assert.match(backup, /running project is not the exact four-service legacy stack/);
  assert.match(
    backup,
    /flat Compose file does not define the exact four-service legacy stack/,
  );
  assert.match(backup, /flat Compose file does not define the exact four legacy volumes/);
  assert.match(backup, /legacy Compose must not use the scale key during recovery/);
  assert.match(backup, /if \(value != "1"\)/);
  assert.match(backup, /legacy Compose may declare only replicas: 1 during recovery/);
  assert.match(backup, /com\.docker\.compose\.config-hash/);
  assert.match(backup, /config --hash/);
  assert.match(backup, /legacy quantd does not have exactly two named volumes/);
  assert.match(backup, /legacy quantd does not have exactly eight runtime bind mounts/);
  assert.match(backup, /org\.opencontainers\.image\.revision/);
  assert.match(backup, /has an OCI revision; use the canonical release backup helper/);

  assert.match(canonicalBackup, /git -C "\$repo_root" rev-parse HEAD/);
  assert.match(canonicalBackup, /quantd_image_revision.*release_commit/s);
  assert.match(canonicalBackup, /web_image_revision.*release_commit/s);
  assert.doesNotMatch(canonicalBackup, /confirm-legacy-quiesce/);
});

test('legacy backup explicitly quiesces all services and never prunes state', () => {
  assert.match(backup, /--confirm-legacy-quiesce/);
  assert.match(backup, /--preflight-only/);
  assert.match(backup, /read-only four-service preflight passed/);
  assert.match(backup, /refusing to stop the legacy deployment/);
  assert.match(backup, /docker stop --time 60/);
  assert.match(backup, /running_project_ids/);
  assert.match(backup, /volume_is_detached/);
  assert.match(backup, /restart_unchanged_legacy_stack/);
  assert.match(backup, /all four legacy services remain stopped for cutover/);
  assert.doesNotMatch(backup, /docker (?:image|volume|system) prune/);
  assert.doesNotMatch(backup, /docker (?:image|volume) rm/);
  assert.doesNotMatch(backup, /\bcompose(?:\[@\]\}")?\s+down\b/);
});

test('legacy backup captures exact IDs, protected config, runtime, and complete volumes', () => {
  for (const field of [
    'QUANTD_CONTAINER_ID',
    'WEB_CONTAINER_ID',
    'CADDY_CONTAINER_ID',
    'SCHEDULER_CONTAINER_ID',
    'QUANTD_IMAGE_ID',
    'WEB_IMAGE_ID',
    'CADDY_IMAGE_ID',
    'SCHEDULER_IMAGE_ID',
  ]) {
    assert.match(backup, new RegExp(`\\b${field}=`));
  }
  assert.match(backup, /docker image tag/);
  assert.match(backup, /refusing to overwrite an existing legacy recovery tag/);
  assert.match(backup, /existing backup root must be mode 0700 and owned by the operator/);
  assert.match(backup, /\.env\.server\.legacy/);
  assert.match(backup, /compose\.legacy\.yaml/);
  assert.match(backup, /Caddyfile\.legacy/);
  assert.match(backup, /runtime-binds\.tgz/);
  assert.match(backup, /runtime-files\.sha256/);
  assert.match(backup, /runtime-directories\.txt/);
  assert.match(backup, /runtime-tree-directories\.txt/);
  assert.match(backup, /quant-state-sqlite-family-files\.txt/);
  assert.match(backup, /sqlite_wal_captured_as_complete_quiesced_volume/);
  assert.match(backup, /write_volume_manifest/);
  assert.match(backup, /write_volume_directories/);
  assert.match(backup, /volume changed while it was archived/);
  assert.match(backup, /volume directory tree changed while it was archived/);
  assert.doesNotMatch(
    backup,
    /^(?:[ \t]*source|[ \t]*\.)[ \t]+[^\r\n]*\.env\.server/m,
  );
  assert.doesNotMatch(backup, /^[ \t]*cat[ \t]+[^\r\n]*\.env\.server/m);
});

test('legacy archives are preflighted before the sealed bundle is accepted', () => {
  assert.match(backup, /archive_member_path_is_safe/);
  assert.match(backup, /archive contains a link or special member/);
  assert.match(backup, /assert_safe_runtime_archive/);
  assert.match(backup, /preflight_volume_archive/);
  assert.match(backup, /extracted archive differs from source manifest/);
  assert.match(backup, /extracted archive omits or adds a directory/);
  assert.match(backup, /runtime_tree_matches_manifest/);
  assert.match(backup, /sha256sum --check --strict SHA256SUMS/);
  assert.match(backup, /mode-0700/);
  assert.match(backup, /mode-0600/);
  assert.match(backup, /environment_contents_printed": false/);
});

test('sealed bundle contains a fail-closed self-contained recovery path', () => {
  assert.match(backup, /restore-legacy-flat\.sh/);
  assert.match(backup, /RECOVERY\.txt/);
  assert.match(restore, /--confirm-legacy-restore/);
  assert.match(restore, /axio\.legacy-flat-migration-backup\.v1/);
  assert.match(restore, /validate_checksum_manifest/);
  assert.match(restore, /count == 24/);
  assert.match(restore, /run the exact restore helper sealed inside this legacy bundle/);
  assert.match(restore, /configuration differs from its sealed hash/);
  assert.match(restore, /stop every current axio7 project container/);
  assert.match(restore, /pre-legacy-restore-/);
  assert.match(restore, /destructive_started=true/);
  assert.match(restore, /all AXIO7 writers are stopped/);
  assert.match(restore, /CRITICAL: restore failed and stopped AXIO7 state cannot be proven/);
  assert.match(restore, /quant-state SQLite\/WAL family differs from the sealed list/);
  assert.ok(
    restore.indexOf('preflight_volume_archive')
      < restore.lastIndexOf('destructive_started=true'),
  );
  assert.ok(
    restore.indexOf('sha256sum --check --strict SHA256SUMS')
      < restore.lastIndexOf('destructive_started=true'),
  );
  assert.match(restore, /--no-build --pull never --force-recreate/);
  assert.match(restore, /does not use the sealed legacy image/);
  assert.match(restore, /LIVE_EXECUTION_ENABLED.*false/s);
  assert.doesNotMatch(restore, /docker (?:image|volume|system) prune/);
  assert.doesNotMatch(restore, /docker (?:image|volume) rm/);
  assert.match(runbook, /production-legacy-flat-migration-backup\.sh/);
  assert.match(runbook, /production-legacy-flat-migration-restore\.sh|restore-legacy-flat\.sh/);
});
