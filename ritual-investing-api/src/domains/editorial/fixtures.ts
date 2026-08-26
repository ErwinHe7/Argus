import {
  ContentCursorStaleError,
  ContentInvalidStateError,
  ContentVersionConflictError,
} from "./repository.ts";
import type {
  ContentRepository,
  MemberRequestContext,
  PageRequest,
  PageResult,
  PublishedResult,
} from "./repository.ts";
import type {
  AssetCodexDetail,
  AssetMetric,
  AssetSummary,
  CircleTemplateDetail,
  CircleTemplateSummary,
  CovenDetail,
  CovenSummary,
  DailyRitualDetail,
  DiscoverItem,
  EvidenceDetail,
  GrimoireDetail,
  GrimoireSummary,
  PublicCovenTeaser,
  PublicDiscoverItem,
  RowanCounsel,
  SeededCreator,
} from "./schemas.ts";

export const fixtureIds = {
  ritualRevision: "10000000-0000-4000-8000-000000000001",
  rowanRevision: "10000000-0000-4000-8000-000000000002",
  assignment: "10000000-0000-4000-8000-000000000003",
  vig: "20000000-0000-4000-8000-000000000001",
  xlv: "20000000-0000-4000-8000-000000000002",
  womn: "20000000-0000-4000-8000-000000000003",
  claimVig: "30000000-0000-4000-8000-000000000001",
  claimXlv: "30000000-0000-4000-8000-000000000002",
  claimWomn: "30000000-0000-4000-8000-000000000003",
  quietPower: "40000000-0000-4000-8000-000000000001",
  quietPowerRevision: "40000000-0000-4000-8000-000000000002",
  creator: "50000000-0000-4000-8000-000000000001",
  softPower: "50000000-0000-4000-8000-000000000002",
  softPowerRevision: "50000000-0000-4000-8000-000000000003",
  aurora: "60000000-0000-4000-8000-000000000001",
  juniper: "60000000-0000-4000-8000-000000000002",
  morrow: "60000000-0000-4000-8000-000000000003",
  thistle: "60000000-0000-4000-8000-000000000004",
  covenRevisionAurora: "62000000-0000-4000-8000-000000000001",
  covenRevisionJuniper: "62000000-0000-4000-8000-000000000002",
  covenRevisionMorrow: "62000000-0000-4000-8000-000000000003",
  covenRevisionThistle: "62000000-0000-4000-8000-000000000004",
} as const;

const observedAt = "2026-08-20T13:35:00.000Z";
const limitations = [
  "Deterministic demo data; prices and signals are fictional.",
  "Educational exploration only; not investment advice.",
];
const demo = {
  is_demo: true as const,
  observed_at: observedAt,
  source_label: "Ritual deterministic demonstration",
  limitations,
};

const evidence: EvidenceDetail[] = [
  {
    claim_id: fixtureIds.claimVig,
    factor_label: "Durable dividend momentum",
    summary:
      "Lower volatility and durable dividend momentum in the scenario window.",
    observed_at: observedAt,
    uncertainty: "Short windows can reverse and do not predict future returns.",
    source: {
      title: "Ritual demo market observation — VIG",
      publisher: "Ritual Research Fixtures",
      url: "https://research.ritual-investing.test/demo/vig",
      published_at: observedAt,
    },
  },
  {
    claim_id: fixtureIds.claimXlv,
    factor_label: "Defensive relative strength",
    summary:
      "Defensive relative strength appeared in the simulated scenario window.",
    observed_at: observedAt,
    uncertainty: "Relative strength is descriptive, not a recommendation.",
    source: {
      title: "Ritual demo market observation — XLV",
      publisher: "Ritual Research Fixtures",
      url: "https://research.ritual-investing.test/demo/xlv",
      published_at: observedAt,
    },
  },
  {
    claim_id: fixtureIds.claimWomn,
    factor_label: "Leadership breadth",
    summary:
      "Broad leadership exposure showed positive breadth in the demo data.",
    observed_at: observedAt,
    uncertainty: "The observation is fictional and may not generalize.",
    source: {
      title: "Ritual demo market observation — WOMN",
      publisher: "Ritual Research Fixtures",
      url: "https://research.ritual-investing.test/demo/womn",
      published_at: observedAt,
    },
  },
];

