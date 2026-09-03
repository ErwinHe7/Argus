#!/usr/bin/env node

import { createHash } from 'node:crypto';
import {
  copyFile,
  mkdir,
  readFile,
  rename,
  unlink,
  writeFile,
} from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

try {
  process.loadEnvFile?.('.env.local');
} catch {
  // `npm run quant:context:sync` also supplies --env-file. Absence is checked
  // explicitly below; there is no credential or sample-data fallback.
}

const DEFAULT_SYMBOLS = [
  'AAPL',
  'AMD',
  'AMZN',
  'AVGO',
  'GOOGL',
  'META',
  'MSFT',
  'NVDA',
  'TSLA',
];


const SEC_CONCEPTS = [
  {
    field: 'revenue',
    domain: 'earnings_actual',
    tags: [
      'RevenueFromContractWithCustomerExcludingAssessedTax',
      'Revenues',
      'SalesRevenueNet',
    ],
    units: ['USD'],
  },
  {
    field: 'net_income',
    domain: 'earnings_actual',
    tags: ['NetIncomeLoss', 'ProfitLoss'],
    units: ['USD'],
  },
  {
    field: 'eps_diluted',
    domain: 'earnings_actual',
    tags: ['EarningsPerShareDiluted'],
    units: ['USD/shares'],
  },
  {
    field: 'gross_profit',
    domain: 'fundamental',
    tags: ['GrossProfit'],
    units: ['USD'],
  },
  {
    field: 'operating_income',
    domain: 'fundamental',
    tags: ['OperatingIncomeLoss'],
    units: ['USD'],
  },
  {
    field: 'operating_cash_flow',
    domain: 'fundamental',
    tags: ['NetCashProvidedByUsedInOperatingActivities'],
    units: ['USD'],
  },
  {
    field: 'capital_expenditure',
    domain: 'fundamental',
    tags: ['PaymentsToAcquirePropertyPlantAndEquipment'],
    units: ['USD'],
  },
  {
    field: 'assets',
    domain: 'fundamental',
    tags: ['Assets'],
    units: ['USD'],
  },
  {
    field: 'liabilities',
    domain: 'fundamental',
    tags: ['Liabilities'],
    units: ['USD'],
  },
  {
    field: 'stockholders_equity',
    domain: 'fundamental',
    tags: ['StockholdersEquity'],
    units: ['USD'],
  },
  {
    field: 'cash',
    domain: 'fundamental',
    tags: [
      'CashAndCashEquivalentsAtCarryingValue',
      'CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents',
    ],
    units: ['USD'],
  },
];

const args = process.argv.slice(2);
const option = (name, fallback) => {
  const index = args.indexOf(name);
  if (index === -1) return fallback;
  if (!args[index + 1] || args[index + 1].startsWith('--')) {
    throw new Error(`${name} requires a value`);
  }
  return args[index + 1];
};

const csvOption = (name, fallback) =>
  option(name, fallback.join(','))
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);

const sources = new Set(csvOption('--sources', ['sec']).map((value) => value.toLowerCase()));
const symbols = csvOption('--symbols', DEFAULT_SYMBOLS).map((value) => value.toUpperCase());
const outputPath = path.resolve(
  option('--output', 'quant_engine_rs/data/context/official_observations.jsonl'),
);
const receivedAt = new Date().toISOString();

for (const source of sources) {
  if (source !== 'sec') {
    throw new Error(`unsupported source: ${source}`);
  }
}

const secUserAgent = process.env.SEC_USER_AGENT?.trim();
const secContactEmail = secUserAgent?.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i)?.[0];
if (
  sources.has('sec')
  && (
    !secUserAgent
    || !/AXIO7/i.test(secUserAgent)
    || !secContactEmail
    || /@(example|invalid|test)\./i.test(secContactEmail)
  )
) {
  throw new Error('SEC_USER_AGENT must identify AXIO7 and contain a real contact email');
}
const sha256 = (value) => createHash('sha256').update(value).digest('hex');
const stableJson = (value) => JSON.stringify(sortObject(value));

function sortObject(value) {
  if (Array.isArray(value)) return value.map(sortObject);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(
    Object.entries(value)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, nested]) => [key, sortObject(nested)]),
  );
}

const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function atomicWrite(file, content) {
  const temporary = path.join(
    path.dirname(file),
    `.${path.basename(file)}.${process.pid}.${Date.now()}.tmp`,
  );
  await writeFile(temporary, content, { encoding: 'utf8', flag: 'wx' });
  try {
    await rename(temporary, file);
  } finally {
    await unlink(temporary).catch((error) => {
      if (error?.code !== 'ENOENT') throw error;
    });
  }
}

