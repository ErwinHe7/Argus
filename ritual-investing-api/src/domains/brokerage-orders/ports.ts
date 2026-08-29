import type {
  BrokerageOrderAuthority,
  BrokerageOrderCommand,
  BrokerageOrderDetail,
  BrokerageOrderList,
  BrokerageOrderOperation,
  BrokerageOrderPreview,
  BrokerageOrderReconciliation,
  NormalizedOrderIntent,
  OwnedOrderTarget,
  PreparedOrderCommand,
  ProviderCommandResult,
  ProviderDetailResult,
  ProviderOrderListProjection,
  ProviderOrderPreview,
  SealedProviderReference,
} from "./types.ts";

export interface BrokerageOrderRepository {
  authority(accountId: string): Promise<BrokerageOrderAuthority>;
  assertInstrumentOwned(accountId: string, instrumentId: string): Promise<void>;
  targetOrder(accountId: string, orderId: string): Promise<OwnedOrderTarget>;
  savePreview(
    input: Readonly<{
      authority: BrokerageOrderAuthority;
      id: string;
      operation: BrokerageOrderOperation;
      targetOrderId: string | null;
      normalizedPayload: NormalizedOrderIntent;
      normalizedPayloadHash: string;
      provider: ProviderOrderPreview;
      policyVersion: string;
    }>,
  ): Promise<BrokerageOrderPreview>;
  prepareCommand(
    input: Readonly<{
      authority: BrokerageOrderAuthority;
      previewId: string;
      commandId: string;
      operation: BrokerageOrderOperation;
      targetOrderId: string | null;
      idempotencyKey: string;
      clientOrderId: string;
      normalizedPayload: NormalizedOrderIntent;
      normalizedPayloadHash: string;
      policyVersion: string;
      now: Date;
    }>,
  ): Promise<PreparedOrderCommand>;
  command(commandId: string): Promise<BrokerageOrderCommand>;
  staffReconciliation(commandId: string): Promise<BrokerageOrderReconciliation>;
  recordAccepted(
    prepared: PreparedOrderCommand,
    result: Extract<ProviderCommandResult, { kind: "acknowledged" }>,
  ): Promise<BrokerageOrderCommand>;
  recordRejected(
    prepared: PreparedOrderCommand,
    providerCode: string,
  ): Promise<BrokerageOrderCommand>;
  recordAmbiguous(
    prepared: PreparedOrderCommand,
    reasonCode: string,
  ): Promise<BrokerageOrderCommand>;
  recordBeforeEgressFailure(
    prepared: PreparedOrderCommand,
    reasonCode: string,
  ): Promise<BrokerageOrderCommand>;
  claimReconciliation(commandId: string): Promise<PreparedOrderCommand | null>;
  recordReconciliationNotFound(
    prepared: PreparedOrderCommand,
  ): Promise<BrokerageOrderCommand>;
  recordReconciliationAmbiguous(
    prepared: PreparedOrderCommand,
    reasonCode: string,
  ): Promise<BrokerageOrderCommand>;
  recordReconciled(
    prepared: PreparedOrderCommand,
    resolution: Extract<
      ProviderDetailResult,
      { kind: "resolved" }
    >["resolution"],
    orderReference: SealedProviderReference,
    order: BrokerageOrderDetail,
  ): Promise<BrokerageOrderCommand>;
  listOrders(accountId: string): Promise<BrokerageOrderList>;
  saveOrderList(
    authority: BrokerageOrderAuthority,
    projection: ProviderOrderListProjection,
  ): Promise<BrokerageOrderList>;
  order(accountId: string, orderId: string): Promise<BrokerageOrderDetail>;
}

export type WithBrokerageOrderRepository = <T>(
  callback: (repository: BrokerageOrderRepository) => Promise<T>,
) => Promise<T>;
