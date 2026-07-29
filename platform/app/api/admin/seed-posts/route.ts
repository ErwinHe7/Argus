import { NextRequest, NextResponse } from 'next/server';
import { isSupabaseConfigured, supabaseAdmin } from '@/lib/supabase';
import { getCurrentUser, isAdmin } from '@/lib/auth';
import { fanOutAgentReplies } from '@/lib/agent-fanout';

export const runtime = 'nodejs';
export const maxDuration = 120;

// Random anonymous usernames — no real identity
const ANON_NAMES = [
  'AXIO@A10042', 'AXIO@B22891', 'AXIO@C33107', 'AXIO@D41256',
  'AXIO@E50334', 'AXIO@F61820', 'AXIO@G72491', 'AXIO@H83056',
  'AXIO@J94102', 'AXIO@K05237', 'AXIO@L16843', 'AXIO@M27509',
  'AXIO@N38621', 'AXIO@P49037', 'AXIO@Q50182', 'AXIO@R61470',
  'AXIO@S72038', 'AXIO@T83196', 'AXIO@U94427', 'AXIO@V05881',
];

// 20 natural Columbia/NYC and market-aware seed posts
const SEED_POOL = [
  "Watching NVDA, TSLA, and COIN into earnings. Which public catalysts are actually moving the tape today, and which ones are just social noise?",
  "What's the most underrated thing to do in NYC as a student that most people don't find until their last semester? Not tourist stuff — things locals actually do.",
  "Hot take: most market commentary is just post-hoc narrative. The only thing I trust intraday is source quality plus whether tape confirms it.",
  "Selling my 2023 MacBook Pro M3 14\" — 18GB RAM, 512GB SSD, AppleCare+ until Sept 2026. Bought it for grad school, upgrading to M4. No scratches, charger included. $1,400 OBO. Pickup Upper West Side.",
  "I got two competing offers — one from a fintech startup (Series B, $140k + equity) and one from Google (L4, $185k total comp, mostly RSU). The startup role is more senior and interesting. How should I actually think through this decision?",
  "Any Columbia students going to NYC Tech Week events next month? Looking for people to go with — especially the AI/founder stuff. Also if anyone has extra tickets to any sessions, DM me.",
  "What's actually the best late-night food within 20 min of 116th & Broadway? I'm talking post-midnight, walking distance or cheap Uber. Please be specific — not just 'get pizza'.",
  "I'm working on a project that uses LLMs to help international students navigate visa/work authorization paperwork (OPT, CPT, H1B timelines). Is this useful to people here? Would you use it?",
  "Serenity and bread both posted about AI infra spend within an hour. Is that actually useful as a signal, or just engagement bait?",
  "Finished my thesis defense today after 3 years. Still processing. The weirdest part isn't relief — it's not knowing what to do with all the mental space that used to be occupied by the problem. Anyone else felt this post-PhD void?",
  "Best coffee shops near Columbia to actually get work done? I need strong wifi, not too loud, and ideally open past 10pm. Bonus if it's not Starbucks.",
  "Anyone selling dining swipes this week? Willing to pay $8–10 per swipe. Can meet anywhere near campus. DM me.",
  "Trading lesson I wish someone told me: a catalyst without source hierarchy is just a rumor with a nicer font.",
  "Does anyone know a good immigration lawyer in NYC who works with international students? Specifically F-1 to H-1B transition. Looking for someone who won't charge $500/hour.",
  "Genuine question: is it worth doing an MBA right after undergrad, or should I work for 2–3 years first? I have a Columbia offer and a decent job at a consulting firm. The opportunity cost is massive.",
  "Anyone want to split a Costco membership? I'm on the UWS, happy to share the card if we do monthly runs together. Saves like $30/year each.",
  "Giving away a barely-used IKEA desk (MICKE, white, 105cm) and office chair. Moving out June 15th. You pick up from 110th Street, I'll help carry it down. Free, first come first served.",
  "Just got back from a week in Tokyo and honestly thinking about whether NYC is worth the cost anymore. $2,800/month for a shoebox studio vs. amazing food/transit for 1/3 the price. What keeps you here?",
  "Anyone else feel like the Columbia career center is completely useless for non-finance/consulting paths? Every event is Goldman or McKinsey. I'm in CS and trying to get into climate tech — completely on my own.",
  "If Reuters confirms a headline after X sees it first, do you trade the confirmation or assume the move is already priced?",
];

