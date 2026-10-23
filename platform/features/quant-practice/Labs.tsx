import React, { useState } from "react";
import { ArrowDown, ArrowRight, ArrowUp, Check, Lightbulb, RotateCcw, Undo2 } from "lucide-react";
import { BAYES_CASES, INITIAL_SEARCH, PAYOFF_CASES, PAYOFF_CURVES, PAYOFF_SAMPLE_PRICES, REASONING_START, SEARCH_NUMBERS, SEARCH_TARGET, VECTOR_CASES, WEATHER_PATHS, isReasoningOrdered, isUniform, meetChameleons, moveReasoningStep, searchStep, type ColorCounts, type ColorPair } from "./labs-state";
import "./labs.css";

type LabProps = { onComplete: (labId: string) => void };
type ChapterLabProps = LabProps & { chapter: number };

function Feedback({ children, success = false }: { children: React.ReactNode; success?: boolean }) {
  return <div className={`qp-lab-feedback${success ? " is-success" : ""}`} role="status" aria-live="polite">{success && <Check size={18} aria-hidden="true" />}<div>{children}</div></div>;
}

function Hint({ children }: { children: React.ReactNode }) {
  return <details className="qp-lab-hint"><summary><Lightbulb size={16} aria-hidden="true" /> Need a hint?</summary><p>{children}</p></details>;
}

function LabShell({ title, description, children }: { title: string; description: string; children: React.ReactNode }) {
  return <section className="qp-lab" aria-label={title}><header className="qp-lab-header"><h3>{title}</h3><p>{description}</p></header>{children}</section>;
}

const REASONING_CARDS: Record<string, { title: string; description: string }> = {
  goal: { title: "Restate the goal", description: "What are we being asked to find?" },
  assumptions: { title: "Name the assumptions", description: "What is known, and what needs clarification?" },
  model: { title: "Build a small model", description: "Choose a simple representation and work through it." },
  check: { title: "Test the result", description: "Check a tiny example, a boundary, or an extreme case." },
  explain: { title: "Explain the tradeoffs", description: "Summarize the answer, limitations, and alternatives." },
};

function ReasoningLab({ onComplete }: LabProps) {
  const [steps, setSteps] = useState<string[]>([...REASONING_START]);
  const [message, setMessage] = useState("");
  const [solved, setSolved] = useState(false);
  const check = () => {
    const correct = isReasoningOrdered(steps);
    setSolved(correct);
    setMessage(correct ? "A clear answer starts with a clear question. This is one useful interview structure; real conversations can loop back when an assumption changes." : "Try again. Clarify the goal and assumptions before building a model; check it before presenting your conclusion.");
    if (correct) onComplete("chapter-1-reasoning");
  };
  return <LabShell title="Build a reasoning ladder" description="Put these five steps into a useful order for an unfamiliar interview problem. Use the arrows to move a step.">
    <ol className="qp-lab-reasoning">{steps.map((id, index) => <li key={id}><span className="qp-lab-step-number" aria-hidden="true">{index + 1}</span><div><strong>{REASONING_CARDS[id].title}</strong><p>{REASONING_CARDS[id].description}</p></div><div className="qp-lab-move-controls"><button type="button" aria-label={`Move ${REASONING_CARDS[id].title} up`} disabled={index === 0 || solved} onClick={() => { setSteps(moveReasoningStep(steps, index, -1)); setMessage(""); }}><ArrowUp size={17} /></button><button type="button" aria-label={`Move ${REASONING_CARDS[id].title} down`} disabled={index === steps.length - 1 || solved} onClick={() => { setSteps(moveReasoningStep(steps, index, 1)); setMessage(""); }}><ArrowDown size={17} /></button></div></li>)}</ol>
    <div className="qp-lab-actions"><button type="button" className="qp-lab-primary" disabled={solved} onClick={check}>Check my order <Check size={16} /></button><button type="button" onClick={() => { setSteps([...REASONING_START]); setMessage(""); setSolved(false); }}><RotateCcw size={16} /> Reset</button></div>
    {message && <Feedback success={solved}>{message}</Feedback>}
    <Hint>Restating and clarifying come first. A model needs a check before you explain why the answer makes sense.</Hint>
  </LabShell>;
}

