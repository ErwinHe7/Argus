import assert from 'node:assert/strict';
import {
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const rootUrl = new URL('../', import.meta.url);
const read = (path) => readFileSync(new URL(path, rootUrl), 'utf8');
const scriptPath = new URL(
  'scripts/capture-databento-technical-entitlement.ps1',
  rootUrl,
);
const fixturesUrl = new URL(
  'scripts/fixtures/databento-technical-entitlement/',
  rootUrl,
);
const scriptFile = fileURLToPath(scriptPath);
const fixturesPath = fileURLToPath(fixturesUrl);

const source = read('scripts/capture-databento-technical-entitlement.ps1');

const quotePowerShell = (value) => `'${value.replaceAll("'", "''")}'`;

function runPowerShell(command) {
  const executable = process.platform === 'win32' ? 'powershell.exe' : 'pwsh';
  const environment = { ...process.env };
  delete environment.DATABENTO_API_KEY;
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
      timeout: 15_000,
    },
  );
}

test('capture script pins the official metadata surface and secret-safe transport', () => {
  for (const endpoint of [
    '/v0/metadata.list_datasets',
    '/v0/metadata.list_schemas',
    '/v0/metadata.get_dataset_range',
  ]) {
    assert.ok(source.includes(endpoint), `missing endpoint ${endpoint}`);
  }

  assert.match(source, /\[Environment\]::GetEnvironmentVariable\(\s*'DATABENTO_API_KEY'/);
  assert.match(source, /\[Text\.Encoding\]::ASCII\.GetBytes\(\$apiKey \+ ':'\)/);
  assert.match(source, /AuthenticationHeaderValue\]::new\('Basic', \$BasicToken\)/);
  assert.match(source, /AllowAutoRedirect = \$false/);
  assert.match(source, /SslProtocols\]::Tls12/);
  assert.match(source, /CheckCertificateRevocationList = \$true/);
  assert.match(source, /FromSeconds\(\$RequestTimeoutSeconds\)/);
  assert.match(source, /\$statusCode -lt 200 -or \$statusCode -ge 300/);
  assert.match(source, /ConvertFrom-StrictUtf8Json/);
  assert.match(source, /Get-LowercaseSha256/);
  assert.match(source, /market_data_rights_receipt\.json/);
  assert.doesNotMatch(source, /ServerCertificateCustomValidationCallback/);
  assert.doesNotMatch(source, /Invoke-Expression|Start-Transcript|Write-Debug/);
});

test('technical capture refuses the market-data rights receipt path', (t) => {
  const temporaryDirectory = mkdtempSync(
    join(tmpdir(), 'axio7-databento-rights-separation-'),
  );
  const forbiddenDestination = join(
    temporaryDirectory,
    'market_data_rights_receipt.json',
  );

  try {
    const command = [
      `& ${quotePowerShell(scriptFile)}`,
      '-TimeoutSeconds 1',
      `-OutputPath ${quotePowerShell(forbiddenDestination)}`,
    ].join(' ');
    const result = runPowerShell(command);
    if (result.error?.code === 'ENOENT') {
      t.skip('PowerShell is unavailable.');
      return;
    }
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /separate market-data rights receipt/);
    assert.deepEqual(readdirSync(temporaryDirectory), []);
  } finally {
    rmSync(temporaryDirectory, { recursive: true, force: true });
  }
});

test('capture script validates synthetic Databento fixtures without network access', (t) => {
  const datasets = JSON.parse(
    read('scripts/fixtures/databento-technical-entitlement/metadata.list_datasets.json'),
  );
  const schemas = JSON.parse(
    read('scripts/fixtures/databento-technical-entitlement/metadata.list_schemas.json'),
  );
  const range = JSON.parse(
    read(
      'scripts/fixtures/databento-technical-entitlement/metadata.get_dataset_range.json',
    ),
  );
  assert.ok(datasets.includes('EQUS.MINI'));
  assert.ok(schemas.includes('ohlcv-1m'));
  assert.ok(range.schema['ohlcv-1m']);
  assert.ok(
    Date.parse(range.schema['ohlcv-1m'].start.slice(0, 23) + 'Z') <
      Date.parse(range.schema['ohlcv-1m'].end.slice(0, 23) + 'Z'),
  );

  const command = [
    `. ${quotePowerShell(scriptFile)}`,
    `$fixtureRoot = ${quotePowerShell(fixturesPath)}`,
    "$datasets = Get-Content -Raw -LiteralPath (Join-Path $fixtureRoot 'metadata.list_datasets.json') | ConvertFrom-Json",
    "$schemas = Get-Content -Raw -LiteralPath (Join-Path $fixtureRoot 'metadata.list_schemas.json') | ConvertFrom-Json",
    "$range = Get-Content -Raw -LiteralPath (Join-Path $fixtureRoot 'metadata.get_dataset_range.json') | ConvertFrom-Json",
    '$validated = Assert-DatabentoTechnicalEntitlementResponse -Datasets $datasets -Schemas $schemas -DatasetRange $range',
    '$validated | ConvertTo-Json -Compress',
  ].join('; ');
  const result = runPowerShell(command);
  if (result.error?.code === 'ENOENT') {
    t.skip('PowerShell is unavailable; JSON fixture assertions still ran.');
    return;
  }
  assert.equal(result.status, 0, result.stderr);
  const validated = JSON.parse(result.stdout.trim());
  assert.deepEqual(Object.keys(validated), [
    'dataset_start',
    'dataset_end',
    'schema',
    'schema_start',
    'schema_end',
  ]);
  assert.equal(validated.schema, 'ohlcv-1m');
  assert.equal(validated.schema_start, range.schema['ohlcv-1m'].start);
  assert.equal(validated.schema_end, range.schema['ohlcv-1m'].end);
});

