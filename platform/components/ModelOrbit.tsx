'use client';

import { AGENTS } from '@/lib/agents';

export function ModelOrbit() {
  const radius = 110;
  const size = 280;

  return (
    <div className="flex justify-center py-8">
      <div style={{ position: 'relative', width: size, height: size }}>
        {/* Orbit ring */}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            borderRadius: '50%',
            border: '1px solid var(--glass-border)',
            animation: 'orbit-spin 30s linear infinite',
          }}
        />
        {/* Center A7 */}
        <div
          style={{
            position: 'absolute',
            top: '50%',
            left: '50%',
            transform: 'translate(-50%, -50%)',
            fontSize: '1.4rem',
            fontWeight: 900,
            fontFamily: 'var(--font-fraunces)',
            fontStyle: 'italic',
            color: 'var(--molt-sand)',
            animation: 'float 4s ease-in-out infinite',
            zIndex: 10,
          }}
        >
          A7
        </div>
        {/* Agent badges around the orbit */}
        {AGENTS.map((agent, i) => {
          const angle = (i / AGENTS.length) * 2 * Math.PI - Math.PI / 2;
          const x = Math.cos(angle) * radius + size / 2;
          const y = Math.sin(angle) * radius + size / 2;
          return (
            <div
              key={agent.id}
              title={agent.name}
              style={{
                position: 'absolute',
                left: x - 20,
                top: y - 20,
                width: 40,
                height: 40,
                borderRadius: '50%',
                overflow: 'hidden',
                border: '2px solid var(--glass-border)',
                boxShadow: '0 0 8px var(--glow-ocean)',
                animation: 'orbit-counter 30s linear infinite',
              }}
            >
              <img src={agent.avatar} alt={agent.name} style={{ width: '100%', height: '100%' }} />
            </div>
          );
        })}
      </div>
      <style>{`
        @keyframes orbit-spin { to { transform: rotate(360deg); } }
        @keyframes orbit-counter { to { transform: rotate(-360deg); } }
        @media (prefers-reduced-motion: reduce) {
          [style*="orbit-spin"], [style*="orbit-counter"] { animation: none !important; }
        }
      `}</style>
    </div>
  );
}