async function fetchJson(url, { headers = {}, attempts = 3 } = {}) {
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 25_000);
    try {
      const response = await fetch(url, {
        headers: {
          Accept: 'application/json',
          ...headers,
        },
        signal: controller.signal,
      });
      const text = await response.text();
      if (!response.ok) {
        throw new Error(`${response.status} ${response.statusText}: ${text.slice(0, 180)}`);
      }
      return { value: JSON.parse(text), raw: text };
    } catch (error) {
      lastError = error;
      if (attempt < attempts) await sleep(250 * 2 ** (attempt - 1));
    } finally {
      clearTimeout(timeout);
    }
  }
  throw lastError;
}

const dataRoot = path.resolve(path.dirname(outputPath), '..');
const rawRoot = path.join(dataRoot, 'raw', 'official_context');
const manifestRoot = path.join(dataRoot, 'manifests');
const archiveRoot = path.join(path.dirname(outputPath), 'archive');

async function archiveRaw(provider, raw, label, rawArtifacts) {
  const digest = sha256(raw);
  const directory = path.join(rawRoot, provider);
  await mkdir(directory, { recursive: true });
  const file = path.join(directory, `${digest}.json`);
  try {
    await writeFile(file, raw, { encoding: 'utf8', flag: 'wx' });
  } catch (error) {
    if (error?.code !== 'EEXIST') throw error;
  }
  rawArtifacts.push({
    provider,
    label,
    sha256: digest,
    path: path.relative(process.cwd(), file),
    pathRelativeToDataRoot: path.relative(dataRoot, file),
  });
  return digest;
}

function columnarRows(source) {
  const accessions = source?.accessionNumber || [];
  return accessions.map((accessionNumber, index) => ({
    accessionNumber,
    acceptanceDateTime: source.acceptanceDateTime?.[index] || null,
    filingDate: source.filingDate?.[index] || null,
    reportDate: source.reportDate?.[index] || null,
    form: source.form?.[index] || null,
    primaryDocument: source.primaryDocument?.[index] || null,
  }));
}

function validIso(value) {
  if (!value) return null;
  if (!/(?:Z|[+-]\d{2}:\d{2})$/i.test(value)) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.valueOf()) ? null : parsed.toISOString();
}

function conservativeDateClose(date) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date || '')) return null;
  return `${date}T23:59:59.999Z`;
}

function contextRow({
  symbol,
  field,
  value,
  eventTime,
  availableTime,
  provider,
  route,
  upstreamVendor,
  frequency,
  units,
  revisionId,
  supersedesRevisionId = null,
  domain,
  availabilityPrecision,
  sourceRecordId,
  licenseClass = 'public',
  featureUse = 'model_candidate',
  rawRecord,
}) {
  const row = {
    symbol,
    field,
    value,
    event_time: eventTime,
    available_time: availableTime,
    received_time: receivedAt,
    provider,
    route,
    upstream_vendor: upstreamVendor,
    frequency,
    units,
    adjusted: null,
    revision_id: revisionId,
    supersedes_revision_id: supersedesRevisionId,
    domain,
    availability_precision: availabilityPrecision,
    source_record_id: sourceRecordId,
    payload_sha256: sha256(stableJson(rawRecord)),
    license_class: licenseClass,
    feature_use: featureUse,
  };
  if (!Number.isFinite(row.value)) throw new Error(`non-finite observation ${sourceRecordId}`);
  if (new Date(row.available_time) < new Date(row.event_time)) {
    throw new Error(`availability precedes event time for ${sourceRecordId}`);
  }
  return row;
}

function periodKind(fact, form) {
  if (!fact.start) return 'instant';
  const start = new Date(`${fact.start}T00:00:00Z`);
  const end = new Date(`${fact.end}T00:00:00Z`);
  const days = (end - start) / 86_400_000;
  if (['10-Q', '10-Q/A'].includes(form) && days >= 70 && days <= 120) return 'quarterly';
  if (['10-K', '10-K/A', '20-F', '20-F/A'].includes(form) && days >= 300 && days <= 400) {
    return 'annual';
  }
  return null;
}

function applyRevisionChains(rows) {
  const grouped = new Map();
  for (const row of rows) {
    const key = `${row.symbol}|${row.field}|${row.event_time}`;
    const bucket = grouped.get(key) || [];
    bucket.push(row);
    grouped.set(key, bucket);
  }
  for (const bucket of grouped.values()) {
    bucket.sort((left, right) =>
      left.available_time.localeCompare(right.available_time)
      || left.revision_id.localeCompare(right.revision_id));
    for (let index = 1; index < bucket.length; index += 1) {
      bucket[index].supersedes_revision_id = bucket[index - 1].revision_id;
    }
  }
}

