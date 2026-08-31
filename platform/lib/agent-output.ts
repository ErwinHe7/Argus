const NON_ANSWER_PATTERNS = [
  /^\s*[\[(]?\s*no response\b/i,
  /^\s*[\[(]?\s*no tactical step\b/i,
  /topic unrelated/i,
  /query unrelated/i,
  /unrelated to (startup )?building/i,
  /does(n't| not) (cover|touch).*building\/launching\/fundraising/i,
];

export function cleanAgentReply(content: string | null | undefined): string {
  return (content ?? '').trim();
}

export function isNonAnswerReply(content: string | null | undefined): boolean {
  const cleaned = cleanAgentReply(content);
  if (!cleaned) return true;
  return NON_ANSWER_PATTERNS.some((pattern) => pattern.test(cleaned));
}
