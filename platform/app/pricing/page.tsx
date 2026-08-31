import type { Metadata } from 'next';
import { headers } from 'next/headers';
import Link from 'next/link';
import {
  ArrowUpRight,
  Check,
  CreditCard,
  LockKeyhole,
  ShieldCheck,
} from 'lucide-react';
import { PaddlePricingClient } from './PaddlePricingClient';
import { getCurrentUser } from '@/lib/auth';
import {
  billingAccountHasAccess,
  getBillingAccount,
  providerBillingAccountHasAccess,
} from '@/lib/billing';
import { getLemonSqueezyVariantId } from '@/lib/lemon-squeezy';
import {
  billingCheckoutPath,
  getActiveBillingProvider,
} from '@/lib/payment-provider';
import { getPaddleBrowserConfig } from '@/lib/paddle';
import { getPublicPaddleTiers, PADDLE_TIERS } from '@/lib/paddle-catalog';
import { getPublicBillingPlans, type BillingPlanKey, type PublicBillingPlan } from '@/lib/stripe';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Pricing - AXIO7',
  description:
    'Choose an AXIO7 quantitative market-research membership and pay through secure hosted checkout.',
};

const SHARED_RESEARCH_FEATURES = [
  'Impersonal quantitative research workspace',
  'Deterministic scan and historical-evaluation requests',
  'Source, cutoff, coverage, and caveat disclosure',
  'Reproducibility and model-version receipts',
] as const;

const PLAN_FEATURES = {
  starter: SHARED_RESEARCH_FEATURES,
  pro: SHARED_RESEARCH_FEATURES,
  premium: SHARED_RESEARCH_FEATURES,
  enterprise: SHARED_RESEARCH_FEATURES,
} as const;

const PLAN_DESCRIPTIONS: Record<BillingPlanKey, string> = {
  starter: 'Starter membership for the AXIO7 impersonal quantitative market-research service.',
  pro: 'Pro membership for the same evidence-first quantitative market-research service.',
  premium: 'Premium membership for the same evidence-first quantitative market-research service.',
  enterprise: 'Enterprise membership for the same evidence-first quantitative market-research service.',
};

const ZERO_DECIMAL_CURRENCIES = new Set([
  'bif',
  'clp',
  'djf',
  'gnf',
  'jpy',
  'kmf',
  'krw',
  'mga',
  'pyg',
  'rwf',
  'ugx',
  'vnd',
  'vuv',
  'xaf',
  'xof',
  'xpf',
]);

const LIVE_PRICING_URL = 'https://axio7.com/pricing';

function formatPrice(plan: PublicBillingPlan) {
  if (plan.unitAmount == null || !plan.currency) return null;
  const divisor = ZERO_DECIMAL_CURRENCIES.has(plan.currency.toLowerCase()) ? 1 : 100;
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: plan.currency.toUpperCase(),
    maximumFractionDigits: plan.unitAmount % divisor === 0 ? 0 : 2,
  }).format(plan.unitAmount / divisor);
}

function formatUsdListPrice(unitAmount: number) {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    maximumFractionDigits: 0,
  }).format(unitAmount / 100);
}

function paddleBillingLabel(tier: (typeof PADDLE_TIERS)[number]): string {
  if (tier.billingMode === 'one_time') return 'One-time payment';
  if (tier.key === 'free') return 'Free access';
  return tier.cadence === 'year' ? 'Annual subscription' : 'Monthly subscription';
}

function paddlePriceSuffix(tier: (typeof PADDLE_TIERS)[number]): string {
  if (tier.billingMode === 'one_time') return 'USD · permanent access';
  return tier.cadence === 'year' ? 'USD / year' : 'USD / month';
}

function paddleDiscount(tier: (typeof PADDLE_TIERS)[number]) {
  if (tier.key === 'free') {
    return { badge: '100% FREE · READ-ONLY', original: null };
  }
  if (tier.key === 'pro') {
    return { badge: '54% OFF', original: 'Original price US$149/month' };
  }
  return { badge: '53% OFF', original: 'Original price US$1,499/year' };
}

