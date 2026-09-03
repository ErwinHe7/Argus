'use client';

import Image from 'next/image';
import Link from 'next/link';
import { ArrowRight, MoonStar } from 'lucide-react';
import { useEffect, useRef } from 'react';
import styles from './CosmicHero.module.css';

type Star = {
  x: number;
  y: number;
  z: number;
  previousZ: number;
  speed: number;
  color: string;
};

const STAR_COLORS = ['#f6ecf7', '#dd94d4', '#ecb667'] as const;

function resetStar(star: Star, depth: number, width: number, height: number) {
  star.x = (Math.random() - 0.5) * width * 1.8;
  star.y = (Math.random() - 0.5) * height * 1.8;
  star.z = depth;
  star.previousZ = depth;
  star.speed = 0.22 + Math.random() * 0.52;
  star.color = STAR_COLORS[Math.floor(Math.random() * STAR_COLORS.length)]!;
}

export function CosmicHero() {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const context = canvas.getContext('2d', { alpha: true });
    if (!context) return;

    const motionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    let animationFrame = 0;
    let width = 0;
    let height = 0;
    let depth = 1;
    let pointerX = 0.5;
    let pointerY = 0.46;
    let targetX = pointerX;
    let targetY = pointerY;
    let stars: Star[] = [];

    const buildStars = () => {
      const count = width < 720 ? 110 : 220;
      stars = Array.from({ length: count }, () => {
        const star: Star = {
          x: 0,
          y: 0,
          z: 1,
          previousZ: 1,
          speed: 0.3,
          color: STAR_COLORS[0],
        };
        resetStar(star, 40 + Math.random() * depth, width, height);
        return star;
      });
    };

    const resize = () => {
      width = window.innerWidth;
      height = Math.max(window.innerHeight, 640);
      depth = Math.max(width, height) * 0.9;
      const pixelRatio = Math.min(window.devicePixelRatio || 1, 1.5);

      canvas.width = Math.round(width * pixelRatio);
      canvas.height = Math.round(height * pixelRatio);
      canvas.style.width = `${width}px`;
      canvas.style.height = `${height}px`;
      context.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
      buildStars();
    };

    const draw = (time: number, still = false) => {
      context.clearRect(0, 0, width, height);
      pointerX += (targetX - pointerX) * 0.035;
      pointerY += (targetY - pointerY) * 0.035;

      const centerX = width * (0.5 + (pointerX - 0.5) * 0.08);
      const centerY = height * (0.46 + (pointerY - 0.46) * 0.06);
      const perspective = Math.min(width, height) * 0.72;

      context.save();
      context.translate(centerX, centerY);
      context.rotate(time * 0.000018);
      for (let ring = 0; ring < 3; ring += 1) {
        context.beginPath();
        context.ellipse(
          0,
          0,
          Math.min(width * (0.18 + ring * 0.09), 430),
          Math.min(height * (0.065 + ring * 0.03), 105),
          ring * 0.52,
          0,
          Math.PI * 2
        );
        context.strokeStyle = ring === 1 ? 'rgba(236, 182, 103, 0.12)' : 'rgba(221, 148, 212, 0.09)';
        context.lineWidth = 0.8;
        context.stroke();
      }
      context.restore();

      for (const star of stars) {
        if (!still) {
          star.previousZ = star.z;
          star.z -= star.speed;
        }

        if (star.z < 6) {
          resetStar(star, depth, width, height);
        }

        const screenX = (star.x / star.z) * perspective + centerX;
        const screenY = (star.y / star.z) * perspective + centerY;
        const previousX = (star.x / star.previousZ) * perspective + centerX;
        const previousY = (star.y / star.previousZ) * perspective + centerY;

        if (
          screenX < -80 ||
          screenX > width + 80 ||
          screenY < -80 ||
          screenY > height + 80
        ) {
          resetStar(star, depth, width, height);
          continue;
        }

        const proximity = Math.max(0, 1 - star.z / depth);
        context.beginPath();
        context.moveTo(previousX, previousY);
        context.lineTo(screenX, screenY);
        context.strokeStyle = `${star.color}${Math.round((0.14 + proximity * 0.5) * 255)
          .toString(16)
          .padStart(2, '0')}`;
        context.lineWidth = 0.45 + proximity * 1.25;
        context.stroke();

        context.beginPath();
        context.arc(screenX, screenY, 0.45 + proximity * 1.45, 0, Math.PI * 2);
        context.fillStyle = star.color;
        context.fill();
      }

      if (!still) animationFrame = window.requestAnimationFrame(draw);
    };

    const handlePointerMove = (event: PointerEvent) => {
      targetX = event.clientX / Math.max(width, 1);
      targetY = event.clientY / Math.max(height, 1);
    };

    const start = () => {
      window.cancelAnimationFrame(animationFrame);
      if (motionQuery.matches || document.hidden) {
        draw(performance.now(), true);
      } else {
        animationFrame = window.requestAnimationFrame(draw);
      }
    };

    const handleVisibility = () => start();
    const handleMotionChange = () => start();

    resize();
    start();
    window.addEventListener('resize', resize);
    window.addEventListener('pointermove', handlePointerMove, { passive: true });
    document.addEventListener('visibilitychange', handleVisibility);
    motionQuery.addEventListener('change', handleMotionChange);

    return () => {
      window.cancelAnimationFrame(animationFrame);
      window.removeEventListener('resize', resize);
      window.removeEventListener('pointermove', handlePointerMove);
      document.removeEventListener('visibilitychange', handleVisibility);
      motionQuery.removeEventListener('change', handleMotionChange);
    };
  }, []);

  return (
    <section className={styles.hero} aria-labelledby="cosmic-hero-title">
      <a className={styles.skipLink} href="#cosmic-actions">
        Skip to product links
      </a>

      <div className={styles.media} aria-hidden="true">
        <Image
          className={styles.cosmicMap}
          src="/ritual-assets/celestial-path.png"
          alt=""
          fill
          priority
          sizes="100vw"
        />
        <canvas ref={canvasRef} className={styles.canvas} />
        <div className={styles.vignette} />
      </div>

      <header className={styles.navbar}>
        <a className={styles.brand} href="#cosmic-hero-title" aria-label="Leo home">
          <Image
            className={styles.brandIcon}
            src="/brand/leo-lion.png"
            alt=""
            width={44}
            height={44}
            priority
          />
          <span className={styles.brandName}>Leo</span>
        </a>
        <nav className={styles.navLinks} aria-label="Homepage navigation">
          <Link href="/pricing">Plans</Link>
          <Link href="/app/">App</Link>
        </nav>
      </header>

      <div className={styles.content}>
        <p className={styles.kicker}>
          <MoonStar aria-hidden="true" /> A private practice for clearer decisions
        </p>
        <h1 id="cosmic-hero-title">
          Read the world.
          <span>Meet yourself.</span>
        </h1>
        <p className={styles.lede}>
          Tarot reflection, guided learning, community, and evidence-led market
          research—held together in one private English-first experience.
        </p>
        <div id="cosmic-actions" className={styles.actions}>
          <Link className={styles.primaryAction} href="/app/">
            Enter Leo <ArrowRight aria-hidden="true" />
          </Link>
        </div>
      </div>

      <div className={styles.signalRail} aria-label="Product boundaries">
        <span><i /> Private by default</span>
        <span>Reflection is not prediction</span>
        <span>Research is not investment advice</span>
      </div>

      <div className={`${styles.curtain} ${styles.curtainTop}`} aria-hidden="true" />
      <div className={`${styles.curtain} ${styles.curtainBottom}`} aria-hidden="true" />
    </section>
  );
}
