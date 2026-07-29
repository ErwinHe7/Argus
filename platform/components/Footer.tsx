import Link from 'next/link';
import { ShieldCheck } from 'lucide-react';
import styles from './SiteChrome.module.css';

export function Footer() {
  return (
    <footer className={styles.footer}>
      <div className={styles.footerTop}>
        <div>
          <Link href="/" className={styles.brand} aria-label="AXIO7 home">
            <span className={styles.brandMark}>A7</span>
            <span>AXIO7</span>
          </Link>
          <p className={styles.footerCopy}>
            Evidence-first market research for inspecting deterministic conditions,
            source coverage, model limits, and reproducible results.
          </p>
          <div className={styles.assurance}>
            <ShieldCheck size={15} />
            No investment advice or trade recommendations
          </div>
        </div>

        <div className={styles.footerLinks}>
          <FooterGroup
            title="PRODUCT"
            links={[
              { href: '/', label: 'Research workspace' },
              { href: '/pricing', label: 'Plans' },
              { href: '/billing', label: 'Membership' },
              { href: '/auth/signin?next=%2F', label: 'Sign in' },
            ]}
          />
          <FooterGroup
            title="LEGAL & SUPPORT"
            links={[
              { href: '/terms', label: 'Terms of Service' },
              { href: '/privacy', label: 'Privacy Policy' },
              { href: '/refund-policy', label: 'Refund Policy' },
              { href: '/support', label: 'Support & contact' },
            ]}
          />
        </div>
      </div>

      <div className={styles.footerBottom}>
        <span>&copy; 2026 AXIO7 &middot; IMPERSONAL MARKET RESEARCH</span>
        <span>INSPECT THE METHOD &middot; REVIEW THE EVIDENCE</span>
      </div>
    </footer>
  );
}

function FooterGroup({
  title,
  links,
}: {
  title: string;
  links: Array<{ href: string; label: string }>;
}) {
  return (
    <div className={styles.footerGroup}>
      <p>{title}</p>
      {links.map((link) => (
        <Link key={`${link.href}-${link.label}`} href={link.href}>
          {link.label}
        </Link>
      ))}
    </div>
  );
}