async function loadSecAcceptanceMap(cik, submissions, rawArtifacts) {
  const rows = columnarRows(submissions.filings?.recent);
  for (const file of submissions.filings?.files || []) {
    await sleep(125);
    const url = `https://data.sec.gov/submissions/${encodeURIComponent(file.name)}`;
    const response = await fetchJson(url, { headers: { 'User-Agent': secUserAgent } });
    await archiveRaw('sec', response.raw, `${cik}:${file.name}`, rawArtifacts);
    rows.push(...columnarRows(response.value));
  }
  return new Map(
    rows
      .filter((row) => row.accessionNumber && validIso(row.acceptanceDateTime))
      .map((row) => [row.accessionNumber, { ...row, acceptedAt: validIso(row.acceptanceDateTime) }]),
  );
}

async function syncSec(rawArtifacts, diagnostics) {
  const headers = { 'User-Agent': secUserAgent };
  const tickerResponse = await fetchJson('https://www.sec.gov/files/company_tickers.json', { headers });
  await archiveRaw('sec', tickerResponse.raw, 'company_tickers', rawArtifacts);
  const tickerMap = new Map(
    Object.values(tickerResponse.value).map((row) => [
      String(row.ticker).toUpperCase(),
      { cik: String(row.cik_str).padStart(10, '0'), title: row.title },
    ]),
  );
  const observations = [];
  for (const symbol of symbols) {
    const issuer = tickerMap.get(symbol);
    if (!issuer) throw new Error(`SEC ticker/CIK mapping missing for ${symbol}`);
    await sleep(125);
    const submissionsUrl = `https://data.sec.gov/submissions/CIK${issuer.cik}.json`;
    const submissionsResponse = await fetchJson(submissionsUrl, { headers });
    await archiveRaw('sec', submissionsResponse.raw, `${symbol}:submissions`, rawArtifacts);
    const acceptanceMap = await loadSecAcceptanceMap(
      issuer.cik,
      submissionsResponse.value,
      rawArtifacts,
    );

    await sleep(125);
    const factsUrl = `https://data.sec.gov/api/xbrl/companyfacts/CIK${issuer.cik}.json`;
    const factsResponse = await fetchJson(factsUrl, { headers });
    await archiveRaw('sec', factsResponse.raw, `${symbol}:companyfacts`, rawArtifacts);
    const facts = factsResponse.value.facts?.['us-gaap'] || {};
    const chosen = new Map();

    for (const definition of SEC_CONCEPTS) {
      for (let priority = 0; priority < definition.tags.length; priority += 1) {
        const tag = definition.tags[priority];
        const concept = facts[tag];
        if (!concept) continue;
        for (const unit of definition.units) {
          for (const fact of concept.units?.[unit] || []) {
            const filing = acceptanceMap.get(fact.accn);
            const form = fact.form || filing?.form;
            const kind = periodKind(fact, form);
            if (!filing?.acceptedAt || !kind || !Number.isFinite(Number(fact.val))) continue;
            const eventTime = conservativeDateClose(fact.end);
            if (!eventTime || new Date(filing.acceptedAt) < new Date(eventTime)) continue;
            const field = `sec.${definition.field}.${kind}`;
            const dedupeKey = `${field}|${fact.end}|${fact.accn}`;
            const previous = chosen.get(dedupeKey);
            if (previous && previous.priority <= priority) continue;
            const sourceRecordId = [
              'sec',
              issuer.cik,
              fact.accn,
              tag,
              unit,
              fact.start || 'instant',
              fact.end,
            ].join(':');
            chosen.set(dedupeKey, {
              priority,
              row: contextRow({
                symbol,
                field,
                value: Number(fact.val),
                eventTime,
                availableTime: filing.acceptedAt,
                provider: 'sec_edgar',
                route: 'api/xbrl/companyfacts',
                upstreamVendor: 'U.S. Securities and Exchange Commission',
                frequency: 'daily',
                units: unit,
                revisionId: `${fact.accn}:${tag}:${fact.start || 'instant'}:${fact.end}`,
                domain: definition.domain,
                availabilityPrecision: 'exact_timestamp',
                sourceRecordId,
                rawRecord: { issuer, tag, unit, fact, filing },
              }),
            });
          }
        }
      }
    }
    observations.push(...Array.from(chosen.values(), (entry) => entry.row));

    for (const filing of acceptanceMap.values()) {
      if (!filing.acceptedAt || !['8-K', '10-Q', '10-Q/A', '10-K', '10-K/A', '20-F', '20-F/A', '6-K'].includes(filing.form)) {
        continue;
      }
      const form = filing.form.replace('/', '_').toLowerCase();
      const sourceRecordId = `sec:${issuer.cik}:${filing.accessionNumber}:filing`;
      observations.push(contextRow({
        symbol,
        field: `sec.filing.${form}`,
        value: 1,
        eventTime: filing.acceptedAt,
        availableTime: filing.acceptedAt,
        provider: 'sec_edgar',
        route: 'submissions',
        upstreamVendor: 'U.S. Securities and Exchange Commission',
        frequency: 'snapshot',
        units: 'event_flag',
        revisionId: filing.accessionNumber,
        domain: 'filing',
        availabilityPrecision: 'exact_timestamp',
        sourceRecordId,
        rawRecord: { issuer, filing },
      }));
    }
    diagnostics.sec ??= {};
    diagnostics.sec[symbol] = {
      cik: issuer.cik,
      acceptedFilings: acceptanceMap.size,
      normalizedObservations: observations.filter((row) => row.symbol === symbol).length,
    };
  }
  applyRevisionChains(observations);
  return observations;
}