const assets: AssetCodexDetail[] = [
  [
    fixtureIds.vig,
    "vig",
    "VIG",
    "Vanguard Dividend Appreciation ETF",
    "Durable dividend growth",
    42,
  ],
  [
    fixtureIds.xlv,
    "xlv",
    "XLV",
    "Health Care Select Sector SPDR Fund",
    "Defensive orbit",
    31,
  ],
  [
    fixtureIds.womn,
    "womn",
    "WOMN",
    "Impact Shares YWCA Women's Empowerment ETF",
    "Leadership exposure",
    27,
  ],
].map(
  ([id, slug, symbol, name, appearance, change], index) =>
    ({
      id: id as string,
      slug: slug as string,
      symbol: symbol as string,
      name: name as string,
      asset_type: "etf" as const,
      currency: "USD" as const,
      revision_id: `21000000-0000-4000-8000-00000000000${index + 1}`,
      appearance_reason: `${appearance} aligned with The Compass scenario.`,
      thesis: `${name} is included as a deterministic research example, not a trade instruction.`,
      risks: [
        {
          title: "Scenario and market risk",
          detail:
            "The fixture is simulated and real market conditions can differ materially.",
          severity: "medium" as const,
        },
      ],
      evidence: [
        {
          claim_id: evidence[index]!.claim_id,
          factor_label: evidence[index]!.factor_label,
          summary: evidence[index]!.summary,
          observed_at: evidence[index]!.observed_at,
          uncertainty: evidence[index]!.uncertainty,
        },
      ],
      metrics_as_of: observedAt,
      limitations: limitations.join(" "),
      saved: false,
      demo: { ...demo, source_label: `Ritual fixture ${symbol}`, limitations },
      _change: change as number,
    }) as AssetCodexDetail & { _change: number },
);

const metricFor = (
  asset: AssetCodexDetail & { _change?: number },
): AssetMetric => ({
  observed_at: observedAt,
  price_minor:
    asset.symbol === "VIG" ? 20142 : asset.symbol === "XLV" ? 15331 : 4217,
  change_bps: asset._change ?? 0,
  expense_ratio_bps: asset.symbol === "WOMN" ? 75 : 10,
  source_label: "Ritual deterministic demonstration",
  demo,
});

const creator: SeededCreator = {
  id: fixtureIds.creator,
  slug: "selene-vale",
  display_name: "Selene Vale",
  bio: "A fictional curator who favors patient, diversified research paths.",
  is_fictional: true,
  demo,
};

const quietPower: GrimoireDetail = {
  id: fixtureIds.quietPower,
  slug: "quiet-power",
  title: "Quiet Power",
  description: "Durability over drama.",
  theme: "durability",
  curator_label: "Ritual Research",
  revision_id: fixtureIds.quietPowerRevision,
  assets: assets.map(stripAsset),
  saved: false,
  demo,
};

const softPower: CircleTemplateDetail = {
  id: fixtureIds.softPower,
  slug: "soft-power-portfolio",
  title: "Soft Power Portfolio",
  description: "A fictional curator's diversified demo circle.",
  theme: "soft_power",
  creator,
  revision_id: fixtureIds.softPowerRevision,
  assets: assets.map((asset, index) => ({
    ...stripAsset(asset),
    ordinal: index + 1,
    weight_bps: [4000, 2500, 3500][index]!,
    note: "Deterministic template allocation.",
  })),
  saved: false,
  demo,
};

