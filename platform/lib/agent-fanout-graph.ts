import * as Sentry from '@sentry/nextjs';
import { Annotation, END, StateGraph } from '@langchain/langgraph';
import { AGENTS } from './agents';
import { chatWithUsage } from './llm';
import { cleanAgentReply, isNonAnswerReply } from './agent-output';
import { buildFanoutContext } from './agent-fanout-context';
import {
  acquireDedupeKey,
  DEFAULT_AGENT_RETRY_POLICY,
  dedupeKeyForReply,
  isNearDuplicate,
  moderateText,
  providerKeyForAgent,
  replyTexts,
  retryFeedbackPrompt,
  runLimitedByProvider,
  runWithRetry,
  scoreAgentReply,
  type FailedAgent,
  type GeneratedAgentOutput,
  type RuleQualityScore,
  type SkippedAgent,
} from './agent-graph-utils';
import { estimateCost } from './observability/pricing';
import { createReply, getPost, incrementLike, listReplies } from './store';
import { flushTraces, startPostTrace, tracedLLMCall, type TraceContext } from './observability/llm-tracer';
import type { AgentPersona, Post, Reply } from './types';

export type GraphFanoutResult = {
  succeeded: number;
  failed: number;
  totalLatencyMs: number;
  totalCostUsd: number;
};

export type GraphFanoutAdapterOptions = {
  mentionedAgentId?: string;
  agentIds?: string[];
  source?: 'api' | 'cron' | 'admin';
  force?: boolean;
  dryRun?: boolean;
  onPublishStarted?: () => void;
};

type PublishAction = {
  agentId: string;
  text: string;
  dedupeKey: string;
  action: 'publish' | 'review' | 'drop';
};

const FanoutState = Annotation.Root({
  mode: Annotation<'fanout'>({ default: () => 'fanout', reducer: (_, v) => v }),
  source: Annotation<'api' | 'cron' | 'admin'>({ default: () => 'api', reducer: (_, v) => v }),
  postId: Annotation<string>(),
  mentionedAgentId: Annotation<string | undefined>({ default: () => undefined, reducer: (_, v) => v }),
  agentIds: Annotation<string[] | undefined>({ default: () => undefined, reducer: (_, v) => v }),
  force: Annotation<boolean>({ default: () => false, reducer: (_, v) => v }),
  dryRun: Annotation<boolean>({ default: () => false, reducer: (_, v) => v }),

  post: Annotation<Post | null>({ default: () => null, reducer: (_, v) => v }),
  user: Annotation<null>({ default: () => null, reducer: (_, v) => v }),
  existingReplies: Annotation<Reply[]>({ default: () => [], reducer: (_, v) => v }),

  feedContext: Annotation<string>({ default: () => '', reducer: (_, v) => v }),
  tradeContext: Annotation<string | null>({ default: () => null, reducer: (_, v) => v }),
  eventContext: Annotation<string | null>({ default: () => null, reducer: (_, v) => v }),
  userContent: Annotation<string>({ default: () => '', reducer: (_, v) => v }),

  selectedAgents: Annotation<string[]>({ default: () => [], reducer: (_, v) => v }),
  agentOutputs: Annotation<GeneratedAgentOutput[]>({ default: () => [], reducer: (_, v) => v }),
  qualityScores: Annotation<Record<string, RuleQualityScore>>({ default: () => ({}), reducer: (_, v) => v }),
  publishActions: Annotation<PublishAction[]>({ default: () => [], reducer: (_, v) => v }),
  failedAgents: Annotation<FailedAgent[]>({ default: () => [], reducer: (_, v) => v }),
  skippedAgents: Annotation<SkippedAgent[]>({ default: () => [], reducer: (_, v) => v }),
  persistedAgentIds: Annotation<string[]>({ default: () => [], reducer: (_, v) => v }),

  totalCostUsd: Annotation<number>({ default: () => 0, reducer: (_, v) => v }),
  startedAt: Annotation<number>({ default: () => Date.now(), reducer: (_, v) => v }),
  publishStarted: Annotation<boolean>({ default: () => false, reducer: (_, v) => v }),
  persistCompleted: Annotation<boolean>({ default: () => false, reducer: (_, v) => v }),
  publishStartedCallback: Annotation<(() => void) | undefined>({ default: () => undefined, reducer: (_, v) => v }),
  critiqueRetryCount: Annotation<number>({ default: () => 0, reducer: (_, v) => v }),
});

