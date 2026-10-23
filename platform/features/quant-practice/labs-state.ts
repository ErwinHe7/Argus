/** Original, fixed educational fixtures. No market inputs or inference. */
export type ColorCounts = readonly [number, number, number];
export type ColorPair = readonly [0 | 1 | 2, 0 | 1 | 2];

export function meetChameleons(counts: ColorCounts, pair: ColorPair): ColorCounts | null {
  const [a, b] = pair;
  if (a === b || counts[a] < 1 || counts[b] < 1) return null;
  const next = [...counts] as [number, number, number];
  next[a] -= 1;
  next[b] -= 1;
  next[3 - a - b] += 2;
  return next;
}

export function isUniform(counts: ColorCounts): boolean {
  return counts.filter((count) => count > 0).length === 1;
}

export function moveReasoningStep(steps: readonly string[], index: number, delta: -1 | 1): string[] {
  const target = index + delta;
  if (index < 0 || index >= steps.length || target < 0 || target >= steps.length) return [...steps];
  const next = [...steps];
  [next[index], next[target]] = [next[target], next[index]];
  return next;
}

export const REASONING_ORDER = ["goal", "assumptions", "model", "check", "explain"] as const;
export const REASONING_START = ["model", "explain", "goal", "check", "assumptions"];

export function isReasoningOrdered(steps: readonly string[]): boolean {
  return steps.length === REASONING_ORDER.length && steps.every((step, index) => step === REASONING_ORDER[index]);
}

export const SEARCH_NUMBERS = [3, 7, 11, 19, 23, 31, 37, 43, 47, 59, 67, 71, 83, 89, 97] as const;
export const SEARCH_TARGET = 37;
export type SearchState = { low: number; high: number; comparisons: number; found: boolean; message: string };
export const INITIAL_SEARCH: SearchState = { low: 0, high: SEARCH_NUMBERS.length - 1, comparisons: 0, found: false, message: "Choose the middle index of the active range." };

export function searchStep(state: SearchState, chosen: number): SearchState {
  if (state.found) return state;
  const middle = Math.floor((state.low + state.high) / 2);
  if (chosen !== middle) return { ...state, message: `The middle index is floor((${state.low} + ${state.high}) / 2). Try that cell.` };
  const value = SEARCH_NUMBERS[chosen];
  const comparisons = state.comparisons + 1;
  if (value === SEARCH_TARGET) return { ...state, comparisons, found: true, message: `Found ${SEARCH_TARGET} at index ${chosen}. Four comparisons, fifteen starting values.` };
  if (value < SEARCH_TARGET) return { ...state, comparisons, low: chosen + 1, message: `${value} is below ${SEARCH_TARGET}. Discard it and everything to its left.` };
  return { ...state, comparisons, high: chosen - 1, message: `${value} is above ${SEARCH_TARGET}. Discard it and everything to its right.` };
}

export const BAYES_CASES = [
  { id: "red-marble", title: "A red marble appears", prior: "Each bag is equally likely: 1/2 each.", observation: "You draw one red marble, then replace it.", bags: [{ name: "Bag A", marbles: ["red", "red", "red", "blue"], likelihood: "P(red | A) = 3/4" }, { name: "Bag B", marbles: ["red", "blue", "blue", "blue"], likelihood: "P(red | B) = 1/4" }], denominator: 4, answer: 3, result: "3/4", explanation: "With equal prior weights, the red observation is three times as likely from A. Normalize the weights 3 : 1 to get P(A | red) = 3/4.", labels: ["0", "1/4", "1/2", "3/4", "1"] },
  { id: "strong-evidence", title: "Stronger evidence", prior: "Each bag is equally likely: 1/2 each.", observation: "Again, the observed marble is red.", bags: [{ name: "Bag A", marbles: ["red", "red", "red", "red", "blue"], likelihood: "P(red | A) = 4/5" }, { name: "Bag B", marbles: ["red", "blue", "blue", "blue", "blue"], likelihood: "P(red | B) = 1/5" }], denominator: 5, answer: 4, result: "4/5", explanation: "The likelihood ratio is 4 : 1. Equal priors keep those relative weights, so the posterior probability of A is 4/5.", labels: ["0", "1/5", "2/5", "3/5", "4/5", "1"] },
  { id: "unequal-priors", title: "The prior pushes back", prior: "Bag A is chosen with probability 1/3; Bag B with probability 2/3.", observation: "The observed marble is red. Account for both the prior and the evidence.", bags: [{ name: "Bag A", marbles: ["red", "red", "blue"], likelihood: "P(red | A) = 2/3" }, { name: "Bag B", marbles: ["red", "blue", "blue"], likelihood: "P(red | B) = 1/3" }], denominator: 2, answer: 1, result: "1/2", explanation: "The joint weights are (1/3)(2/3) = 2/9 for A and (2/3)(1/3) = 2/9 for B. Equal weights give P(A | red) = 1/2. The likelihood alone is not the posterior.", labels: ["0", "1/2", "1"] },
] as const;

