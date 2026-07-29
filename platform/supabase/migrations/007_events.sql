-- AXIO7 Events Discovery — migration 007
-- Adds event_sources and events tables for Columbia/NYC event aggregation.

create table if not exists public.event_sources (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kind text not null check (kind in ('api','rss','ical','html','user_submit','manual')),
  url text,
  trust_score int not null default 50,
  refresh_interval_minutes int not null default 360,
  enabled boolean not null default true,
  last_synced_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  source_id uuid references public.event_sources(id) on delete set null,
  external_id text,
  title text not null,
  description text,
  start_time timestamptz,
  end_time timestamptz,
  location text,
  borough text,
  lat double precision,
  lng double precision,
  url text,
  poster_url text,
  tags text[] not null default '{}',
  category text,
  price_text text,
  is_free boolean,
  raw_payload jsonb,
  submitted_by_author_id text,
  status text not null default 'published'
    check (status in ('pending','published','rejected','expired')),
  freshness_score int not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(source_id, external_id)
);

create index if not exists events_start_time_idx on public.events(start_time);
create index if not exists events_status_idx on public.events(status);
create index if not exists events_tags_gin on public.events using gin(tags);

-- Auto-update updated_at
create or replace function public.events_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists events_updated_at on public.events;
create trigger events_updated_at
  before update on public.events
  for each row execute procedure public.events_set_updated_at();

-- RLS: events readable by anyone when published; insert by anyone (pending); update/delete service role only
alter table public.event_sources disable row level security;
alter table public.events disable row level security;
-- (RLS disabled for MVP, same pattern as other tables)

-- Seed core sources
insert into public.event_sources (name, kind, url, trust_score, refresh_interval_minutes) values
  ('Columbia Events Calendar', 'ical', 'https://events.columbia.edu/feeder/main/eventsFeed.do?f=y&sort=dtstart.utc:asc&skinName=ical', 95, 240),
  ('NYC Open Data — Permitted Events', 'api', 'https://data.cityofnewyork.us/resource/tvpp-9vvx.json', 85, 720),
  ('Ticketmaster Discovery NYC', 'api', 'https://app.ticketmaster.com/discovery/v2/events.json', 80, 360),
  ('User Submission', 'user_submit', null, 60, 0),
  ('AXIO7 Curated', 'manual', null, 100, 0)
on conflict do nothing;

-- Seed 20 curated events so the page is never empty on first load
with curated as (
  select id from public.event_sources where name = 'AXIO7 Curated' limit 1
)
insert into public.events
  (source_id, external_id, title, description, start_time, end_time, location, borough, url, poster_url, tags, category, price_text, is_free, status)
select
  curated.id,
  e.external_id,
  e.title, e.description, e.start_time, e.end_time,
  e.location, e.borough, e.url, e.poster_url,
  e.tags, e.category, e.price_text, e.is_free, 'published'
