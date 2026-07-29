'use client';

import { useEffect, useState } from 'react';
import {
  Check,
  FileText,
  GitCompareArrows,
  ListTree,
  Pause,
  Play,
  ScanSearch,
  ShieldCheck,
} from 'lucide-react';
import styles from './AxioLanding.module.css';

const steps = [
  {
    key: 'sources',
    number: '01',
    label: 'Sources',
    title: 'Collect the record',
    caption: 'Three public records are attached to the lesson.',
    icon: ScanSearch,
  },
  {
    key: 'timeline',
    number: '02',
    label: 'Timeline',
    title: 'Put events in order',
    caption: 'Claims and later corrections are separated by date.',
    icon: ListTree,
  },
  {
    key: 'compare',
    number: '03',
    label: 'Compare',
    title: 'Reveal what changed',
    caption: 'The original wording is checked against later context.',
    icon: GitCompareArrows,
  },
  {
    key: 'review',
    number: '04',
    label: 'Review',
    title: 'Write only what holds',
    caption: 'The final note keeps its support and limits visible.',
    icon: ShieldCheck,
  },
] as const;

export function AxioMethodDemo() {
  const [activeStep, setActiveStep] = useState(0);
  const [playing, setPlaying] = useState(true);

  useEffect(() => {
    if (!playing) return;

    const timer = window.setTimeout(() => {
      setActiveStep((current) => (current + 1) % steps.length);
    }, 4200);

    return () => window.clearTimeout(timer);
  }, [activeStep, playing]);

  const active = steps[activeStep];

  return (
    <div className={styles.demoShell}>
      <div className={styles.demoHeader}>
        <div>
          <span className={styles.demoProduct}>AXIO7 / REVIEW LAB</span>
          <span className={styles.demoCase}>CASE 03 · PUBLIC RECORD</span>
        </div>
        <div className={styles.demoHeaderStatus}>
          <span />
          LIVE LESSON
        </div>
      </div>

      <div className={styles.demoLayout}>
        <nav className={styles.demoNav} aria-label="AXIO7 method steps">
          {steps.map((step, index) => {
            const Icon = step.icon;
            const selected = activeStep === index;
            return (
              <button
                key={step.key}
                type="button"
                aria-pressed={selected}
                className={selected ? styles.demoNavActive : undefined}
                onClick={() => setActiveStep(index)}
              >
                <span className={styles.demoNavNumber}>{step.number}</span>
                <Icon size={16} />
                <span>{step.label}</span>
                {selected && playing ? <i key={`${step.key}-${activeStep}`} /> : null}
              </button>
            );
          })}
        </nav>

        <div className={styles.demoWorkarea}>
          <div className={styles.demoStageHeading}>
            <div>
              <span>{active.number} / 04</span>
              <h2>{active.title}</h2>
            </div>
            <p>{active.caption}</p>
          </div>

          <div className={styles.demoFrame} aria-live="polite">
            <div key={active.key} className={styles.demoFrameContent}>
              {active.key === 'sources' ? <SourcesFrame /> : null}
              {active.key === 'timeline' ? <TimelineFrame /> : null}
              {active.key === 'compare' ? <CompareFrame /> : null}
              {active.key === 'review' ? <ReviewFrame /> : null}
            </div>
          </div>

          <div className={styles.demoFooter}>
            <span>
              <ShieldCheck size={14} />
              Source links stay attached at every step
            </span>
            <button
              type="button"
              onClick={() => setPlaying((current) => !current)}
              aria-label={playing ? 'Pause lesson playback' : 'Play lesson playback'}
            >
              {playing ? <Pause size={13} /> : <Play size={13} />}
              {playing ? 'PAUSE' : 'PLAY'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

function SourcesFrame() {
  const sources = [
    ['A', 'Initial public statement', 'MAR 02 · 09:10'],
    ['B', 'Supporting document', 'MAR 02 · 14:40'],
    ['C', 'Later correction', 'MAR 05 · 11:25'],
  ];

  return (
    <div className={styles.sourcesFrame}>
      <div className={styles.sourceSummary}>
        <span>RECORD SET</span>
        <strong>3 sources</strong>
        <small>All dates normalized · originals preserved</small>
      </div>
      <div className={styles.sourceRows}>
        {sources.map(([letter, title, date], index) => (
          <div key={letter} style={{ animationDelay: `${index * 100}ms` }}>
            <span>{letter}</span>
            <FileText size={15} />
            <strong>{title}</strong>
            <small>{date}</small>
            <Check size={14} />
          </div>
        ))}
      </div>
    </div>
  );
}

function TimelineFrame() {
  return (
    <div className={styles.timelineFrame}>
      <div className={styles.timelineAxis} aria-hidden="true">
        <i />
      </div>
      {[
        ['MAR 02', '09:10', 'Initial statement', 'What was known first'],
        ['MAR 02', '14:40', 'Document published', 'New supporting detail'],
        ['MAR 05', '11:25', 'Correction issued', 'Earlier wording narrowed'],
      ].map(([date, time, title, body], index) => (
        <div
          key={time}
          className={styles.timelineEvent}
          style={{ animationDelay: `${index * 150}ms` }}
        >
          <span>{date}</span>
          <small>{time}</small>
          <i>{index + 1}</i>
          <div>
            <strong>{title}</strong>
            <p>{body}</p>
          </div>
        </div>
      ))}
    </div>
  );
}

function CompareFrame() {
  return (
    <div className={styles.compareFrame}>
      <article>
        <span>SOURCE A · ORIGINAL</span>
        <p>
          “The change applies to <mark>all reviewed records</mark> beginning March 2.”
        </p>
        <small>Published MAR 02 · 09:10</small>
      </article>
      <div className={styles.compareDivider}>
        <GitCompareArrows size={17} />
        <span>3 days later</span>
      </div>
      <article>
        <span>SOURCE C · CORRECTION</span>
        <p>
          “The change applies to <mark>one category of records</mark> beginning March 2.”
        </p>
        <small>Published MAR 05 · 11:25</small>
      </article>
    </div>
  );
}

function ReviewFrame() {
  return (
    <div className={styles.reviewFrame}>
      <div className={styles.reviewVerdict}>
        <span>REVIEW NOTE</span>
        <strong>The later correction narrows the scope of the original statement.</strong>
        <p>
          The date did not change. The affected category did. A broad conclusion is not
          supported by the complete record.
        </p>
      </div>
      <div className={styles.reviewChecks}>
        <div>
          <span>SUPPORTED BY</span>
          <strong>3 / 3</strong>
          <small>linked sources</small>
        </div>
        <div>
          <span>LIMITS KEPT</span>
          <strong>02</strong>
          <small>open questions</small>
        </div>
        <div>
          <span>STATUS</span>
          <strong className={styles.reviewReady}>READY</strong>
          <small>for reflection</small>
        </div>
      </div>
    </div>
  );
}
