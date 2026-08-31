import type { Metadata } from 'next';
import { CosmicHero } from '@/components/home/CosmicHero';

export const metadata: Metadata = {
  title: 'Leo — Reflection with evidence',
  description:
    'Tarot reflection, guided learning, community, and evidence-led market research in one private English-first product.',
  openGraph: {
    title: 'Leo — Reflection with evidence',
    description:
      'A private daily practice for Tarot reflection, learning, community, and evidence-led research.',
  },
  twitter: {
    card: 'summary',
    title: 'Leo — Reflection with evidence',
    description:
      'A private daily practice for Tarot reflection, learning, community, and evidence-led research.',
  },
};

export default function HomePage() {
  return <CosmicHero />;
}
