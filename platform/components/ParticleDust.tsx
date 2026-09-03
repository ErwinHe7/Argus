'use client';

import { useEffect, useRef } from 'react';

/**
 * Subtle floating gold-dust particle effect for light sub-pages.
 * Pure canvas, no deps. Respects prefers-reduced-motion.
 */
export function ParticleDust() {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const canvas = ref.current!;
    const ctx = canvas.getContext('2d')!;
    if (!canvas.getContext) return;

    let raf: number;
    const PARTICLES = 55;

    type P = { x: number; y: number; r: number; speed: number; drift: number; opacity: number; hue: number };
    let particles: P[] = [];

    function resize() {
      canvas.width = canvas.offsetWidth;
      canvas.height = canvas.offsetHeight;
    }

    function spawn(): P {
      return {
        x: Math.random() * canvas.width,
        y: canvas.height + Math.random() * 40,
        r: Math.random() * 2.5 + 0.5,
        speed: Math.random() * 0.5 + 0.2,
        drift: (Math.random() - 0.5) * 0.4,
        opacity: Math.random() * 0.35 + 0.1,
        hue: Math.random() * 30, // 0–30 → warm gold range
      };
    }

    function init() {
      particles = Array.from({ length: PARTICLES }, () => {
        const p = spawn();
        p.y = Math.random() * canvas.height; // spread on load
        return p;
      });
    }

    function draw() {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      for (const p of particles) {
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
        // warm gold → soft amber
        ctx.fillStyle = `hsla(${30 + p.hue}, 70%, 55%, ${p.opacity})`;
        ctx.fill();

        p.y -= p.speed;
        p.x += p.drift;
        p.opacity -= 0.0008;

        if (p.y < -10 || p.opacity <= 0) {
          Object.assign(p, spawn());
        }
      }
      raf = requestAnimationFrame(draw);
    }

    resize();
    init();
    draw();

    const ro = new ResizeObserver(resize);
    ro.observe(canvas);

    return () => {
      cancelAnimationFrame(raf);
      ro.disconnect();
    };
  }, []);

  return (
    <canvas
      ref={ref}
      aria-hidden
      style={{
        position: 'fixed',
        inset: 0,
        width: '100%',
        height: '100%',
        pointerEvents: 'none',
        zIndex: 0,
        opacity: 0.7,
      }}
    />
  );
}
