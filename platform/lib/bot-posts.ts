export type BotPost = {
  author_name: string;
  author_avatar: string;
  content: string;
  images?: string[];
  topics: string[];
};

const BOT_USERS = [
  { name: 'Maya Chen', seed: 'maya-chen-nyc' },
  { name: 'Jordan Rivera', seed: 'jordan-r-2026' },
  { name: 'Priya Nair', seed: 'priya-nair-columbia' },
  { name: 'Luca Bianchi', seed: 'luca-b-nyc' },
  { name: 'Zoe Park', seed: 'zoe-park-ms' },
  { name: 'Aiden Walsh', seed: 'aiden-walsh-tech' },
  { name: 'Sofia Mendez', seed: 'sofia-mendez-26' },
  { name: 'Marcus Thompson', seed: 'marcus-t-nyc' },
];

const POST_TEMPLATES: Array<{ content: string; imageKeyword?: string; topics: string[] }> = [
  // NYC life
  { content: "Anyone else notice how the L train has been surprisingly on time this week? Did they secretly fix it or am I just getting lucky lmao", topics: ['nyc', 'transit'] },
  { content: "Found a $12 ramen spot on St. Marks that's genuinely better than Ippudo. The broth is obsessive. No line after 9pm.", imageKeyword: "ramen,food,noodles", topics: ['nyc', 'food'] },
  { content: "NVDA just erased a morning selloff after a single supply-chain headline. Market feels allergic to waiting for confirmed filings.", topics: ['markets', 'ai', 'stocks'] },
  { content: "Just sold my IKEA desk for $40 on Facebook Marketplace in literally 6 minutes. May move-out season is the best time to buy anything in this city.", topics: ['nyc', 'trade', 'furniture'] },
  { content: "The High Line at 7am before tourists arrive is a completely different place. Quiet, misty, just the regulars walking dogs. Highly recommend.", imageKeyword: "high-line,park,nyc,morning", topics: ['nyc', 'culture'] },
  // Tech/AI
  { content: "Hot take: the 'AI is coming for your job' panic skips the part where most jobs are 40% meetings and 30% formatting PowerPoints. Automate that first.", topics: ['tech', 'ai', 'startup'] },
  { content: "Spent 6 hours debugging a Next.js hydration error today. Turns out I had a Date.now() in a server component. I am not okay.", topics: ['tech', 'dev'] },
  { content: "The gap between 'this AI product looks incredible' and 'this AI is useful every day' is still the widest gap in software rn", topics: ['tech', 'ai', 'startup'] },
  { content: "LangGraph for multi-agent workflows is actually pretty solid once you stop fighting the state management. Week 2 update for anyone following along.", imageKeyword: "code,programming,terminal,dark", topics: ['tech', 'ai', 'dev'] },
  // Philosophy/life
  { content: "Thesis: the reason people feel more productive in coffee shops isn't the caffeine, it's having witnesses. Social accountability is underrated.", topics: ['philosophy', 'life', 'study'] },
  { content: "There's a specific kind of loneliness that comes from being surrounded by ambitious people who are all too busy to actually connect. NYC thing or just grad school?", topics: ['life', 'nyc', 'philosophy'] },
  { content: "Reading Camus in the park after a brutal week of problem sets is the most Columbia thing I've done. 'One must imagine Sisyphus happy.' ok sure Albert", imageKeyword: "reading,book,park,sunlight", topics: ['books', 'philosophy', 'study'] },
  // Culture
  { content: "The Basquiat exhibit at the Guggenheim is worth every penny of the $30 ticket. His notebooks alone are worth the trip — raw, angry, brilliant.", imageKeyword: "museum,art,exhibition,modern", topics: ['culture', 'art', 'nyc'] },
  { content: "Caught a free jazz set in Tompkins Square Park last night. Three guys, no audience at first, then suddenly 50 people just stopped. Magic.", topics: ['culture', 'nyc', 'music'] },
  // Startup/entrepreneurship
  { content: "6 months ago I had an idea. Last week someone asked me to pitch it to their fund. The only thing I did differently: I shipped something ugly and showed it to people.", topics: ['startup', 'founder', 'build'] },
  { content: "The best feedback I ever got on a product: 'I use it but I wouldn't miss it.' That sentence rewired how I think about retention.", topics: ['startup', 'product', 'pmf'] },
  // Books
  { content: "Finished 'The Remains of the Day' last night. The ending hit different at 2am. Stevens realizing his whole life was built on deference... genuinely devastating.", imageKeyword: "book,reading,night,lamp", topics: ['books', 'reading', 'philosophy'] },
  { content: "Currently reading 'Bullshit Jobs' by David Graeber and having a small existential crisis. Recommend for anyone questioning what they're doing with their life.", topics: ['books', 'philosophy', 'life'] },
];

export function pickBotPost(): BotPost {
  const template = POST_TEMPLATES[Math.floor(Math.random() * POST_TEMPLATES.length)];
  const user = BOT_USERS[Math.floor(Math.random() * BOT_USERS.length)];
  const avatar = `https://api.dicebear.com/9.x/thumbs/svg?seed=${user.seed}&backgroundColor=b6e3f4,c0aede,d1f4d1,ffd5dc,fde68a`;
  const images = template.imageKeyword
    ? [`https://source.unsplash.com/800x600/?${encodeURIComponent(template.imageKeyword)}`]
    : [];
  return {
    author_name: user.name,
    author_avatar: avatar,
    content: template.content,
    images,
    topics: template.topics,
  };
}
