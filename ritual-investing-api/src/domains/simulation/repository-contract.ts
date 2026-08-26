import type { MemberContext } from "../accounts/repository.ts";
import type {
  CheckoutSession,
  ContributionInput,
  DemoEntitlement,
  DemoPlan,
  FundingFixtureInput,
  FundingSource,
  FutureMirror,
  FutureMirrorInput,
  Intention,
  IntentionCreateInput,
  IntentionPatchInput,
  OrderCommitInput,
  OrderPreview,
  OrderPreviewInput,
  OrderView,
  PortfolioCreateInput,
  PortfolioPatchInput,
  PortfolioView,
  RebalancePreview,
  RebalancePreviewInput,
  RecurringPlan,
  RecurringPlanCreateInput,
  RecurringPlanPatchInput,
  SimulationResult,
} from "./schemas.ts";

export type SimulationPage<T> = { items: T[]; nextPosition: string | null };

export interface SimulationRepository {
  listPortfolios(
    context: MemberContext,
    limit: number,
    after?: string,
  ): Promise<SimulationPage<PortfolioView>>;
  createPortfolio(
    context: MemberContext,
    input: PortfolioCreateInput,
    key: string,
  ): Promise<PortfolioView>;
  getPortfolio(
    context: MemberContext,
    portfolioId: string,
  ): Promise<PortfolioView | null>;
  patchPortfolio(
    context: MemberContext,
    portfolioId: string,
    input: PortfolioPatchInput,
    version: number,
  ): Promise<PortfolioView | null>;
  archivePortfolio(
    context: MemberContext,
    portfolioId: string,
    version: number,
  ): Promise<boolean>;
  listHoldings(
    context: MemberContext,
    portfolioId: string,
    limit: number,
    after?: string,
  ): Promise<SimulationPage<PortfolioView["positions"][number]>>;
  listActivity(
    context: MemberContext,
    portfolioId: string,
    input: Record<string, unknown>,
  ): Promise<SimulationPage<Record<string, unknown>>>;
  listSnapshots(
    context: MemberContext,
    portfolioId: string,
    input: Record<string, unknown>,
  ): Promise<SimulationPage<Record<string, unknown>>>;
  listFundingSources(context: MemberContext): Promise<FundingSource[]>;
  createFundingSource(
    context: MemberContext,
    input: FundingFixtureInput,
    key: string,
  ): Promise<FundingSource>;
  deleteFundingSource(
    context: MemberContext,
    sourceId: string,
  ): Promise<boolean>;
  contribute(
    context: MemberContext,
    portfolioId: string,
    input: ContributionInput,
    idempotencyKey: string,
  ): Promise<SimulationResult>;
  previewOrder(
    context: MemberContext,
    portfolioId: string,
    input: OrderPreviewInput,
  ): Promise<OrderPreview>;
  commitOrder(
    context: MemberContext,
    portfolioId: string,
    input: OrderCommitInput,
    key: string,
  ): Promise<SimulationResult>;
  listOrders(
    context: MemberContext,
    input: Record<string, unknown>,
  ): Promise<SimulationPage<OrderView>>;
  getOrder(context: MemberContext, orderId: string): Promise<OrderView | null>;
  listRecurringPlans(
    context: MemberContext,
    portfolioId: string,
    input: Record<string, unknown>,
  ): Promise<SimulationPage<RecurringPlan>>;
  createRecurringPlan(
    context: MemberContext,
    portfolioId: string,
    input: RecurringPlanCreateInput,
    key: string,
  ): Promise<RecurringPlan>;
  getRecurringPlan(
    context: MemberContext,
    planId: string,
  ): Promise<RecurringPlan | null>;
  patchRecurringPlan(
    context: MemberContext,
    planId: string,
    input: RecurringPlanPatchInput,
    version: number,
  ): Promise<RecurringPlan | null>;
  transitionRecurringPlan(
    context: MemberContext,
    planId: string,
    transition: "pause" | "resume",
    version: number,
  ): Promise<RecurringPlan | null>;
  cancelRecurringPlan(
    context: MemberContext,
    planId: string,
    version: number,
  ): Promise<boolean>;
  deliverRecurringPlan(
    context: MemberContext,
    planId: string,
    scheduledFor: string,
    resetGeneration: number,
  ): Promise<Record<string, unknown>>;
  previewRebalance(
    context: MemberContext,
    portfolioId: string,
    input: RebalancePreviewInput,
  ): Promise<RebalancePreview>;
  commitRebalance(
    context: MemberContext,
    portfolioId: string,
    input: OrderCommitInput,
    key: string,
  ): Promise<SimulationResult>;
  listIntentions(
    context: MemberContext,
    input: Record<string, unknown>,
  ): Promise<SimulationPage<Intention>>;
  createIntention(
    context: MemberContext,
    input: IntentionCreateInput,
    key: string,
  ): Promise<Intention>;
  getIntention(
    context: MemberContext,
    intentionId: string,
  ): Promise<Intention | null>;
  patchIntention(
    context: MemberContext,
    intentionId: string,
    input: IntentionPatchInput,
    version: number,
  ): Promise<Intention | null>;
  archiveIntention(
    context: MemberContext,
    intentionId: string,
    version: number,
  ): Promise<boolean>;
  buildFutureMirror(
    context: MemberContext,
    intentionId: string,
    input: FutureMirrorInput,
    key: string,
  ): Promise<FutureMirror>;
  getLatestFutureMirror(
    context: MemberContext,
    intentionId: string,
  ): Promise<FutureMirror | null>;
  getFutureMirror(
    context: MemberContext,
    intentionId: string,
    runId: string,
  ): Promise<FutureMirror | null>;
  listDemoPlans(context: MemberContext): Promise<DemoPlan[]>;
  getEntitlement(context: MemberContext): Promise<DemoEntitlement>;
  createCheckout(
    context: MemberContext,
    planCode: "premium_demo",
    key: string,
  ): Promise<CheckoutSession>;
  getCheckout(
    context: MemberContext,
    sessionId: string,
  ): Promise<CheckoutSession | null>;
  confirmCheckout(
    context: MemberContext,
    sessionId: string,
    version: number,
    key: string,
  ): Promise<DemoEntitlement>;
  restoreEntitlement(
    context: MemberContext,
    key: string,
  ): Promise<DemoEntitlement>;
  downgradeEntitlement(
    context: MemberContext,
    version: number,
    key: string,
  ): Promise<DemoEntitlement>;
  resetDemo(
    context: MemberContext,
    seedVersion: number,
    key: string,
  ): Promise<Record<string, unknown>>;
}

export class SimulationConflictError extends Error {
  readonly code: string;

  constructor(code: string) {
    super(code);
    this.code = code;
  }
}

export class SimulationNotFoundError extends Error {
  constructor() {
    super("not_found");
  }
}

export class SimulationInputError extends Error {
  readonly code: string;

  constructor(code: string) {
    super(code);
    this.code = code;
  }
}

export class SimulationInProgressError extends Error {
  constructor() {
    super("command_in_progress");
  }
}
