import Link from 'next/link';
import Image from 'next/image';
import { CreditCard, MoonStar } from 'lucide-react';
import styles from './SiteChrome.module.css';

export async function Nav() {
  return (
    <header className={styles.nav}>
      <Link href="/" className={styles.brand} aria-label="Leo home">
        <Image className={styles.brandLion} src="/brand/leo-lion.png" alt="" width={40} height={40} />
        <span>Leo</span>
      </Link>

      <nav className={styles.links} aria-label="Primary navigation">
        <Link href="/pricing" className={styles.link}>
          <CreditCard size={15} aria-hidden="true" />
          <span>Plans</span>
        </Link>
        <Link href="/app/" className={`${styles.link} ${styles.astrologyLink}`}>
          <MoonStar size={15} aria-hidden="true" />
          <span>App</span>
        </Link>
      </nav>
    </header>
  );
}
