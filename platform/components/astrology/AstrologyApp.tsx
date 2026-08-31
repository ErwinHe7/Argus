'use client';

import Image from 'next/image';
import type { LucideIcon } from 'lucide-react';
import {
  ArrowLeft,
  ArrowRight,
  BookOpenText,
  CalendarDays,
  Check,
  CheckCircle2,
  Compass,
  Eye,
  HeartHandshake,
  LockKeyhole,
  MoonStar,
  Save,
  ShieldCheck,
  Sparkles,
  Trash2,
} from 'lucide-react';
import { useEffect, useMemo, useRef, useState } from 'react';
import styles from './AstrologyApp.module.css';

type Focus = 'clarity' | 'connection' | 'courage' | 'restoration';
type Phase = 'setup' | 'reveal' | 'reflection' | 'saved';
type SunSign =
  | 'Aries'
  | 'Taurus'
  | 'Gemini'
  | 'Cancer'
  | 'Leo'
  | 'Virgo'
  | 'Libra'
  | 'Scorpio'
  | 'Sagittarius'
  | 'Capricorn'
  | 'Aquarius'
  | 'Pisces';

interface FocusOption {
  id: Focus;
  title: string;
  description: string;
  icon: LucideIcon;
}

interface PersistedMap {
  version: 1;
  dayKey: string;
  focus: Focus | null;
  phase: Phase;
  reflection: string;
  savedAt: string | null;
}

const PROFILE_STORAGE_KEY = 'axio7.astrology.profile.v1';
const MAP_STORAGE_KEY = 'axio7.astrology.daily-map.v1';
const MAX_REFLECTION_LENGTH = 1200;

const FOCUS_OPTIONS: readonly FocusOption[] = [
  {
    id: 'clarity',
    title: 'Clarity',
    description: 'Name what is known, assumed, and still unresolved.',
    icon: Compass,
  },
  {
    id: 'connection',
    title: 'Connection',
    description: 'Notice the relationship that deserves patient attention.',
    icon: HeartHandshake,
  },
  {
    id: 'courage',
    title: 'Courage',
    description: 'Find the next honest action without forcing certainty.',
    icon: Sparkles,
  },
  {
    id: 'restoration',
    title: 'Restoration',
    description: 'Make room for recovery, limits, and a gentler pace.',
    icon: MoonStar,
  },
] as const;

const FOCUS_PROMPTS: Record<Focus, readonly string[]> = {
  clarity: [
    'What becomes easier to name when you separate what you know from what you are assuming?',
    'Which unanswered question can remain open today without becoming a demand for certainty?',
    'What detail have you been overlooking because the larger story felt more urgent?',
    'If you removed the need to be right, what would you be willing to examine again?',
  ],
  connection: [
    'Where would listening with fewer prepared answers change the quality of a conversation?',
    'Which relationship could use one specific expression of care rather than a broad promise?',
    'What boundary would make closeness feel more honest and sustainable?',
    'Who helps you feel more like yourself, and how might you acknowledge that today?',
  ],
  courage: [
    'What small, reversible action would let you learn instead of waiting to feel completely ready?',
    'Which truth are you already carrying, even if you have not said it plainly yet?',
    'Where could you choose steadiness over performance today?',
    'What would a brave next step look like if it did not need to be dramatic?',
  ],
  restoration: [
    'What can be made smaller, slower, or simpler so your attention has room to return?',
    'Which signal from your body or environment have you been treating as background noise?',
    'What would enough look like for today, without borrowing standards from another day?',
    'Which unfinished task can you set down deliberately rather than carry unconsciously?',
  ],
};

const SIGN_LENSES: Record<SunSign, string> = {
  Aries: 'initiative',
  Taurus: 'steadiness',
  Gemini: 'curiosity',
  Cancer: 'care',
  Leo: 'expression',
  Virgo: 'discernment',
  Libra: 'balance',
  Scorpio: 'depth',
  Sagittarius: 'perspective',
  Capricorn: 'commitment',
  Aquarius: 'possibility',
  Pisces: 'imagination',
};

