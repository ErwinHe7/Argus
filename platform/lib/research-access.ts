import 'server-only';

import { NextResponse } from 'next/server';
import { getCurrentUser, isAdmin, type CurrentUser } from './auth';
import { billingAccountHasAccess, getBillingAccount } from './billing';

type AllowedResearchAccess = {
  allowed: true;
  user: CurrentUser;
};

type DeniedResearchAccess = {
  allowed: false;
  response: NextResponse;
};

export type ResearchAccessDecision =
  | AllowedResearchAccess
  | DeniedResearchAccess;

export async function requirePaidResearchAccess(): Promise<ResearchAccessDecision> {
  const user = await getCurrentUser();
  if (!user.authenticated) {
    return {
      allowed: false,
      response: NextResponse.json(
        {
          error: 'authentication_required',
          message: 'Sign in and choose Pro or Annual to run AXIO7 research.',
          signInUrl: '/auth/signin?next=%2Fpricing',
          pricingUrl: '/pricing',
        },
        { status: 401, headers: { 'Cache-Control': 'no-store' } }
      ),
    };
  }

  if (isAdmin(user)) return { allowed: true, user };

  const account = await getBillingAccount(user.id).catch(() => null);
  if (billingAccountHasAccess(account)) return { allowed: true, user };

  return {
    allowed: false,
    response: NextResponse.json(
      {
        error: 'paid_research_required',
        message:
          'Free access is read-only. Choose Pro or Annual to run research, scans, backtests, or monitors.',
        pricingUrl: '/pricing',
      },
      { status: 402, headers: { 'Cache-Control': 'no-store' } }
    ),
  };
}
