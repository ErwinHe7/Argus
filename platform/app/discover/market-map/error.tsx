'use client';

export default function MarketMapError({ reset }: { reset: () => void }) {
  return <main style={{ minHeight: '100vh', display: 'grid', placeContent: 'center', gap: 20, padding: 24, background: '#0d0912', color: '#f6ecf7' }}><h1>The page could not open.</h1><button onClick={reset} style={{ padding: 14, background: '#ecb667', color: '#15101d', borderRadius: 6 }}>Reload page</button><a href="/app/#/discover" style={{ color: '#c5b5ce' }}>Return to Discover</a></main>;
}