export async function POST(req: NextRequest) {
  const user = await getCurrentUser();
  if (!isAdmin(user)) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }
  if (!isSupabaseConfigured()) {
    return NextResponse.json({ error: 'Supabase not configured' }, { status: 503 });
  }

  const body = await req.json().catch(() => ({}));
  const dryRun = body.dry_run === true;
  const triggerFanout = body.trigger_fanout !== false; // default true
  const targetCount: number = typeof body.target_count === 'number' ? body.target_count : 29;

  // Count existing posts
  const { count: currentCount, error: countErr } = await supabaseAdmin()
    .from('posts')
    .select('*', { count: 'exact', head: true });

  if (countErr) {
    return NextResponse.json({ error: 'Failed to count posts', detail: countErr.message }, { status: 500 });
  }

  const current = currentCount ?? 0;
  const needed = Math.max(0, targetCount - current);

  if (dryRun || needed === 0) {
    return NextResponse.json({
      dry_run: dryRun,
      current_count: current,
      target_count: targetCount,
      needed,
      inserted: 0,
      would_insert: needed,
      sample: SEED_POOL.slice(0, needed).map((c) => c.slice(0, 80) + '…'),
    });
  }

  // Fetch existing content to avoid duplicates
  const { data: existingPosts } = await supabaseAdmin()
    .from('posts')
    .select('content')
    .order('created_at', { ascending: false })
    .limit(100);

  const existingContent = new Set((existingPosts ?? []).map((p: { content: string }) => p.content.trim()));
  const candidates = SEED_POOL.filter((c) => !existingContent.has(c.trim()));
  const toInsert = candidates.slice(0, needed);

  if (toInsert.length === 0) {
    return NextResponse.json({
      current_count: current,
      target_count: targetCount,
      needed,
      inserted: 0,
      note: 'All seed posts already exist — no duplicates inserted.',
    });
  }

  const results: { id: string; content_preview: string; author: string; fanout: string }[] = [];
  const errors: string[] = [];

  // Spread timestamps over the past 7 days so feed looks natural
  const now = Date.now();
  const spread = 7 * 24 * 60 * 60 * 1000; // 7 days in ms

  for (let i = 0; i < toInsert.length; i++) {
    const content = toInsert[i];
    // Pick a random anon name
    const authorName = ANON_NAMES[Math.floor(Math.random() * ANON_NAMES.length)];
    const authorId = `seed-${Math.random().toString(36).slice(2, 10)}`;
    const avatarSeed = encodeURIComponent(authorName);
    const authorAvatar = `https://api.dicebear.com/9.x/thumbs/svg?seed=${avatarSeed}`;

    // Random timestamp in the past 7 days
    const ageMs = Math.floor(Math.random() * spread);
    const createdAt = new Date(now - ageMs).toISOString();

    const { data: post, error } = await supabaseAdmin()
      .from('posts')
      .insert({
        author_id: authorId,
        author_name: authorName,
        author_avatar: authorAvatar,
        content,
        images: [],
        created_at: createdAt,
      })
      .select('id')
      .single();

    if (error || !post) {
      errors.push(error?.message ?? 'insert failed');
      continue;
    }

    // Fire agent fanout directly via internal function (no HTTP)
    let fanoutStatus = 'skipped';
    if (triggerFanout) {
      try {
        await fanOutAgentReplies(post.id);
        fanoutStatus = 'triggered';
      } catch (err: any) {
        fanoutStatus = `error: ${err?.message ?? String(err)}`;
      }
    }

    results.push({ id: post.id, content_preview: content.slice(0, 60), author: authorName, fanout: fanoutStatus });

    // Small pause to avoid hammering LLM APIs
    if (triggerFanout) await new Promise((r) => setTimeout(r, 500));
  }

  return NextResponse.json({
    current_count: current,
    target_count: targetCount,
    needed,
    inserted: results.length,
    errors: errors.length,
    results,
    error_details: errors,
  });
}
