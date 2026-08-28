import type {
  BrokerageProjectionProvider,
} from "../../../../ritual-investing-api/src/domains/brokerage-projections/service.ts";
import type {
  WebullAccountMappingStore,
} from "../../../../ritual-investing-api/src/domains/brokerage-accounts/repository.ts";
import {
  type BrokerageAccountContext,
  BrokerageProjectionError,
  type BrokerageProjectionResource,
  type ProviderProjection,
} from "../../../../ritual-investing-api/src/domains/brokerage-projections/types.ts";
import { WebullTokenVault } from "./tokens.ts";

export interface GuardedWebullReadTransport {
  read(
    input: Readonly<{
      providerAccountId: string;
      ownerRateLimitScope: string;
      resource: BrokerageProjectionResource;
    }>,
  ): Promise<ProviderProjection>;
}

async function sha256Hex(value: string): Promise<string> {
  const bytes = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
  );
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

/**
 * Resolves a provider account identifier only after exact owner, connection,
 * account, deletion-epoch and environment checks. Decryption necessarily
 * happens before the injected transport can perform any network egress.
 */
export function createResourceBoundWebullReadProvider(
  input: Readonly<{
    environment: "sandbox" | "production";
    vault: WebullTokenVault;
    mappings: WebullAccountMappingStore;
    transport: GuardedWebullReadTransport;
  }>,
): BrokerageProjectionProvider {
  const provider: BrokerageProjectionProvider = {
    read: async ({ context, resource }) => {
      const mapping = await input.mappings.get(context);
      if (
        mapping.accountId !== context.accountId ||
        mapping.connectionId !== context.connectionId ||
        mapping.userId !== context.userId ||
        mapping.deletionEpoch !== context.deletionEpoch ||
        mapping.environment !== input.environment
      ) {
        throw new BrokerageProjectionError("provider_contract_unavailable");
      }
      let providerAccountId: string;
      try {
        providerAccountId = await input.vault.openProviderIdentifier(
          mapping.providerAccountIdCiphertext,
          {
            environment: input.environment,
            userId: context.userId,
            connectionId: context.connectionId,
            deletionEpoch: context.deletionEpoch,
          },
          context.accountId,
          mapping.keyVersion,
        );
      } catch {
        throw new BrokerageProjectionError("provider_contract_unavailable");
      }
      return input.transport.read({
        providerAccountId,
        ownerRateLimitScope: await sha256Hex(context.userId),
        resource,
      });
    },
  };
  return Object.freeze(provider);
}
