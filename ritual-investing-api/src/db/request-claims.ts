export type VerifiedRequestClaims = Readonly<{
  userId: string;
  sessionId: string;
  aal: "aal1" | "aal2";
}>;