test('receipt constructor has an exact persistence allowlist', (t) => {
  const fakeHash = '0'.repeat(64);
  const command = [
    `. ${quotePowerShell(scriptFile)}`,
    `$fixtureRoot = ${quotePowerShell(fixturesPath)}`,
    "$datasets = Get-Content -Raw -LiteralPath (Join-Path $fixtureRoot 'metadata.list_datasets.json') | ConvertFrom-Json",
    "$schemas = Get-Content -Raw -LiteralPath (Join-Path $fixtureRoot 'metadata.list_schemas.json') | ConvertFrom-Json",
    "$range = Get-Content -Raw -LiteralPath (Join-Path $fixtureRoot 'metadata.get_dataset_range.json') | ConvertFrom-Json",
    '$validated = Assert-DatabentoTechnicalEntitlementResponse -Datasets $datasets -Schemas $schemas -DatasetRange $range',
    `$hash = ${quotePowerShell(fakeHash)}`,
    "$evidence = @('/v0/metadata.list_datasets','/v0/metadata.list_schemas','/v0/metadata.get_dataset_range') | ForEach-Object { [pscustomobject][ordered]@{ host = 'hist.databento.com'; path = $_; status = 200; response_sha256 = $hash } }",
    "$receipt = New-DatabentoTechnicalEntitlementReceipt -EndpointEvidence $evidence -ValidatedRange $validated -CapturedAt ([DateTimeOffset]'2026-07-28T20:00:00Z')",
    '$receipt | ConvertTo-Json -Depth 8 -Compress',
  ].join('; ');
  const result = runPowerShell(command);
  if (result.error?.code === 'ENOENT') {
    t.skip('PowerShell is unavailable.');
    return;
  }
  assert.equal(result.status, 0, result.stderr);
  const receipt = JSON.parse(result.stdout.trim());
  assert.deepEqual(Object.keys(receipt), [
    'schema_version',
    'status',
    'provider',
    'product',
    'dataset',
    'captured_at',
    'endpoints',
    'entitled',
    'range',
  ]);
  assert.equal(receipt.schema_version, 'axio.databento_technical_entitlement.v1');
  assert.equal(receipt.status, 'TECHNICAL_ENTITLEMENT_VERIFIED');
  assert.equal(receipt.entitled, true);
  assert.deepEqual(Object.keys(receipt.endpoints[0]), [
    'host',
    'path',
    'status',
    'response_sha256',
  ]);
  const serialized = JSON.stringify(receipt);
  assert.doesNotMatch(
    serialized,
    /DATABENTO_API_KEY|authorization|basic\s|account|response_body|query/i,
  );
});

test('missing schema fixture fails closed and the evidence path is ignored', (t) => {
  const command = [
    `. ${quotePowerShell(scriptFile)}`,
    `$fixtureRoot = ${quotePowerShell(fixturesPath)}`,
    "$datasets = Get-Content -Raw -LiteralPath (Join-Path $fixtureRoot 'metadata.list_datasets.json') | ConvertFrom-Json",
    "$range = Get-Content -Raw -LiteralPath (Join-Path $fixtureRoot 'metadata.get_dataset_range.json') | ConvertFrom-Json",
    "Assert-DatabentoTechnicalEntitlementResponse -Datasets $datasets -Schemas @('trades') -DatasetRange $range",
  ].join('; ');
  const result = runPowerShell(command);
  if (result.error?.code === 'ENOENT') {
    t.skip('PowerShell is unavailable.');
    return;
  }
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /did not include required value 'ohlcv-1m'/);

  const gitignore = read('.gitignore');
  assert.match(
    gitignore,
    /^quant_engine_rs\/data\/evidence\/databento_technical_entitlement_latest\.json$/m,
  );
});

test('a failed capture does not overwrite the last successful receipt', (t) => {
  const temporaryDirectory = mkdtempSync(
    join(tmpdir(), 'axio7-databento-entitlement-'),
  );
  const destination = join(
    temporaryDirectory,
    'databento_technical_entitlement_latest.json',
  );
  const sentinel = '{"previous_success":true}\n';
  writeFileSync(destination, sentinel, 'utf8');

  try {
    const command = [
      `& ${quotePowerShell(scriptFile)}`,
      '-TimeoutSeconds 1',
      `-OutputPath ${quotePowerShell(destination)}`,
    ].join(' ');
    const result = runPowerShell(command);
    if (result.error?.code === 'ENOENT') {
      t.skip('PowerShell is unavailable.');
      return;
    }
    assert.notEqual(result.status, 0);
    assert.equal(readFileSync(destination, 'utf8'), sentinel);
    assert.deepEqual(readdirSync(temporaryDirectory), [
      'databento_technical_entitlement_latest.json',
    ]);
  } finally {
    rmSync(temporaryDirectory, { recursive: true, force: true });
  }
});