const covenSeed: Array<{
  id: string;
  slug: string;
  company: string;
  symbol: string;
  category: "founder" | "owner" | "chief_executive";
  person: string;
  focus: string;
}> = [
  {
    id: fixtureIds.aurora,
    slug: "aurora-healthworks",
    company: "Aurora Healthworks",
    symbol: "AURA",
    category: "founder",
    person: "Maya Rowan",
    focus: "Preventive health technology",
  },
  {
    id: fixtureIds.juniper,
    slug: "juniper-robotics",
    company: "Juniper Robotics",
    symbol: "JNPR",
    category: "chief_executive",
    person: "Elena Park",
    focus: "Industrial automation",
  },
  {
    id: fixtureIds.morrow,
    slug: "morrow-energy",
    company: "Morrow Energy",
    symbol: "MROW",
    category: "owner",
    person: "Asha Morrow",
    focus: "Distributed clean energy",
  },
  {
    id: fixtureIds.thistle,
    slug: "thistle-foods",
    company: "Thistle Foods",
    symbol: "THST",
    category: "founder",
    person: "Nora Thistle",
    focus: "Sustainable nutrition",
  },
];

const covenDetails: CovenDetail[] = covenSeed.map((entry, index) => ({
  id: entry.id,
  slug: entry.slug,
  company: entry.company,
  symbol: entry.symbol,
  focus: entry.focus,
  summary: `${entry.focus} in the fictional Founders' Coven demo directory.`,
  inclusion_rationale: `Included under the distinct ${entry.category} qualification only.`,
  limitations:
    "Fictional demonstration record; not an investment recommendation.",
  qualifications: [
    {
      category: entry.category,
      person_name: entry.person,
      effective_date: "2026-01-01",
      valid_to: null,
      verified_as_of: "2026-08-20",
      evidence: [
        {
          claim_id: `61000000-0000-4000-8000-00000000000${index + 1}`,
          factor_label: `${entry.category} qualification`,
          summary: `${entry.person} is the fixture's dated ${entry.category} example.`,
          observed_at: observedAt,
          uncertainty:
            "This identity and company are fictional demonstration data.",
        },
      ],
    },
  ],
  revision_id: [
    fixtureIds.covenRevisionAurora,
    fixtureIds.covenRevisionJuniper,
    fixtureIds.covenRevisionMorrow,
    fixtureIds.covenRevisionThistle,
  ][index]!,
  saved: false,
  demo,
}));

function stripAsset(asset: AssetCodexDetail): AssetSummary {
  const {
    thesis: _thesis,
    risks: _risks,
    evidence: _evidence,
    metrics_as_of: _metricsAsOf,
    limitations: _limitations,
    saved: _saved,
    _change: _change,
    ...summary
  } = asset as AssetCodexDetail & { _change?: number };
  return summary;
}

function stripAssetDetail(asset: AssetCodexDetail): AssetCodexDetail {
  const { _change: _change, ...detail } = asset as AssetCodexDetail & {
    _change?: number;
  };
  return detail;
}

function stableAssignmentId(key: string): string {
  const hashes = [0x811c9dc5, 0x9e3779b9, 0x85ebca6b, 0xc2b2ae35]
    .map((seed) => {
      let hash = seed >>> 0;
      for (const character of key) {
        hash ^= character.codePointAt(0)!;
        hash = Math.imul(hash, 0x01000193) >>> 0;
      }
      return hash.toString(16).padStart(8, "0");
    })
    .join("")
    .split("");
  hashes[12] = "4";
  hashes[16] = "8";
  const compact = hashes.join("");
  return `${compact.slice(0, 8)}-${compact.slice(8, 12)}-${compact.slice(12, 16)}-${compact.slice(16, 20)}-${compact.slice(20)}`;
}

