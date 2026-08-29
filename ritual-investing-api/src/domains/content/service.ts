import { uuidSchema } from "../retained-http/schemas.ts";

export function contentRecord(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

export function contentNullableString(
  value: Record<string, unknown>,
  key: string,
): string | null {
  const candidate = value[key];
  return typeof candidate === "string" && candidate.trim().length > 0
    ? candidate
    : null;
}

export function timestampString(value: unknown): string | null {
  if (value instanceof Date) {
    return value.toJSON();
  }
  return typeof value === "string" &&
      value.trim().length > 0 &&
      !Number.isNaN(Date.parse(value))
    ? value
    : null;
}

export function contentNullableTimestamp(
  value: Record<string, unknown>,
  key: string,
): string | null {
  return timestampString(value[key]);
}

export function contentArray(value: Record<string, unknown>, key: string): unknown[] {
  const candidate = value[key];
  return Array.isArray(candidate) ? candidate : [];
}

function invalidProjection(field: string): never {
  throw new Error(`invalid_content_projection:${field}`);
}

function requiredContentString(
  value: Record<string, unknown>,
  key: string,
): string {
  const candidate = value[key];
  return typeof candidate === "string" && candidate.trim().length > 0
    ? candidate
    : invalidProjection(key);
}

function requiredTimestamp(value: unknown, field: string): string {
  const timestamp = timestampString(value);
  return timestamp === null
    ? invalidProjection(field)
    : new Date(timestamp).toISOString();
}

function requiredPositiveInteger(value: unknown, field: string): number {
  // postgres decodes int8 as a decimal string. Normalize only its canonical
  // integer form so the response boundary keeps the same safe-integer guard.
  const candidate = typeof value === "string" && /^[1-9][0-9]*$/.test(value)
    ? Number(value)
    : value;
  return typeof candidate === "number" && Number.isSafeInteger(candidate) &&
      candidate > 0
    ? candidate
    : invalidProjection(field);
}

function requiredDate(value: unknown, field: string): string {
  // postgres decodes DATE as Date in this boundary. Preserve DATE semantics
  // exactly: accept canonical date strings or UTC-midnight Date values only.
  const suppliedDate = typeof value === "string" ? value : null;
  const date = value instanceof Date
    ? value
    : typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value)
    ? new Date(`${value}T00:00:00.000Z`)
    : null;
  if (
    date === null || Number.isNaN(date.valueOf()) ||
    date.getUTCHours() !== 0 || date.getUTCMinutes() !== 0 ||
    date.getUTCSeconds() !== 0 || date.getUTCMilliseconds() !== 0
  ) {
    return invalidProjection(field);
  }
  const normalized = date.toISOString().slice(0, 10);
  return suppliedDate === null || suppliedDate === normalized
    ? normalized
    : invalidProjection(field);
}

export function researchDisclosure(
  observedAt: unknown,
): Record<string, unknown> {
  return {
    is_demo: false,
    observed_at: requiredTimestamp(observedAt, "observed_at"),
    source_label: "Argus editorial",
    limitations: [
      "Editorial research is informational and is not brokerage authority.",
    ],
  };
}

export function presentEvidenceSummary(value: unknown): Record<string, unknown> {
  const claim = contentRecord(value);
  return {
    claim_id: requiredContentString(claim, "id"),
    factor_label: requiredContentString(claim, "claim_type"),
    summary: requiredContentString(claim, "summary"),
    observed_at: requiredTimestamp(claim.observed_at, "observed_at"),
    uncertainty: requiredContentString(claim, "uncertainty"),
  };
}

export function presentEvidenceDetail(value: unknown): Record<string, unknown> {
  const claim = contentRecord(value);
  const source = contentRecord(claim.source);
  const candidateUrl = contentNullableString(source, "canonical_url");
  const url = candidateUrl !== null && candidateUrl.startsWith("https://")
    ? candidateUrl
    : null;
  return {
    ...presentEvidenceSummary(claim),
    source: {
      title: requiredContentString(source, "title"),
      publisher: requiredContentString(source, "publisher"),
      url,
      published_at: contentNullableTimestamp(source, "published_at"),
    },
  };
}

export function presentAssetSummary(value: unknown): Record<string, unknown> {
  const asset = contentRecord(value);
  const payload = contentRecord(asset.payload);
  const assetType = requiredContentString(asset, "asset_type");
  if (!["equity", "etf", "index", "cash"].includes(assetType)) {
    invalidProjection("asset_type");
  }
  return {
    id: uuidSchema.parse(asset.id),
    slug: requiredContentString(asset, "slug"),
    symbol: requiredContentString(asset, "symbol"),
    name: requiredContentString(asset, "name"),
    asset_type: assetType === "index" ? "market_index" : assetType,
    currency: requiredContentString(asset, "currency"),
    revision_id: uuidSchema.parse(asset.revision_id),
    appearance_reason: requiredContentString(payload, "appearance_reason"),
    demo: researchDisclosure(asset.revision_created_at),
  };
}