type S = typeof FanoutState.State;

function agentById(agentId: string): AgentPersona | undefined {
  return AGENTS.find((agent) => agent.id === agentId);
}

function orderedAgents(agentIds?: string[], mentionedAgentId?: string): AgentPersona[] {
  const selected = agentIds && agentIds.length > 0
    ? AGENTS.filter((agent) => agentIds.includes(agent.id))
    : [...AGENTS];
  if (mentionedAgentId) {
    const idx = selected.findIndex((agent) => agent.id === mentionedAgentId);
    if (idx > 0) {
      const [mentioned] = selected.splice(idx, 1);
      selected.unshift(mentioned);
    }
    if (idx !== -1) {
      console.log(`[fanout:graph] @mention detected - running ${mentionedAgentId} first`);
    }
  }
  return selected.slice(0, 7);
}

async function loadContextNode(state: S): Promise<Partial<S>> {
  const post = await getPost(state.postId);
  if (!post) throw new Error(`post ${state.postId} not found`);
  const existingReplies = await listReplies(state.postId).catch(() => [] as Reply[]);
  return { post, existingReplies };
}

async function retrieveContextNode(state: S): Promise<Partial<S>> {
  const context = await buildFanoutContext(state.post!.content);
  return {
    feedContext: context.feedContext,
    tradeContext: context.tradeContext,
    eventContext: context.eventContext,
    userContent: context.userContent,
  };
}

function selectAgentsNode(state: S): Partial<S> {
  const selectedAgents = orderedAgents(state.agentIds, state.mentionedAgentId).map((agent) => agent.id);
  return { selectedAgents };
}

async function recoverFanoutReply(
  agent: AgentPersona,
  userContent: string,
): Promise<{ content: string; costUsd: number }> {
  const result = await chatWithUsage(
    [
      {
        role: 'system',
        content: `${agent.system_prompt}

Important: never output "No response", "topic unrelated", or any refusal placeholder. If the post is vague or outside your specialty, still give a grounded practical take that fits the post.`,
      },
      { role: 'user', content: userContent },
    ],
    {
      model: agent.id === 'ember' ? 'openai/gpt-4o-mini' : agent.model,
      temperature: 0.7,
      max_tokens: 260,
    },
  );
  const costUsd = result.usage
    ? estimateCost(agent.model ?? '', result.usage.prompt_tokens ?? 0, result.usage.completion_tokens ?? 0)
    : 0;
  return { content: cleanAgentReply(result.content), costUsd };
}

function retryUserContent(baseUserContent: string, previousDraft: string, score: RuleQualityScore): string {
  return `${baseUserContent}

Previous draft:
"""${previousDraft}"""

${retryFeedbackPrompt(score)}`;
}

async function generateFanoutReply(input: {
  agent: AgentPersona;
  post: Post;
  userContent: string;
  traceCtx: TraceContext;
  retryScore?: RuleQualityScore;
  previousDraft?: string;
}): Promise<{ text: string; costUsd: number }> {
  const retrying = Boolean(input.retryScore);
  const userContent = retrying
    ? retryUserContent(input.userContent, input.previousDraft ?? '', input.retryScore!)
    : input.userContent;

  const result = await tracedLLMCall(
    input.agent,
    input.post.content,
    () =>
      chatWithUsage(
        [
          { role: 'system', content: input.agent.system_prompt },
          { role: 'user', content: userContent },
        ],
        {
          model: input.agent.model,
          temperature: retrying ? 0.65 : 0.8,
          max_tokens: retrying
            ? 160
            : input.agent.model?.includes('nemotron') || input.agent.model?.includes('kimi')
              ? 800
              : 220,
          presence_penalty: retrying && input.retryScore ? input.retryScore.specificity < 14 ? 0.3 : undefined : undefined,
        },
      ),
    input.traceCtx,
  );

  let text = cleanAgentReply(result.content);
  let costUsd = result.costUsd;
  if (!retrying && (!text || isNonAnswerReply(text))) {
    const recovered = await recoverFanoutReply(input.agent, input.userContent);
    text = recovered.content;
    costUsd += recovered.costUsd;
  }
  if (!text || isNonAnswerReply(text)) throw new Error('empty completion');
  return { text, costUsd };
}

