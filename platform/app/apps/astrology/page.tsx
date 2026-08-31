import type { Metadata } from 'next';
import { AstrologyApp } from '@/components/astrology/AstrologyApp';

export const metadata: Metadata = {
  title: 'Daily Star Map — AXIO7 Astrology',
  description:
    'A private, browser-only symbolic reflection practice. Create a deterministic daily prompt without an account, forecast, or advice.',
};

export default function AstrologyPage() {
  return <AstrologyApp />;
}
