import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/view_state.dart';
import '../domain/daily_ritual.dart';
import 'daily_ritual_repository.dart';

class GeneratedRitualApiService implements DailyRitualService {
  GeneratedRitualApiService(RitualInvestingApiClient client)
    : _api = RitualsApi(client.dio);

  final RitualsApi _api;

  @override
  Future<DailyRitual> fetchDaily({DailyRitualMode? mode}) async {
    try {
      final response = await _api.getDailyRitual(
        mode: switch (mode) {
          null => null,
          DailyRitualMode.tarot => 'tarot',
          DailyRitualMode.astrology => 'astrology',
          DailyRitualMode.unknown => throw const LoadFailure(
            LoadPhase.terminalFailure,
          ),
        },
      );
      return _map(response.data!.data);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<DailyRitual> fetchAssignment(String assignmentId) async {
    try {
      return _map(
        (await _api.getRitual(assignmentId: assignmentId)).data!.data,
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<List<RitualEvidenceDetail>> fetchEvidence(String assignmentId) async {
    try {
      final claims = (await _api.getRitualEvidence(assignmentId: assignmentId))
          .data!
          .data;
      return claims
          .map(
            (claim) => RitualEvidenceDetail(
              claimId: claim.id,
              factorLabel: claim.claimType,
              observedAt: claim.observedAt ?? claim.source_.retrievedAt.toUtc(),
              summary: claim.summary,
              uncertainty: claim.uncertainty,
              source: RitualEvidenceSource(
                publisher: claim.source_.publisher,
                title: claim.source_.title,
                url: Uri.parse(claim.source_.canonicalUrl),
                publishedAt: claim.source_.publishedAt?.toUtc(),
              ),
            ),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    } on FormatException {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
  }

  @override
  Future<RitualHistoryPage> fetchHistory({String? cursor}) async {
    if (cursor != null) throw const LoadFailure(LoadPhase.terminalFailure);
    try {
      final items = (await _api.listRitualHistory()).data!.data
          .map((value) => RitualHistoryEntry.fromRitual(_map(value)))
          .toList(growable: false);
      return RitualHistoryPage(items: items, nextCursor: null, hasMore: false);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<DailyRitual> reveal(String assignmentId, int version) => _transition(
    assignmentId: assignmentId,
    version: version,
    from: TransitionRitualRequestFromEnum.assigned,
    to: TransitionRitualRequestToEnum.revealed,
  );

  @override
  Future<DailyRitual> complete(String assignmentId, int version) => _transition(
    assignmentId: assignmentId,
    version: version,
    from: TransitionRitualRequestFromEnum.revealed,
    to: TransitionRitualRequestToEnum.completed,
  );

  Future<DailyRitual> _transition({
    required String assignmentId,
    required int version,
    required TransitionRitualRequestFromEnum from,
    required TransitionRitualRequestToEnum to,
  }) async {
    try {
      final response = await _api.transitionRitual(
        assignmentId: assignmentId,
        ifMatch: '"v$version"',
        transitionRitualRequest: TransitionRitualRequest(from: from, to: to),
      );
      return _map(response.data!.data);
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const RitualAmbiguousMutation();
      }
      ApiFailureMapper.throwFailure(error);
    } on RitualAmbiguousMutation {
      rethrow;
    } on Object {
      // The request was handed to the generated client. A decode or mapping
      // failure after that point cannot prove whether the transition committed.
      throw const RitualAmbiguousMutation();
    }
  }
}

DailyRitual _map(DailyRitualAssignment value) {
  final payload = value.payload;
  final localDate = DateTime.utc(
    value.localDate.year,
    value.localDate.month,
    value.localDate.day,
  );
  final title = _optionalString(payload, 'title') ?? '';
  final interpretation = _optionalString(payload, 'interpretation') ?? '';
  final guidance = _optionalString(payload, 'guidance') ?? '';
  final marketLabel = _optionalString(payload, 'market_label') ?? '';
  final uncertainty = _optionalString(payload, 'uncertainty') ?? '';
  final revisionNumber = _integer(payload['revision_number']) ?? 0;
  final ideaValues = _tryObjects(payload['ideas']);
  final evidenceValues = _tryObjects(payload['evidence']);
  final ideas = _tryIdeas(ideaValues);
  final evidence = _tryEvidence(evidenceValues);
  final contentAvailable =
      title.isNotEmpty &&
      interpretation.isNotEmpty &&
      guidance.isNotEmpty &&
      marketLabel.isNotEmpty &&
      uncertainty.isNotEmpty &&
      revisionNumber > 0 &&
      ideas != null &&
      evidence != null;
  final artKey = _optionalString(payload, 'art_key') ?? '';
  final observedAt = _timestamp(payload['observation_at']) ?? localDate;
  return DailyRitual(
    assignmentId: value.id,
    date: localDate,
    mode: switch (value.mode) {
      DailyRitualAssignmentModeEnum.tarot => DailyRitualMode.tarot,
      DailyRitualAssignmentModeEnum.astrology => DailyRitualMode.astrology,
      DailyRitualAssignmentModeEnum.unknownDefaultOpenApi =>
        DailyRitualMode.unknown,
    },
    revision: RitualRevision(id: value.revisionId, number: revisionNumber),
    title: title,
    art: RitualArt(
      key: artKey,
      alt: _optionalString(payload, 'art_alt') ?? title,
    ),
    interpretation: interpretation,
    guidance: guidance,
    marketLabel: marketLabel,
    ideas: ideas ?? const [],
    evidence: evidence ?? const [],
    rowan: RitualCounsel(
      scriptRevisionId: value.rowanRevisionId ?? value.revisionId,
      surface: 'daily_ritual',
      body: value.bodyTemplate ?? guidance,
      riskFooter: value.riskFooter ?? uncertainty,
    ),
    version: value.version,
    state: switch (value.state) {
      DailyRitualAssignmentStateEnum.assigned => DailyRitualState.assigned,
      DailyRitualAssignmentStateEnum.revealed => DailyRitualState.revealed,
      DailyRitualAssignmentStateEnum.completed => DailyRitualState.completed,
      DailyRitualAssignmentStateEnum.unknownDefaultOpenApi =>
        DailyRitualState.unknown,
    },
    revealedAt: value.revealedAt?.toUtc(),
    completedAt: value.completedAt?.toUtc(),
    demo: RitualDisclosure(
      isDemo: false,
      observedAt: observedAt.toUtc(),
      sourceLabel: 'Argus editorial',
      limitations: const ['Educational context only.'],
    ),
    userId: value.userId,
    deletionEpoch: value.deletionEpoch,
    scheduleId: value.scheduleId,
    serverEvaluatedAt: value.serverEvaluatedAt.toUtc(),
    validUntil: value.validUntil.toUtc(),
    contentIdentity: sha256
        .convert(utf8.encode(jsonEncode(_canonicalJson(payload))))
        .toString(),
    mediaAvailability: artKey.isEmpty
        ? RitualMediaAvailability.missingIdentity
        : RitualMediaAvailability.exactIdentity,
    contentAvailability: contentAvailable
        ? RitualContentAvailability.available
        : RitualContentAvailability.unavailable,
  );
}

RitualIdea _idea(Map<String, Object?> value) => RitualIdea(
  assetId: _string(value, 'asset_id'),
  symbol: _string(value, 'symbol'),
  name: _string(value, 'name'),
  appearanceReason: _string(value, 'appearance_reason'),
  riskSummary: _string(value, 'risk_summary'),
);

RitualEvidence _evidence(Map<String, Object?> value) => RitualEvidence(
  claimId: _string(value, 'claim_id'),
  factorLabel: _string(value, 'factor_label'),
  observedAt:
      _timestamp(value['observed_at']) ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  summary: _string(value, 'summary'),
  uncertainty: _string(value, 'uncertainty'),
);

String _string(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is! String || field.trim().isEmpty) {
    throw const LoadFailure(LoadPhase.terminalFailure);
  }
  return field;
}

String? _optionalString(Map<String, Object?> value, String key) {
  final field = value[key];
  return field is String && field.trim().isNotEmpty ? field : null;
}

int? _integer(Object? value) => value is int ? value : null;

DateTime? _timestamp(Object? value) => value is String
    ? DateTime.tryParse(value)?.toUtc()
    : value is DateTime
    ? value.toUtc()
    : null;

List<Map<String, Object?>> _objects(Object? value) {
  if (value == null) return const [];
  if (value is! List) throw const LoadFailure(LoadPhase.terminalFailure);
  return value
      .map((entry) {
        if (entry is! Map) throw const LoadFailure(LoadPhase.terminalFailure);
        return Map<String, Object?>.from(entry);
      })
      .toList(growable: false);
}

List<Map<String, Object?>>? _tryObjects(Object? value) {
  try {
    return _objects(value);
  } on LoadFailure {
    return null;
  }
}

List<RitualIdea>? _tryIdeas(List<Map<String, Object?>>? values) {
  if (values == null) return null;
  try {
    return values.map(_idea).toList(growable: false);
  } on LoadFailure {
    return null;
  }
}

List<RitualEvidence>? _tryEvidence(List<Map<String, Object?>>? values) {
  if (values == null) return null;
  try {
    return values.map(_evidence).toList(growable: false);
  } on LoadFailure {
    return null;
  }
}

Object? _canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.whereType<String>().toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalJson(value[key]),
    };
  }
  if (value is List) return value.map(_canonicalJson).toList(growable: false);
  return value;
}
