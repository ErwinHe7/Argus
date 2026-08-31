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

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://axio7.com';

export const metadata: Metadata = {
  title: 'AXIO7 — Evidence and reflection',
  description:
    'Navigate uncertainty with evidence-first market research and a private celestial reflection practice.',
  metadataBase: new URL(siteUrl),
  openGraph: {
    title: 'AXIO7 — Evidence and reflection',
    description:
      'Evidence-first market research and private celestial reflection in one English-first product.',
    siteName: 'AXIO7',
    url: siteUrl,
    type: 'website',
    images: [
      {
        url: '/og.png',
        width: 1745,
        height: 873,
        alt: 'AXIO7 — Evidence and reflection',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'AXIO7 — Evidence and reflection',
    description:
      'Evidence-first market research and private celestial reflection in one English-first product.',
    images: ['/og.png'],
  },
  icons: {
    icon: '/logo.png',
    apple: '/logo.png',
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