function ritualFor(
  date: string,
  mode: "tarot" | "astrology",
  state: DailyRitualDetail["state"] = "assigned",
  assignmentId: string = fixtureIds.assignment,
  revisionId: string = fixtureIds.ritualRevision,
): DailyRitualDetail {
  const counsel: RowanCounsel = {
    script_revision_id: fixtureIds.rowanRevision,
    surface: "daily_ritual",
    body: "I'll show you what changed beneath the reading. You decide what, if anything, to explore.",
    risk_footer:
      "This deterministic demo explains uncertainty and never tells you to trade.",
  };
  return {
    assignment_id: assignmentId,
    date,
    mode,
    revision: { id: revisionId, number: 1 },
    title: "Direction, not urgency.",
    art: {
      key: "the_compass",
      alt: "The Compass tarot card: a woman holding a lantern at a celestial crossroads",
    },
    interpretation:
      "The strongest path today rewards patience. Favor durable momentum; let noisy names pass without you.",
    guidance:
      "Inspect the evidence, compare risks, and choose whether any research path deserves more attention.",
    market_label: "Market-informed · reveal the pattern",
    ideas: assets.map((asset) => ({
      asset_id: asset.id,
      symbol: asset.symbol,
      name: asset.name,
      appearance_reason: asset.appearance_reason,
      risk_summary: asset.risks[0]!.detail,
    })),
    evidence: evidence.map(({ source: _source, ...summary }) => summary),
    rowan: counsel,
    version: 1,
    state,
    revealed_at: state === "assigned" ? null : "2026-08-20T14:00:00.000Z",
    completed_at: state === "completed" ? "2026-08-20T14:05:00.000Z" : null,
    demo,
  };
}

function page<T>(
  items: T[],
  request: PageRequest,
  position: (item: T) => string,
): PageResult<T> {
  const found =
    request.after === undefined
      ? -1
      : items.findIndex((item) => position(item) === request.after);
  if (request.after !== undefined && found < 0)
    throw new ContentCursorStaleError();
  const start = found + 1;
  const selected = items.slice(start, start + request.limit);
  return {
    items: selected,
    nextPosition:
      start + request.limit < items.length && selected.length > 0
        ? position(selected[selected.length - 1]!)
        : null,
  };
}

export type DeterministicPublicationControl = {
  ritualRevisionId: string;
  catalogRevisionId: string;
  ritualAvailable: boolean;
  catalogAvailable: boolean;
};

export function deterministicPublicationControl(): DeterministicPublicationControl {
  return {
    ritualRevisionId: fixtureIds.ritualRevision,
    catalogRevisionId: fixtureIds.ritualRevision,
    ritualAvailable: true,
    catalogAvailable: true,
  };
}

