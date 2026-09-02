import Link from 'next/link';
import Image from 'next/image';
import { ShieldCheck } from 'lucide-react';
import styles from './SiteChrome.module.css';

export function Footer() {
  return (
    <footer className={styles.footer}>
      <div className={styles.footerTop}>
        <div>
          <Link href="/" className={styles.brand} aria-label="Leo home">
            <Image className={styles.brandLion} src="/brand/leo-lion.png" alt="" width={40} height={40} />
            <span>Leo</span>
          </Link>
          <p className={styles.footerCopy}>
            A private English-first practice for Tarot reflection, learning,
            community, and evidence-led market research.
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
              { href: '/app/', label: 'Open Leo' },
              { href: '/pricing', label: 'Plans & payment' },
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
        <span>&copy; 2026 Leo</span>
        <span>Reflection with evidence</span>
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
