import Link from 'next/link';
import {
  ArrowRight,
  BookOpen,
  CheckCircle2,
  FileSearch,
  GraduationCap,
  Landmark,
  ShieldCheck,
  Sparkles,
} from 'lucide-react';

const learningTracks = [
  {
    number: '01',
    icon: Landmark,
    title: 'Evidence foundations',
    body: 'Learn how to read public documents, structured datasets, definitions, dates, and source notes with care.',
    lessons: '8 lessons · beginner',
  },
  {
    number: '02',
    icon: FileSearch,
    title: 'Historical review',
    body: 'Turn past cases into clear timelines, separate observation from interpretation, and record what changed over time.',
    lessons: '6 lessons · beginner',
  },
  {
    number: '03',
    icon: BookOpen,
    title: 'Source comparison',
    body: 'Compare public sources by date, authorship, scope, and context before writing a review note.',
    lessons: '7 lessons · intermediate',
  },
  {
    number: '04',
    icon: Sparkles,
    title: 'Reflection practice',
    body: 'Summarize what a historical record supports, what changed later, and which questions remain open.',
    lessons: '9 lessons · intermediate',
  },
];

const reviewStandards = [
  'A clear date range and review question',
  'Cited public sources and labeled examples',
  'Visible assumptions and alternative explanations',
  'A written reflection on limits and open questions',
];

export function EducationHome({ membershipFrom }: { membershipFrom: string | null }) {
  return (
    <main className="education-home">
      <section className="education-hero">
        <div className="education-boundary-bar">
          <ShieldCheck className="h-4 w-4" />
          <span>EDUCATIONAL PURPOSE</span>
          <span className="education-boundary-copy">
            Guided lessons · Historical review · Public sources · Transparent methods
          </span>
        </div>

        <div className="education-hero-grid">
          <div className="education-hero-copy">
            <div className="education-eyebrow">
              <GraduationCap className="h-4 w-4" /> AXIO7 LEARNING &amp; REVIEW LAB
            </div>
            <h1>
              Learn the method.
              <em> Review the evidence.</em>
            </h1>
            <p className="education-lede">
              AXIO7 is an education-only workspace for guided lessons, source-reading exercises,
              transparent demonstrations, and structured review of historical cases.
            </p>
            <div className="education-hero-actions">
              <Link href="/learn" className="education-button education-button-primary">
                Explore the curriculum <ArrowRight className="h-4 w-4" />
              </Link>
              <Link href="/about" className="education-button education-button-secondary">
                How AXIO7 teaches
              </Link>
            </div>
            <p className="education-fineprint">
              General educational material · Historical and fictional examples · Self-paced learning
            </p>
          </div>

          <div className="lesson-preview" aria-label="Sample historical review lesson">
            <div className="lesson-preview-head">
              <span>LESSON PREVIEW</span>
              <span>03 / 30</span>
            </div>
            <div className="lesson-preview-body">
              <span className="lesson-kicker">HISTORICAL REVIEW</span>
              <h2>Build the timeline before the conclusion.</h2>
              <p>
                Put source dates, claims, and later corrections in order. Then record what was known at each point.
              </p>
              <div className="review-timeline-demo" aria-hidden="true">
                <div><span>01</span><p>First source</p></div>
                <div><span>02</span><p>New context</p></div>
                <div><span>03</span><p>Later review</p></div>
              </div>
              <div className="lesson-question">
                <Sparkles className="h-4 w-4" />
                <span>Reflection: which conclusion only became possible with hindsight?</span>
              </div>
            </div>
          </div>
        </div>

        <div className="education-principles" aria-label="Product principles">
          <span>PUBLIC-SOURCE LITERACY</span>
          <span>HISTORICAL CONTEXT</span>
          <span>CAREFUL SOURCE READING</span>
          <span>STRUCTURED REVIEW</span>
        </div>
      </section>

      <section className="education-section" id="curriculum">
        <div className="education-section-heading">
          <div>
            <span className="education-section-label">THE CURRICULUM</span>
          <h2>Four tracks. One better review habit.</h2>
          </div>
          <p>
            Each track teaches a durable idea with plain-language explanations, worked examples,
            knowledge checks, and source notes.
          </p>
        </div>

        <div className="learning-track-grid">
          {learningTracks.map(({ number, icon: Icon, title, body, lessons }) => (
            <article key={title} className="learning-track-card">
              <div className="learning-track-topline">
                <span>{number}</span>
                <Icon className="h-5 w-5" />
              </div>
              <h3>{title}</h3>
              <p>{body}</p>
              <div className="learning-track-meta">{lessons}</div>
            </article>
          ))}
        </div>
      </section>

      <section className="education-method-section">
        <div className="education-method-copy">
          <span className="education-section-label">THE AXIO7 METHOD</span>
          <h2>Evidence first. Context always visible.</h2>
          <p>
            Good education should make the source trail easy to follow. Every lesson separates source,
            context, interpretation, and reflection.
          </p>
          <Link href="/learn#method" className="education-text-link">
            See the learning method <ArrowRight className="h-4 w-4" />
          </Link>
        </div>
        <ol className="education-method-list">
          <li><span>1</span><div><strong>Observe</strong><p>Start with a public document or historical dataset.</p></div></li>
          <li><span>2</span><div><strong>Organize</strong><p>Place dates, claims, and context in a clear order.</p></div></li>
          <li><span>3</span><div><strong>Compare</strong><p>Check missing context and alternative explanations.</p></div></li>
          <li><span>4</span><div><strong>Reflect</strong><p>Record what the evidence can—and cannot—support.</p></div></li>
        </ol>
      </section>

      <section className="education-boundaries-section">
        <div>
          <span className="education-section-label">REVIEW STANDARDS</span>
          <h2>A quiet place to learn and look back carefully.</h2>
          <p>
            Every AXIO7 case is organized for education and retrospective review. Examples are generalized,
            historical, or fictional, with sources and limitations kept visible.
          </p>
        </div>
        <ul>
          {reviewStandards.map((standard) => (
            <li key={standard}><CheckCircle2 className="h-5 w-5" /> {standard}</li>
          ))}
        </ul>
      </section>

      <section className="education-cta-section">
        <BookOpen className="h-8 w-8" />
        <div>
          <span className="education-section-label">START WITH THE FOUNDATIONS</span>
          <h2>Turn complex information into structured review notes.</h2>
          <p>
            Explore the free curriculum overview, then choose a learning membership
            {membershipFrom ? ` from ${membershipFrom} per month` : ''}.
          </p>
        </div>
        <div className="education-cta-actions">
          <Link href="/learn" className="education-button education-button-primary">Open curriculum</Link>
          <Link href="/pricing" className="education-button education-button-secondary">View memberships</Link>
        </div>
      </section>
    </main>
  );
}
