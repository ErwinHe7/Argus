import { createWebullCallbackRepository } from "../../../ritual-investing-api/src/domains/brokerage-connections/repository.ts";
import { withDatabaseTransaction } from "../../../ritual-investing-api/src/db/database-port.ts";
import { withCallbackRequestTransaction } from "../../../ritual-investing-api/src/db/request-transaction.ts";
import { createSupabaseDatabasePool } from "../_shared/database.ts";
import { withBuildRevisionHeader } from "../_shared/build-revision.ts";
import { requiredEnvironment } from "../_shared/environment.ts";
import { createBlockedWebullProvider } from "../_shared/webull/client.ts";
import {
  parsePartnerConfirmedContractFromEnvironment,
  WebullProtocolGateError,
} from "../_shared/webull/contract.ts";
import {
  parseWebullMasterKeyRing,
  WebullTokenVault,
} from "../_shared/webull/tokens.ts";
import { createWebullCallbackHandler } from "./handler.ts";

const configuredContract = parsePartnerConfirmedContractFromEnvironment(
  (name) => Deno.env.get(name),
);
if ("confirmationReference" in configuredContract) {
  // A versioned, partner-confirmed account response parser must be added with
  // its sanitized fixture before this branch can construct a live client.
  throw new WebullProtocolGateError("partner_account_fixture_missing");
}
const provider = createBlockedWebullProvider(configuredContract);
const databasePool = createSupabaseDatabasePool(
  requiredEnvironment("EDGE_RUNTIME_DATABASE_URL"),
);
const tokenVault = new WebullTokenVault(
  configuredContract.environment,
  parseWebullMasterKeyRing(requiredEnvironment("WEBULL_TOKEN_KEY_RING")),
);

const handler = createWebullCallbackHandler({
  withRepository: (claims, callback) =>
    claims === null
      ? withDatabaseTransaction(
        databasePool,
        "argus_callback",
        (database) => callback(createWebullCallbackRepository(database)),
      )
      : withCallbackRequestTransaction(
        { pool: databasePool, verifiedClaims: claims },
        (database) => callback(createWebullCallbackRepository(database)),
      ),
  provider,
  providerEnvironment: configuredContract.environment,
  tokenVault,
  accountIdPepper: requiredEnvironment("WEBULL_ACCOUNT_ID_PEPPER"),
});

Deno.serve(withBuildRevisionHeader(handler));