async function runAgentsParallelNode(state: S): Promise<Partial<S>> {
  const traceCtx = startPostTrace(state.postId, state.post!.author_id);
  const deadline = state.startedAt + 60_000;
  const selectedAgents = state.selectedAgents
    .map(agentById)
    .filter((agent): agent is AgentPersona => Boolean(agent));

  const results = await runLimitedByProvider(
    selectedAgents,
    providerKeyForAgent,
    async (agent) => {
      if (Date.now() >= deadline) throw new Error('fanout_total_budget_exceeded');
      const startedAt = Date.now();
      const result = await runWithRetry(
        async () => generateFanoutReply({ agent, post: state.post!, userContent: state.userContent, traceCtx }),
        DEFAULT_AGENT_RETRY_POLICY,
      );
      return {
        agentId: agent.id,
        attempt: result.attempts,
        text: result.value.text,
        latencyMs: Date.now() - startedAt,
        costUsd: result.value.costUsd,
      } satisfies GeneratedAgentOutput;
    },
    { maxConcurrency: 3, providerConcurrency: 2 },
  );

  const agentOutputs: GeneratedAgentOutput[] = [];
  const failedAgents: FailedAgent[] = [...state.failedAgents];
  let totalCostUsd = state.totalCostUsd;

  results.forEach((result, index) => {
    const agentId = selectedAgents[index]?.id ?? 'unknown';
    if (result.status === 'fulfilled') {
      agentOutputs.push(result.value);
      totalCostUsd += result.value.costUsd ?? 0;
      return;
    }
    const retryable = String(result.reason?.message ?? '').includes('timeout') ||
      [429, 500, 502, 503, 504].includes(Number(result.reason?.status));
    failedAgents.push({
      agentId,
      reason: result.reason?.message ?? String(result.reason),
      retryable,
      attempts: DEFAULT_AGENT_RETRY_POLICY.maxAttempts,
    });
    Sentry.captureException(result.reason, { extra: { post_id: state.postId, agent_id: agentId, graph: 'fanout' } });
  });

  return { agentOutputs, failedAgents, totalCostUsd };
}

function dedupeAndModerateNode(state: S): Partial<S> {
  const qualityScores: Record<string, RuleQualityScore> = { ...state.qualityScores };
  const skippedAgents: SkippedAgent[] = [...state.skippedAgents];
  const seenTexts = [...replyTexts(state.existingReplies)];

  for (const output of state.agentOutputs) {
    if (!output.text) continue;
    const agent = agentById(output.agentId);
    if (isNearDuplicate(output.text, seenTexts, 0.62)) {
      qualityScores[output.agentId] = {
        total: 0,
        relevance: 0,
        specificity: 0,
        personaFit: 0,
        novelty: 0,
        safety: 10,
        format: 0,
        reasons: ['novelty: duplicate existing reply or another generated reply'],
        action: 'drop',
      };
      skippedAgents.push({ agentId: output.agentId, reason: 'duplicate_reply' });
      continue;
    }

    const moderation = moderateText(output.text);
    if (moderation.action !== 'pass') {
      qualityScores[output.agentId] = scoreAgentReply({
        text: output.text,
        sourceText: state.post!.content,
        agent,
        existingTexts: seenTexts,
      });
      qualityScores[output.agentId].action = moderation.action === 'drop' ? 'drop' : 'review';
      qualityScores[output.agentId].reasons.push(`safety: ${moderation.reason ?? moderation.action}`);
    }
    seenTexts.push(output.text);
  }

  return { qualityScores, skippedAgents };
}

