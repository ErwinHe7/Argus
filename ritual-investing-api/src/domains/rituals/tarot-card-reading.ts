type TarotCardReading = Readonly<{
  key: string;
  title: string;
  artAlt: string;
  interpretation: string;
  guidance: string;
  counsel: string;
}>;

const DAY_IN_MILLISECONDS = 24 * 60 * 60 * 1000;
const TAROT_EPOCH = Date.UTC(2000, 0, 1);
const TAROT_RISK_FOOTER =
  "Tarot is a reflection tool, not a prediction or financial recommendation.";

const majorArcanaReadings = Object.freeze<TarotCardReading[]>([
  {
    key: "the_fool",
    title: "The Fool",
    artAlt: "The Fool tarot card: a traveler approaches a cliff with a white dog",
    interpretation:
      "The Fool opens a path before certainty has arrived. Curiosity matters, but so does knowing what you have not yet checked.",
    guidance:
      "Choose one unfamiliar idea and list the facts you need before treating it as more than a possibility.",
    counsel:
      "Begin lightly. A first step can be exploratory without becoming a commitment.",
  },
  {
    key: "the_magician",
    title: "The Magician",
    artAlt:
      "The Magician tarot card: a creator raises a wand above an elemental table",
    interpretation:
      "The Magician gathers available tools and turns intention into deliberate action. The question is not whether resources exist, but how clearly they are being used.",
    guidance:
      "Inventory what you already know, what remains uncertain, and which single research step would close the most important gap.",
    counsel:
      "Use what is actually in your hands. Precision is more useful than the appearance of mastery.",
  },
  {
    key: "the_high_priestess",
    title: "The High Priestess",
    artAlt:
      "The High Priestess tarot card: a guardian sits between dark and light pillars",
    interpretation:
      "The High Priestess asks for attention to what is quiet, incomplete, or not yet visible. Missing information deserves space before a conclusion hardens.",
    guidance:
      "Write down the assumption doing the most work in your thinking, then identify what evidence could confirm or challenge it.",
    counsel:
      "You do not need to force clarity. Notice what the available facts have not answered yet.",
  },
  {
    key: "the_empress",
    title: "The Empress",
    artAlt:
      "The Empress tarot card: a crowned figure sits among grain, forest, and flowing water",
    interpretation:
      "The Empress represents patient growth, stewardship, and the conditions that let value compound. Sustainable expansion needs care as well as momentum.",
    guidance:
      "Look for the inputs that support durable growth and note which of them can be observed rather than merely hoped for.",
    counsel:
      "Nurture what can become resilient. Growth that exhausts its foundations is not abundance.",
  },
  {
    key: "the_emperor",
    title: "The Emperor",
    artAlt:
      "The Emperor tarot card: a ruler sits on a ram-carved throne before mountains",
    interpretation:
      "The Emperor brings structure, boundaries, and accountability. A sound framework makes it easier to distinguish conviction from impulse.",
    guidance:
      "Define the rule or limit that should govern your next research decision before emotion supplies one for you.",
    counsel:
      "A boundary is useful when it protects your purpose. Let structure carry the weight that mood cannot.",
  },
  {
    key: "the_hierophant",
    title: "The Hierophant",
    artAlt:
      "The Hierophant tarot card: a mentor blesses two learners above crossed keys",
    interpretation:
      "The Hierophant turns toward established knowledge, shared standards, and trusted instruction. Convention can be a foundation without becoming a cage.",
    guidance:
      "Find the authoritative source behind one claim you have been repeating and compare the source with the shorthand version.",
    counsel:
      "Learn the rule before deciding whether it serves you. Good tradition can preserve hard-won evidence.",
  },
  {
    key: "the_lovers",
    title: "The Lovers",
    artAlt: "The Lovers tarot card: two partners stand beneath a radiant angel",
    interpretation:
      "The Lovers illuminate alignment, values, and consequential choice. A decision becomes clearer when it is measured against what matters most.",
    guidance:
      "Name the value behind your current question and check whether each option is genuinely consistent with it.",
    counsel:
      "Choose from alignment, not attraction alone. The strongest yes is honest about what it excludes.",
  },
  {
    key: "the_chariot",
    title: "The Chariot",
    artAlt:
      "The Chariot tarot card: an armored navigator stands with black and white sphinxes",
    interpretation:
      "The Chariot channels competing forces toward one direction. Progress depends on steady control more than speed.",
    guidance:
      "Separate the signals pulling you in different directions and decide which question must be answered first.",
    counsel:
      "Direction is a discipline. Hold the reins without pretending the opposing forces have disappeared.",
  },
  {
    key: "strength",
    title: "Strength",
    artAlt: "Strength tarot card: a calm woman gently holds a golden lion",
    interpretation:
      "Strength favors patience, composure, and influence without force. Staying present with uncertainty can be more powerful than trying to overpower it.",
    guidance:
      "Notice where urgency is distorting your judgment and give that question one slower, evidence-led review.",
    counsel:
      "Gentleness can be disciplined. You can meet uncertainty without either fleeing it or forcing it quiet.",
  },
  {
    key: "the_hermit",
    title: "The Hermit",
    artAlt:
      "The Hermit tarot card: an elder holds a star lantern on a snowy mountain",
    interpretation:
      "The Hermit narrows the field so a quieter truth can be examined. Distance from the crowd can reveal which conclusions are genuinely your own.",
    guidance:
      "Set aside the prevailing narrative and write the strongest independent reason for and against the idea you are studying.",
    counsel:
      "Let solitude sharpen the question, not isolate you from evidence. Carry only the light you can verify.",
  },
  {
    key: "wheel_of_fortune",
    title: "Wheel of Fortune",
    artAlt:
      "Wheel of Fortune tarot card: a symbolic wheel turns among winged creatures",
    interpretation:
      "Wheel of Fortune points to cycles, changing conditions, and the role of timing. What feels permanent may simply be the current turn of the wheel.",
    guidance:
      "Identify which part of your thesis depends on present conditions continuing and what would change if the cycle turned.",
    counsel:
      "Movement is not destiny. Prepare your thinking for change without pretending you can command the cycle.",
  },
  {
    key: "justice",
    title: "Justice",
    artAlt:
      "Justice tarot card: a crowned judge holds a sword and balanced scales",
    interpretation:
      "Justice asks for proportion, evidence, and responsibility for consequences. A balanced judgment weighs uncomfortable facts as carefully as welcome ones.",
    guidance:
      "List the evidence on both sides of your question and check whether you have held each side to the same standard.",
    counsel:
      "Clarity grows when the scales are honest. Let consequences belong in the decision, not arrive as an afterthought.",
  },
  {
    key: "the_hanged_man",
    title: "The Hanged Man",
    artAlt:
      "The Hanged Man tarot card: a peaceful figure hangs upside down from a living tree",
    interpretation:
      "The Hanged Man creates insight through pause and reversal. A stalled answer may need a different vantage point rather than more force.",
    guidance:
      "Restate your current thesis from the perspective of someone who disagrees with it, then note what becomes newly visible.",
    counsel:
      "Suspension is not failure. A changed angle can reveal what forward motion kept hidden.",
  },
  {
    key: "death",
    title: "Death",
    artAlt: "Death tarot card: a skeletal rider advances on a white horse at sunrise",
    interpretation:
      "Death marks a necessary ending: a pattern has run its course, creating room for a cleaner beginning.",
    guidance:
      "Name one assumption you are ready to release. Write down the evidence that would show an old thesis no longer fits.",
    counsel:
      "Let the ending be information, not catastrophe. Clearing an expired story can make your next question more honest.",
  },
  {
    key: "temperance",
    title: "Temperance",
    artAlt: "Temperance tarot card: an angel pours water between two cups",
    interpretation:
      "Temperance blends opposing elements into a workable whole. Balance is an active practice of calibration, not a motionless midpoint.",
    guidance:
      "Find the two competing considerations in your research and describe a measured approach that respects both.",
    counsel:
      "Adjust before you react. A careful mixture can hold truths that extremes would discard.",
  },
  {
    key: "the_devil",
    title: "The Devil",
    artAlt:
      "The Devil tarot card: a chained pair stands before a horned winged figure",
    interpretation:
      "The Devil exposes attachment, compulsion, and stories that feel binding because they have gone unquestioned. Naming the hold is the beginning of choice.",
    guidance:
      "Identify the fear, habit, or desired outcome that could be biasing your research, then test the thesis without it.",
    counsel:
      "Look directly at the chain. What can be named can be examined, and what can be examined may not own you.",
  },
  {
    key: "the_tower",
    title: "The Tower",
    artAlt: "The Tower tarot card: lightning shatters a crowned tower",
    interpretation:
      "The Tower reveals instability that a familiar structure concealed. Disruption is painful, but it can make weak assumptions impossible to ignore.",
    guidance:
      "Stress-test the foundation of your thesis: write the single fact that, if disproved, would require rebuilding it.",
    counsel:
      "Do not confuse the collapse of an assumption with the collapse of every possibility. Rebuild from what remains true.",
  },
  {
    key: "the_star",
    title: "The Star",
    artAlt: "The Star tarot card: a woman pours water beneath eight stars",
    interpretation:
      "The Star offers renewal, perspective, and hope grounded in openness. After uncertainty, a clear guiding question can restore direction.",
    guidance:
      "Choose the long-term question that still matters after short-term noise fades, and gather one source that speaks directly to it.",
    counsel:
      "Hope is strongest when it can breathe beside reality. Let a distant light guide inquiry, not promise an outcome.",
  },
  {
    key: "the_moon",
    title: "The Moon",
    artAlt:
      "The Moon tarot card: a wolf and dog face the moon between two towers",
    interpretation:
      "The Moon moves through ambiguity, projection, and incomplete visibility. An uncertain path calls for careful observation rather than a confident story.",
    guidance:
      "Separate what you know, what you infer, and what you fear. Do not let those three categories borrow each other's certainty.",
    counsel:
      "Move gently when the landscape is unclear. Imagination can illuminate possibilities, but it cannot certify facts.",
  },
  {
    key: "the_sun",
    title: "The Sun",
    artAlt: "The Sun tarot card: a joyful child rides beneath a radiant sun",
    interpretation:
      "The Sun brings visibility, vitality, and direct understanding. Clarity is an invitation to see the whole picture, including limits that optimism might skip.",
    guidance:
      "State the clearest fact supporting your view and the clearest remaining risk in equally plain language.",
    counsel:
      "Welcome what is illuminated. Confidence becomes steadier when nothing important has to hide in its shadow.",
  },
  {
    key: "judgement",
    title: "Judgement",
    artAlt:
      "Judgement tarot card: an angel sounds a trumpet as people rise",
    interpretation:
      "Judgement calls for an honest review of what has been learned and what must change. Reflection becomes useful when it informs a more accountable next chapter.",
    guidance:
      "Revisit one past decision, record what the outcome taught you, and name the rule you would carry forward.",
    counsel:
      "Answer the lesson without turning it into punishment. A clear reckoning can release you from repeating the same story.",
  },
  {
    key: "the_world",
    title: "The World",
    artAlt: "The World tarot card: a dancer floats within a laurel wreath",
    interpretation:
      "The World marks integration, completion, and a wider view of the journey. Finishing well includes understanding how the pieces now relate.",
    guidance:
      "Summarize what your research has established, what remains open, and the condition that would justify revisiting the question.",
    counsel:
      "Let completion be whole rather than absolute. Close the circle while leaving room for the world to keep changing.",
  },
]);

