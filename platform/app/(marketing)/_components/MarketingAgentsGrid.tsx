const AGENTS = [
  ['Source Auditor', 'Reuters/LSEG, SEC, vendor evidence quality'],
  ['Influencer Monitor', 'Serenity, bread, 3x long labubu, Elon Musk'],
  ['Catalyst Mapper', 'Ticker exposure, sector read-through, event materiality'],
  ['Tape Reader', 'Quote shocks, volume, confirmation, failed moves'],
  ['Risk Officer', 'MNPI blocks, source rights, invalidation checks'],
  ['Signal Synthesizer', 'Paper/live-signal action, thesis, next checks'],
];

export function MarketingAgentsGrid() {
  return (
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      {AGENTS.map(([name, body]) => (
        <div key={name} className="rounded-[18px] border border-white/10 bg-white/[0.04] p-4">
          <div className="text-sm font-black text-white">{name}</div>
          <p className="mt-2 text-xs leading-5 text-white/60">{body}</p>
        </div>
      ))}
    </div>
  );
}