function critiqueNode(state: S): Partial<S> {
  if (process.env.AGENT_LLM_CRITIQUE_ENABLED === 'true') {
    console.warn('[fanout:graph] AGENT_LLM_CRITIQUE_ENABLED is ignored in Phase 1; using rules');
  }
  const qualityScores: Record<string, RuleQualityScore> = { ...state.qualityScores };
  const existingTexts = replyTexts(state.existingReplies);
  for (const output of state.agentOutputs) {
    if (!output.text || qualityScores[output.agentId]?.action === 'drop') continue;
    const agent = agentById(output.agentId);
    qualityScores[output.agentId] = scoreAgentReply({
      text: output.text,
      sourceText: state.post!.content,
      agent,
      existingTexts,
      maxWords: 70,
    });
  }
  return { qualityScores };
}

async function retryLowQualityOnceNode(state: S): Promise<Partial<S>> {
  const traceCtx = startPostTrace(state.postId, state.post!.author_id);
  const agentOutputs = [...state.agentOutputs];
  const qualityScores: Record<string, RuleQualityScore> = { ...state.qualityScores };
  let totalCostUsd = state.totalCostUsd;
  let critiqueRetryCount = state.critiqueRetryCount;

  for (const output of state.agentOutputs) {
    const score = qualityScores[output.agentId];
    if (!output.text || score?.action !== 'retry') continue;
    const agent = agentById(output.agentId);
    if (!agent) continue;
    try {
      const result = await runWithRetry(
        async () =>
          generateFanoutReply({
            agent,
            post: state.post!,
            userContent: state.userContent,
            traceCtx,
            retryScore: score,
            previousDraft: output.text,
          }),
        { ...DEFAULT_AGENT_RETRY_POLICY, maxAttempts: 1 },
      );
      totalCostUsd += result.value.costUsd;
      critiqueRetryCount++;
      const retried: GeneratedAgentOutput = {
        agentId: output.agentId,
        attempt: 2,
        text: result.value.text,
        latencyMs: result.latencyMs,
        costUsd: result.value.costUsd,
      };
      const index = agentOutputs.findIndex((item) => item.agentId === output.agentId);
      if (index >= 0) agentOutputs[index] = retried;
      qualityScores[output.agentId] = scoreAgentReply({
        text: result.value.text,
        sourceText: state.post!.content,
        agent,
        existingTexts: [...replyTexts(state.existingReplies), output.text],
        maxWords: 70,
      });
    } catch (error: any) {
      qualityScores[output.agentId] = { ...score, action: 'review', reasons: [...score.reasons, 'retry: failed to regenerate'] };
    }
  }

  return { agentOutputs, qualityScores, totalCostUsd, critiqueRetryCount };
}

function decidePublishNode(state: S): Partial<S> {
  const publishActions: PublishAction[] = [];
  for (const output of state.agentOutputs) {
    if (!output.text) continue;
    const score = state.qualityScores[output.agentId];
    const action = state.dryRun
      ? 'drop'
      : score?.action === 'publish' || state.force
        ? 'publish'
        : score?.action === 'review' || score?.action === 'retry'
          ? 'review'
          : 'drop';
    publishActions.push({
      agentId: output.agentId,
      text: output.text,
      dedupeKey: dedupeKeyForReply(state.postId, output.agentId, 'fanout'),
      action,
    });
  }
  return { publishActions };
}

