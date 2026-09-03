import type { Metadata } from 'next';
import { Fraunces, Instrument_Serif, Inter } from 'next/font/google';
import './globals.css';
import { AppShell } from '@/components/AppShell';
import { BgMesh } from '@/components/BgMesh';
import { Footer } from '@/components/Footer';
import { GoogleAnalytics } from '@/components/GoogleAnalytics';
import { Nav } from '@/components/Nav';
import { PostHogProvider } from '@/components/PostHogProvider';
import { PostHogSession } from '@/components/PostHogSession';

const fraunces = Fraunces({
  subsets: ['latin'],
  variable: '--font-fraunces',
  display: 'swap',
});

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
});

const instrumentSerif = Instrument_Serif({
  subsets: ['latin'],
  weight: ['400'],
  style: ['normal', 'italic'],
  variable: '--font-instrument-serif',
  display: 'swap',
});

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://leo.axio7.workers.dev';

export const metadata: Metadata = {
  title: 'Leo — Reflection with evidence',
  description:
    'A private daily practice for Tarot reflection, learning, community, and evidence-led market research.',
  metadataBase: new URL(siteUrl),
  openGraph: {
    title: 'Leo — Reflection with evidence',
    description:
      'Tarot reflection and evidence-led market research in one English-first product.',
    siteName: 'Leo',
    url: siteUrl,
    type: 'website',
  },
  twitter: {
    card: 'summary',
    title: 'Leo — Reflection with evidence',
    description:
      'Tarot reflection and evidence-led market research in one English-first product.',
  },
  icons: {
    icon: '/brand/leo-lion.png',
    apple: '/brand/leo-lion.png',
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${fraunces.variable} ${inter.variable} ${instrumentSerif.variable}`}>
      <body className="min-h-screen">
        <PostHogProvider>
          <PostHogSession />
          <GoogleAnalytics />
          <AppShell bg={<BgMesh />} nav={<Nav />} footer={<Footer />}>
            {children}
          </AppShell>
        </PostHogProvider>
      </body>
    </html>
  );
}