function PaddlePricingFallback({ authenticated }: { authenticated: boolean }) {
  return (
    <>
      <div
        role="status"
        className="axio-pricing-notice"
      >
        This environment cannot open payments directly. Choose a membership below to continue on
        AXIO7&apos;s live secure checkout page.
      </div>

      <div className="axio-plan-grid">
        {PADDLE_TIERS.map((tier) => {
          const highlighted = tier.key === 'pro';
          const discount = paddleDiscount(tier);
          return (
            <article
              key={tier.key}
              className={`axio-plan-card ${highlighted ? 'axio-plan-card--featured' : ''}`}
            >
              {highlighted ? (
                <span className="axio-plan-popular">
                  Most popular
                </span>
              ) : null}
              <p className="axio-plan-kicker">
                {paddleBillingLabel(tier)}
              </p>
              <h2 className="axio-plan-title">{tier.name}</h2>
              <p className="axio-plan-description">{tier.description}</p>

              <div className="axio-plan-price">
                <span className="axio-pricing-total">
                  {formatUsdListPrice(tier.baseUnitAmount)}
                </span>
                <span className="axio-price-suffix">
                  {paddlePriceSuffix(tier)}
                </span>
              </div>

              <div className="axio-plan-discount">
                <strong>{discount.badge}</strong>
                {discount.original ? <span>{discount.original}</span> : null}
              </div>

              <Link
                href={`${LIVE_PRICING_URL}?plan=${tier.key}`}
                className={`axio-subscribe-action ${
                  highlighted ? 'axio-subscribe-action--featured' : ''
                }`}
              >
                <CreditCard className="h-4 w-4" />
                {authenticated ? 'Subscribe securely' : 'Sign in to subscribe'}
                <ArrowUpRight className="h-4 w-4" />
              </Link>

              <ul className="axio-plan-features">
                {tier.features.map((feature) => (
                  <li key={feature}>
                    <Check />
                    <span>{feature}</span>
                  </li>
                ))}
              </ul>
            </article>
          );
        })}

        <article className="axio-plan-card axio-plan-card--enterprise">
          <p className="axio-plan-kicker">Enterprise</p>
          <h2 className="axio-plan-title">Enterprise</h2>
          <p className="axio-plan-description">
            Multi-seat research access, procurement support, and an enterprise
            agreement sized to your organization.
          </p>
          <div className="axio-plan-price">
            <span className="axio-pricing-total">Custom</span>
            <span className="axio-price-suffix">volume pricing</span>
          </div>
          <div className="axio-plan-discount">
            <strong>CUSTOM DISCOUNT</strong>
            <span>Written quote based on seats and deployment scope</span>
          </div>
          <Link className="axio-subscribe-action" href="/support">
            <CreditCard className="h-4 w-4" />
            Contact enterprise sales
          </Link>
          <ul className="axio-plan-features">
            <li><Check /><span>Multi-seat team access</span></li>
            <li><Check /><span>Procurement and onboarding support</span></li>
            <li><Check /><span>Volume discount documented in the enterprise quote</span></li>
          </ul>
        </article>
      </div>
    </>
  );
}

function checkoutMessage(state?: string) {
  if (state === 'cancelled') return 'Checkout was cancelled. You have not been charged.';
  if (state === 'invalid-plan') return 'That plan is not available.';
  if (state === 'unavailable') return 'Secure checkout is not available yet. Please try again later.';
  return null;
}

