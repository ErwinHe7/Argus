import type {
  BrokerageAccountContext,
  BrokerageAccountSummary,
  BrokerageProjectionResource,
  ProviderProjection,
  StoredProjection,
} from "./types.ts";

export interface BrokerageProjectionRepository {
  listAccounts(): Promise<readonly BrokerageAccountSummary[]>;
  account(accountId: string): Promise<BrokerageAccountContext>;
  latest(
    accountId: string,
    resource: BrokerageProjectionResource,
  ): Promise<StoredProjection | null>;
  acquireRefreshLease(
    input: Readonly<{
      context: BrokerageAccountContext;
      resource: BrokerageProjectionResource;
      leaseToken: string;
      leasedUntil: Date;
    }>,
  ): Promise<boolean>;
  appendGeneration(
    input: Readonly<{
      context: BrokerageAccountContext;
      resource: BrokerageProjectionResource;
      leaseToken: string;
      projection: ProviderProjection;
      purgeAfter: Date;
    }>,
  ): Promise<StoredProjection>;
  releaseRefreshLease(
    input: Readonly<{
      accountId: string;
      resource: BrokerageProjectionResource;
      leaseToken: string;
    }>,
  ): Promise<void>;
  invalidateAccount(accountId: string): Promise<void>;
  requireReauthorization(connectionId: string): Promise<void>;
}

export type WithBrokerageProjectionRepository = <T>(
  callback: (repository: BrokerageProjectionRepository) => Promise<T>,
) => Promise<T>;