const PHASE_STEPS = [
  { title: 'Set intention', shortTitle: 'Setup' },
  { title: 'Reveal prompt', shortTitle: 'Reveal' },
  { title: 'Reflect and save', shortTitle: 'Reflect' },
] as const;

function localDayKey(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function displayDate(dayKey: string): string {
  if (!dayKey) return 'Today';
  const date = new Date(`${dayKey}T12:00:00`);
  return new Intl.DateTimeFormat('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  }).format(date);
}

function isFocus(value: unknown): value is Focus {
  return FOCUS_OPTIONS.some((option) => option.id === value);
}

function isPhase(value: unknown): value is Phase {
  return value === 'setup' || value === 'reveal' || value === 'reflection' || value === 'saved';
}

function approximateWesternSunSign(birthDate: string): SunSign | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(birthDate);
  if (!match) return null;
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;

  if ((month === 3 && day >= 21) || (month === 4 && day <= 19)) return 'Aries';
  if ((month === 4 && day >= 20) || (month === 5 && day <= 20)) return 'Taurus';
  if ((month === 5 && day >= 21) || (month === 6 && day <= 20)) return 'Gemini';
  if ((month === 6 && day >= 21) || (month === 7 && day <= 22)) return 'Cancer';
  if ((month === 7 && day >= 23) || (month === 8 && day <= 22)) return 'Leo';
  if ((month === 8 && day >= 23) || (month === 9 && day <= 22)) return 'Virgo';
  if ((month === 9 && day >= 23) || (month === 10 && day <= 22)) return 'Libra';
  if ((month === 10 && day >= 23) || (month === 11 && day <= 21)) return 'Scorpio';
  if ((month === 11 && day >= 22) || (month === 12 && day <= 21)) return 'Sagittarius';
  if ((month === 12 && day >= 22) || (month === 1 && day <= 19)) return 'Capricorn';
  if ((month === 1 && day >= 20) || (month === 2 && day <= 18)) return 'Aquarius';
  return 'Pisces';
}

function stableIndex(value: string, length: number): number {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0) % length;
}

function dailyPrompt(dayKey: string, sign: SunSign | null, focus: Focus): string {
  const candidates = FOCUS_PROMPTS[focus];
  const prompt = candidates[stableIndex(`${dayKey}|${sign ?? 'no-sign'}|${focus}`, candidates.length)];
  const lens = sign
    ? `Use ${sign} only as a symbolic lens for ${SIGN_LENSES[sign]}.`
    : 'No birth date is needed; use the day itself as your symbolic anchor.';
  return `${lens} ${prompt}`;
}

function focusLabel(focus: Focus | null): string {
  return FOCUS_OPTIONS.find((option) => option.id === focus)?.title ?? 'Not selected';
}

function savedTime(savedAt: string | null): string | null {
  if (!savedAt) return null;
  const date = new Date(savedAt);
  if (Number.isNaN(date.valueOf())) return null;
  return new Intl.DateTimeFormat('en-US', {
    hour: 'numeric',
    minute: '2-digit',
  }).format(date);
}