export default async function PricingPage({
  searchParams,
}: {
  searchParams?: { checkout?: string };
}) {
  const user = await getCurrentUser();
  const provider = getActiveBillingProvider();
  const [plans, account] = await Promise.all([
    provider === 'paddle'
      ? Promise.resolve([])
      : getPublicBillingPlans(provider === 'stripe'),
    user.authenticated ? getBillingAccount(user.id).catch(() => null) : Promise.resolve(null),
  ]);
  const hasAccess = billingAccountHasAccess(account);
  const message = checkoutMessage(searchParams?.checkout);
  const checkoutPath = billingCheckoutPath(provider);
  const databaseProvider =
    provider === 'lemonsqueezy'
      ? 'lemon_squeezy'
      : provider === 'paddle'
        ? 'paddle'
        : 'stripe';
  const providerAccount = account?.provider_accounts?.find(
    (entry) =>
      entry.provider === databaseProvider && providerBillingAccountHasAccess(entry)
  );
  let paddlePricing:
    | {
        tiers: ReturnType<typeof getPublicPaddleTiers>;
        clientToken: string;
        environment: 'sandbox' | 'production';
      }
    | null = null;

  if (provider === 'paddle') {
    try {
      const browserConfig = getPaddleBrowserConfig();
      paddlePricing = {
        tiers: getPublicPaddleTiers(),
        clientToken: browserConfig.clientToken,
        environment: browserConfig.environment,
      };
    } catch (error) {
      console.error('[billing] Paddle pricing configuration is unavailable', error);
    }
  }

  const rawCountryCode = provider === 'paddle'
    ? headers().get('x-vercel-ip-country')?.trim().toUpperCase()
    : undefined;
  const countryCode = rawCountryCode && /^[A-Z]{2}$/.test(rawCountryCode)
    ? rawCountryCode
    : undefined;

  return (
    <div className="axio-pricing-shell">
      <div className="education-pricing axio-pricing-wrap">
        <section className="axio-pricing-hero">
          <div className="axio-pricing-hero-content">
            <div className="axio-pricing-kicker">
              AXIO7 MEMBERSHIPS
            </div>
            <h1>Choose your research membership.</h1>
            <p>
              Select the access level that fits your AXIO7 quantitative
              market-research workspace.
            </p>
          </div>
        </section>

        <section className="education-pricing-boundary axio-research-boundary">
          <span className="axio-boundary-icon">
            <ShieldCheck aria-hidden="true" />
          </span>
          <div>
            <strong>Research software, not advice or execution.</strong>
            <p>Every tier follows the same evidence-first boundary. No plan guarantees a dataset, model output, market result, or uninterrupted availability.</p>
          </div>
          <span className="axio-boundary-status">
            <i aria-hidden="true" /> RESEARCH ONLY
          </span>
        </section>

        {message ? (
          <div className="axio-pricing-notice">
            {message}
          </div>
        ) : null}

        {hasAccess ? (
          <div className="axio-pricing-active">
            <span>Your AXIO7 paid access is active.</span>
            <Link href="/billing">
              Manage billing
            </Link>
          </div>
        ) : null}

        <section className="axio-pricing-heading">
          <span>MEMBERSHIP PLANS</span>
          <h2>Simple access. Clear billing.</h2>
          <p>
            All plans use secure Paddle checkout and the same evidence-first research boundary.
          </p>
        </section>

        {provider === 'paddle' ? (
          paddlePricing ? (
            <PaddlePricingClient
              authenticated={user.authenticated}
              clientToken={paddlePricing.clientToken}
              countryCode={countryCode}
              environment={paddlePricing.environment}
              tiers={paddlePricing.tiers}
            />
          ) : (
            <PaddlePricingFallback authenticated={user.authenticated} />
          )
        ) : (
          <div className="axio-plan-grid">
            {plans.map((plan) => {
            const amount = formatPrice(plan);
            const highlighted = plan.key === 'pro';
            const providerPriceId =
              provider === 'lemonsqueezy'
                ? getLemonSqueezyVariantId(plan)
                : plan.priceId;
            const planOwned = hasAccess && Boolean(
              account?.lifetime_access ||
                (providerPriceId && providerAccount?.provider_price_id === providerPriceId)
            );
            return (
              <article
                key={plan.key}
                className={`axio-plan-card ${highlighted ? 'axio-plan-card--featured' : ''}`}
              >
                {highlighted ? (
                  <span className="axio-plan-popular">
                    Most popular
                  </span>
                ) : null}
                <p className="axio-plan-kicker">
                  Monthly subscription
                </p>
                <h2 className="axio-plan-title">{plan.name}</h2>
                <p className="axio-plan-description">{PLAN_DESCRIPTIONS[plan.key]}</p>

                <div className="axio-plan-price">
                  <span className="axio-pricing-total">
                    {amount ?? '—'}
                  </span>
                  {amount ? (
                    <span className="axio-price-suffix">
                      /{plan.recurringInterval ?? 'month'} · {plan.currency?.toUpperCase() ?? 'USD'}
                    </span>
                  ) : null}
                </div>

                <form action={checkoutPath} method="post">
                  <input type="hidden" name="plan" value={plan.key} />
                  <button
                    type="submit"
                    disabled={planOwned}
                    className={`axio-subscribe-action ${
                      highlighted ? 'axio-subscribe-action--featured' : ''
                    }`}
                  >
                    <CreditCard className="h-4 w-4" />
                    {planOwned
                      ? 'This access is active'
                      : user.authenticated
                        ? 'Start research membership'
                        : 'Sign in to join'}
                  </button>
                </form>

                <ul className="axio-plan-features">
                  {PLAN_FEATURES[plan.key].map((feature) => (
                    <li key={feature}>
                      <Check />
                      <span>{feature}</span>
                    </li>
                  ))}
                </ul>
              </article>
            );
            })}
          </div>
        )}

        <section className="axio-pricing-detail-grid">
          <div className="axio-pricing-detail-card">
            <span>DELIVERY // 01</span>
            <h2>Digital delivery</h2>
            <p>Paid access is tied to your AXIO7 account after payment confirmation. No physical goods are shipped.</p>
          </div>
          <div className="axio-pricing-detail-card">
            <span>BILLING // 02</span>
            <h2>Automatic renewal</h2>
            <p>Plans renew at the selected billing frequency until cancelled. Any applicable tax is shown at checkout.</p>
          </div>
          <div className="axio-pricing-detail-card">
            <span>CONTROL // 03</span>
            <h2>Cancellation</h2>
            <p>
              Recurring plans can be canceled in <Link href="/billing" className="underline">Billing</Link> to stop the next renewal.
            </p>
          </div>
        </section>

        <section className="axio-pricing-detail-grid axio-pricing-detail-grid--trust">
          {[
            [LockKeyhole, 'Secure hosted checkout', 'AXIO7 never receives or stores your full card number.'],
            [ShieldCheck, 'Verified payment events', 'Access changes only after a verified payment-provider event.'],
            [CreditCard, 'Self-service billing', 'Update cards, view invoices, or cancel in the portal.'],
          ].map(([Icon, title, copy]) => {
            const ItemIcon = Icon as typeof LockKeyhole;
            return (
              <div key={String(title)} className="axio-pricing-detail-card axio-trust-card">
                <ItemIcon />
                <h3>{String(title)}</h3>
                <p>{String(copy)}</p>
              </div>
            );
          })}
        </section>

        <p className="axio-pricing-footnote">
          Available payment methods vary by payment provider, device, country, and currency.
        </p>

        <nav aria-label="Purchase policies" className="axio-pricing-policies">
          <Link href="/terms">Terms of Service</Link>
          <Link href="/privacy">Privacy Policy</Link>
          <Link href="/refund-policy">Refund Policy</Link>
          <Link href="/support">Support & Contact</Link>
        </nav>
      </div>
    </div>
  );
}
