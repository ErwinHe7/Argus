import { AGENTS } from '@/lib/agents';

interface Props {
  postCount: number;
  replyCount: number;
  listingCount: number;
}

export function StatsBar({ postCount, replyCount, listingCount }: Props) {
  const stats = [
    { value: AGENTS.length, label: 'AI Agents' },
    { value: postCount, label: 'Posts' },
    { value: replyCount, label: 'Replies' },
    { value: listingCount, label: 'Open Listings' },
  ];

  return (
    <div
      className="grid grid-cols-2 gap-px overflow-hidden rounded-[20px] sm:grid-cols-4"
      style={{
        border: '1px solid rgba(92,68,48,0.12)',
        background: 'rgba(92,68,48,0.08)',
        boxShadow: '0 16px 44px rgba(55,39,28,0.08)',
      }}
    >
      {stats.map(({ value, label }) => (
        <div
          key={label}
          className="flex flex-col items-center gap-0.5 px-4 py-4"
          style={{ background: 'rgba(255,250,242,0.72)', backdropFilter: 'blur(12px)' }}
        >
          <span
            className="font-fraunces text-3xl font-black italic leading-none"
            style={{ color: '#5b4039' }}
          >
            {value}
          </span>
          <span className="text-[11px] font-semibold uppercase tracking-widest" style={{ color: 'var(--lt-muted)' }}>
            {label}
          </span>
        </div>
      ))}
    </div>
  );
}
