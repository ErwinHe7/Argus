import Link from 'next/link';
import {
  ArrowDown,
  ArrowRight,
  Check,
  FileClock,
  GitCompareArrows,
  ScanSearch,
  ShieldCheck,
} from 'lucide-react';
import { AxioMethodDemo } from './AxioMethodDemo';
import styles from './AxioLanding.module.css';

export type LandingPlan = {
  name: string;
  price: string;
  interval: string;
  description: string;
  features: string[];
};

const capabilities = [
  {
    number: '01',
    icon: ScanSearch,
    title: 'Keep the original record',
    body: 'Public documents, dates, and source notes stay attached to the lesson instead of disappearing behind an answer.',
  },
  {
    number: '02',
    icon: FileClock,
    title: 'See when the story changed',
    body: 'AXIO7 rebuilds the sequence so you can tell what was known then from what only became clear later.',
  },
  {
    number: '03',
    icon: GitCompareArrows,
    title: 'Compare before you conclude',
    body: 'Original wording, later context, and remaining uncertainty are reviewed side by side.',
  },
];

export function AxioLanding({ plans }: { plans: LandingPlan[] }) {
  return (
    <main className={styles.page}>
      <section className={styles.hero} aria-labelledby="hero-title">
        <div className={styles.heroGrid}>
          <div className={styles.heroCopy}>
            <div className={styles.kicker}>
              <span>EDUCATIONAL SOFTWARE</span>
              <i />
              <span>SOURCE-FIRST REVIEW</span>
            </div>
            <h1 id="hero-title">
              Follow the evidence.
              <span>Don’t lose the trail.</span>
            </h1>
            <p className={styles.lede}>
              AXIO7 teaches you to move from public record to careful conclusion.
              Every date, change, comparison, and limit stays visible while you work.
            </p>
            <div className={styles.heroActions}>
              <a href="#live-method" className={styles.primaryButton}>
                Watch the method <ArrowDown size={16} />
              </a>
              <a href="#pricing" className={styles.textButton}>
                View memberships <ArrowRight size={16} />
              </a>
            </div>
            <div className={styles.heroAssurances}>
              <span><Check size={14} /> Public-source literacy</span>
              <span><Check size={14} /> Historical context</span>
              <span><Check size={14} /> No investment advice</span>
            </div>
          </div>

          <div className={styles.heroDemo} id="live-method">
            <AxioMethodDemo />
          </div>
        </div>

        <div className={styles.heroIndex}>
          <span>AXIO7 / 2026</span>
          <div><i /> SOURCES <i /> TIMELINE <i /> COMPARE <i /> REVIEW</div>
          <span>SCROLL TO EXPLORE ↓</span>
        </div>
      </section>

      <section className={styles.explanation} id="overview" aria-labelledby="overview-title">
        <div className={styles.explanationIntro}>
          <span className={styles.sectionNumber}>01 / WHAT IT DOES</span>
          <h2 id="overview-title">
            Not another answer box.
            <span>AXIO7 shows the work.</span>
          </h2>
          <p>
            The point is not to hand you a conclusion. It is to make the path to that
            conclusion inspectable, repeatable, and easier to question.
          </p>
        </div>

        <div className={styles.capabilityTable}>
          {capabilities.map(({ number, icon: Icon, title, body }) => (
            <article key={title}>
              <div className={styles.capabilityNumber}>{number}</div>
              <Icon size={22} />
              <h3>{title}</h3>
              <p>{body}</p>
            </article>
          ))}
        </div>

        <div className={styles.processStrip} aria-label="AXIO7 review process">
          <div className={styles.processTrack} aria-hidden="true"><span /></div>
          {['PUBLIC RECORD', 'ORDER BY DATE', 'COMPARE CONTEXT', 'WRITE THE LIMITS'].map(
            (label, index) => (
              <div key={label}>
                <span>{String(index + 1).padStart(2, '0')}</span>
                <strong>{label}</strong>
              </div>
            )
          )}
        </div>
      </section>

      <section className={styles.pricing} id="pricing" aria-labelledby="pricing-title">
        <div className={styles.pricingIntro}>
          <span className={styles.sectionNumber}>02 / MEMBERSHIPS</span>
          <h2 id="pricing-title">Pay for depth, not mystery.</h2>
          <p>
            Choose the learning library that fits your review practice. Your available
            currency and final total are shown before payment.
          </p>
        </div>

        <div className={styles.planTable}>
          {plans.map((plan, index) => {
            const featured = index === 1;
            return (
              <article key={plan.name} className={featured ? styles.featuredPlan : undefined}>
                <div className={styles.planTopline}>
                  <span>{String(index + 1).padStart(2, '0')}</span>
                  {featured ? <strong>RECOMMENDED</strong> : null}
                </div>
                <h3>{plan.name}</h3>
                <div className={styles.priceRow}>
                  <strong>{plan.price}</strong>
                  <span>/{plan.interval}</span>
                </div>
                <p className={styles.planDescription}>{plan.description}</p>
                <ul>
                  {plan.features.slice(0, 4).map((feature) => (
                    <li key={feature}>
                      <Check size={14} /> {feature}
                    </li>
                  ))}
                </ul>
                <Link href="/pricing" className={styles.planAction}>
                  Choose {plan.name}
                  <ArrowRight size={16} />
                </Link>
              </article>
            );
          })}
        </div>

        <div className={styles.paymentLine}>
          <span><ShieldCheck size={14} /> Secure hosted checkout</span>
          <span>Taxes may vary by location</span>
          <Link href="/pricing">Full plan details <ArrowRight size={14} /></Link>
        </div>
      </section>
    </main>
  );
}
