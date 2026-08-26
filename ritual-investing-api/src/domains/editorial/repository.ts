import type { ResolvedAccountContext } from "../../db/client.ts";
import type {
  AssetCodexDetail,
  AssetComparison,
  AssetMetric,
  AssetSummary,
  CircleTemplateDetail,
  CircleTemplateSummary,
  CovenDetail,
  CovenSummary,
  DailyRitualDetail,
  DailyRitualPreview,
  DiscoverItem,
  EvidenceDetail,
  GrimoireDetail,
  GrimoireSummary,
  PublicCovenTeaser,
  PublicDiscoverItem,
  RowanCounsel,
  SeededCreator,
} from "./schemas.ts";

export type MemberRequestContext = ResolvedAccountContext & {
  subject: string;
};

export type PageRequest = {
  limit: number;
  after?: string;
};

export type PageResult<T> = {
  items: T[];
  nextPosition: string | null;
};

export type PublishedResult<T> = {
  value: T;
  revisionId: string;
};

export type PublicContentRepository = {
  resolveDailyRevision(input: { date: string; mode: "tarot" | "astrology" }): Promise<string | null>;
  loadDaily(input: { date: string; mode: "tarot" | "astrology" }, revisionId: string): Promise<DailyRitualPreview | null>;
  resolveDiscoverRevision(): Promise<string>;
  listDiscover(input: PageRequest, revisionId: string): Promise<PageResult<PublicDiscoverItem>>;
  resolveCovenRevision(slug?: string): Promise<string | null>;
  listCoven(input: PageRequest & { category?: "founder" | "owner" | "chief_executive" }, revisionId: string): Promise<PageResult<PublicCovenTeaser>>;
  getCoven(slug: string, revisionId: string): Promise<PublicCovenTeaser | null>;
};

export type RitualRepository = {
  getOrCreateDaily(context: MemberRequestContext, input: { date?: string; mode: "tarot" | "astrology" }): Promise<DailyRitualDetail | null>;
  getAssignment(context: MemberRequestContext, assignmentId: string): Promise<DailyRitualDetail | null>;
  getAssignmentEvidence(context: MemberRequestContext, assignmentId: string): Promise<EvidenceDetail[] | null>;
  transitionAssignment(context: MemberRequestContext, assignmentId: string, transition: "reveal" | "complete", version: number): Promise<DailyRitualDetail | null>;
  listHistory(context: MemberRequestContext, input: PageRequest & { mode?: "tarot" | "astrology"; from?: string; to?: string }): Promise<PageResult<DailyRitualDetail>>;
  resolveRowan(context: MemberRequestContext, input: { surface: "daily_ritual" | "evidence" | "asset_codex" | "coven"; contextCode: string; resourceId?: string }): Promise<RowanCounsel | null>;
};

export type AssetRepository = {
  listAssets(context: MemberRequestContext, input: PageRequest & { assetType?: "equity" | "etf" | "index" | "cash"; symbolPrefix?: string }): Promise<PageResult<AssetSummary>>;
  getAsset(context: MemberRequestContext, assetId: string): Promise<AssetCodexDetail | null>;
  getAssetEvidence(context: MemberRequestContext, assetId: string): Promise<EvidenceDetail[] | null>;
  getAssetMetrics(context: MemberRequestContext, assetId: string, asOf?: string): Promise<AssetMetric[] | null>;
  compareAssets(context: MemberRequestContext, assetIds: string[]): Promise<AssetComparison | null>;
};

export type CovenRepository = {
  listMemberCoven(context: MemberRequestContext, input: PageRequest & { category?: "founder" | "owner" | "chief_executive"; verifiedAsOf?: string }): Promise<PageResult<CovenSummary>>;
  getMemberCoven(context: MemberRequestContext, entryId: string): Promise<CovenDetail | null>;
  getMemberCovenEvidence(context: MemberRequestContext, entryId: string): Promise<EvidenceDetail[] | null>;
};

export type DiscoverRepository = {
  listMemberDiscover(context: MemberRequestContext, input: PageRequest & { section?: "asset" | "coven" | "grimoire" | "circle_template" }): Promise<PageResult<DiscoverItem>>;
  listGrimoires(context: MemberRequestContext, input: PageRequest & { theme?: string }): Promise<PageResult<GrimoireSummary>>;
  getGrimoire(context: MemberRequestContext, id: string): Promise<GrimoireDetail | null>;
  listCreators(context: MemberRequestContext, input: PageRequest): Promise<PageResult<SeededCreator>>;
  listCircleTemplates(context: MemberRequestContext, input: PageRequest & { theme?: string; creator?: string }): Promise<PageResult<CircleTemplateSummary>>;
  getCircleTemplate(context: MemberRequestContext, id: string): Promise<CircleTemplateDetail | null>;
  search(context: MemberRequestContext, input: PageRequest & { query: string; kinds: Array<"asset" | "coven" | "grimoire" | "circle_template"> }): Promise<PageResult<DiscoverItem>>;
};

export type MemberContentRepository = RitualRepository
  & AssetRepository
  & CovenRepository
  & DiscoverRepository;

export type ContentRepository = PublicContentRepository & MemberContentRepository;

export class ContentVersionConflictError extends Error {
  constructor() {
    super("content_version_conflict");
    this.name = "ContentVersionConflictError";
  }
}

export class ContentCursorStaleError extends Error {
  constructor() {
    super("content_cursor_stale");
    this.name = "ContentCursorStaleError";
  }
}

export class ContentInvalidStateError extends Error {
  constructor() {
    super("content_invalid_state");
    this.name = "ContentInvalidStateError";
  }
}