const COLORS = ["Red", "Green", "Blue"];
const COLOR_PAIRS: { pair: ColorPair; label: string; result: string }[] = [
  { pair: [0, 1], label: "Red + green", result: "2 blue" },
  { pair: [0, 2], label: "Red + blue", result: "2 green" },
  { pair: [1, 2], label: "Green + blue", result: "2 red" },
];

function ChameleonLab({ onComplete }: LabProps) {
  const [mode, setMode] = useState<"practice" | "book">("practice");
  const [history, setHistory] = useState<ColorCounts[]>([[2, 2, 2]]);
  const [hypothesis, setHypothesis] = useState<"possible" | "impossible" | null>(null);
  const [proof, setProof] = useState<string | null>(null);
  const counts = history[history.length - 1];
  const uniform = isUniform(counts);
  const reset = (next: "practice" | "book") => { setMode(next); setHistory([next === "practice" ? [2, 2, 2] : [13, 15, 17]]); setHypothesis(null); setProof(null); };
  const move = (pair: ColorPair) => {
    const next = meetChameleons(counts, pair);
    if (!next) return;
    setHistory([...history, next]);
    if (isUniform(next)) onComplete("chapter-2-chameleons");
  };
  return <LabShell title="Chameleon island" description="When two different colors meet, both become the third color. Can you turn the whole island one color?">
    <div className="qp-lab-tabs" aria-label="Chameleon starting position"><button type="button" aria-pressed={mode === "practice"} onClick={() => reset("practice")}>First, solve 2 · 2 · 2</button><button type="button" aria-pressed={mode === "book"} onClick={() => reset("book")}>Then, test 13 · 15 · 17</button></div>
    <div className="qp-lab-island" aria-label={`Island population: ${counts[0]} red, ${counts[1]} green, ${counts[2]} blue`}>{counts.map((count, index) => <div key={COLORS[index]} className={`qp-lab-population color-${index}`}><span className="qp-lab-color-swatch" /><strong>{count}</strong><span>{COLORS[index]}</span></div>)}</div>
    <div className="qp-lab-pair-buttons">{COLOR_PAIRS.map(({ pair, label, result }) => <button type="button" key={label} disabled={uniform || counts[pair[0]] === 0 || counts[pair[1]] === 0} onClick={() => move(pair)}><span>{label}</span><ArrowRight size={16} aria-hidden="true" /><strong>{result}</strong></button>)}</div>
    <div className="qp-lab-actions"><span className="qp-lab-count">{history.length - 1} meetings</span><button type="button" disabled={history.length < 2} onClick={() => setHistory(history.slice(0, -1))}><Undo2 size={16} /> Undo</button><button type="button" onClick={() => reset(mode)}><RotateCcw size={16} /> Restart island</button></div>
    {uniform && <Feedback success>One color! Try the 13 · 15 · 17 island next. A successful small example does not prove that every starting position can be solved.</Feedback>}
    {mode === "book" && <div className="qp-lab-proof"><h4>Make a claim, then prove it</h4><p>Can an island starting at 13 red, 15 green, and 17 blue ever reach one color?</p><div className="qp-lab-choices qp-lab-choice-row"><button type="button" aria-pressed={hypothesis === "possible"} onClick={() => { setHypothesis("possible"); setProof(null); }}>Yes, a sequence exists</button><button type="button" aria-pressed={hypothesis === "impossible"} onClick={() => setHypothesis("impossible")}>No, it is impossible</button></div>{hypothesis === "possible" && <Feedback>Trying moves can suggest an answer, but it cannot establish that a sequence exists. These counts have a preserved property that blocks the goal. Try the other claim, then identify that property.</Feedback>}{hypothesis === "impossible" && <><p className="qp-lab-proof-prompt">Which invariant proves your claim?</p><div className="qp-lab-choices">{[{ id: "total", text: "The population stays at 45" }, { id: "difference", text: "Pairwise count differences keep their residues modulo 3" }, { id: "odd", text: "Every color starts with an odd count" }].map((choice) => <button type="button" key={choice.id} aria-pressed={proof === choice.id} onClick={() => { setProof(choice.id); if (choice.id === "difference") onComplete("chapter-2-chameleons"); }}>{choice.text}</button>)}</div>{proof && <Feedback success={proof === "difference"}>{proof === "difference" ? "Exactly. Each pairwise difference changes by 0 or ±3. Initially the differences are not all divisible by 3. A uniform population of 45 has all differences divisible by 3, so it is unreachable." : "That property alone does not rule out a uniform island. Look for a property of the differences between color counts that survives every meeting."}</Feedback>}</>}</div>}
    <Hint>A meeting subtracts 1 from two counts and adds 2 to the third. Watch what happens to the differences between counts, rather than the counts alone.</Hint>
  </LabShell>;
}