export function createDeterministicContentRepository(
  publication: DeterministicPublicationControl = deterministicPublicationControl(),
): ContentRepository {
  const assignments = new Map<string, DailyRitualDetail>();
  const keyFor = (context: MemberRequestContext, date: string, mode: string) =>
    `${context.tenantId}:${date}:${mode}`;
  const discoverItems: DiscoverItem[] = [
    ...assets.map((asset) => ({
      kind: "asset" as const,
      asset: stripAsset(asset),
    })),
    ...covenDetails.map((entry) => ({
      kind: "coven" as const,
      coven: covenSummary(entry),
    })),
    { kind: "grimoire" as const, grimoire: grimoireSummary(quietPower) },
    {
      kind: "circle_template" as const,
      circle_template: circleTemplateSummary(softPower),
    },
  ];
  const publicDiscoverItems: PublicDiscoverItem[] = [
    ...assets.map((asset) => ({
      kind: "asset" as const,
      slug: asset.slug,
      symbol: asset.symbol,
      title: asset.name,
      teaser: asset.appearance_reason,
      demo: asset.demo,
    })),
    ...covenDetails.map((entry) => ({
      kind: "coven" as const,
      slug: entry.slug,
      title: entry.company,
      category: entry.qualifications[0]!.category,
      verified_as_of: entry.qualifications[0]!.verified_as_of,
      teaser: entry.summary,
      demo: entry.demo,
    })),
    {
      kind: "grimoire" as const,
      slug: quietPower.slug,
      title: quietPower.title,
      teaser: quietPower.description,
      demo: quietPower.demo,
    },
    {
      kind: "circle_template" as const,
      slug: softPower.slug,
      title: softPower.title,
      teaser: softPower.description,
      creator_label: creator.display_name,
      is_fictional: true as const,
      demo: softPower.demo,
    },
  ];
  return {
    async resolveDailyRevision() {
      return publication.ritualAvailable ? publication.ritualRevisionId : null;
    },
    async loadDaily({ date, mode }, revisionId) {
      if (
        !publication.ritualAvailable ||
        revisionId !== publication.ritualRevisionId
      )
        return null;
      const detail = ritualFor(
        date,
        mode,
        "assigned",
        fixtureIds.assignment,
        revisionId,
      );
      return {
        date,
        mode,
        title: detail.title,
        art: detail.art,
        interpretation_excerpt: detail.interpretation,
        market_label: detail.market_label,
        idea_teasers: detail.ideas.map(
          ({ symbol, name, appearance_reason }) => ({
            symbol,
            name,
            appearance_reason,
          }),
        ),
        demo: detail.demo,
      };
    },
    async resolveDiscoverRevision() {
      return publication.catalogAvailable
        ? publication.catalogRevisionId
        : "empty";
    },
    async listDiscover(input, revisionId) {
      if (
        revisionId !==
        (publication.catalogAvailable ? publication.catalogRevisionId : "empty")
      )
        throw new ContentCursorStaleError();
      return page(
        publication.catalogAvailable ? publicDiscoverItems : [],
        input,
        publicDiscoverPosition,
      );
    },
    async resolveCovenRevision(slug) {
      if (!publication.catalogAvailable) return null;
      if (
        slug !== undefined &&
        !covenDetails.some((entry) => entry.slug === slug)
      )
        return null;
      return publication.catalogRevisionId;
    },
    async listCoven(input, revisionId) {
      if (
        !publication.catalogAvailable ||
        revisionId !== publication.catalogRevisionId
      )
        throw new ContentCursorStaleError();
      const filtered = covenDetails.filter(
        (entry) =>
          input.category === undefined ||
          entry.qualifications[0]!.category === input.category,
      );
      return page(filtered.map(publicCoven), input, (entry) => entry.slug);
    },
    async getCoven(slug, revisionId) {
      if (
        !publication.catalogAvailable ||
        revisionId !== publication.catalogRevisionId
      )
        return null;
      const detail = covenDetails.find((entry) => entry.slug === slug);
      return detail === undefined ? null : publicCoven(detail);
    },
    async getOrCreateDaily(context, input) {
      const date = input.date ?? "2026-08-20";
      const key = keyFor(context, date, input.mode);
      const existing = assignments.get(key);
      if (existing !== undefined) return structuredClone(existing);
      if (!publication.ritualAvailable) return null;
      const created = ritualFor(
        date,
        input.mode,
        "assigned",
        stableAssignmentId(key),
        publication.ritualRevisionId,
      );
      assignments.set(key, created);
      return structuredClone(created);
    },
    async getAssignment(context, id) {
      const value = [...assignments.entries()].find(
        ([key, assignment]) =>
          key.startsWith(`${context.tenantId}:`) &&
          assignment.assignment_id === id,
      )?.[1];
      return value === undefined ? null : structuredClone(value);
    },
    async getAssignmentEvidence(context, id) {
      const assignment = await this.getAssignment(context, id);
      return assignment === null ? null : structuredClone(evidence);
    },
    async transitionAssignment(context, id, transition, version) {
      const entry = [...assignments.entries()].find(
        ([key, assignment]) =>
          key.startsWith(`${context.tenantId}:`) &&
          assignment.assignment_id === id,
      );
      if (entry === undefined) return null;
      if (
        transition === "reveal" &&
        ["revealed", "completed"].includes(entry[1].state)
      )
        return structuredClone(entry[1]);
      if (transition === "complete" && entry[1].state === "completed")
        return structuredClone(entry[1]);
      if (version !== entry[1].version) throw new ContentVersionConflictError();
      if (transition === "complete" && entry[1].state === "assigned")
        throw new ContentInvalidStateError();
      entry[1].state = transition === "reveal" ? "revealed" : "completed";
      entry[1].version += 1;
      entry[1].revealed_at ??= "2026-08-20T14:00:00.000Z";
      entry[1].completed_at =
        transition === "complete" ? "2026-08-20T14:05:00.000Z" : null;
      return structuredClone(entry[1]);
    },
    async listHistory(context, input) {
      const values = [...assignments.entries()]
        .filter(
          ([key, item]) =>
            key.startsWith(`${context.tenantId}:`) &&
            (input.mode === undefined || item.mode === input.mode) &&
            (input.from === undefined || item.date >= input.from) &&
            (input.to === undefined || item.date <= input.to),
        )
        .map(([, item]) => item)
        .sort((left, right) => right.date.localeCompare(left.date));
      return page(
        values,
        input,
        (item) => `${item.date}|${item.assignment_id}`,
      );
    },
    async resolveRowan(_context, input) {
      const expectedContext = {
        daily_ritual: "daily",
        evidence: "evidence",
        asset_codex: "asset",
        coven: "coven",
      } as const;
      if (expectedContext[input.surface] !== input.contextCode) return null;
      if (input.resourceId !== undefined) {
        const active =
          input.surface === "daily_ritual" || input.surface === "evidence"
            ? [...assignments.entries()].some(
                ([key, assignment]) =>
                  key.startsWith(`${_context.tenantId}:`) &&
                  assignment.assignment_id === input.resourceId,
              )
            : input.surface === "asset_codex"
              ? assets.some((asset) => asset.id === input.resourceId)
              : covenDetails.some((entry) => entry.id === input.resourceId);
        if (!active) return null;
      }
      return {
        script_revision_id: fixtureIds.rowanRevision,
        surface: input.surface,
        body: "I'll separate what changed from what merely got louder. The choice remains yours.",
        risk_footer: "Deterministic demo counsel; not investment advice.",
      };
    },
    async listAssets(_context, input) {
      const filtered = assets.filter(
        (asset) =>
          (input.assetType === undefined ||
            asset.asset_type === input.assetType) &&
          (input.symbolPrefix === undefined ||
            asset.symbol.startsWith(input.symbolPrefix.toUpperCase())),
      );
      filtered.sort((left, right) => left.symbol.localeCompare(right.symbol));
      return page(
        filtered.map(stripAsset),
        input,
        (item) => `${item.symbol}|${item.id}`,
      );
    },
    async getAsset(_context, id) {
      const asset = assets.find((item) => item.id === id);
      return asset === undefined
        ? null
        : structuredClone(stripAssetDetail(asset));
    },
    async getAssetEvidence(_context, id) {
      const asset = assets.find((item) => item.id === id);
      if (asset === undefined) return null;
      return evidence.filter(
        (claim) => claim.claim_id === asset.evidence[0]!.claim_id,
      );
    },
    async getAssetMetrics(_context, id, asOf) {
      const asset = assets.find((item) => item.id === id);
      if (asset === undefined) return null;
      const metric = metricFor(asset);
      return asOf === undefined || metric.observed_at <= asOf ? [metric] : [];
    },
    async compareAssets(_context, ids) {
      const selected = ids.map((id) => assets.find((asset) => asset.id === id));
      if (selected.some((asset) => asset === undefined)) return null;
      return {
        assets: selected.map((asset) => ({
          asset: stripAsset(asset!),
          latest_metric: metricFor(asset!),
          risk_count: asset!.risks.length,
        })),
        compared_at: observedAt,
        demo,
      };
    },
    async listMemberCoven(_context, input) {
      const filtered = covenDetails.filter(
        (entry) =>
          (input.category === undefined ||
            entry.qualifications[0]!.category === input.category) &&
          (input.verifiedAsOf === undefined ||
            entry.qualifications[0]!.verified_as_of <= input.verifiedAsOf),
      );
      return page(
        filtered.map(covenSummary),
        input,
        (entry) => `${entry.company}|${entry.id}`,
      );
    },
    async getMemberCoven(_context, id) {
      const detail = covenDetails.find((entry) => entry.id === id);
      return detail === undefined ? null : structuredClone(detail);
    },
    async getMemberCovenEvidence(_context, id) {
      const detail = covenDetails.find((entry) => entry.id === id);
      if (detail === undefined) return null;
      const qualification = detail.qualifications[0]!;
      return qualification.evidence.map((claim) => ({
        ...claim,
        source: {
          title: `Ritual Coven verification — ${detail.company}`,
          publisher: "Ritual Research Fixtures",
          url: `https://research.ritual-investing.test/demo/coven/${detail.slug}`,
          published_at: observedAt,
        },
      }));
    },
    async listMemberDiscover(_context, input) {
      const filtered =
        input.section === undefined
          ? discoverItems
          : discoverItems.filter((item) => item.kind === input.section);
      return page(filtered, input, discoverPosition);
    },
    async listGrimoires(_context, input) {
      const values =
        input.theme === undefined || input.theme === quietPower.theme
          ? [quietPower]
          : [];
      return page(values, input, (item) => `${item.title}|${item.id}`);
    },
    async getGrimoire(_context, id) {
      return id === quietPower.id ? structuredClone(quietPower) : null;
    },
    async listCreators(_context, input) {
      return page(
        [creator],
        input,
        (item) => `${item.display_name}|${item.id}`,
      );
    },
    async listCircleTemplates(_context, input) {
      const values =
        (input.theme === undefined || input.theme === softPower.theme) &&
        (input.creator === undefined || input.creator === creator.slug)
          ? [softPower]
          : [];
      return page(values, input, (item) => `${item.title}|${item.id}`);
    },
    async getCircleTemplate(_context, id) {
      return id === softPower.id ? structuredClone(softPower) : null;
    },
    async search(_context, input) {
      const query = input.query.toLocaleLowerCase("en-US");
      const filtered = discoverItems.filter(
        (item) =>
          input.kinds.includes(item.kind) &&
          JSON.stringify(item).toLocaleLowerCase("en-US").includes(query),
      );
      return page(filtered, input, discoverPosition);
    },
  };
}