export function presentAssetDetail(
  value: unknown,
  evidenceValues: readonly unknown[] = [],
): Record<string, unknown> {
  const asset = contentRecord(value);
  const payload = contentRecord(asset.payload);
  return {
    ...presentAssetSummary(asset),
    thesis: requiredContentString(payload, "thesis"),
    limitations: requiredContentString(payload, "limitations"),
    metrics_as_of: requiredTimestamp(asset.metrics_as_of, "metrics_as_of"),
    evidence: evidenceValues.map(presentEvidenceSummary),
    risks: contentArray(payload, "risks").map((entry) => {
      const risk = contentRecord(entry);
      const severity = requiredContentString(risk, "severity");
      if (!["low", "medium", "high"].includes(severity)) {
        invalidProjection("risk.severity");
      }
      return {
        title: requiredContentString(risk, "title"),
        detail: requiredContentString(risk, "detail"),
        severity,
      };
    }),
    saved: asset.saved === true,
  };
}

export function presentAssetMetric(value: unknown): Record<string, unknown> {
  const row = contentRecord(value);
  const metric = contentRecord(row.metric ?? value);
  const priceMinor = metric.price_minor;
  if (
    typeof priceMinor !== "number" || !Number.isSafeInteger(priceMinor) ||
    priceMinor < 0
  ) {
    invalidProjection("price_minor");
  }
  return {
    observed_at: requiredTimestamp(metric.observed_at, "observed_at"),
    price_minor: priceMinor,
    change_bps: metric.change_bps === null
      ? null
      : Number.isSafeInteger(metric.change_bps)
      ? metric.change_bps
      : invalidProjection("change_bps"),
    expense_ratio_bps: metric.expense_ratio_bps === null
      ? null
      : typeof metric.expense_ratio_bps === "number" &&
          Number.isSafeInteger(metric.expense_ratio_bps) &&
          metric.expense_ratio_bps >= 0
      ? metric.expense_ratio_bps
      : invalidProjection("expense_ratio_bps"),
    source_label: requiredContentString(metric, "source_label"),
    demo: researchDisclosure(metric.observed_at),
  };
}

export function presentBriefingSummary(value: unknown): Record<string, unknown> {
  const briefing = contentRecord(value);
  return {
    id: uuidSchema.parse(briefing.id),
    briefing_type: requiredContentString(briefing, "briefing_type"),
    period_start: requiredDate(briefing.period_start, "period_start"),
    period_end: requiredDate(briefing.period_end, "period_end"),
    generated_at: requiredTimestamp(briefing.generated_at, "generated_at"),
    generation: requiredPositiveInteger(briefing.generation, "generation"),
    source_sequence: requiredPositiveInteger(briefing.source_sequence, "source_sequence"),
    read_at: contentNullableTimestamp(briefing, "read_at"),
  };
}

export function presentBriefingDetail(value: unknown): Record<string, unknown> {
  const briefing = contentRecord(value);
  return {
    ...presentBriefingSummary(briefing),
    sections: contentArray(briefing, "sections").map((entry) => {
      const section = contentRecord(entry);
      return {
        ordinal: requiredPositiveInteger(section.ordinal, "ordinal"),
        source_sequence: requiredPositiveInteger(section.source_sequence, "source_sequence"),
        schema_version: requiredPositiveInteger(section.schema_version, "schema_version"),
        disclosure: requiredContentString(section, "disclosure"),
      };
    }),
  };
}

export function presentCircleTemplate(value: unknown): Record<string, unknown> {
  const template = contentRecord(value);
  const payload = contentRecord(template.payload);
  const observedAt = template.revision_created_at;
  return {
    id: uuidSchema.parse(template.id),
    revision_id: uuidSchema.parse(template.revision_id),
    slug: requiredContentString(template, "slug"),
    title: requiredContentString(template, "title"),
    description: requiredContentString(template, "description"),
    theme: requiredContentString(payload, "theme"),
    creator: {
      id: uuidSchema.parse(template.creator_id),
      slug: requiredContentString(template, "creator_slug"),
      display_name: requiredContentString(template, "creator_display_name"),
      bio: requiredContentString(template, "creator_bio"),
      is_fictional: template.creator_is_fictional === true
        ? true
        : invalidProjection("creator_is_fictional"),
      demo: researchDisclosure(observedAt),
    },
    assets: contentArray(template, "assets").map((entry) => {
      const asset = contentRecord(entry);
      return {
        ...presentAssetSummary(asset),
        ordinal: requiredPositiveInteger(asset.ordinal, "ordinal"),
        weight_bps: typeof asset.weight_bps === "number" ? asset.weight_bps : null,
        note: contentNullableString(asset, "note"),
      };
    }),
    saved: template.saved === true,
    demo: researchDisclosure(observedAt),
  };
}

