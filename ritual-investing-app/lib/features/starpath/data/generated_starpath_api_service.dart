import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

import '../../../core/api/api_failure_mapper.dart';
import '../domain/starpath.dart';
import 'starpath_repository.dart';

class GeneratedStarpathApiService implements StarpathService {
  GeneratedStarpathApiService(api.RitualInvestingApiClient client)
    : _api = api.StarpathApi(client.dio);

  final api.StarpathApi _api;

  @override
  Future<StarpathSnapshot> fetch() async {
    try {
      final response = await _api.getStarpath();
      return _mapResponse(response.data);
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const OfflineException();
      }
      _throwStarpathFailure(error);
    } on StarpathUnsupportedContract {
      rethrow;
    } on Object {
      throw const StarpathUnsupportedContract();
    }
  }

  @override
  Future<StarpathSnapshot> start({required String idempotencyKey}) async {
    try {
      final response = await _api.startOrResumeStarpath(
        idempotencyKey: idempotencyKey,
      );
      return _mapResponse(response.data);
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const StarpathAmbiguousCommand();
      }
      _throwStarpathFailure(error);
    } on StarpathUnsupportedContract {
      rethrow;
    } on Object {
      throw const StarpathUnsupportedContract();
    }
  }

  @override
  Future<StarpathSnapshot> answer({
    required String idempotencyKey,
    required int version,
    required StarpathAnswerCommand command,
  }) async {
    try {
      final response = await _api.answerStarpathQuestion(
        idempotencyKey: idempotencyKey,
        ifMatch: '"v$version"',
        answerStarpathQuestion: api.AnswerStarpathQuestion(
          attemptKind: switch (command.attemptKind) {
            StarpathAttemptKind.node =>
              api.AnswerStarpathQuestionAttemptKindEnum.node,
            StarpathAttemptKind.recall =>
              api.AnswerStarpathQuestionAttemptKindEnum.recall,
          },
          sessionId: command.sessionId,
          manifestId: command.manifestId,
          revisionId: command.revisionId,
          questionId: command.questionId,
          optionId: command.optionId,
        ),
      );
      return _mapResponse(response.data);
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const StarpathAmbiguousCommand();
      }
      _throwStarpathFailure(error);
    } on StarpathUnsupportedContract {
      rethrow;
    } on Object {
      throw const StarpathUnsupportedContract();
    }
  }

  @override
  Future<StarpathSnapshot> skipRecall({
    required String idempotencyKey,
    required int version,
    required String sessionId,
  }) async {
    try {
      final response = await _api.skipStarpathRecall(
        idempotencyKey: idempotencyKey,
        ifMatch: '"v$version"',
        skipStarpathRecall: api.SkipStarpathRecall(sessionId: sessionId),
      );
      return _mapResponse(response.data);
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const StarpathAmbiguousCommand();
      }
      _throwStarpathFailure(error);
    } on StarpathUnsupportedContract {
      rethrow;
    } on Object {
      throw const StarpathUnsupportedContract();
    }
  }
}

Never _throwStarpathFailure(DioException error) {
  final code = ApiFailureMapper.errorCode(error.response?.data);
  switch (code) {
    case 'forbidden':
    case 'insufficient_scope':
      throw const StarpathForbidden();
    case 'starpath_unavailable':
    case 'starpath_content_unavailable':
    case 'starpath_replacement_unavailable':
    case 'service_unavailable':
    case 'temporarily_unavailable':
      throw const StarpathUnavailable();
    case 'starpath_lifecycle_closed':
    case 'starpath_idempotency_conflict':
    case 'starpath_progress_conflict':
    case 'starpath_session_not_found':
    case 'starpath_session_conflict':
    case 'starpath_node_locked':
    case 'starpath_content_conflict':
    case 'starpath_recall_conflict':
    case 'version_conflict':
    case 'idempotency_conflict':
      throw const StarpathConflict();
    case null:
      switch (error.response?.statusCode) {
        case 403:
          throw const StarpathForbidden();
        case 409:
          throw const StarpathConflict();
        case final status when status != null && status >= 500:
          throw const StarpathUnavailable();
        default:
          throw const StarpathUnsupportedContract();
      }
    default:
      throw const StarpathUnsupportedContract();
  }
}

