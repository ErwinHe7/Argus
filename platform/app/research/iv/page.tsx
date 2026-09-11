import type { Metadata } from 'next';
import Link from 'next/link';
import { IvLab } from '@/components/iv-lab/IvLab';
import { getIvLabOverview } from '@/lib/iv-lab/server';

export const metadata: Metadata = {
  title: 'Leo IV Lab — Technical, Volatility and Event Research',
  description: 'Explore option scenarios as stock price, implied volatility and time change together. Market snapshots, technical indicators, official event evidence and saved research notes.',
  robots: { index: false, follow: false },
};

export default function IvLabPage() {
  const overview = getIvLabOverview();
  if (!overview) return <main style={{ background: '#0d0912', color: '#f6edf7', minHeight: '100vh', padding: '12vh 8vw', fontFamily: 'sans-serif' }}><h1>IV research data is not ready</h1><p>The research snapshot is missing or failed its integrity checks. The workbench will be available once a valid snapshot is imported.</p><Link href="/discover/market-map">Back to Market Map</Link></main>;
  return <IvLab overview={overview} />;
}
