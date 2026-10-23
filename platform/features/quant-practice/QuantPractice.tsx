import React, { useEffect, useRef, useState } from 'react';
import { ArrowLeft, ArrowRight, BookOpen, Check, CheckCircle2, ChevronDown, Clock3, Download, Lightbulb, RotateCcw, Upload } from 'lucide-react';
import { catalog, type Challenge } from './content';
import { ChapterLab } from './Labs';
import { emptyProgress, mergeProgress, parseNumericAnswer, parseProgress, PROGRESS_KEY, recordAnswer, recordExposure, recordLab, type PracticeProgress } from './progress';
import './practice.css';

const questions = catalog.chapters.flatMap(chapter => chapter.challenges);
const questionIds = new Set(questions.map(question => question.id));
const chapterFromHash = () => {
  const candidate = Number(new URLSearchParams(location.hash.split('?')[1]).get('chapter'));
  return catalog.chapters.some(chapter => chapter.number === candidate) ? candidate : 2;
};
function loadProgress(): { progress: PracticeProgress; notice: string; canSave: boolean } {
  try {
    const raw = localStorage.getItem(PROGRESS_KEY);
    return { progress: raw ? parseProgress(raw, questionIds) : emptyProgress(), notice: '', canSave: true };
  } catch {
    return { progress: emptyProgress(), notice: 'Saved progress could not be read. This session still works; export your progress before leaving. Existing saved data has been left intact.', canSave: false };
  }
}
function exportProgress(progress: PracticeProgress) {
  const blob = new Blob([JSON.stringify(progress, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob), anchor = document.createElement('a');
  anchor.href = url; anchor.download = `leo-practice-${new Date().toISOString().slice(0, 10)}.json`; anchor.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
type View = 'lab' | 'practice' | 'review';
export function QuantPractice() {
  const [initial] = useState(loadProgress), [progress, setProgress] = useState(initial.progress);
  const [notice, setNotice] = useState(initial.notice), [canSave, setCanSave] = useState(initial.canSave);
  const [chapterNumber, setChapterNumber] = useState(chapterFromHash), [view, setView] = useState<View>('lab');
  const [position, setPosition] = useState(0), [timed, setTimed] = useState(true), [confirmReset, setConfirmReset] = useState(false);
  const [resetGeneration, setResetGeneration] = useState(0);
  const [reviewIds, setReviewIds] = useState<string[]>([]), input = useRef<HTMLInputElement>(null);
  const [importMessage, setImportMessage] = useState('');
  const chapter = catalog.chapters.find(row => row.number === chapterNumber)!;
  const completed = questions.filter(q => progress.answers[q.id]?.completed).length;
  const review = questions.filter(q => progress.answers[q.id]?.needsReview);
  const chapterDone = chapter.challenges.filter(q => progress.answers[q.id]?.completed).length;
  const visibleQuestions = view === 'review' ? reviewIds.map(id => questions.find(q => q.id === id)).filter((q): q is Challenge => Boolean(q)) : chapter.challenges;
  const question = visibleQuestions[Math.min(position, Math.max(0, visibleQuestions.length - 1))];
  useEffect(() => {
    const change = () => { const next = chapterFromHash(); setChapterNumber(next); setPosition(0); setView('lab'); };
    window.addEventListener('hashchange', change); return () => window.removeEventListener('hashchange', change);
  }, []);
  useEffect(() => {
    if (!canSave) return;
    try { localStorage.setItem(PROGRESS_KEY, JSON.stringify(progress)); }
    catch { setCanSave(false); setNotice('This browser could not save progress. Keep learning, then export before leaving.'); }
  }, [progress, canSave]);
  const chooseChapter = (number: number) => {
    setChapterNumber(number); setPosition(0); setView('lab'); setImportMessage('');
    history.replaceState(null, '', `#/learn?chapter=${number}`);
  };
  const openReview = () => { setReviewIds(review.map(q => q.id)); setPosition(0); setView('review'); };
  const onLabComplete = (id: string) => setProgress(previous => recordLab(previous, id));
  const onExposure = (id: string) => setProgress(previous => recordExposure(previous, id));
  const onAnswer = (id: string, correct: boolean, assisted: boolean) => setProgress(previous => recordAnswer(previous, id, correct, assisted));
  const importFile = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]; event.target.value = '';
    if (!file) return;
    try {
      if (file.size > 200000) throw new Error('This file is too large to be a progress export.');
      const incoming = parseProgress(await file.text(), questionIds);
      setProgress(previous => mergeProgress(previous, incoming));
      setImportMessage('Progress merged. For overlapping exercises, the newer record was kept.');
    } catch (error) { setImportMessage(error instanceof Error ? error.message : 'This progress file could not be read.'); }
  };
  return <section className="tool-body learn" aria-label="Chapter learning companion">
    <div className="learn-title"><h1>Quant practice</h1><p>Explore each Green Book chapter, then test the idea under a clock.</p></div>
    <div className="learn-toolbar"><p><BookOpen size={16}/><b>{completed} of {questions.length}</b> exercises completed <span>· {progress.labs.length} lab levels completed</span></p><div><button onClick={openReview} className="learn-review-button"><RotateCcw size={14}/>Review mistakes <span>{review.length}</span></button><details className="learn-save"><summary>Saved progress<ChevronDown size={14}/></summary><div><p>{canSave ? 'Saved automatically in this browser. Export to keep a copy or move devices.' : 'Session only. Export to keep this session.'}</p><button onClick={() => exportProgress(progress)}><Download size={14}/>Export progress</button><button onClick={() => input.current?.click()}><Upload size={14}/>Import &amp; merge</button><button onClick={() => setConfirmReset(true)}><RotateCcw size={14}/>Clear practice progress</button></div></details><input ref={input} type="file" accept="application/json,.json" aria-label="Import practice progress" onChange={importFile} hidden/></div></div>
    {notice && <p className="notice" role="status">{notice}</p>}
    {importMessage && <p className="learn-message" role="status">{importMessage}</p>}
    {confirmReset && <div className="learn-reset" role="group" aria-label="Confirm clearing progress"><p>Clear this practice app’s exercise history and completed labs? Export a copy first if you want to keep it.</p><button onClick={() => { setProgress(emptyProgress()); setConfirmReset(false); setCanSave(true); setNotice(''); setResetGeneration(value => value + 1); }} className="gold-button">Clear practice progress</button><button onClick={() => setConfirmReset(false)}>Keep my progress</button></div>}
    <div className="learn-mobile-chapter"><label htmlFor="learn-chapter">Book chapter</label><select id="learn-chapter" value={chapterNumber} onChange={event => chooseChapter(Number(event.target.value))}>{catalog.chapters.map(row => <option key={row.id} value={row.number}>{row.number}. {row.title}</option>)}</select></div>
    <div className="learn-layout"><aside className="learn-syllabus"><h2>Work through the book</h2><p>Seven chapters. All open.</p><nav aria-label="Book chapters">{catalog.chapters.map(row => { const done = row.challenges.filter(q => progress.answers[q.id]?.completed).length; return <button key={row.id} onClick={() => chooseChapter(row.number)} aria-current={chapterNumber === row.number ? 'step' : undefined}><span className="learn-chapter-number">{row.number}</span><span><b>{row.title}</b><small>{done} / {row.challenges.length} exercises</small></span>{done === row.challenges.length && <Check size={14}/>}</button>; })}</nav><p className="learn-syllabus-note">Start with the lab. Explain your reasoning before checking an answer. Return to anything you needed help with.</p></aside>
      <div className="learn-workspace"><div className="learn-chapter-heading"><div><h2>{view === 'review' ? 'Revisit your mistakes' : chapter.title}</h2><p>{view === 'review' ? 'Questions you missed or used help with. Work through them again before revealing the solution.' : chapter.description}</p></div>{view !== 'review' && <span>{chapterDone}/{chapter.challenges.length} completed</span>}</div>
        <div className="learn-tabs" role="group" aria-label="Practice activity"><button aria-pressed={view === 'lab'} onClick={() => { setView('lab'); setPosition(0); }}>Play the lab</button><button aria-pressed={view === 'practice'} onClick={() => { setView('practice'); setPosition(0); }}>Practise concepts <span>{chapter.challenges.length}</span></button><button aria-pressed={view === 'review'} onClick={openReview}>Review <span>{review.length}</span></button></div>
        {view === 'lab' ? <><ChapterLab key={`${chapter.number}:${resetGeneration}`} chapter={chapter.number} onComplete={onLabComplete}/><div className="learn-lab-next"><p>Ready to put the idea into words and numbers?</p><button className="gold-button" onClick={() => { setView('practice'); setPosition(0); }}>Practise this chapter<ArrowRight size={16}/></button></div></> : question ? <><div className="learn-question-toolbar"><p>{position + 1} of {visibleQuestions.length} · {question.concept}</p><label><input type="checkbox" checked={timed} onChange={event => setTimed(event.target.checked)}/>90-second challenge</label></div><Exercise key={`${view}:${question.id}:${resetGeneration}`} question={question} timed={timed} record={progress.answers[question.id]} onAnswer={onAnswer} onExposure={onExposure}/><div className="learn-question-navigation"><button disabled={position === 0} onClick={() => setPosition(index => index - 1)}><ArrowLeft size={16}/>Previous</button><p>{view === 'review' ? 'Review queue keeps its place while you practise.' : `Chapter ${chapter.number} · ${question.section}`}</p><button onClick={() => setPosition(index => (index + 1) % visibleQuestions.length)}>{position === visibleQuestions.length - 1 ? 'Back to first' : 'Next exercise'}<ArrowRight size={16}/></button></div><details className="learn-exercise-list"><summary>Choose an exercise</summary><ol>{visibleQuestions.map((row, index) => <li key={row.id}><button aria-current={position === index ? 'step' : undefined} onClick={() => setPosition(index)}>{row.concept}{progress.answers[row.id]?.completed && <Check size={14}/>}</button></li>)}</ol></details></> : <div className="learn-empty"><CheckCircle2 size={32}/><h3>No questions waiting for review</h3><p>Missed questions and exercises where you use hints appear here. Pick a chapter to keep learning.</p><button className="gold-button" onClick={() => setView('lab')}>Return to the lab</button></div>}
      </div></div>
    <details className="learn-about"><summary>About this learning companion</summary><p>Original exercises organised around the seven chapters of Xinfeng Zhou’s <cite>A Practical Guide to Quantitative Finance Interviews</cite>. Use the book for the complete treatment; this is an independent learning companion.</p><p>Exercises use fictional teaching examples and offline-computed solutions. Completion records practice activity, not certified mastery or interview readiness. Progress stays in this browser; it is separate from your LEO account and can be exported.</p><p><a href={catalog.provenance.outlineUrl} target="_blank" rel="noreferrer">Chapter outline source</a></p></details>
  </section>;
}

function Exercise({question, timed, record, onAnswer, onExposure}: { question: Challenge; timed: boolean; record?: PracticeProgress['answers'][string]; onAnswer: (id: string, correct: boolean, assisted: boolean) => void; onExposure: (id: string) => void }) {
  const [choice, setChoice] = useState(''), [numeric, setNumeric] = useState(''), [hintCount, setHintCount] = useState(0);
  const [solution, setSolution] = useState(false), [feedback, setFeedback] = useState<'correct' | 'wrong' | 'invalid' | null>(null), [hadWrong, setHadWrong] = useState(false);
  const [lastAssisted, setLastAssisted] = useState(false);
  const [deadline, setDeadline] = useState<number | null>(null), [remaining, setRemaining] = useState(90);
  const feedbackRef = useRef<HTMLDivElement>(null);
  useEffect(() => { setDeadline(null); setRemaining(90); }, [timed]);
  useEffect(() => {
    if (!timed || deadline === null) return;
    const tick = () => setRemaining(Math.max(0, Math.ceil((deadline - Date.now()) / 1000)));
    tick(); const interval = setInterval(tick, 250); return () => clearInterval(interval);
  }, [timed, deadline]);
  const assisted = hintCount > 0 || solution || hadWrong;
  const check = (event: React.FormEvent) => {
    event.preventDefault(); if (feedback === 'correct' || solution) return;
    const value = question.type === 'numeric' ? parseNumericAnswer(numeric, question.answer.unit) : undefined;
    if ((question.type === 'choice' && !choice) || (question.type === 'numeric' && value === undefined)) { setFeedback('invalid'); return; }
    const correct = question.type === 'choice' ? choice === question.answer.choiceId : Math.abs(value! - question.answer.numericValue!) <= (question.answer.tolerance ?? 0.000001);
    setFeedback(correct ? 'correct' : 'wrong'); setLastAssisted(assisted); setHadWrong(previous => previous || !correct);
    onAnswer(question.id, correct, assisted); if (correct) { setDeadline(null); setSolution(true); }
    setTimeout(() => feedbackRef.current?.focus(), 0);
  };
  const reveal = () => { setSolution(true); setDeadline(null); onExposure(question.id); };
  return <article className="learn-exercise" aria-labelledby="learn-prompt"><div className="learn-exercise-meta"><span>{question.level} · {question.type === 'numeric' ? 'Your calculation' : 'Choose your reasoning'}</span>{record?.needsReview && <span>Marked for review</span>}</div>
    {timed && <div className="learn-timer"><Clock3 size={15}/>{solution ? <span>Challenge ended</span> : deadline === null ? <button onClick={() => { setRemaining(90); setDeadline(Date.now() + 90000); }}>Start 90-second timer</button> : <span>{remaining === 0 ? 'Time is up. You can keep solving.' : `${remaining}s remaining`}</span>}</div>}
    <h3 id="learn-prompt">{question.prompt}</h3>
    <form onSubmit={check}>{question.type === 'choice' ? <fieldset className="learn-choices"><legend className="learn-sr-only">Choose an answer</legend>{question.choices?.map((option, index) => <label key={option.id} className={choice === option.id ? 'selected' : ''}><input type="radio" name={`answer-${question.id}`} value={option.id} checked={choice === option.id} disabled={solution} onChange={() => { setChoice(option.id); setFeedback(null); }}/><span className="learn-option-letter" aria-hidden>{String.fromCharCode(65 + index)}</span><span>{option.label}</span></label>)}</fieldset> : <div className="learn-numeric"><label htmlFor="learn-number">Your answer{question.answer.unit ? ` (${question.answer.unit})` : ''}</label><input id="learn-number" type="text" inputMode="text" autoComplete="off" placeholder="Number or fraction, e.g. 1/4" value={numeric} disabled={solution} onChange={event => { setNumeric(event.target.value); setFeedback(null); }}/><p>Fractions and scientific notation work.{question.answer.unit === 'probability' ? ' For probability, 1/4, 0.25 and 25% are equivalent.' : ''}</p></div>}
      {!solution && <button className="gold-button" type="submit">Check my answer<ArrowRight size={15}/></button>}</form>
    {feedback && <div ref={feedbackRef} tabIndex={-1} className={`learn-feedback ${feedback}`} role="status"><b>{feedback === 'correct' ? lastAssisted ? 'Correct with practice. Revisit it later.' : 'Correct. Now check the reasoning.' : feedback === 'wrong' ? 'Not yet. Try another approach.' : question.type === 'choice' ? 'Choose an answer first.' : 'Enter a finite number or fraction.'}</b>{feedback === 'wrong' && <p>It’s been added to review. Use a hint if you need a new starting point.</p>}</div>}
    {!solution && <div className="learn-help"><button disabled={hintCount >= question.hints.length} onClick={() => { setHintCount(count => count + 1); onExposure(question.id); }}><Lightbulb size={15}/>{hintCount ? 'Next hint' : 'Give me a hint'} <span>{Math.min(hintCount, question.hints.length)}/{question.hints.length}</span></button><button onClick={reveal}>Show worked solution</button></div>}
    {hintCount > 0 && <ol className="learn-hints">{question.hints.slice(0, hintCount).map((hint, index) => <li key={index}>{hint}</li>)}</ol>}
    {solution && <section className="learn-solution" aria-label="Worked solution"><div><CheckCircle2 size={19}/><h4>Answer: {question.answer.display}</h4></div><p>{question.explanation}</p><ol>{question.workedSteps.map((step, index) => <li key={index}>{step}</li>)}</ol><p className="learn-takeaway"><b>Keep this idea:</b> {question.takeaway}</p><button onClick={() => { setSolution(false); setFeedback(null); setChoice(''); setNumeric(''); setHintCount(question.hints.length); }}>Try again with the solution in mind<RotateCcw size={14}/></button></section>}
  </article>;
}
