/**
 * V0.2 — Seed posts script
 * Usage:
 *   npx tsx scripts/seed-posts.ts [--dry-run]
 *
 * Requires .env.local with:
 *   NEXT_PUBLIC_SUPABASE_URL=...
 *   SUPABASE_SERVICE_ROLE_KEY=...
 *   NEXT_PUBLIC_SITE_URL=https://axio7.com  (used to call /api/fanout)
 */

import { createClient } from '@supabase/supabase-js';

const DRY_RUN = process.argv.includes('--dry-run');

// ─── Edit your seed posts here ───────────────────────────────────────────────
const SEED_POSTS: Array<{ content: string; author_name: string }> = [
  {
    author_name: 'Erwin He',
    content:
      "Just moved to Morningside Heights for my Columbia MSCS. Rent is wild — any tips on finding a no-broker-fee sublet for the summer? I'm looking for June–August, ideally within 10 min walk of campus.",
  },
  {
    author_name: 'Erwin He',
    content:
      "What's the most underrated thing to do in NYC as a student that most people don't find until their last semester? Not tourist stuff — things locals actually do.",
  },
  {
    author_name: 'Erwin He',
    content:
      "Hot take: Columbia's grad student stipends haven't kept up with NYC rent inflation at all. In 2019 you could live within walking distance on a PhD stipend. Now it's basically impossible. Is this just Columbia or every NYC school?",
  },
  {
    author_name: 'Erwin He',
    content:
      'Selling my 2023 MacBook Pro M3 14" — 18GB RAM, 512GB SSD, AppleCare+ until Sept 2026. Bought it for grad school, upgrading to M4. No scratches, charger included. $1,400 OBO. Pickup Upper West Side.',
  },
  {
    author_name: 'Erwin He',
    content:
      "I got two competing offers — one from a fintech startup (Series B, $140k + equity) and one from Google (L4, $185k total comp, mostly RSU). The startup role is more senior and interesting. How should I actually think through this decision?",
  },
  {
    author_name: 'Erwin He',
    content:
      'Any Columbia students going to NYC Tech Week events next month? Looking for people to go with — especially the AI/founder stuff. Also if anyone has extra tickets to any sessions, DM me.',
  },
  {
    author_name: 'Erwin He',
    content:
      "What's actually the best late-night food within 20 min of 116th & Broadway? I'm talking post-midnight, walking distance or cheap Uber. Please be specific — not just 'get pizza'.",
  },
  {
    author_name: 'Erwin He',
    content:
      "I'm working on a project that uses LLMs to help international students navigate visa/work authorization paperwork (OPT, CPT, H1B timelines). Is this useful to people here? Would you use it? Trying to figure out if there's real demand before I build more.",
  },
  {
    author_name: 'Erwin He',
    content:
      'Looking for 1–2 roommates for a 3BR in Washington Heights, June 1st. $1,150/person all-in (utilities + wifi included). 5 min walk from the A train, laundry in building. Reach out if interested — happy to do a virtual tour.',
  },
  {
    author_name: 'Erwin He',
    content:
      "Finished my thesis defense today after 3 years. Still processing. The weirdest part isn't relief — it's not knowing what to do with all the mental space that used to be occupied by the problem. Anyone else felt this post-PhD void?",
  },
];
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const siteUrl = (process.env.NEXT_PUBLIC_SITE_URL ?? 'https://axio7.com').replace(/\/$/, '');

  if (!url || !key || url.includes('YOUR_PROJECT')) {
    console.error('❌  Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in env.');
    console.error('   Create a .env.local file or export the vars before running.');
    process.exit(1);
  }

  const sb = createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  console.log(`\n📋  Seeding ${SEED_POSTS.length} posts${DRY_RUN ? ' [DRY RUN — nothing written]' : ''}...\n`);

  let inserted = 0;
  let failed = 0;

  for (const p of SEED_POSTS) {
    if (DRY_RUN) {
      console.log(`  [dry-run] Would post: "${p.content.slice(0, 60)}…" by ${p.author_name}`);
      continue;
    }

    // Insert post directly via Supabase (bypasses rate limit)
    const { data: post, error } = await sb
      .from('posts')
      .insert({
        author_id: 'seed-admin',
        author_name: p.author_name,
        author_avatar: `https://api.dicebear.com/9.x/thumbs/svg?seed=ErwinHe`,
        content: p.content,
        images: [],
      })
      .select('id')
      .single();

    if (error || !post) {
      console.error(`  ❌  Failed to insert post: ${error?.message}`);
      failed++;
      continue;
    }

    console.log(`  ✅  Inserted post ${post.id} — "${p.content.slice(0, 55)}…"`);
    inserted++;

    // Trigger 7-agent fan-out via the API (needs server running, or use internal call)
    try {
      const fanoutRes = await fetch(`${siteUrl}/api/fanout`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ post_id: post.id }),
      });
      if (fanoutRes.ok) {
        console.log(`     🤖  Fanout triggered for ${post.id}`);
      } else {
        console.warn(`     ⚠️   Fanout HTTP ${fanoutRes.status} for ${post.id} — run manually if needed`);
      }
    } catch (e) {
      console.warn(`     ⚠️   Fanout fetch failed (server may not be running): ${e}`);
    }

    // Small delay to avoid hammering the API
    await new Promise((r) => setTimeout(r, 500));
  }

  if (!DRY_RUN) {
    console.log(`\n✅  Done: ${inserted} inserted, ${failed} failed.`);
    console.log(`   If fanout didn't run, trigger it manually:`);
    console.log(`   curl -X POST ${siteUrl}/api/fanout -H 'Content-Type: application/json' -d '{"post_id":"<id>"}'`);
  }
}

main().catch((e) => { console.error(e); process.exit(1); });