function VectorLab({ onComplete }: LabProps) {
  const [round, setRound] = useState(0);
  const [answer, setAnswer] = useState<boolean | null>(null);
  const [finished, setFinished] = useState(false);
  const item = VECTOR_CASES[round];
  const correct = answer === item.sameLine;
  const advance = () => { if (round < VECTOR_CASES.length - 1) { setRound(round + 1); setAnswer(null); } else { setFinished(true); onComplete("chapter-3-eigenvectors"); } };
  return <LabShell title="Will the vector turn?" description="An eigenvector stays on the same line after a matrix transformation. It may stretch, shrink, or reverse direction.">
    <div className="qp-lab-round"><strong>{item.title}</strong><span>Direction {round + 1} of {VECTOR_CASES.length}</span></div>
    <div className="qp-lab-vector-layout"><div className="qp-lab-matrix"><code>{item.matrix}</code><code>{item.vector}</code><p>Predict the direction of Av.</p>{answer !== null && <code className="qp-lab-reveal">{item.image}</code>}</div><svg className="qp-lab-vector-svg" viewBox="0 0 280 240" role="img" aria-label={`Input vector ${item.vector}${answer !== null ? `, transformed vector ${item.image}` : ". Choose an answer to reveal its transformation."}`}><defs><marker id="qp-vector-input" markerWidth="7" markerHeight="7" refX="5" refY="3" orient="auto"><path d="M0,0 L0,6 L6,3 z" fill="currentColor" /></marker><marker id="qp-vector-output" markerWidth="7" markerHeight="7" refX="5" refY="3" orient="auto"><path d="M0,0 L0,6 L6,3 z" fill="currentColor" /></marker></defs><line x1="20" y1="120" x2="260" y2="120" className="qp-lab-axis" /><line x1="140" y1="15" x2="140" y2="225" className="qp-lab-axis" /><text x="262" y="135">x</text><text x="150" y="22">y</text><line x1="140" y1="120" x2={140 + item.input[0]} y2={120 - item.input[1]} className="qp-lab-vector-input" markerEnd="url(#qp-vector-input)" />{answer !== null && <line x1="140" y1="120" x2={140 + item.output[0]} y2={120 - item.output[1]} className="qp-lab-vector-output" markerEnd="url(#qp-vector-output)" />}<circle cx="140" cy="120" r="3" className="qp-lab-origin" /></svg></div>
    <p className="qp-lab-legend"><span><i className="qp-lab-legend-input" /> Original v</span><span><i className="qp-lab-legend-output" /> Transformed Av {answer === null ? "(hidden)" : ""}</span></p>
    <div className="qp-lab-choices qp-lab-choice-row"><button type="button" disabled={finished} aria-pressed={answer === true} onClick={() => setAnswer(true)}>Stays on the same line</button><button type="button" disabled={finished} aria-pressed={answer === false} onClick={() => setAnswer(false)}>Turns onto a different line</button></div>
    {answer !== null && <Feedback success={correct}>{correct ? item.explanation : "Look at the two arrows. An eigenvector needs one scalar to map both coordinates: Av = λv. Try the other prediction."}</Feedback>}
    {correct && !finished && <div className="qp-lab-actions"><button type="button" className="qp-lab-primary" onClick={advance}>{round === VECTOR_CASES.length - 1 ? "Finish direction lab" : "Next direction"}<ArrowRight size={16} /></button></div>}
    {finished && <Feedback success>Three transformations understood. A negative eigenvalue reverses direction; it does not disqualify the eigenvector.</Feedback>}
    <Hint>“Same line” includes an arrow pointing in the exact opposite direction. Compare the ratios between corresponding coordinates.</Hint>
  </LabShell>;
}