export function presentCovenSummary(value: unknown): Record<string, unknown> {
  const row = contentRecord(value);
  const payload = contentRecord(row.payload);
  const category = requiredContentString(row, "category");
  if (!["founder", "owner", "chief_executive"].includes(category)) {
    invalidProjection("category");
  }
  const observed = row.revision_created_at;
  return {
    id: uuidSchema.parse(row.id),
    revision_id: uuidSchema.parse(row.revision_id),
    slug: requiredContentString(row, "slug"),
    company: requiredContentString(row, "company_name"),
    symbol: contentNullableString(row, "symbol"),
    category,
    focus: requiredContentString(payload, "focus"),
    teaser: requiredContentString(payload, "teaser"),
    effective_date: requiredDate(row.effective_date, "effective_date"),
    verified_as_of: requiredDate(row.verified_as_of, "verified_as_of"),
    demo: researchDisclosure(observed),
  };
}

export function evidenceClaimIds(value: unknown): string[] {
  const row = contentRecord(value);
  return [...new Set(contentArray(row, "qualification_payload")
    .map((entry) => contentRecord(entry).evidence_claim_id)
    .filter((claimId): claimId is string =>
      typeof claimId === "string" && uuidSchema.safeParse(claimId).success
    ))];
}

export function presentCovenDetail(
  value: unknown,
  evidenceValues: readonly unknown[] = [],
): Record<string, unknown> {
  const row = contentRecord(value);
  const payload = contentRecord(row.payload);
  const qualificationRows = contentArray(row, "qualification_payload")
    .map(contentRecord);
  const primaryQualification = qualificationRows[0] ??
    invalidProjection("qualification_payload");
  const company = contentRecord(row.company);
  const summaryInput = {
    ...row,
    company_name: requiredContentString(company, "name"),
    category: primaryQualification.category,
    effective_date: primaryQualification.effective_date,
    verified_as_of: primaryQualification.verified_as_of,
  };
  const evidenceById = new Map(
    evidenceValues.map((entry) => {
      const evidence = contentRecord(entry);
      return [uuidSchema.parse(evidence.id), evidence] as const;
    }),
  );
  const evidence = [...evidenceById.values()].map(presentEvidenceDetail);
  return {
    ...presentCovenSummary(summaryInput),
    summary: requiredContentString(payload, "summary"),
    inclusion_rationale: requiredContentString(payload, "inclusion_rationale"),
    limitations: requiredContentString(payload, "limitations"),
    qualifications: qualificationRows.map((qualification) => {
      const category = requiredContentString(qualification, "category");
      if (!["founder", "owner", "chief_executive"].includes(category)) {
        invalidProjection("qualification.category");
      }
      const claimId = qualification.evidence_claim_id;
      const qualificationEvidence = (
        typeof claimId === "string" && uuidSchema.safeParse(claimId).success
          ? [claimId]
          : []
      ).map((id) => evidenceById.get(id))
        .filter((claim): claim is Record<string, unknown> => claim !== undefined)
        .map(presentEvidenceSummary);
      return {
        category,
        person_name: requiredContentString(qualification, "person_name"),
        effective_date: requiredDate(
          qualification.effective_date,
          "qualification.effective_date",
        ),
        valid_to: qualification.valid_to == null
          ? null
          : requiredDate(qualification.valid_to, "qualification.valid_to"),
        verified_as_of: requiredDate(
          qualification.verified_as_of,
          "qualification.verified_as_of",
        ),
        evidence: qualificationEvidence,
      };
    }),
    evidence,
    saved: row.saved === true,
  };
}

export function presentGrimoireSummary(value: unknown): Record<string, unknown> {
  const row = contentRecord(value);
  const payload = contentRecord(row.payload);
  return {
    id: uuidSchema.parse(row.id),
    revision_id: uuidSchema.parse(row.revision_id),
    slug: requiredContentString(row, "slug"),
    title: requiredContentString(payload, "title"),
    description: requiredContentString(payload, "description"),
    theme: requiredContentString(row, "theme_code"),
    curator_label: requiredContentString(payload, "curator_label"),
    demo: researchDisclosure(row.revision_created_at),
  };
}

export function presentGrimoireDetail(value: unknown): Record<string, unknown> {
  const row = contentRecord(value);
  return {
    ...presentGrimoireSummary(row),
    assets: contentArray(row, "assets").map(presentAssetSummary),
    saved: row.saved === true,
  };
}

export function presentCircleTemplateSummary(value: unknown): Record<string, unknown> {
  const detail = presentCircleTemplate(value);
  const { assets: _assets, saved: _saved, ...summary } = detail;
  return summary;
}

export function presentCreator(value: unknown): Record<string, unknown> {
  const row = contentRecord(value);
  return {
    id: uuidSchema.parse(row.id),
    slug: requiredContentString(row, "slug"),
    display_name: requiredContentString(row, "display_name"),
    bio: requiredContentString(row, "bio"),
    is_fictional: row.is_fictional === true
      ? true
      : invalidProjection("is_fictional"),
    demo: researchDisclosure(row.observed_at),
  };
}