StarpathSnapshot _mapResponse(api.StarpathSnapshotResponse? response) {
  if (response == null) throw const StarpathUnsupportedContract();
  final value = response.data;
  final availability = switch (value.availability) {
    api.StarpathSnapshotAvailabilityEnum.available =>
      StarpathAvailability.available,
    api.StarpathSnapshotAvailabilityEnum.notStarted =>
      StarpathAvailability.notStarted,
    api.StarpathSnapshotAvailabilityEnum.unknownDefaultOpenApi =>
      throw const StarpathUnsupportedContract(),
  };
  final authority = _mapAuthority(value.authority);
  final nodes = value.nodes.map(_mapNode).toList(growable: false)
    ..sort((a, b) => a.nodeOrdinal.compareTo(b.nodeOrdinal));
  _validateNodes(nodes);
  final session = value.session == null ? null : _mapSession(value.session!);
  final progress = value.progress == null
      ? null
      : _mapProgress(value.progress!);
  final theme = value.theme == null ? null : _mapTheme(value.theme!);
  if (availability == StarpathAvailability.available &&
      (session == null || progress == null || theme == null)) {
    throw const StarpathUnsupportedContract();
  }
  if (availability == StarpathAvailability.notStarted &&
      (session != null || progress != null || theme != null)) {
    throw const StarpathUnsupportedContract();
  }
  if (value.version < 0 ||
      (progress != null && progress.version != value.version)) {
    throw const StarpathUnsupportedContract();
  }
  return StarpathSnapshot(
    availability: availability,
    version: value.version,
    authority: authority,
    nodes: nodes,
    session: session,
    progress: progress,
    theme: theme,
    recall: value.recall == null ? null : _mapRecall(value.recall!),
    answer: value.answer == null
        ? null
        : StarpathAnswerFeedback(
            isCorrect: value.answer!.isCorrect,
            explanation: _text(value.answer!.explanation),
          ),
    commandEffect: value.commandEffect == null
        ? null
        : _mapCommandEffect(value.commandEffect!),
  );
}

StarpathAuthority _mapAuthority(api.StarpathAuthority value) =>
    StarpathAuthority(
      environment: switch (value.environment) {
        api.StarpathAuthorityEnvironmentEnum.beta => StarpathEnvironment.beta,
        api.StarpathAuthorityEnvironmentEnum.production =>
          StarpathEnvironment.production,
        api.StarpathAuthorityEnvironmentEnum.unknownDefaultOpenApi =>
          throw const StarpathUnsupportedContract(),
      },
      jurisdiction: _text(value.jurisdiction),
      capabilityVersion: _nonNegative(value.capabilityVersion),
      policyVersion: _text(value.policyVersion),
      manifestId: _text(value.manifestId),
      manifestVersion: _text(value.manifestVersion),
    );

StarpathSession _mapSession(api.StarpathSession value) => StarpathSession(
  id: _text(value.id),
  explicitStart: value.explicitStart,
  startedAt: value.startedAt.toUtc(),
  lastActionAt: value.lastActionAt.toUtc(),
  replacementOfSessionId: value.replacementOfSessionId,
  state: switch (value.state) {
    api.StarpathSessionStateEnum.active => StarpathSessionState.active,
    api.StarpathSessionStateEnum.closed => StarpathSessionState.closed,
    api.StarpathSessionStateEnum.replaced => StarpathSessionState.replaced,
    api.StarpathSessionStateEnum.unknownDefaultOpenApi =>
      throw const StarpathUnsupportedContract(),
  },
);

StarpathProgress _mapProgress(api.StarpathProgress value) {
  if (value.currentNodeOrdinal < 1 || value.currentNodeOrdinal > 9) {
    throw const StarpathUnsupportedContract();
  }
  return StarpathProgress(
    currentNodeOrdinal: value.currentNodeOrdinal,
    version: _nonNegative(value.version),
    updatedAt: value.updatedAt.toUtc(),
  );
}

StarpathTheme _mapTheme(api.StarpathSessionTheme value) => StarpathTheme(
  id: _text(value.id),
  key: _text(value.key),
  title: _text(value.title),
  horoscopeFrame: _text(value.horoscopeFrame),
  factualFocus: _text(value.factualFocus),
  accessibleLabel: _text(value.accessibleLabel),
);

StarpathNode _mapNode(api.StarpathNode value) => StarpathNode(
  lessonId: _text(value.lessonId),
  revisionId: _text(value.revisionId),
  nodeOrdinal: value.nodeOrdinal,
  pathwayOrdinal: value.pathwayOrdinal,
  pathwayPosition: value.pathwayPosition,
  title: _text(value.title),
  mythicMnemonic: _text(value.mythicMnemonic),
  factualSummary: _text(value.factualSummary),
  materialLimitations: _text(value.materialLimitations),
  riskContext: _text(value.riskContext),
  recallPrompt: _text(value.recallPrompt),
  rowanExplanation: _text(value.rowanExplanation),
  guide: StarpathGuide(
    tarotKey: _text(value.guide.tarotKey),
    accessibleLabel: _text(value.guide.accessibleLabel),
  ),
  factualSections: value.factualSections
      .map(_mapFactualSection)
      .toList(growable: false),
  knowledgeCheck: _mapKnowledgeCheck(value.knowledgeCheck),
  state: switch (value.state) {
    api.StarpathNodeStateEnum.completed => StarpathNodeState.completed,
    api.StarpathNodeStateEnum.current => StarpathNodeState.current,
    api.StarpathNodeStateEnum.locked => StarpathNodeState.locked,
    api.StarpathNodeStateEnum.unknownDefaultOpenApi =>
      throw const StarpathUnsupportedContract(),
  },
);

