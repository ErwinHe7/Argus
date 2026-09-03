'use client';

export function BgMesh() {
  return (
    <div
      aria-hidden
      className="axio-bg-mesh"
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: -10,
        pointerEvents: 'none',
        overflow: 'hidden',
        background:
          'linear-gradient(135deg, #fffaf2 0%, #f7f0e8 42%, #efe2d1 100%)',
      }}
    >
      <div
        style={{
          position: 'absolute',
          inset: '-20%',
          background:
            'linear-gradient(115deg, rgba(255,255,255,0.55) 0%, transparent 28%, rgba(216,71,39,0.06) 52%, transparent 78%), linear-gradient(22deg, transparent 0%, rgba(166,120,70,0.12) 45%, transparent 72%)',
          animation: 'goldSweep 28s ease-in-out infinite',
        }}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background:
            'repeating-linear-gradient(90deg, rgba(92,68,48,0.035) 0 1px, transparent 1px 96px), repeating-linear-gradient(0deg, rgba(92,68,48,0.025) 0 1px, transparent 1px 96px)',
          opacity: 0.75,
        }}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          opacity: 0.55,
          backgroundImage: 'radial-gradient(rgba(23,55,47,0.18) 0.75px, transparent 0.75px)',
          backgroundSize: '42px 42px',
        }}
      />
    </div>
  );
}
