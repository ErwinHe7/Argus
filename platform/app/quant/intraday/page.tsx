import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { ArrowLeft, Database, ShieldCheck } from 'lucide-react';
import { QuantOperatingSystem } from '@/components/quant/QuantOperatingSystem';
import { getCurrentUser, isAdmin } from '@/lib/auth';
import styles from './IntradayPage.module.css';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'AXIO7 · SPX Intraday Research OS',
  description: 'Leakage-safe SPX minute research, historical analogs, purged walk-forward tests, and executable-cost backtesting.',
};

export default async function IntradayResearchPage() {
  const user = await getCurrentUser();
  if (!isAdmin(user)) {
    redirect('/auth/signin?next=%2Fquant%2Fintraday');
  }
  return (
    <div className={`${styles.page} quant-intraday-dark`}>
      <span className={styles.ambientOne} aria-hidden="true" />
      <span className={styles.ambientTwo} aria-hidden="true" />
      <div className={styles.shell}>
        <div className={styles.contextBar}>
          <Link href="/learn" className={styles.backLink}>
            <ArrowLeft className="h-4 w-4" /> 返回研究学习中心
          </Link>
          <div className={styles.evidence}>
            <span className="inline-flex items-center gap-1.5"><Database className="h-3.5 w-3.5" /> Rust · vendor data registry</span>
            <span className="inline-flex items-center gap-1.5"><ShieldCheck className="h-3.5 w-3.5" /> Purged walk-forward</span>
          </div>
        </div>
        <QuantOperatingSystem />
        <footer className={styles.footer}>
          <span className={styles.footerMark}><ShieldCheck className="h-3.5 w-3.5" /></span>
          <p>
            非人格化市场研究系统，不构成投资建议、订单或执行指令。Market Emotion 仅是由价格、成交量与跨资产状态推导的市场反应代理，不是对人类心理的直接观测，也不是概率。Synthetic 结果只验证软件；没有真实历史期权 NBBO 时，系统明确拒绝生成期权收益结论。
          </p>
        </footer>
      </div>
    </div>
  );
}
