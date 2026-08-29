import { digest } from "../retained-http/boundary.ts";

export function createPlatformContractService(
  buildDocument: () => unknown,
): Readonly<{
  serializedContract(): Promise<{ body: string; etag: string }>;
}> {
  let contract: Promise<{ body: string; etag: string }> | undefined;
  return Object.freeze({
    serializedContract: () => {
      contract ??= (async () => {
        const body = JSON.stringify(buildDocument());
        return {
          body,
          etag: `"openapi-${(await digest(body)).slice(0, 24)}"`,
        };
      })();
      return contract;
    },
  });
}

export type PlatformContractService = ReturnType<
  typeof createPlatformContractService
>;