export function AstrologyApp() {
  const [hydrated, setHydrated] = useState(false);
  const [storageAvailable, setStorageAvailable] = useState(true);
  const [dayKey, setDayKey] = useState('');
  const [birthDate, setBirthDate] = useState('');
  const [focus, setFocus] = useState<Focus | null>(null);
  const [phase, setPhase] = useState<Phase>('setup');
  const [reflection, setReflection] = useState('');
  const [savedAt, setSavedAt] = useState<string | null>(null);
  const [announcement, setAnnouncement] = useState('');
  const stageHeadingRef = useRef<HTMLHeadingElement>(null);

  const approximateSign = useMemo(
    () => approximateWesternSunSign(birthDate),
    [birthDate]
  );
  const prompt = useMemo(
    () => (dayKey && focus ? dailyPrompt(dayKey, approximateSign, focus) : ''),
    [approximateSign, dayKey, focus]
  );
  const activeStep = phase === 'setup' ? 0 : phase === 'reveal' ? 1 : 2;

  useEffect(() => {
    const today = localDayKey(new Date());
    setDayKey(today);

    try {
      const storedProfile = localStorage.getItem(PROFILE_STORAGE_KEY);
      if (storedProfile) {
        const profile = JSON.parse(storedProfile) as { birthDate?: unknown };
        if (typeof profile.birthDate === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(profile.birthDate)) {
          setBirthDate(profile.birthDate);
        }
      }

      const storedMap = localStorage.getItem(MAP_STORAGE_KEY);
      if (storedMap) {
        const map = JSON.parse(storedMap) as Partial<PersistedMap>;
        if (map.version === 1 && map.dayKey === today) {
          const restoredFocus = isFocus(map.focus) ? map.focus : null;
          const restoredPhase = isPhase(map.phase) && restoredFocus ? map.phase : 'setup';
          const restoredReflection =
            typeof map.reflection === 'string'
              ? map.reflection.slice(0, MAX_REFLECTION_LENGTH)
              : '';
          setFocus(restoredFocus);
          setPhase(restoredPhase === 'saved' && !restoredReflection.trim() ? 'reflection' : restoredPhase);
          setReflection(restoredReflection);
          setSavedAt(typeof map.savedAt === 'string' ? map.savedAt : null);
        } else {
          localStorage.removeItem(MAP_STORAGE_KEY);
        }
      }
    } catch {
      setStorageAvailable(false);
    } finally {
      setHydrated(true);
    }
  }, []);

  useEffect(() => {
    if (!hydrated) return;
    try {
      if (birthDate) {
        localStorage.setItem(PROFILE_STORAGE_KEY, JSON.stringify({ version: 1, birthDate }));
      } else {
        localStorage.removeItem(PROFILE_STORAGE_KEY);
      }
    } catch {
      setStorageAvailable(false);
    }
  }, [birthDate, hydrated]);

  useEffect(() => {
    if (!hydrated || !dayKey) return;
    try {
      const map: PersistedMap = {
        version: 1,
        dayKey,
        focus,
        phase,
        reflection,
        savedAt,
      };
      localStorage.setItem(MAP_STORAGE_KEY, JSON.stringify(map));
    } catch {
      setStorageAvailable(false);
    }
  }, [dayKey, focus, hydrated, phase, reflection, savedAt]);

  function focusStageHeading() {
    requestAnimationFrame(() => stageHeadingRef.current?.focus());
  }

  function resetMap(nextFocus: Focus | null = null) {
    setFocus(nextFocus);
    setPhase('setup');
    setReflection('');
    setSavedAt(null);
  }

  function handleBirthDateChange(value: string) {
    if (dayKey && value > dayKey) return;
    setBirthDate(value);
    if (phase !== 'setup') resetMap(focus);
    setAnnouncement(
      value
        ? 'Birth date saved in this browser. The approximate sun sign has been updated.'
        : 'No birth date is saved.'
    );
  }

  function handleDeleteBirthDate() {
    try {
      localStorage.removeItem(PROFILE_STORAGE_KEY);
    } catch {
      setStorageAvailable(false);
    }
    setBirthDate('');
    resetMap(focus);
    setAnnouncement('Birth date deleted from this browser. Return to setup to reveal a new prompt.');
    focusStageHeading();
  }

  function handleReveal() {
    if (!focus || !dayKey) return;
    setPhase('reveal');
    setReflection('');
    setSavedAt(null);
    setAnnouncement('Your Daily Star Map reflection prompt is ready.');
    focusStageHeading();
  }

  function handleOpenReflection() {
    setPhase('reflection');
    setAnnouncement('Reflection editor opened.');
    focusStageHeading();
  }

  function handleSaveReflection() {
    const normalized = reflection.trim();
    if (!normalized) return;
    setReflection(normalized);
    setSavedAt(new Date().toISOString());
    setPhase('saved');
    setAnnouncement(
      storageAvailable
        ? 'Reflection saved in this browser.'
        : 'Reflection kept for this open tab. Browser storage is unavailable.'
    );
    focusStageHeading();
  }

  function handleDeleteReflection() {
    try {
      localStorage.removeItem(MAP_STORAGE_KEY);
    } catch {
      setStorageAvailable(false);
    }
    resetMap(null);
    setAnnouncement('Today\'s reflection deleted from this browser.');
    focusStageHeading();
  }

  return (
    <div className={styles.page}>
      <div className={styles.shell}>
        <header className={styles.hero}>
          <div className={styles.heroCopy}>
            <p className={styles.productLabel}>AXIO7 Astrology · private reflection</p>
            <h1>Daily Star Map</h1>
            <p className={styles.heroDescription}>
              A quiet, browser-only ritual for choosing what deserves your attention today. No
              account, payment, or external service is required.
            </p>
            <ul className={styles.heroAssurances} aria-label="Daily Star Map assurances">
              <li>
                <LockKeyhole size={17} aria-hidden="true" />
                Your entries stay on this device
              </li>
              <li>
                <Eye size={17} aria-hidden="true" />
                Symbolic reflection, never prediction
              </li>
            </ul>
          </div>

          <figure className={styles.artwork}>
            <Image
              src="/ritual-assets/celestial-path.png"
              alt="A candle-gold celestial path connecting four illustrated constellations"
              width={1536}
              height={1024}
              priority
              sizes="(max-width: 760px) 100vw, 46vw"
            />
            <figcaption>The Celestial Path · an illustration for reflection</figcaption>
          </figure>
        </header>

        <section className={styles.workspace} aria-labelledby="map-workspace-title">
          <div className={styles.workspaceHeader}>
            <div>
              <p className={styles.today}>{displayDate(dayKey)}</p>
              <h2 id="map-workspace-title">Your private daily practice</h2>
            </div>
            <div className={styles.localStatus}>
              <LockKeyhole size={16} aria-hidden="true" />
              <span>{storageAvailable ? 'Browser-only storage' : 'This tab only'}</span>
            </div>
          </div>

          <nav className={styles.progress} aria-label="Daily Star Map progress">
            <ol>
              {PHASE_STEPS.map((step, index) => {
                const complete = phase === 'saved' || index < activeStep;
                const current = phase !== 'saved' && index === activeStep;
                return (
                  <li
                    key={step.title}
                    className={`${current ? styles.currentStep : ''} ${complete ? styles.completeStep : ''}`}
                    aria-current={current ? 'step' : undefined}
                  >
                    <span className={styles.stepMark} aria-hidden="true">
                      {complete ? <Check size={15} /> : index + 1}
                    </span>
                    <span className={styles.stepLong}>{step.title}</span>
                    <span className={styles.stepShort}>{step.shortTitle}</span>
                  </li>
                );
              })}
            </ol>
          </nav>

          <aside className={styles.boundary} aria-label="Reflection boundary">
            <ShieldCheck size={22} aria-hidden="true" />
            <div>
              <strong>Reflection prompt — not a forecast</strong>
              <p>
                This is a symbolic journaling aid. It is not evidence, advice, a prediction, or
                guidance for consequential decisions.
              </p>
            </div>
          </aside>

          <div className={styles.profileBar} aria-label="Local birth date status">
            <div>
              <CalendarDays size={18} aria-hidden="true" />
              {birthDate && approximateSign ? (
                <p>
                  Approximate Western sun sign: <strong>{approximateSign}</strong>
                </p>
              ) : (
                <p>No birth date is saved. You can still complete today&apos;s practice.</p>
              )}
            </div>
            {birthDate ? (
              <button type="button" className={styles.deleteButton} onClick={handleDeleteBirthDate}>
                <Trash2 size={16} aria-hidden="true" />
                Delete birth date
              </button>
            ) : null}
          </div>

          <div className={styles.stage}>
            {phase === 'setup' ? (
              <section className={styles.stagePanel} aria-labelledby="setup-heading">
                <div className={styles.stageIntro}>
                  <p>Step one</p>
                  <h2 id="setup-heading" ref={stageHeadingRef} tabIndex={-1}>
                    Set a simple intention
                  </h2>
                  <span>Choose one focus. A birth date is optional.</span>
                </div>

                <form
                  className={styles.setupForm}
                  onSubmit={(event) => {
                    event.preventDefault();
                    handleReveal();
                  }}
                >
                  <div className={styles.birthField}>
                    <div className={styles.fieldHeading}>
                      <label htmlFor="astrology-birth-date">Birth date (optional)</label>
                      <span>Used only for an approximate sun sign</span>
                    </div>
                    <div className={styles.birthRow}>
                      <input
                        id="astrology-birth-date"
                        type="date"
                        max={dayKey || undefined}
                        value={birthDate}
                        onChange={(event) => handleBirthDateChange(event.target.value)}
                        aria-describedby="birth-privacy birth-limit"
                      />
                      <div className={styles.signReadout} aria-live="polite">
                        <span>Approximate Western sun sign</span>
                        <strong>{approximateSign ?? 'Not calculated'}</strong>
                      </div>
                    </div>
                    <p id="birth-privacy" className={styles.privacyCopy}>
                      <LockKeyhole size={15} aria-hidden="true" />
                      Saved only in this browser and never sent to AXIO7. Use “Delete birth date”
                      above to remove it at any time.
                    </p>
                    <p id="birth-limit" className={styles.limitCopy}>
                      Common date ranges provide an approximation only. We do not calculate a natal
                      chart, moon sign, rising sign, compatibility, or forecast.
                    </p>
                  </div>

                  <fieldset className={styles.focusFieldset}>
                    <legend>Choose today&apos;s focus</legend>
                    <div className={styles.focusOptions}>
                      {FOCUS_OPTIONS.map((option) => {
                        const Icon = option.icon;
                        return (
                          <label key={option.id} className={styles.focusOption}>
                            <input
                              type="radio"
                              name="daily-focus"
                              value={option.id}
                              checked={focus === option.id}
                              onChange={() => setFocus(option.id)}
                            />
                            <span className={styles.focusIcon} aria-hidden="true">
                              <Icon size={20} />
                            </span>
                            <span>
                              <strong>{option.title}</strong>
                              <small>{option.description}</small>
                            </span>
                            <span className={styles.radioMark} aria-hidden="true" />
                          </label>
                        );
                      })}
                    </div>
                  </fieldset>

                  <div className={styles.actionRow}>
                    <p>{focus ? `${focusLabel(focus)} selected` : 'Select one focus to continue.'}</p>
                    <button
                      type="submit"
                      className={styles.primaryButton}
                      disabled={!focus || !hydrated}
                    >
                      <Sparkles size={18} aria-hidden="true" />
                      {hydrated ? 'Reveal today\'s map' : 'Preparing today\'s map'}
                      <ArrowRight size={18} aria-hidden="true" />
                    </button>
                  </div>
                </form>
              </section>
            ) : null}

            {phase === 'reveal' ? (
              <section className={styles.stagePanel} aria-labelledby="reveal-heading">
                <div className={styles.stageIntro}>
                  <p>Step two</p>
                  <h2 id="reveal-heading" ref={stageHeadingRef} tabIndex={-1}>
                    Today&apos;s symbolic prompt
                  </h2>
                  <span>
                    {focusLabel(focus)} · {approximateSign ?? 'No sun sign selected'}
                  </span>
                </div>

                <div className={styles.promptBlock}>
                  <BookOpenText size={24} aria-hidden="true" />
                  <div>
                    <p className={styles.promptLabel}>Reflection prompt — not a forecast</p>
                    <p className={styles.promptText}>{prompt}</p>
                  </div>
                </div>

                <div className={styles.actionRow}>
                  <button
                    type="button"
                    className={styles.secondaryButton}
                    onClick={() => {
                      setPhase('setup');
                      setAnnouncement('Returned to setup.');
                      focusStageHeading();
                    }}
                  >
                    <ArrowLeft size={18} aria-hidden="true" />
                    Change setup
                  </button>
                  <button type="button" className={styles.primaryButton} onClick={handleOpenReflection}>
                    Write a reflection
                    <ArrowRight size={18} aria-hidden="true" />
                  </button>
                </div>
              </section>
            ) : null}

            {phase === 'reflection' ? (
              <section className={styles.stagePanel} aria-labelledby="reflection-heading">
                <div className={styles.stageIntro}>
                  <p>Step three</p>
                  <h2 id="reflection-heading" ref={stageHeadingRef} tabIndex={-1}>
                    Put the thought in your own words
                  </h2>
                  <span>Your note remains on this device.</span>
                </div>

                <div className={styles.promptRecap}>
                  <span>Today&apos;s prompt</span>
                  <p>{prompt}</p>
                </div>

                <div className={styles.reflectionField}>
                  <label htmlFor="daily-reflection">Your reflection</label>
                  <textarea
                    id="daily-reflection"
                    value={reflection}
                    maxLength={MAX_REFLECTION_LENGTH}
                    onChange={(event) => setReflection(event.target.value)}
                    placeholder="Write what feels worth remembering. A few sentences are enough."
                    aria-describedby="reflection-help reflection-count"
                  />
                  <div className={styles.textareaMeta}>
                    <p id="reflection-help">Private to this browser. Nothing is submitted.</p>
                    <p id="reflection-count">
                      {reflection.length} / {MAX_REFLECTION_LENGTH}
                    </p>
                  </div>
                </div>

                <div className={styles.actionRow}>
                  <button
                    type="button"
                    className={styles.secondaryButton}
                    onClick={() => {
                      setPhase('reveal');
                      setAnnouncement('Returned to the revealed prompt.');
                      focusStageHeading();
                    }}
                  >
                    <ArrowLeft size={18} aria-hidden="true" />
                    Back to prompt
                  </button>
                  <button
                    type="button"
                    className={styles.primaryButton}
                    disabled={!reflection.trim()}
                    onClick={handleSaveReflection}
                  >
                    <Save size={18} aria-hidden="true" />
                    Save on this device
                  </button>
                </div>
              </section>
            ) : null}

            {phase === 'saved' ? (
              <section className={styles.stagePanel} aria-labelledby="saved-heading">
                <div className={styles.savedHeading}>
                  <CheckCircle2 size={30} aria-hidden="true" />
                  <div>
                    <p>Practice complete</p>
                    <h2 id="saved-heading" ref={stageHeadingRef} tabIndex={-1}>
                      Reflection saved {storageAvailable ? 'in this browser' : 'for this tab'}
                    </h2>
                    <span>
                      {displayDate(dayKey)}
                      {savedTime(savedAt) ? ` · ${savedTime(savedAt)}` : ''}
                    </span>
                  </div>
                </div>

                <div className={styles.savedReflection}>
                  <p className={styles.promptLabel}>Reflection prompt — not a forecast</p>
                  <p className={styles.savedPrompt}>{prompt}</p>
                  <blockquote>{reflection}</blockquote>
                </div>

                <div className={styles.savedActions}>
                  <button
                    type="button"
                    className={styles.secondaryButton}
                    onClick={() => {
                      setPhase('reflection');
                      setAnnouncement('Reflection editor reopened.');
                      focusStageHeading();
                    }}
                  >
                    <BookOpenText size={18} aria-hidden="true" />
                    Edit reflection
                  </button>
                  <button
                    type="button"
                    className={styles.secondaryButton}
                    onClick={() => {
                      resetMap(null);
                      setAnnouncement('A new Daily Star Map setup is ready.');
                      focusStageHeading();
                    }}
                  >
                    <Compass size={18} aria-hidden="true" />
                    Return to setup
                  </button>
                  <button
                    type="button"
                    className={styles.deleteButton}
                    onClick={handleDeleteReflection}
                  >
                    <Trash2 size={16} aria-hidden="true" />
                    Delete today&apos;s reflection
                  </button>
                </div>
              </section>
            ) : null}
          </div>

          {!storageAvailable ? (
            <p className={styles.storageWarning} role="status">
              Browser storage is unavailable. You can still complete the practice, but it will not
              remain after this tab closes.
            </p>
          ) : null}

          <p className={styles.srOnly} aria-live="polite" aria-atomic="true">
            {announcement}
          </p>
        </section>
      </div>
    </div>
  );
}
