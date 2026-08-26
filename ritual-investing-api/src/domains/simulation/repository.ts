import type { DatabasePoolFactory } from "../../db/client.ts";
import { createEntitlementRepository } from "./entitlement-repository.ts";
import { createIntentionRepository } from "./intention-repository.ts";
import { createOrderRepository } from "./order-repository.ts";
import { createPortfolioRepository } from "./portfolio-repository.ts";
import { createRebalanceRepository } from "./rebalance-repository.ts";
import { createRecurringRepository } from "./recurring-repository.ts";
import type { SimulationRepository } from "./repository-contract.ts";

export * from "./repository-contract.ts";
export { sha256 as simulationHashForTesting } from "./repository-shared.ts";

export function createPostgresSimulationRepository(
  url: string,
  poolFactory?: DatabasePoolFactory,
): SimulationRepository {
  const database = { url, poolFactory };
  const portfolio = createPortfolioRepository(database);
  return {
    ...portfolio,
    ...createOrderRepository(database),
    ...createRecurringRepository(database, portfolio.contribute),
    ...createRebalanceRepository(database),
    ...createIntentionRepository(database),
    ...createEntitlementRepository(database),
  };
}
