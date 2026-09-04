import type {
  DevelopmentReplayReceipt,
  MarketQueryV1,
  QuantEvidenceEnvelope,
} from '@/lib/forecast-chat-types';

export function supportsDevelopmentReplay(query: MarketQueryV1): boolean {
  return (
    query.version === 'axio.market-query.v2' &&
    query.intent === 'forecast' &&
    query.setup_type === 'model_forecast' &&
    query.horizon_minutes === undefined &&
    query.symbols.length === 1 &&
    query.symbols[0] === 'SPX'
  );
}

export function developmentReplayReceipt(
  envelope: QuantEvidenceEnvelope
): DevelopmentReplayReceipt {
  if (envelope.evidence_mode !== 'deterministic_historical_replay') {
    throw new Error('DATABENTO_REPLAY_EVIDENCE_MODE_MISSING');
  }
  const inputEnvelopeCount =
    envelope.model_contract.replay_source_envelope_count;
  const contextObservationCount =
    envelope.model_contract.replay_context_observation_count;
  const sourceMode = envelope.model_contract.replay_source_mode;
  const syntheticContextIntervals =
    envelope.model_contract.synthetic_context_intervals;
  const artifactFeatureIdentityMatchesReplay =
    envelope.model_contract.artifact_feature_identity_matches_replay;
  const replayLocalModelTrained =
    envelope.model_contract.replay_local_model_trained;
  const productionArtifactUsed =
    envelope.model_contract.production_artifact_used;
  if (
    typeof inputEnvelopeCount !== 'number' ||
    !Number.isSafeInteger(inputEnvelopeCount) ||
    inputEnvelopeCount < 1
  ) {
    throw new Error('DATABENTO_REPLAY_SOURCE_ENVELOPE_COUNT_INVALID');
  }
  if (
    typeof contextObservationCount !== 'number' ||
    !Number.isSafeInteger(contextObservationCount) ||
    contextObservationCount < 0 ||
    (sourceMode !== 'RECORDED_DATABENTO_ENVELOPES' &&
      sourceMode !== 'DATABENTO_SHAPED_HISTORICAL_TRANSPORT_MOCK' &&
      sourceMode !== 'STRICT_INSTALLED_HISTORICAL_REPLAY') ||
    typeof syntheticContextIntervals !== 'number' ||
    !Number.isSafeInteger(syntheticContextIntervals) ||
    syntheticContextIntervals < 0 ||
    typeof artifactFeatureIdentityMatchesReplay !== 'boolean' ||
    replayLocalModelTrained !== true ||
    productionArtifactUsed !== false
  ) {
    throw new Error('DATABENTO_REPLAY_CONTEXT_RECEIPT_INVALID');
  }
  if (
    sourceMode === 'STRICT_INSTALLED_HISTORICAL_REPLAY' &&
    (syntheticContextIntervals !== 0 ||
      artifactFeatureIdentityMatchesReplay !== true)
  ) {
    throw new Error('STRICT_HISTORICAL_REPLAY_IDENTITY_INVALID');
  }
  return {
    mode: 'DATABENTO_PIPELINE_REPLAY',
    replayId: envelope.request_id,
    sourceContract: 'quant_engine_rs::data::databento_replay',
    observationCutoff: envelope.observation_cutoff,
    inputEnvelopeCount,
    contextObservationCount,
    sourceMode,
    syntheticContextIntervals,
    artifactFeatureIdentityMatchesReplay,
    replayLocalModelTrained: true,
    productionArtifactUsed: false,
    rustInference: true,
    currentMarketData: false,
    liveStateWritten: false,
  };
}