from curated, (values
  ('seed-01', 'Columbia Startup Lab Demo Day',
   'Student founders present their startups to investors, VCs, and the Columbia community. Networking reception follows.',
   now() + interval '2 days', now() + interval '2 days' + interval '3 hours',
   'Lerner Hall, 2920 Broadway, NYC', 'Manhattan',
   'https://entrepreneurship.columbia.edu',
   'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800&q=80',
   array['startup','columbia','networking','demo day'], 'talk', 'Free', true),

  ('seed-02', 'NYC Tech Week: AI & the Future of Work',
   'Panel discussion with founders, researchers, and operators on AI''s impact on jobs, creativity, and the labor market.',
   now() + interval '3 days', now() + interval '3 days' + interval '2 hours',
   'WeWork, 575 Lexington Ave, Midtown', 'Manhattan',
   'https://nyctechweek.com',
   'https://images.unsplash.com/photo-1591453089816-0fbb971b454c?w=800&q=80',
   array['ai','tech','panel','nyc'], 'talk', '$10', false),

  ('seed-03', 'Rooftop Social: Columbia Grad Students',
   'Casual rooftop mixer for Columbia grad students across all schools. Free drinks 7–8pm.',
   now() + interval '4 days', now() + interval '4 days' + interval '4 hours',
   'The Heights Bar & Grill Rooftop, 2867 Broadway', 'Manhattan',
   'https://instagram.com/columbiagsas',
   'https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?w=800&q=80',
   array['social','columbia','grad','party','mixer'], 'social', 'Free', true),

  ('seed-04', 'Brooklyn Museum: First Saturday',
   'Free admission + live music, art workshops, and performances at the Brooklyn Museum. No ticket needed.',
   now() + interval '5 days', now() + interval '5 days' + interval '4 hours',
   'Brooklyn Museum, 200 Eastern Pkwy', 'Brooklyn',
   'https://brooklynmuseum.org/programs/first_saturdays',
   'https://images.unsplash.com/photo-1580130732478-4e339fb33746?w=800&q=80',
   array['art','museum','brooklyn','free','culture'], 'culture', 'Free', true),

  ('seed-05', 'Columbia International Affairs Association Gala',
   'Annual gala celebrating global student engagement. Keynote speaker TBA. Formal attire encouraged.',
   now() + interval '6 days', now() + interval '6 days' + interval '4 hours',
   'Faculty House, Columbia University', 'Manhattan',
   'https://ciaa.columbia.edu',
   'https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?w=800&q=80',
   array['columbia','gala','international','formal'], 'social', '$35', false),

  ('seed-06', 'Jazz at Lincoln Center: Open Rehearsal',
   'Watch the Jazz at Lincoln Center Orchestra rehearse live — free, first-come seats. Doors open 10am.',
   now() + interval '7 days', now() + interval '7 days' + interval '2 hours',
   'Lincoln Center, Columbus Ave & 62nd St', 'Manhattan',
   'https://jazz.org',
   'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=800&q=80',
   array['jazz','music','lincoln center','free','nyc'], 'music', 'Free', true),

  ('seed-07', 'Smorgasburg Williamsburg',
   'NYC''s legendary outdoor food market returns every Saturday. 100+ vendors. Williamsburg waterfront.',
   now() + interval '8 days', now() + interval '8 days' + interval '6 hours',
   'East River State Park, Williamsburg, Brooklyn', 'Brooklyn',
   'https://smorgasburg.com',
   'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800&q=80',
   array['food','market','brooklyn','outdoor','weekend'], 'food', 'Free entry', true),

  ('seed-08', 'Columbia SEAS Hackathon',
   '24-hour hackathon hosted by Columbia Engineering. Open to all Columbia students. Prizes, mentors, free food.',
   now() + interval '9 days', now() + interval '10 days',
   'Columbia SEAS Makerspace, Mudd Hall', 'Manhattan',
   'https://seas.columbia.edu/events',
   'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=800&q=80',
   array['hackathon','columbia','engineering','tech','coding'], 'academic', 'Free', true),

  ('seed-09', 'High Line Sunset Walk & Social',
   'Community walk along the High Line followed by drinks at Hudson Yards. Meet at 14th St entrance.',
   now() + interval '10 days', now() + interval '10 days' + interval '3 hours',
   'High Line, 14th St Entrance, Manhattan', 'Manhattan',
   'https://thehighline.org',
   'https://images.unsplash.com/photo-1569974507005-6dc61f97fb5c?w=800&q=80',
   array['outdoor','social','nyc','walk','networking'], 'social', 'Free', true),

  ('seed-10', 'MOMA Free Fridays',
   'Museum of Modern Art is free every Friday 5:30–9pm. No reservations needed. Gallery talks included.',
   now() + interval '11 days', now() + interval '11 days' + interval '3 hours 30 minutes',
   'MoMA, 11 W 53rd St, Midtown', 'Manhattan',
   'https://moma.org',
   'https://images.unsplash.com/photo-1518998053901-5348d3961a04?w=800&q=80',
   array['art','museum','moma','free','midtown'], 'culture', 'Free', true),

  ('seed-11', 'Columbia Farmers Market',
   'Weekly farmers market on the Columbia campus. Fresh produce, flowers, artisan goods.',
   now() + interval '12 days', now() + interval '12 days' + interval '4 hours',
   'Columbia University, 116th & Broadway', 'Manhattan',
   'https://dining.columbia.edu',
   'https://images.unsplash.com/photo-1488459716781-31db52582fe9?w=800&q=80',
   array['market','columbia','food','outdoor'], 'food', 'Free entry', true),

  ('seed-12', 'NYC House Music Party: Basement Sessions',
   'Underground house music night at a Bushwick loft. DJs rotating all night. BYOB + $5 door.',
   now() + interval '13 days', now() + interval '13 days' + interval '5 hours',
   'Bushwick Loft (address on RSVP)', 'Brooklyn',
   'https://ra.co',
   'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&q=80',
   array['party','music','brooklyn','nightlife','house music'], 'nightlife', '$5', false),

  ('seed-13', 'Columbia Pre-Law Society Info Session',
   'Learn about the LSAT, law school applications, and career paths in law. Open to all undergrads.',
   now() + interval '14 days', now() + interval '14 days' + interval '1 hour 30 minutes',
   'Butler Library, Columbia University', 'Manhattan',
   'https://law.columbia.edu',
   'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=800&q=80',
   array['columbia','law','academic','career','info session'], 'academic', 'Free', true),

  ('seed-14', 'Prospect Park SummerStage: Free Concert',
   'Free outdoor concert at Prospect Park''s SummerStage. Bring a blanket and picnic.',
   now() + interval '15 days', now() + interval '15 days' + interval '3 hours',
   'Prospect Park SummerStage, Brooklyn', 'Brooklyn',
   'https://cityparksfoundation.org/summerstage',
   'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=800&q=80',
   array['music','concert','free','brooklyn','outdoor'], 'music', 'Free', true),

  ('seed-15', 'The Met: Late Nights',
   'The Metropolitan Museum of Art stays open until 9pm on Fridays. Free with suggested donation.',
   now() + interval '16 days', now() + interval '16 days' + interval '4 hours',
   'The Met, 1000 5th Ave, Upper East Side', 'Manhattan',
   'https://metmuseum.org',
   'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=80',
   array['art','museum','met','culture','nyc'], 'culture', 'Pay what you wish', true),

  ('seed-16', 'Columbia University Film Festival',
   'Student-made short films screened across genres. Q&A with directors after each program block.',
   now() + interval '17 days', now() + interval '17 days' + interval '3 hours',
   'Dodge Hall, Columbia University', 'Manhattan',
   'https://arts.columbia.edu',
   'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=800&q=80',
   array['film','columbia','arts','screening','student'], 'culture', 'Free', true),

  ('seed-17', 'Astoria Park Yoga',
   'Free community yoga in Astoria Park every Sunday morning. All levels welcome. Bring your mat.',
   now() + interval '18 days', now() + interval '18 days' + interval '1 hour',
   'Astoria Park, Queens', 'Queens',
   'https://nycparks.gov',
   'https://images.unsplash.com/photo-1599901860904-17e6ed7083a0?w=800&q=80',
   array['yoga','fitness','outdoor','free','queens'], 'wellness', 'Free', true),

  ('seed-18', 'NYC Tech Meetup',
   'Monthly gathering of NYC''s tech community. Lightning talks + networking. 500+ attendees.',
   now() + interval '19 days', now() + interval '19 days' + interval '3 hours',
   'NYU Skirball Center, 566 LaGuardia Pl', 'Manhattan',
   'https://nytm.org',
   'https://images.unsplash.com/photo-1475721027785-f74eccf877e2?w=800&q=80',
   array['tech','networking','meetup','nyc','startup'], 'networking', 'Free', true),

  ('seed-19', 'Columbia GSAS Graduate Research Symposium',
   'Annual symposium showcasing PhD and MA student research across the humanities, social sciences, and sciences.',
   now() + interval '20 days', now() + interval '20 days' + interval '6 hours',
   'Faculty House, Columbia University', 'Manhattan',
   'https://gsas.columbia.edu',
   'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=800&q=80',
   array['columbia','academic','research','grad','symposium'], 'academic', 'Free', true),

  ('seed-20', 'Coney Island Summer Nights',
   'Live music, rides, and Nathan''s Famous at Coney Island. Free boardwalk access, rides optional.',
   now() + interval '21 days', now() + interval '21 days' + interval '5 hours',
   'Coney Island Boardwalk, Brooklyn', 'Brooklyn',
   'https://coneyisland.com',
   'https://images.unsplash.com/photo-1567538096630-e0c55bd6374c?w=800&q=80',
   array['brooklyn','outdoor','music','summer','free'], 'social', 'Free entry', true)
) as e(external_id, title, description, start_time, end_time, location, borough, url, poster_url, tags, category, price_text, is_free)
on conflict (source_id, external_id) do nothing;