StarpathFactualSection _mapFactualSection(api.StarpathFactualSection value) =>
    StarpathFactualSection(
      ordinal: value.ordinal,
      kind: switch (value.kind) {
        api.StarpathFactualSectionKindEnum.fact =>
          StarpathFactualSectionKind.fact,
        api.StarpathFactualSectionKindEnum.neutralExample =>
          StarpathFactualSectionKind.neutralExample,
        api.StarpathFactualSectionKindEnum.unknownDefaultOpenApi =>
          throw const StarpathUnsupportedContract(),
      },
      heading: _text(value.heading),
      body: _text(value.body),
      observedAt: value.observedAt.toUtc(),
      uncertainty: _text(value.uncertainty),
      evidence: value.evidence.map(_mapEvidence).toList(growable: false),
    );

StarpathEvidence _mapEvidence(api.StarpathEvidence value) {
  final url = Uri.tryParse(value.canonicalUrl);
  if (url == null || url.scheme != 'https' || url.host.isEmpty) {
    throw const StarpathUnsupportedContract();
  }
  return StarpathEvidence(
    ordinal: value.ordinal,
    publisher: _text(value.publisher),
    sourceTitle: _text(value.sourceTitle),
    canonicalUrl: url,
    claimSummary: _text(value.claimSummary),
    retrievedAt: value.retrievedAt.toUtc(),
    sourceObservedAt: value.sourceObservedAt.toUtc(),
    currentUntil: value.currentUntil.toUtc(),
    effectiveAt: value.effectiveAt?.toUtc(),
  );
}

StarpathKnowledgeCheck _mapKnowledgeCheck(api.StarpathKnowledgeCheck value) =>
    StarpathKnowledgeCheck(
      id: _text(value.id),
      prompt: _text(value.prompt),
      options: value.options
          .map(
            (option) => StarpathKnowledgeCheckOption(
              id: _text(option.id),
              ordinal: option.ordinal,
              label: _text(option.label),
            ),
          )
          .toList(growable: false),
    );

StarpathRecall _mapRecall(api.StarpathRecall value) {
  if (value.status == api.StarpathRecallStatusEnum.unknownDefaultOpenApi) {
    throw const StarpathUnsupportedContract();
  }
  return StarpathRecall(
    id: _text(value.id),
    lessonId: _text(value.lessonId),
    revisionId: _text(value.revisionId),
    questionId: _text(value.questionId),
    prompt: _text(value.prompt),
    knowledgeCheck: _mapKnowledgeCheck(value.knowledgeCheck),
  );
}

StarpathCommandEffect _mapCommandEffect(
  api.StarpathSnapshotCommandEffectEnum value,
) => switch (value) {
  api.StarpathSnapshotCommandEffectEnum.started =>
    StarpathCommandEffect.started,
  api.StarpathSnapshotCommandEffectEnum.resumed =>
    StarpathCommandEffect.resumed,
  api.StarpathSnapshotCommandEffectEnum.contentReplaced =>
    StarpathCommandEffect.contentReplaced,
  api.StarpathSnapshotCommandEffectEnum.wrongAnswer =>
    StarpathCommandEffect.wrongAnswer,
  api.StarpathSnapshotCommandEffectEnum.lessonCompleted =>
    StarpathCommandEffect.lessonCompleted,
  api.StarpathSnapshotCommandEffectEnum.recallCompleted =>
    StarpathCommandEffect.recallCompleted,
  api.StarpathSnapshotCommandEffectEnum.recallSkipped =>
    StarpathCommandEffect.recallSkipped,
  api.StarpathSnapshotCommandEffectEnum.semanticReplay =>
    StarpathCommandEffect.semanticReplay,
  api.StarpathSnapshotCommandEffectEnum.idempotentReplay =>
    StarpathCommandEffect.idempotentReplay,
  api.StarpathSnapshotCommandEffectEnum.unknownDefaultOpenApi =>
    throw const StarpathUnsupportedContract(),
};

void _validateNodes(List<StarpathNode> nodes) {
  if (nodes.length != 8) throw const StarpathUnsupportedContract();
  final lessonIds = <String>{};
  for (var index = 0; index < nodes.length; index += 1) {
    final node = nodes[index];
    final ordinal = index + 1;
    if (node.nodeOrdinal != ordinal ||
        node.pathwayOrdinal != ((ordinal - 1) ~/ 2) + 1 ||
        node.pathwayPosition != ((ordinal - 1) % 2) + 1 ||
        node.factualSections.isEmpty ||
        node.knowledgeCheck.options.isEmpty ||
        !lessonIds.add(node.lessonId)) {
      throw const StarpathUnsupportedContract();
    }
  }
}

String _text(String value) {
  final result = value.trim();
  if (result.isEmpty) throw const StarpathUnsupportedContract();
  return result;
}

int _nonNegative(int value) {
  if (value < 0) throw const StarpathUnsupportedContract();
  return value;
}