function positiveModulo(value: number, divisor: number): number {
  return ((value % divisor) + divisor) % divisor;
}

export function dailyTarotReading(localDate: string): TarotCardReading {
  const [year, month, day] = localDate.split("-").map(Number);
  const dayNumber = Math.floor(
    (Date.UTC(year!, month! - 1, day) - TAROT_EPOCH) / DAY_IN_MILLISECONDS,
  );
  return majorArcanaReadings[
    positiveModulo(dayNumber, majorArcanaReadings.length)
  ]!;
}

export function replaceLegacyDailyTarotProjection(
  assignment: Record<string, unknown>,
): Record<string, unknown> {
  const payload = assignment.payload;
  if (
    assignment.mode !== "tarot" ||
    typeof assignment.local_date !== "string" ||
    typeof payload !== "object" ||
    payload === null ||
    Array.isArray(payload) ||
    (payload as Record<string, unknown>).art_key !== "the_compass"
  ) {
    return { ...assignment };
  }

  const card = dailyTarotReading(assignment.local_date);
  return {
    ...assignment,
    payload: {
      ...payload,
      title: card.title,
      art_key: card.key,
      art_alt: card.artAlt,
      interpretation: card.interpretation,
      guidance: card.guidance,
      market_label: "Tarot reflection",
      observation_at: `${assignment.local_date}T12:00:00Z`,
      uncertainty: TAROT_RISK_FOOTER,
      idea_asset_ids: [],
      evidence_claim_ids: [],
      ideas: [],
      evidence: [],
    },
    body_template: card.counsel,
    allowed_tokens: [],
    risk_footer: TAROT_RISK_FOOTER,
  };
}