async function persistNode(state: S): Promise<Partial<S>> {
  if (state.dryRun) return { persistCompleted: true };

  let publishStarted = state.publishStarted;
  const persistedAgentIds: string[] = [...state.persistedAgentIds];
  const failedAgents: FailedAgent[] = [...state.failedAgents];
  const skippedAgents: SkippedAgent[] = [...state.skippedAgents];

  for (const action of state.publishActions) {
    if (action.action !== 'publish') {
      skippedAgents.push({ agentId: action.agentId, reason: action.action });
      continue;
    }
    if (!publishStarted) {
      publishStarted = true;
      state.publishStartedCallback?.();
    }
    const acquired = await acquireDedupeKey(action.dedupeKey);
    if (!acquired) {
      skippedAgents.push({ agentId: action.agentId, reason: 'dedupe_key_exists' });
      continue;
    }
    const agent = agentById(action.agentId);
    if (!agent) {
      failedAgents.push({ agentId: action.agentId, reason: 'agent_not_found', retryable: false, attempts: 0 });
      continue;
    }
    try {
      await createReply({
        post_id: state.postId,
        author_kind: 'agent',
        author_name: agent.name,
        author_avatar: agent.avatar,
        agent_persona: agent.id,
        content: action.text,
        confidence_score: 0.8,
        visibility: 'public',
      });
      await incrementLike(state.postId, `agent-${agent.id}`).catch((error) => {
        console.warn('[fanout:graph] like failed', agent.id, error);
      });
      persistedAgentIds.push(agent.id);
    } catch (error: any) {
      failedAgents.push({
        agentId: action.agentId,
        reason: error?.message ?? String(error),
        retryable: false,
        attempts: 1,
      });
      Sentry.captureException(error, { extra: { post_id: state.postId, agent_id: action.agentId, graph: 'fanout.persist' } });
    }
  }

  return { publishStarted, persistedAgentIds, failedAgents, skippedAgents, persistCompleted: true };
}

function notifyAndLogNode(state: S): Partial<S> {
  const totalLatencyMs = Date.now() - state.startedAt;
  console.log('[fanout:graph]', {
    postId: state.postId,
    selectedAgents: state.selectedAgents,
    succeededAgents: state.persistedAgentIds,
    failedAgents: state.failedAgents,
    skippedAgents: state.skippedAgents,
    totalCostUsd: state.totalCostUsd,
    totalLatencyMs,
    critiqueRetryCount: state.critiqueRetryCount,
  });
  flushTraces().catch(() => {});
  return {};
}

const workflow = new StateGraph(FanoutState)
  .addNode('loadContext', loadContextNode)
  .addNode('retrieveContext', retrieveContextNode)
  .addNode('selectAgents', selectAgentsNode)
  .addNode('runAgentsParallel', runAgentsParallelNode)
  .addNode('dedupeAndModerate', dedupeAndModerateNode)
  .addNode('critique', critiqueNode)
  .addNode('retryLowQualityOnce', retryLowQualityOnceNode)
  .addNode('decidePublish', decidePublishNode)
  .addNode('persist', persistNode)
  .addNode('notifyAndLog', notifyAndLogNode)
  .addEdge('__start__', 'loadContext')
  .addEdge('loadContext', 'retrieveContext')
  .addEdge('retrieveContext', 'selectAgents')
  .addEdge('selectAgents', 'runAgentsParallel')
  .addEdge('runAgentsParallel', 'dedupeAndModerate')
  .addEdge('dedupeAndModerate', 'critique')
  .addEdge('critique', 'retryLowQualityOnce')
  .addEdge('retryLowQualityOnce', 'decidePublish')
  .addEdge('decidePublish', 'persist')
  .addEdge('persist', 'notifyAndLog')
  .addEdge('notifyAndLog', END);

const graph = workflow.compile();

function resultFromState(state: S): GraphFanoutResult {
  const succeeded = state.persistedAgentIds.length;
  const selected = state.selectedAgents.length;
  return {
    succeeded,
    failed: Math.max(0, selected - succeeded),
    totalLatencyMs: Date.now() - state.startedAt,
    totalCostUsd: state.totalCostUsd,
  };
}

export async function runGraphFanoutAdapter(
  postId: string,
  opts: GraphFanoutAdapterOptions = {},
): Promise<GraphFanoutResult> {
  const finalState = await graph.invoke({
    mode: 'fanout',
    postId,
    source: opts.source ?? 'api',
    mentionedAgentId: opts.mentionedAgentId,
    agentIds: opts.agentIds,
    force: opts.force ?? false,
    dryRun: opts.dryRun ?? false,
    startedAt: Date.now(),
    publishStartedCallback: opts.onPublishStarted,
  });
  return resultFromState(finalState);
}
