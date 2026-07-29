import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import {
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';

const rootUrl = new URL('../', import.meta.url);
const scriptPath = fileURLToPath(
  new URL('scripts/bind-production-release-env.ps1', rootUrl),
);
const source = readFileSync(scriptPath, 'utf8');
const powershellExecutable =
  process.platform === 'win32' ? 'powershell.exe' : 'pwsh';
const powershellAvailable =
  spawnSync(
    powershellExecutable,
    ['-NoProfile', '-NonInteractive', '-Command', '$PSVersionTable.PSVersion'],
    { encoding: 'utf8', timeout: 5_000 },
  ).status === 0;
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');
const jsonBytes = (value) =>
  Buffer.from(`${JSON.stringify(value, null, 2)}\n`, 'utf8');

function buildEvidence(root) {
  const technicalPath = join(root, 'technical.json');
  const attestationPath = join(root, 'attestation.json');
  const rightsPath = join(root, 'rights.json');

  const technical = jsonBytes({
    schema_version: 'axio.databento_technical_entitlement.v1',
    status: 'TECHNICAL_ENTITLEMENT_VERIFIED',
    provider: 'databento',
    product: 'Databento US Equities Mini',
    dataset: 'EQUS.MINI',
    entitled: true,
  });
  writeFileSync(technicalPath, technical);
  const technicalHash = sha256(technical);

  const attestation = jsonBytes({
    schema_version: 'axio.account_owner_market_data_attestation.v1',
    evidence_kind: 'ACCOUNT_OWNER_ATTESTATION',
    evidence_basis: 'OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT',
    provider: 'databento',
    product: 'EQUS.MINI',
    technical_entitlement_receipt_sha256: technicalHash,
  });
  writeFileSync(attestationPath, attestation);
  const attestationHash = sha256(attestation);

  const rights = jsonBytes({
    schema_version: 'axio.market_data_rights.v2',
    provider: 'databento',
    product: 'EQUS.MINI',
    plan_status: 'ACTIVE',
    evidence_kind: 'ACCOUNT_OWNER_ATTESTATION',
    evidence_artifact_sha256: attestationHash,
    permitted_uses: {
      model_input: true,
      customer_external_display: true,
      derived_output_publication: true,
      raw_data_redistribution: false,
    },
    owner_attestation: {
      technical_entitlement_receipt_sha256: technicalHash,
    },
  });
  writeFileSync(rightsPath, rights);

  return {
    technicalPath,
    technicalHash,
    attestationPath,
    attestationHash,
    rightsPath,
    rightsHash: sha256(rights),
  };
}

function environmentBytes() {
  return Buffer.from(
    [
      '# Synthetic contract fixture; contains no real credential.',
      'AXIO7_SITE_URL=https://axio7.com',
      'DATABENTO_API_KEY=synthetic-databento-key',
      `INTRADAY_QUANT_TOKEN=${'1'.repeat(64)}`,
      `MARKET_MONITOR_CRON_SECRET=${'2'.repeat(64)}`,
      'NEXT_PUBLIC_SUPABASE_URL=https://example.supabase.co',
      'NEXT_PUBLIC_SUPABASE_ANON_KEY=synthetic-anon',
      'SUPABASE_SERVICE_ROLE_KEY=synthetic-service',
      'PADDLE_API_KEY=pdl_live_apikey_synthetic',
      'NEXT_PUBLIC_PADDLE_CLIENT_TOKEN=live_synthetic',
      `PRIVATE_UNRELATED_SECRET=${'3'.repeat(64)}`,
      'LIVE_EXECUTION_ENABLED=true',
      'BROKER_LIVE_ENABLED=true',
      'ANOMALY_LIVE_ORDER_ENABLED=true',
      '',
    ].join('\n'),
    'utf8',
  );
}

function runBinding({ envPath, evidence }) {
  return spawnSync(
    powershellExecutable,
    [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      scriptPath,
      '-EnvPath',
      envPath,
      '-GitCommit',
      'a'.repeat(40),
      '-RightsReceiptPath',
      evidence.rightsPath,
      '-TechnicalEntitlementReceiptPath',
      evidence.technicalPath,
      '-OwnerAttestationPath',
      evidence.attestationPath,
    ],
    {
      encoding: 'utf8',
      timeout: 15_000,
    },
  );
}

test('release binding is narrowly scoped, atomic, and secret-silent', (t) => {
  assert.match(source, /AXIO7_MARKET_DATA_RIGHTS_RECEIPT_SHA256/);
  assert.match(source, /OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT/);
  assert.match(source, /\[IO\.File\]::Replace/);
  assert.doesNotMatch(source, /Write-(?:Host|Output).*(?:API_KEY|TOKEN|SECRET)/i);
  if (!powershellAvailable) {
    t.skip('PowerShell is unavailable on this runner.');
    return;
  }

  const root = mkdtempSync(join(tmpdir(), 'axio7-release-env-'));
  try {
    const evidence = buildEvidence(root);
    const envPath = join(root, '.env.server');
    const original = environmentBytes();
    writeFileSync(envPath, original);

    const result = runBinding({ envPath, evidence });
    assert.equal(result.status, 0, result.stderr);
    assert.doesNotMatch(
      `${result.stdout}\n${result.stderr}`,
      /synthetic-databento-key|synthetic-service|PRIVATE_UNRELATED_SECRET/,
    );

    const receipt = JSON.parse(result.stdout.trim());
    assert.equal(receipt.status, 'BOUND');
    assert.equal(receipt.secret_values_printed, false);
    assert.equal(receipt.rights_receipt_sha256, evidence.rightsHash);
    assert.equal(
      receipt.technical_entitlement_receipt_sha256,
      evidence.technicalHash,
    );
    assert.equal(receipt.owner_attestation_sha256, evidence.attestationHash);

    const bound = readFileSync(envPath, 'utf8');
    assert.match(bound, new RegExp(`^GIT_COMMIT=${'a'.repeat(40)}$`, 'm'));
    assert.match(bound, /^AXIO7_PUBLIC_MARKET_DATA_PROVIDER=databento$/m);
    assert.match(
      bound,
      new RegExp(
        `^AXIO7_MARKET_DATA_RIGHTS_RECEIPT_SHA256=${evidence.rightsHash}$`,
        'm',
      ),
    );
    assert.match(bound, /^LIVE_EXECUTION_ENABLED=false$/m);
    assert.match(bound, /^BROKER_LIVE_ENABLED=false$/m);
    assert.match(bound, /^ANOMALY_LIVE_ORDER_ENABLED=false$/m);
    assert.match(bound, new RegExp(`PRIVATE_UNRELATED_SECRET=${'3'.repeat(64)}`));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('a mismatched private attestation leaves the environment unchanged', (t) => {
  if (!powershellAvailable) {
    t.skip('PowerShell is unavailable on this runner.');
    return;
  }
  const root = mkdtempSync(join(tmpdir(), 'axio7-release-env-tamper-'));
  try {
    const evidence = buildEvidence(root);
    const envPath = join(root, '.env.server');
    const original = environmentBytes();
    writeFileSync(envPath, original);
    writeFileSync(
      evidence.attestationPath,
      Buffer.concat([readFileSync(evidence.attestationPath), Buffer.from(' ')]),
    );

    const result = runBinding({ envPath, evidence });
    assert.notEqual(result.status, 0);
    assert.deepEqual(readFileSync(envPath), original);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
