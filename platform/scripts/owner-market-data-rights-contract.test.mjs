import assert from 'node:assert/strict';
import {
  existsSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const rootUrl = new URL('../', import.meta.url);
const read = (path) => readFileSync(new URL(path, rootUrl), 'utf8');
const scriptPath = fileURLToPath(
  new URL('scripts/create-owner-market-data-rights-receipt.ps1', rootUrl),
);
const configPath = fileURLToPath(
  new URL('quant_engine_rs/configs/production.yaml', rootUrl),
);
const quantctlPath = fileURLToPath(
  new URL(
    process.platform === 'win32'
      ? 'quant_engine_rs/target/debug/quantctl.exe'
      : 'quant_engine_rs/target/debug/quantctl',
    rootUrl,
  ),
);
const source = read('scripts/create-owner-market-data-rights-receipt.ps1');

const sha256 = (value) => createHash('sha256').update(value).digest('hex');
const quotePowerShell = (value) => `'${value.replaceAll("'", "''")}'`;

function technicalReceipt(capturedAt) {
  return {
    schema_version: 'axio.databento_technical_entitlement.v1',
    status: 'TECHNICAL_ENTITLEMENT_VERIFIED',
    provider: 'databento',
    product: 'Databento US Equities Mini',
    dataset: 'EQUS.MINI',
    captured_at: capturedAt,
    endpoints: [
      {
        host: 'hist.databento.com',
        path: '/v0/metadata.list_datasets',
        status: 200,
        response_sha256: 'e'.repeat(64),
      },
      {
        host: 'hist.databento.com',
        path: '/v0/metadata.list_schemas',
        status: 200,
        response_sha256: 'f'.repeat(64),
      },
      {
        host: 'hist.databento.com',
        path: '/v0/metadata.get_dataset_range',
        status: 200,
        response_sha256: '9'.repeat(64),
      },
    ],
    entitled: true,
    range: {
      dataset_start: '2018-05-01T00:00:00Z',
      dataset_end: '2026-07-28T15:59:00Z',
      schema: 'ohlcv-1m',
      schema_start: '2018-05-01T00:00:00Z',
      schema_end: '2026-07-28T15:59:00Z',
    },
  };
}

function runGenerator({
  runtimeRoot,
  technicalPath,
  now,
  rawRedistribution = false,
}) {
  const iso = (milliseconds) =>
    new Date(now.getTime() + milliseconds).toISOString();
  const command = [
    `& ${quotePowerShell(scriptPath)}`,
    `-OwnerHandle ${quotePowerShell('TEST_OWNER_HANDLE')}`,
    `-OwnerSignature ${quotePowerShell('TEST_OWNER_HANDLE')}`,
    `-LegalEntity ${quotePowerShell('TEST LEGAL ENTITY')}`,
    `-PlanName ${quotePowerShell('TEST ACTIVE PLAN')}`,
    '-PlanStatus ACTIVE',
    `-AccountReference ${quotePowerShell('TEST-ACCOUNT-REFERENCE-123')}`,
    `-SubscriptionReference ${quotePowerShell('TEST-SUBSCRIPTION-REFERENCE-456')}`,
    '-SubscriptionReferenceKind OWNER_DEFINED_NOT_VENDOR_ID',
    '-ModelInputPermitted $true',
    '-CustomerExternalDisplayPermitted $true',
    '-DerivedOutputPublicationPermitted $true',
    `-RawDataRedistributionPermitted $${rawRedistribution ? 'true' : 'false'}`,
    `-AttestedAt ${quotePowerShell(iso(-2 * 60 * 60 * 1000))}`,
    `-ValidFrom ${quotePowerShell(iso(-24 * 60 * 60 * 1000))}`,
    `-ValidUntil ${quotePowerShell(iso(30 * 24 * 60 * 60 * 1000))}`,
    `-ReviewerHandle ${quotePowerShell('TEST_RIGHTS_REVIEWER')}`,
    `-ReviewedAt ${quotePowerShell(iso(-60 * 60 * 1000))}`,
    `-ReviewDueAt ${quotePowerShell(iso(7 * 24 * 60 * 60 * 1000))}`,
    `-OfficialTermsUrl ${quotePowerShell('https://databento.com/legal/terms-of-use')}`,
    `-OfficialProductUrl ${quotePowerShell('https://databento.com/stocks')}`,
    `-TechnicalEntitlementReceiptPath ${quotePowerShell(technicalPath)}`,
    `-RuntimeRoot ${quotePowerShell(runtimeRoot)}`,
    `-QuantctlPath ${quotePowerShell(quantctlPath)}`,
    `-ConfigPath ${quotePowerShell(configPath)}`,
  ].join(' ');
  const executable = process.platform === 'win32' ? 'powershell.exe' : 'pwsh';
  const environment = { ...process.env };
  for (const key of Object.keys(environment)) {
    if (/DATABENTO.*KEY/i.test(key)) delete environment[key];
  }
  return spawnSync(
    executable,
    [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      command,
    ],
    {
      encoding: 'utf8',
      env: environment,
      timeout: 30_000,
    },
  );
}

test('owner generator has no credential path and commits the rights receipt last', () => {
  assert.doesNotMatch(
    source,
    /GetEnvironmentVariable|DATABENTO_API_KEY|authorization\s*header/i,
  );
  assert.match(source, /ACCOUNT_OWNER_ATTESTATION/);
  assert.match(source, /OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT/);
  assert.match(source, /RawDataRedistributionPermitted/);
  assert.match(source, /if \(\$RawDataRedistributionPermitted\)/);
  assert.match(source, /Invoke-RustRightsValidation/);
  assert.match(source, /validate-market-data-rights/);
  assert.match(
    source,
    /Commit the authorization receipt last[\s\S]*quant-rights\\market_data_rights_receipt\.json/,
  );
});

test('synthetic owner inputs produce only hash-bound private artifacts accepted by Rust', (t) => {
  if (!existsSync(quantctlPath)) {
    t.skip('Build quantctl before this integration test.');
    return;
  }
  const root = mkdtempSync(join(tmpdir(), 'axio7-owner-rights-'));
  const runtimeRoot = join(root, 'runtime');
  const technicalPath = join(root, 'technical.json');
  const now = new Date();
  const technicalBytes = Buffer.from(
    `${JSON.stringify(
      technicalReceipt(new Date(now.getTime() - 30_000).toISOString()),
      null,
      2,
    )}\n`,
    'utf8',
  );
  writeFileSync(technicalPath, technicalBytes);

  try {
    const result = runGenerator({
      runtimeRoot,
      technicalPath,
      now,
    });
    assert.equal(result.status, 0, result.stderr);
    const output = JSON.parse(result.stdout.trim());
    assert.deepEqual(Object.keys(output), [
      'attestation_path',
      'attestation_sha256',
      'technical_entitlement_receipt_path',
      'technical_entitlement_receipt_sha256',
      'rights_receipt_path',
      'rights_receipt_sha256',
    ]);
    for (const hashField of [
      'attestation_sha256',
      'technical_entitlement_receipt_sha256',
      'rights_receipt_sha256',
    ]) {
      assert.match(output[hashField], /^[0-9a-f]{64}$/);
    }

    const attestationBytes = readFileSync(output.attestation_path);
    const copiedTechnicalBytes = readFileSync(
      output.technical_entitlement_receipt_path,
    );
    const rightsBytes = readFileSync(output.rights_receipt_path);
    assert.equal(sha256(attestationBytes), output.attestation_sha256);
    assert.equal(
      sha256(copiedTechnicalBytes),
      output.technical_entitlement_receipt_sha256,
    );
    assert.equal(sha256(rightsBytes), output.rights_receipt_sha256);
    assert.deepEqual(copiedTechnicalBytes, technicalBytes);

    const attestation = JSON.parse(attestationBytes);
    const rights = JSON.parse(rightsBytes);
    assert.equal(attestation.signature.signed_by, 'TEST_OWNER_HANDLE');
    assert.equal(
      attestation.evidence_basis,
      'OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT',
    );
    assert.equal(rights.evidence_kind, 'ACCOUNT_OWNER_ATTESTATION');
    assert.equal(
      rights.owner_attestation.subscription_reference_kind,
      'OWNER_DEFINED_NOT_VENDOR_ID',
    );
    assert.match(
      attestation.attestation_statement,
      /owner-defined local binding, not a vendor subscription ID/,
    );
    assert.equal(rights.official_evidence_url, undefined);
    assert.equal(rights.permitted_uses.model_input, true);
    assert.equal(rights.permitted_uses.customer_external_display, true);
    assert.equal(rights.permitted_uses.derived_output_publication, true);
    assert.equal(rights.permitted_uses.raw_data_redistribution, false);
    assert.equal(rights.raw_data_redistribution_support, undefined);
    assert.equal(
      rights.evidence_artifact_sha256,
      output.attestation_sha256,
    );
    assert.equal(
      rights.owner_attestation.technical_entitlement_receipt_sha256,
      output.technical_entitlement_receipt_sha256,
    );
    const serializedPrivateArtifacts =
      attestationBytes.toString('utf8') + rightsBytes.toString('utf8');
    assert.doesNotMatch(
      serializedPrivateArtifacts,
      /TEST-ACCOUNT-REFERENCE-123|TEST-SUBSCRIPTION-REFERENCE-456/,
    );
    assert.deepEqual(
      readdirSync(runtimeRoot).sort(),
      ['private-rights-evidence', 'quant-evidence', 'quant-rights'],
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('raw redistribution request fails before writing authorization artifacts', (t) => {
  if (!existsSync(quantctlPath)) {
    t.skip('Build quantctl before this integration test.');
    return;
  }
  const root = mkdtempSync(join(tmpdir(), 'axio7-owner-rights-raw-'));
  const runtimeRoot = join(root, 'runtime');
  const technicalPath = join(root, 'technical.json');
  const now = new Date();
  writeFileSync(
    technicalPath,
    `${JSON.stringify(
      technicalReceipt(new Date(now.getTime() - 30_000).toISOString()),
    )}\n`,
  );

  try {
    const result = runGenerator({
      runtimeRoot,
      technicalPath,
      now,
      rawRedistribution: true,
    });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /Raw-data redistribution must remain false/);
    assert.equal(existsSync(runtimeRoot), false);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
