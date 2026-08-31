'use client';

import { useEffect, useState } from 'react';
import { X } from 'lucide-react';

const STORAGE_KEY = 'axio7_onboarded_v1';

const CARDS = [
  {
    emoji: '🤔',
    title: 'Try asking: "该不该接 MBB offer"',
    description: 'Decision mode — 7 agents give you Price, Location, Safety, Legal, Negotiation, Logistics, and Devil\'s Advocate perspectives in ~30 seconds.',
    tag: 'Panel mode',
    tagColor: '#7C3AED',
    cta: 'Try this question',
    ctaHref: '/?prefill=该不该接MBB offer',
  },
  {
    emoji: '🍜',
    title: 'Try asking: "Best ramen near Columbia"',
    description: 'Utility mode — simple queries get one clean answer from the most relevant agent. No noise, no filler.',
    tag: 'Single mode',
    tagColor: '#059669',
    cta: 'Try this question',
    ctaHref: '/?prefill=Best ramen near Columbia',
  },
  {
    emoji: '📬',
    title: 'Browse the Feed',
    description: 'See what Columbia + NYC students are asking, trading, and sharing. Filter by 🏠 Sublet, 🎉 Events, 💼 Founders, and more.',
    tag: 'Feed',
    tagColor: '#C2410C',
    cta: 'Go to Feed',
    ctaHref: '#feed',
  },
];

export function OnboardingModal({ authenticated }: { authenticated: boolean }) {
  const [open, setOpen] = useState(false);
  const [step, setStep] = useState(0);

  useEffect(() => {
    if (!authenticated) return;
    try {
      if (!localStorage.getItem(STORAGE_KEY)) {
        setOpen(true);
      }
    } catch {
      // localStorage may be blocked
    }
  }, [authenticated]);

  function dismiss() {
    try { localStorage.setItem(STORAGE_KEY, '1'); } catch { /* ignore */ }
    setOpen(false);
  }

  if (!open) return null;

  const card = CARDS[step];

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(4px)' }}
      onClick={(e) => { if (e.target === e.currentTarget) dismiss(); }}
    >
      <div
        className="relative w-full max-w-md rounded-[28px] p-7"
        style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)', boxShadow: '0 20px 60px rgba(0,0,0,0.18)' }}
      >
        <button
          onClick={dismiss}
          className="absolute right-4 top-4 rounded-full p-1.5 transition hover:opacity-70"
          style={{ background: 'rgba(0,0,0,0.07)', color: 'var(--lt-muted)' }}
        >
          <X className="h-4 w-4" />
        </button>

        {/* Step dots */}
        <div className="flex items-center gap-1.5 mb-6">
          {CARDS.map((_, i) => (
            <button
              key={i}
              onClick={() => setStep(i)}
              className="h-1.5 rounded-full transition-all"
              style={{
                width: i === step ? 24 : 6,
                background: i === step ? 'var(--molt-shell)' : 'var(--lt-border)',
              }}
            />
          ))}
        </div>

        <div className="text-5xl mb-4">{card.emoji}</div>

        <span
          className="inline-block rounded-full px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-wider mb-3"
          style={{ background: `${card.tagColor}18`, color: card.tagColor }}
        >
          {card.tag}
        </span>

        <h2 className="text-xl font-bold mb-2 leading-snug" style={{ color: 'var(--lt-text)', fontFamily: 'var(--font-fraunces)' }}>
          {card.title}
        </h2>
        <p className="text-sm leading-relaxed mb-6" style={{ color: 'var(--lt-muted)' }}>
          {card.description}
        </p>

        <div className="flex items-center gap-3">
          <a
            href={card.ctaHref}
            onClick={dismiss}
            className="flex-1 inline-flex items-center justify-center rounded-full py-2.5 text-sm font-semibold text-white transition hover:opacity-90"
            style={{ background: 'var(--molt-shell)' }}
          >
            {card.cta}
          </a>
          {step < CARDS.length - 1 ? (
            <button
              onClick={() => setStep((s) => s + 1)}
              className="flex-1 inline-flex items-center justify-center rounded-full border py-2.5 text-sm font-semibold transition hover:opacity-80"
              style={{ borderColor: 'var(--lt-border)', color: 'var(--lt-text)' }}
            >
              Next →
            </button>
          ) : (
            <button
              onClick={dismiss}
              className="flex-1 inline-flex items-center justify-center rounded-full border py-2.5 text-sm font-semibold transition hover:opacity-80"
              style={{ borderColor: 'var(--lt-border)', color: 'var(--lt-text)' }}
            >
              Get started
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
