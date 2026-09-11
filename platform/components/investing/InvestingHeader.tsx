import Image from 'next/image';
import Link from 'next/link';
import type { ReactNode } from 'react';
import styles from './InvestingWorkspace.module.css';

export function InvestingWorkspace({ active, children }: { active: 'stocks' | 'brokers'; children: ReactNode }) {
  return <div className={styles.page}>
    <a className={styles.skip} href="#workspace">Skip to workspace</a>
    <header className={styles.header}>
      <Link href="/" className={styles.brand}><Image src="/brand/leo-lion.png" alt="" width={34} height={34} /><span>Leo</span></Link>
      <nav aria-label="Investing navigation">
        <Link href="/discover/stocks" aria-current={active === 'stocks' ? 'page' : undefined}>Stocks</Link>
        <Link href="/discover/market-map">Market Map</Link>
        <Link href="/brokers" aria-current={active === 'brokers' ? 'page' : undefined}>Brokers</Link>
      </nav>
      <Link href="/app/" className={styles.appLink}>Your account</Link>
    </header>
    <main className={styles.main} id="workspace">{children}</main>
    <footer className={styles.footer}><span>Leo · Research & investing</span><span>U.S. securities · Your decisions</span></footer>
  </div>;
}
