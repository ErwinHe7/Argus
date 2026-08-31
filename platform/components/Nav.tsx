import Link from 'next/link';
import { ArrowRight, CircleUserRound, CreditCard, LogIn, LogOut, Sparkles } from 'lucide-react';
import { getCurrentUser } from '@/lib/auth';
import styles from './SiteChrome.module.css';

export async function Nav() {
  const user = await getCurrentUser();

  return (
    <header className={styles.nav}>
      <Link href="/" className={styles.brand} aria-label="AXIO7 home">
        <span className={styles.brandMark}>A7</span>
        <span>AXIO7</span>
        <span className={styles.brandMeta}>SYSTEM</span>
      </Link>

      <nav className={styles.links} aria-label="Primary navigation">
        <Link href="/#research-workspace" className={`${styles.link} ${styles.researchLink}`}>
          Research
        </Link>
        <Link href="/apps/astrology" className={`${styles.link} ${styles.astrologyLink}`}>
          <Sparkles size={15} aria-hidden="true" />
          <span>Astrology</span>
        </Link>
        <Link
          href="/billing"
          className={`${styles.link} ${styles.membershipLink}`}
          aria-label="Manage membership"
        >
          <CircleUserRound size={15} aria-hidden="true" />
          <span>Membership</span>
        </Link>
        <Link href="/pricing" className={styles.payLink} aria-label="View membership plans">
          <CreditCard size={15} aria-hidden="true" />
          <span>Plans</span>
          <ArrowRight size={14} aria-hidden="true" />
        </Link>
        {user.authenticated ? (
          <form
            action="/auth/signout?next=%2F"
            method="post"
            className={styles.signOutForm}
          >
            <button
              type="submit"
              className={styles.signOutLink}
              aria-label="Sign out"
              title="Sign out"
            >
              <LogOut size={15} aria-hidden="true" />
            </button>
          </form>
        ) : (
          <Link href="/auth/signin?next=%2Fpricing" className={styles.accountLink}>
            <LogIn size={15} aria-hidden="true" />
            <span>Sign in</span>
          </Link>
        )}
      </nav>
    </header>
  );
}
