import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'AXIO7 — Learning & Review Lab',
  description: 'Educational software for guided lessons, public-source reading, historical timelines, and retrospective review.',
};

export default function MarketingLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <link rel="preconnect" href="https://fonts.googleapis.com" />
      <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
      <link
        href="https://fonts.googleapis.com/css2?family=Geist+Mono:wght@300;400;500;600;700&family=Geist:wght@300;400;500;600;700;800;900&family=Instrument+Serif:ital@0;1&display=swap"
        rel="stylesheet"
      />
      {children}
    </>
  );
}
