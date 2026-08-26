import {
  InactiveBootstrapPrincipalError,
  type SessionRepository,
} from "./repository.ts";
import type { SessionBootstrapData } from "./schemas.ts";

export class SessionAccessDeniedError extends Error {
  constructor() {
    super("session_access_denied");
    this.name = "SessionAccessDeniedError";
  }
}

export async function bootstrapSession(
  repository: SessionRepository,
  verifiedSubject: string,
): Promise<SessionBootstrapData> {
  try {
    return await repository.bootstrap(verifiedSubject);
  } catch (error) {
    if (error instanceof InactiveBootstrapPrincipalError) {
      throw new SessionAccessDeniedError();
    }
    throw error;
  }
}
