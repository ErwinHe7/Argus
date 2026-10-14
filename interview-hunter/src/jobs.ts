// Job discovery from the public job-board APIs of the three applicant tracking
// systems whose hosted forms the agent knows how to fill.

export type Ats = 'greenhouse' | 'lever' | 'ashby';

export interface Company { ats: Ats; slug: string }

export interface Job {
  key: string;
  ats: Ats;
  company: string;
  title: string;
  location: string;
  remote: boolean;
  postedAt: string;
  url: string;
  applyUrl: string;
}

export interface JobFilter { titles: string[]; locations: string[]; exclude: string[] }

const SLUG = /^[A-Za-z0-9][A-Za-z0-9._-]{0,80}$/;
export const MAX_COMPANIES = 100;
export const MAX_RESULTS = 300;

export function parseCompany(entry: string): Company | null {
  const [ats, slug] = entry.trim().split(':');
  if ((ats === 'greenhouse' || ats === 'lever' || ats === 'ashby') && slug && SLUG.test(slug)) return { ats, slug };
  return null;
}

function boardUrl({ ats, slug }: Company): string {
  const s = encodeURIComponent(slug);
  if (ats === 'greenhouse') return `https://boards-api.greenhouse.io/v1/boards/${s}/jobs`;
  if (ats === 'lever') return `https://api.lever.co/v0/postings/${s}?mode=json`;
  return `https://api.ashbyhq.com/posting-api/job-board/${s}`;
}

const str = (value: unknown): string => (typeof value === 'string' ? value : '');
const isRemote = (text: string) => /\bremote\b/i.test(text);

/** Converts one board's API payload into jobs. Unknown shapes yield no jobs. */
export function normalizeBoard({ ats, slug }: Company, payload: unknown): Job[] {
  const jobs: Job[] = [];
  if (ats === 'greenhouse') {
    const list = (payload as { jobs?: unknown })?.jobs;
    for (const raw of Array.isArray(list) ? list : []) {
      const id = raw?.id;
      if (typeof id !== 'number' && typeof id !== 'string') continue;
      const location = str(raw.location?.name);
      jobs.push({
        key: `greenhouse:${slug}:${id}`, ats, company: str(raw.company_name) || slug, title: str(raw.title), location,
        remote: isRemote(location), postedAt: str(raw.first_published) || str(raw.updated_at), url: str(raw.absolute_url),
        applyUrl: `https://job-boards.greenhouse.io/embed/job_app?for=${encodeURIComponent(slug)}&token=${encodeURIComponent(String(id))}`,
      });
    }
  } else if (ats === 'lever') {
    for (const raw of Array.isArray(payload) ? payload : []) {
      const id = str(raw?.id);
      if (!id) continue;
      const location = str(raw.categories?.location);
      const url = str(raw.hostedUrl) || `https://jobs.lever.co/${slug}/${id}`;
      jobs.push({
        key: `lever:${slug}:${id}`, ats, company: slug, title: str(raw.text), location,
        remote: raw.workplaceType === 'remote' || isRemote(location),
        postedAt: typeof raw.createdAt === 'number' ? new Date(raw.createdAt).toISOString() : '',
        url, applyUrl: str(raw.applyUrl) || `${url}/apply`,
      });
    }
  } else {
    const list = (payload as { jobs?: unknown })?.jobs;
    for (const raw of Array.isArray(list) ? list : []) {
      const id = str(raw?.id);
      if (!id || raw.isListed === false) continue;
      const location = str(raw.location);
      const url = str(raw.jobUrl) || `https://jobs.ashbyhq.com/${slug}/${id}`;
      jobs.push({
        key: `ashby:${slug}:${id}`, ats, company: slug, title: str(raw.title), location,
        remote: raw.isRemote === true || isRemote(location), postedAt: str(raw.publishedAt),
        url, applyUrl: str(raw.applyUrl) || `${url}/application`,
      });
    }
  }
  return jobs.filter(job => job.title);
}

export async function fetchJobs(companies: Company[]): Promise<{ jobs: Job[]; skipped: string[] }> {
  const results = await Promise.all(companies.map(async company => {
    try {
      const response = await fetch(boardUrl(company), { headers: { accept: 'application/json' } });
      if (!response.ok) throw new Error(String(response.status));
      return normalizeBoard(company, await response.json());
    } catch {
      return null;
    }
  }));
  const skipped = companies.filter((_, i) => results[i] === null).map(c => `${c.ats}:${c.slug}`);
  return { jobs: results.flatMap(r => r ?? []), skipped };
}

const words = (text: string) => text.toLowerCase().replace(/[^a-z0-9+#]+/g, ' ').trim().split(' ').filter(Boolean);

/** Keeps jobs whose title contains every word of some target title, newest first. */
export function matchJobs(jobs: Job[], filter: JobFilter): Job[] {
  const titles = filter.titles.map(words).filter(w => w.length);
  const exclude = new Set(filter.exclude.flatMap(words));
  const locations = filter.locations.map(l => words(l).join(' ')).filter(Boolean);
  return jobs
    .filter(job => {
      const titleWords = new Set(words(job.title));
      if (titles.length && !titles.some(t => t.every(w => titleWords.has(w)))) return false;
      if ([...titleWords].some(w => exclude.has(w))) return false;
      if (!locations.length) return true;
      const where = words(job.location).join(' ');
      return locations.some(l => (l === 'remote' ? job.remote : ` ${where} `.includes(` ${l} `)));
    })
    .sort((a, b) => b.postedAt.localeCompare(a.postedAt))
    .slice(0, MAX_RESULTS);
}

/** Turns a pasted Greenhouse, Lever, or Ashby job link into an applyable job. */
export function jobFromLink(link: string): Job | null {
  let url: URL;
  try {
    url = new URL(link.trim());
  } catch {
    return null;
  }
  if (url.protocol !== 'https:') return null;
  const parts = url.pathname.split('/').filter(Boolean);
  const make = (ats: Ats, slug: string, id: string, applyUrl: string): Job | null =>
    SLUG.test(slug) && /^[A-Za-z0-9-]{1,64}$/.test(id)
      ? { key: `${ats}:${slug}:${id}`, ats, company: slug, title: '', location: '', remote: false, postedAt: '', url: url.href, applyUrl }
      : null;

  if (url.hostname === 'boards.greenhouse.io' || url.hostname === 'job-boards.greenhouse.io') {
    const slug = parts[0] === 'embed' ? url.searchParams.get('for') ?? '' : parts[0] ?? '';
    const id = parts[0] === 'embed' ? url.searchParams.get('token') ?? '' : parts[1] === 'jobs' ? parts[2] ?? '' : '';
    return make('greenhouse', slug, id,
      `https://job-boards.greenhouse.io/embed/job_app?for=${encodeURIComponent(slug)}&token=${encodeURIComponent(id)}`);
  }
  if (url.hostname === 'jobs.lever.co' || url.hostname === 'jobs.eu.lever.co') {
    const [slug = '', id = ''] = parts;
    return make('lever', slug, id, `https://${url.hostname}/${slug}/${id}/apply`);
  }
  if (url.hostname === 'jobs.ashbyhq.com') {
    const [slug = '', id = ''] = parts;
    return make('ashby', slug, id, `https://jobs.ashbyhq.com/${slug}/${id}/application`);
  }
  return null;
}