function published<T>(value: T, revisionId: string): PublishedResult<T> {
  return { value, revisionId };
}

function publicCoven(entry: CovenDetail): PublicCovenTeaser {
  const qualification = entry.qualifications[0]!;
  return {
    slug: entry.slug,
    company: entry.company,
    category: qualification.category,
    verified_as_of: qualification.verified_as_of,
    teaser: entry.summary,
    demo: entry.demo,
  };
}

function covenSummary(entry: CovenDetail): CovenSummary {
  const qualification = entry.qualifications[0]!;
  return {
    ...publicCoven(entry),
    id: entry.id,
    symbol: entry.symbol,
    focus: entry.focus,
    effective_date: qualification.effective_date,
    revision_id: entry.revision_id,
  };
}

function grimoireSummary(entry: GrimoireDetail): GrimoireSummary {
  const { assets: _assets, saved: _saved, ...summary } = entry;
  return summary;
}

function circleTemplateSummary(
  entry: CircleTemplateDetail,
): CircleTemplateSummary {
  const { assets: _assets, saved: _saved, ...summary } = entry;
  return summary;
}

function discoverPosition(item: DiscoverItem): string {
  switch (item.kind) {
    case "asset":
      return `asset|${item.asset!.symbol}|${item.asset!.id}`;
    case "coven":
      return `coven|${item.coven!.company}|${item.coven!.id}`;
    case "grimoire":
      return `grimoire|${item.grimoire!.title}|${item.grimoire!.id}`;
    case "circle_template":
      return `circle_template|${item.circle_template!.title}|${item.circle_template!.id}`;
  }
}

function publicDiscoverPosition(item: PublicDiscoverItem): string {
  return `${item.kind}|${item.title}|${item.slug}`;
}