function BayesLab({ onComplete }: LabProps) {
  const [round, setRound] = useState(0);
  const [answer, setAnswer] = useState<number | null>(null);
  const [checked, setChecked] = useState(false);
  const [finished, setFinished] = useState(false);
  const item = BAYES_CASES[round];
  const correct = checked && answer === item.answer;
  const advance = () => { if (round < BAYES_CASES.length - 1) { setRound(round + 1); setAnswer(null); setChecked(false); } else { setFinished(true); onComplete("chapter-4-bayes"); } };
  return <LabShell title="Update your belief" description="Choose the hidden bag's probability after seeing evidence. Each round changes the evidence or the prior.">
    <div className="qp-lab-round"><strong>{item.title}</strong><span>Update {round + 1} of {BAYES_CASES.length}</span></div><p className="qp-lab-prior">{item.prior}</p>
    <div className="qp-lab-bags">{item.bags.map((bag) => <div key={bag.name} className="qp-lab-bag"><h4>{bag.name}</h4><div className="qp-lab-marbles" aria-label={bag.marbles.join(", ")}>{bag.marbles.map((color, index) => <span key={index} className={`qp-lab-marble marble-${color}`} aria-hidden="true">{color === "red" ? "R" : "B"}</span>)}</div><p>{bag.likelihood}</p></div>)}</div>
    <div className="qp-lab-observation"><span className="qp-lab-marble marble-red" aria-hidden="true">R</span><p>{item.observation}</p></div>
    <fieldset className="qp-lab-fieldset"><legend>What is P(Bag A | red)?</legend><div className="qp-lab-probability-options">{item.labels.map((label, index) => <button type="button" key={label} disabled={finished || correct} aria-pressed={answer === index} onClick={() => { setAnswer(index); setChecked(false); }}>{label}</button>)}</div></fieldset>
    {!correct && <div className="qp-lab-actions"><button type="button" className="qp-lab-primary" disabled={answer === null} onClick={() => setChecked(true)}>Reveal the update<Check size={16} /></button></div>}
    {checked && <Feedback success={correct}>{correct ? item.explanation : "Keep the prior in the calculation. Compare prior × likelihood for each bag, then normalize those two weights. Choose again."}</Feedback>}
    {correct && !finished && <div className="qp-lab-actions"><button type="button" className="qp-lab-primary" onClick={advance}>{round === BAYES_CASES.length - 1 ? "Finish belief lab" : "Next evidence"}<ArrowRight size={16} /></button></div>}
    {finished && <Feedback success>All three updates complete. Evidence changes your belief through the prior; the likelihood by itself is not the posterior.</Feedback>}
    <Hint>Use P(A | red) ∝ P(A) × P(red | A). Compute a weight for both bags before turning the weights into probabilities.</Hint>
  </LabShell>;
}