async function loadExistingRows() {
  try {
    const text = await readFile(outputPath, 'utf8');
    return text
      .split(/\r?\n/)
      .filter(Boolean)
      .map((line, index) => {
        try {
          return JSON.parse(line);
        } catch (error) {
          throw new Error(`invalid existing JSONL at line ${index + 1}: ${error.message}`);
        }
      });
  } catch (error) {
    if (error?.code === 'ENOENT') return [];
    throw error;
  }
}

function mergeImmutable(existing, incoming) {
  const byRecord = new Map();
  for (const row of [...existing, ...incoming]) {
    if (!row.source_record_id || !row.payload_sha256) {
      throw new Error('every normalized row requires source_record_id and payload_sha256');
    }
    const prior = byRecord.get(row.source_record_id);
    if (prior && prior.payload_sha256 !== row.payload_sha256) {
      throw new Error(`immutable source record changed: ${row.source_record_id}`);
    }
    byRecord.set(row.source_record_id, prior || row);
  }
  return Array.from(byRecord.values()).sort((left, right) =>
    left.available_time.localeCompare(right.available_time)
    || left.symbol.localeCompare(right.symbol)
    || left.field.localeCompare(right.field)
    || left.source_record_id.localeCompare(right.source_record_id));
}

async function main() {
  const rawArtifacts = [];
  const diagnostics = {};
  const incoming = [];
  if (sources.has('sec')) incoming.push(...(await syncSec(rawArtifacts, diagnostics)));
  if (!incoming.length) throw new Error('sync returned no official observations');

  const existing = await loadExistingRows();
  const merged = mergeImmutable(existing, incoming);
  const jsonl = `${merged.map((row) => stableJson(row)).join('\n')}\n`;
  const outputSha256 = sha256(jsonl);
  await mkdir(path.dirname(outputPath), { recursive: true });
  await mkdir(archiveRoot, { recursive: true });
  await mkdir(manifestRoot, { recursive: true });
  if (existing.length) {
    const previous = await readFile(outputPath);
    const previousHash = sha256(previous);
    const archive = path.join(archiveRoot, `official_observations_${previousHash}.jsonl`);
    try {
      await copyFile(outputPath, archive, 1);
    } catch (error) {
      if (error?.code !== 'EEXIST') throw error;
    }
  }
  await atomicWrite(outputPath, jsonl);

  const manifest = {
    schemaVersion: 'official-context-sync-v2',
    generatedAt: receivedAt,
    sources: Array.from(sources).sort(),
    symbols,
    existingRows: existing.length,
    incomingRows: incoming.length,
    mergedRows: merged.length,
    output: path.relative(process.cwd(), outputPath),
    outputRelativeToDataRoot: path.relative(dataRoot, outputPath),
    outputSha256,
    rawArtifacts,
    diagnostics,
    availabilityRules: {
      sec: 'acceptanceDateTime from SEC submissions; rows without an exact acceptance timestamp are excluded',
    },
    prohibitedClaims: [
      'SEC actuals are not analyst consensus or guidance estimates',
      'FRED and ALFRED are unsupported by this sync because current terms do not authorize AXIO7 model development or archival use',
      'successful ingestion does not promote a feature or trading model',
    ],
  };
  const manifestName = `official_context_sync_${receivedAt.replace(/[:.]/g, '-')}_${outputSha256.slice(0, 12)}.json`;
  await atomicWrite(
    path.join(manifestRoot, manifestName),
    `${JSON.stringify(manifest, null, 2)}\n`,
  );
  process.stdout.write(`${JSON.stringify({ status: 'OK', ...manifest }, null, 2)}\n`);
}

main().catch((error) => {
  process.stderr.write(`official context sync failed: ${error?.stack || error}\n`);
  process.exitCode = 1;
});
