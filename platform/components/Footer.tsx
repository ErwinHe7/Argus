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
            One English-first system for evidence-led market research and private
            celestial reflection.
          </p>
          <div className={styles.assurance}>
            <ShieldCheck size={15} />
            Reflection is not a forecast. Research is not investment advice.
          </div>
        </div>

        <div className={styles.footerLinks}>
          <FooterGroup
            title="PRODUCT"
            links={[
              { href: '/#research-workspace', label: 'Research workspace' },
              { href: '/apps/astrology', label: 'Astrology app' },
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
        <span>&copy; 2026 AXIO7 &middot; EVIDENCE AND REFLECTION</span>
        <span>INSPECT THE METHOD &middot; KEEP THE BOUNDARIES</span>
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