function MarkovLab({ onComplete }: LabProps) {
  const [path, setPath] = useState<("clear" | "cloudy")[]>([]);
  const [seen, setSeen] = useState<string[]>([]);
  const [answer, setAnswer] = useState<string | null>(null);
  const current = path.length ? path[path.length - 1] : "clear";
  const pathKey = path.join("-") as keyof typeof WEATHER_PATHS;
  const detail = path.length === 2 ? WEATHER_PATHS[pathKey] : null;
  const choose = (weather: "clear" | "cloudy") => {
    const next = [...path, weather]; setPath(next);
    if (next.length === 2 && !seen.includes(next.join("-"))) setSeen([...seen, next.join("-")]);
  };
  return <LabShell title="Walk a two-day chain" description="Tomorrow depends only on today's weather in this fictional two-state model. Explore the routes, then combine the right ones.">
    <div className="qp-lab-transition-table"><table><caption>Fixed transition probabilities</caption><thead><tr><th scope="col">Today</th><th scope="col">Tomorrow: clear</th><th scope="col">Tomorrow: cloudy</th></tr></thead><tbody><tr><th scope="row">Clear</th><td>3/4</td><td>1/4</td></tr><tr><th scope="row">Cloudy</th><td>1/2</td><td>1/2</td></tr></tbody></table></div>
    <div className="qp-lab-weather-path" aria-label="Selected weather path"><span>Today<strong>Clear</strong></span><ArrowRight size={20} aria-hidden="true" /><span>Day 1<strong>{path[0] ? path[0] === "clear" ? "Clear" : "Cloudy" : "Choose below"}</strong></span><ArrowRight size={20} aria-hidden="true" /><span>Day 2<strong>{path[1] ? path[1] === "clear" ? "Clear" : "Cloudy" : "Choose below"}</strong></span></div>
    {path.length < 2 ? <div className="qp-lab-choices qp-lab-choice-row"><button type="button" onClick={() => choose("clear")}>Next: clear <span>{current === "clear" ? "3/4" : "1/2"}</span></button><button type="button" onClick={() => choose("cloudy")}>Next: cloudy <span>{current === "clear" ? "1/4" : "1/2"}</span></button></div> : <div className="qp-lab-path-result"><strong>This path's weight: {detail?.weight}</strong><p>{detail?.detail}</p><button type="button" onClick={() => setPath([])}><RotateCcw size={16} /> Explore another path</button></div>}
    {seen.length > 0 && <div className="qp-lab-path-ledger"><h4>Paths you explored</h4><ul>{seen.map((key) => <li key={key}><span>Clear → {key.split("-").map((part) => part === "clear" ? "Clear" : "Cloudy").join(" → ")}</span><strong>{WEATHER_PATHS[key as keyof typeof WEATHER_PATHS].weight}</strong></li>)}</ul></div>}
    <fieldset className="qp-lab-fieldset"><legend>Starting clear, what is P(clear in two days)?</legend><div className="qp-lab-probability-options">{["3/4", "11/16", "1/2", "9/16"].map((option) => <button type="button" key={option} aria-pressed={answer === option} onClick={() => { setAnswer(option); if (option === "11/16") onComplete("chapter-5-markov"); }}>{option}</button>)}</div></fieldset>
    {answer && <Feedback success={answer === "11/16"}>{answer === "11/16" ? "There are two disjoint routes ending clear: clear → clear → clear contributes 9/16; clear → cloudy → clear contributes 2/16. Add them to get 11/16." : "Include every two-step route that ends clear. Multiply along one route, then add the weights of those disjoint routes."}</Feedback>}
    <Hint>There is a route through cloudy on day 1 that still ends clear on day 2. Do not count only the always-clear route.</Hint>
  </LabShell>;
}

function PayoffLab({ onComplete }: LabProps) {
  const [round, setRound] = useState(0);
  const [answer, setAnswer] = useState<string | null>(null);
  const [checked, setChecked] = useState(false);
  const [finished, setFinished] = useState(false);
  const item = PAYOFF_CASES[round];
  const correct = checked && answer === item.answer;
  const advance = () => { if (round < PAYOFF_CASES.length - 1) { setRound(round + 1); setAnswer(null); setChecked(false); } else { setFinished(true); onComplete("chapter-6-payoffs"); } };
  return <LabShell title="Match the payoff" description="Read a contract, then choose its shape at expiry. These are gross payoffs before premiums, fees, or financing.">
    <div className="qp-lab-round"><strong>{item.title}</strong><span>Contract {round + 1} of {PAYOFF_CASES.length}</span></div><p className="qp-lab-prior">{item.prompt}</p>
    <div className="qp-lab-curves">{PAYOFF_CURVES.map((curve) => <button type="button" key={curve.id} aria-label={`Choose curve ${curve.label}: ${curve.description}`} aria-pressed={answer === curve.id} disabled={finished || correct} onClick={() => { setAnswer(curve.id); setChecked(false); }}><strong>Curve {curve.label}</strong><svg viewBox="0 0 260 150" role="img" aria-label={`Curve ${curve.label}: ${curve.description}`}><line x1="20" y1="112" x2="244" y2="112" className="qp-lab-axis" /><line x1="20" y1="12" x2="20" y2="117" className="qp-lab-axis" /><polyline points={curve.points} className="qp-lab-payoff-line" /><text x="11" y="130">30</text><text x="66" y="130">40</text><text x="121" y="130">50</text><text x="176" y="130">60</text><text x="231" y="130">70</text><text x="8" y="107">0</text></svg></button>)}</div>
    <p className="qp-lab-caption">Horizontal axis: terminal price S · Vertical axis: gross payoff. Each panel uses its own vertical scale.</p>
    <details className="qp-lab-curve-values"><summary>Read the curve values</summary><div className="qp-lab-transition-table"><table><caption>Gross payoff at each terminal price, before premiums</caption><thead><tr><th scope="col">Curve</th>{PAYOFF_SAMPLE_PRICES.map((price) => <th scope="col" key={price}>S = {price}</th>)}</tr></thead><tbody>{PAYOFF_CURVES.map((curve) => <tr key={curve.id}><th scope="row">{curve.label}</th>{curve.values.map((value, index) => <td key={index}>{value}</td>)}</tr>)}</tbody></table></div></details>
    {!correct && <div className="qp-lab-actions"><button type="button" className="qp-lab-primary" disabled={answer === null} onClick={() => setChecked(true)}>Check this curve<Check size={16} /></button></div>}
    {checked && <Feedback success={correct}>{correct ? <><code>{item.formula}</code><p>{item.explanation}</p></> : "Trace the payoff below, between, and above the strikes. A short option subtracts its payoff. Try another curve."}</Feedback>}
    {correct && !finished && <div className="qp-lab-actions"><button type="button" className="qp-lab-primary" onClick={advance}>{round === PAYOFF_CASES.length - 1 ? "Finish payoff lab" : "Next contract"}<ArrowRight size={16} /></button></div>}
    {finished && <Feedback success>Three payoff shapes matched. Gross payoff is not profit: subtracting the premium changes the break-even points.</Feedback>}
    <Hint>A call responds to prices above its strike; a put responds to prices below it. Add long legs and subtract short legs.</Hint>
  </LabShell>;
}

function SearchLab({ onComplete }: LabProps) {
  const [state, setState] = useState(INITIAL_SEARCH);
  const choose = (index: number) => { const next = searchStep(state, index); setState(next); if (next.found) onComplete("chapter-7-binary-search"); };
  return <LabShell title="Cut the search space in half" description="Find 37 in the sorted array. At every turn, choose the middle index of the active range; the comparison tells you which half to discard.">
    <div className="qp-lab-search-summary"><span>Target <strong>{SEARCH_TARGET}</strong></span><span>Active indices <strong>{state.low}–{state.high}</strong></span><span>Comparisons <strong>{state.comparisons}</strong></span></div>
    <div className="qp-lab-array" aria-label="Sorted search array">{SEARCH_NUMBERS.map((number, index) => <button type="button" key={number} className={state.found && index === state.low ? "is-found" : ""} disabled={state.found || index < state.low || index > state.high} aria-label={`Index ${index}, value ${number}${index < state.low || index > state.high ? ", discarded" : ""}`} onClick={() => choose(index)}><small>{index}</small><strong>{number}</strong></button>)}</div>
    <Feedback success={state.found}>{state.message}</Feedback>
    <div className="qp-lab-actions"><button type="button" onClick={() => setState(INITIAL_SEARCH)}><RotateCcw size={16} /> Start again</button></div>
    <Hint>Use middle = floor((low + high) / 2). After a miss, exclude the tested middle itself: low = middle + 1 or high = middle − 1.</Hint>
    {state.found && <div className="qp-lab-proof"><h4>Why it scales</h4><p>Each comparison removes roughly half the remaining candidates. The sorted-array assumption makes that safe; applying this rule to an unsorted array would fail.</p><code>while low &lt;= high: compare a[(low + high) // 2]</code></div>}
  </LabShell>;
}

export function ChapterLab({ chapter, onComplete }: ChapterLabProps) {
  const labs = [ReasoningLab, ChameleonLab, VectorLab, BayesLab, MarkovLab, PayoffLab, SearchLab];
  const Lab = labs[chapter - 1];
  return Lab ? <Lab key={chapter} onComplete={onComplete} /> : null;
}