export const VECTOR_CASES = [
  { title: "Stretch one axis", matrix: "A = [[2, 0], [0, 1]]", vector: "v = (1, 0)", image: "Av = (2, 0)", input: [40, 0], output: [80, 0], sameLine: true, explanation: "Av = 2v. The vector stays on its original line, so v is an eigenvector with eigenvalue 2." },
  { title: "A direction that turns", matrix: "A = [[2, 0], [0, 1]]", vector: "v = (1, 1)", image: "Av = (2, 1)", input: [40, 40], output: [80, 40], sameLine: false, explanation: "One coordinate doubles while the other does not. There is no single scalar λ with Av = λv, so this v is not an eigenvector." },
  { title: "Reverse can still qualify", matrix: "A = [[0, 1], [1, 0]]", vector: "v = (1, −1)", image: "Av = (−1, 1)", input: [48, -48], output: [-48, 48], sameLine: true, explanation: "Av = −v. Opposite direction still lies on the same line: v is an eigenvector with eigenvalue −1." },
] as const;

export const WEATHER_PATHS = {
  "clear-clear": { weight: "9/16", detail: "(3/4) × (3/4) = 9/16", final: "Clear" },
  "clear-cloudy": { weight: "3/16", detail: "(3/4) × (1/4) = 3/16", final: "Cloudy" },
  "cloudy-clear": { weight: "2/16", detail: "(1/4) × (1/2) = 2/16", final: "Clear" },
  "cloudy-cloudy": { weight: "2/16", detail: "(1/4) × (1/2) = 2/16", final: "Cloudy" },
} as const;

export const PAYOFF_CASES = [
  { id: "call", title: "A right to buy at 50", prompt: "Choose the payoff that belongs to a long call with strike 50.", answer: "call", formula: "max(S − 50, 0)", explanation: "A call pays nothing when the terminal price is at or below its strike. Above 50, each extra unit of price adds one unit of gross payoff." },
  { id: "straddle", title: "Movement in either direction", prompt: "Choose the payoff for a long call and a long put, both with strike 50.", answer: "straddle", formula: "|S − 50|", explanation: "This is a long straddle. The put supplies the left arm; the call supplies the right arm. Its smallest gross payoff is at the shared strike." },
  { id: "spread", title: "An upside payoff with a ceiling", prompt: "Choose the payoff for a long 45 call and a short 55 call.", answer: "spread", formula: "max(S − 45, 0) − max(S − 55, 0)", explanation: "The long call starts paying above 45. The short call offsets additional gains above 55, so the gross payoff is capped at 10." },
] as const;

/** Authored gross-payoff samples and matching SVG geometry; premiums excluded. */
export const PAYOFF_SAMPLE_PRICES = [30, 40, 50, 60, 70] as const;
export const PAYOFF_CURVES = [
  { id: "call", label: "A", points: "20,112 75,112 130,112 185,66 240,20", description: "Zero through price 50, then rises in a straight line", values: [0, 0, 0, 10, 20] },
  { id: "put", label: "B", points: "20,20 75,66 130,112 185,112 240,112", description: "Falls in a straight line to zero at price 50, then stays zero", values: [20, 10, 0, 0, 0] },
  { id: "straddle", label: "C", points: "20,20 75,66 130,112 185,66 240,20", description: "V-shaped, with zero payoff at price 50 and equal rises on either side", values: [20, 10, 0, 10, 20] },
  { id: "spread", label: "D", points: "20,112 102.5,112 157.5,20 240,20", description: "Zero through price 45, rises to payoff 10 at price 55, then stays flat", values: [0, 0, 5, 10, 10] },
] as const;
