import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/date_only_request_interceptor.dart';
import '../domain/model.dart' as intention_domain;
import 'repository.dart';

class GeneratedIntentionApiService implements IntentionService {
  GeneratedIntentionApiService(RitualInvestingApiClient client)
    : _api = IntentionsApi(client.dio) {
    ensureDateOnlyRequestSerialization(client.dio);
  }

  final IntentionsApi _api;

  @override
  Future<intention_domain.IntentionPage> list({
    String? cursor,
    intention_domain.IntentionStatus? status,
  }) async {
    try {
      final response = (await _api.listIntentions(
        cursor: cursor,
        status: status?.name,
      )).data!;
      final items = response.data.map(_intention).toList(growable: false);
      if (items.map((item) => item.id).toSet().length != items.length ||
          (response.meta.hasMore &&
              (response.meta.nextCursor == null ||
                  response.meta.nextCursor!.trim().isEmpty)) ||
          (!response.meta.hasMore && response.meta.nextCursor != null)) {
        ApiFailureMapper.terminalContract();
      }
      return intention_domain.IntentionPage(
        items: items,
        hasMore: response.meta.hasMore,
        nextCursor: response.meta.nextCursor,
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<intention_domain.Intention> get(String intentionId) async {
    try {
      final value = (await _api.getIntention(intentionId: intentionId))
          .data!
          .data;
      if (value.id != intentionId) ApiFailureMapper.terminalContract();
      return _intention(value);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<intention_domain.Intention> create(
    intention_domain.IntentionCreate command,
  ) async {
    final draft = command.draft;
    try {
      final value = (await _api.createIntention(
        idempotencyKey: command.idempotencyKey,
        createIntentionRequest: CreateIntentionRequest(
          portfolioId: draft.portfolioId,
          title: draft.title.trim(),
          target: PositiveInputMoney(
            currency: PositiveInputMoneyCurrencyEnum.USD,
            minorUnits: draft.targetMinor,
          ),
          targetDate: draft.targetDate,
        ),
      )).data!.data;
      if (value.portfolioId != draft.portfolioId ||
          value.title != draft.title.trim() ||
          value.target.minorUnits != draft.targetMinor ||
          !_sameDate(value.targetDate, draft.targetDate)) {
        ApiFailureMapper.terminalContract();
      }
      return _intention(value);
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const intention_domain.AmbiguousIntentionCreate();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<intention_domain.Intention> patch(
    intention_domain.IntentionPatch command,
  ) async {
    final draft = command.draft;
    try {
      final value = (await _api.patchIntention(
        intentionId: command.intentionId,
        ifMatch: '"v${command.expectedVersion}"',
        patchIntentionRequest: PatchIntentionRequest(
          title: draft.title.trim(),
          target: PositiveInputMoney(
            currency: PositiveInputMoneyCurrencyEnum.USD,
            minorUnits: draft.targetMinor,
          ),
          targetDate: draft.targetDate,
          status: switch (draft.status) {
            intention_domain.IntentionStatus.active =>
              PatchIntentionRequestStatusEnum.active,
            intention_domain.IntentionStatus.completed =>
              PatchIntentionRequestStatusEnum.completed,
            intention_domain.IntentionStatus.archived =>
              ApiFailureMapper.terminalContract(),
          },
        ),
      )).data!.data;
      final result = _intention(value);
      if (result.id != command.intentionId || !draft.exactlyMatches(result)) {
        ApiFailureMapper.terminalContract();
      }
      return result;
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const intention_domain.AmbiguousIntentionMutation();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<void> archive(String intentionId, int expectedVersion) async {
    try {
      await _api.archiveIntention(
        intentionId: intentionId,
        ifMatch: '"v$expectedVersion"',
      );
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const intention_domain.AmbiguousIntentionMutation();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }

  intention_domain.Intention _intention(Intention value) {
    _requireSimulationDemo(value.demo);
    _requireGeneratedUuid(value.id);
    _requireGeneratedUuid(value.portfolioId);
    if (value.latestProjectionId case final id?) _requireGeneratedUuid(id);
    if (value.title.trim().isEmpty ||
        value.title.length > 120 ||
        value.target.currency != MoneyCurrencyEnum.USD ||
        value.progress.currency != MoneyCurrencyEnum.USD ||
        value.target.minorUnits < 1 ||
        value.target.minorUnits > 1000000000 ||
        value.progress.minorUnits < 0 ||
        value.progressBps < 0 ||
        value.progressBps > 10000 ||
        value.version < 1 ||
        _expectedProgressBps(
              value.progress.minorUnits,
              value.target.minorUnits,
            ) !=
            value.progressBps) {
      ApiFailureMapper.terminalContract();
    }
    final status = switch (value.status) {
      IntentionStatusEnum.active => intention_domain.IntentionStatus.active,
      IntentionStatusEnum.completed =>
        intention_domain.IntentionStatus.completed,
      IntentionStatusEnum.archived => intention_domain.IntentionStatus.archived,
      IntentionStatusEnum.unknownDefaultOpenApi =>
        ApiFailureMapper.terminalContract(),
    };
    return intention_domain.Intention(
      id: value.id,
      portfolioId: value.portfolioId,
      title: value.title,
      targetMinor: value.target.minorUnits,
      targetDate: _generatedDateOnly(value.targetDate),
      status: status,
      progressMinor: value.progress.minorUnits,
      progressBps: value.progressBps,
      latestProjectionId: value.latestProjectionId,
      version: value.version,
      demo: intention_domain.IntentionDemoDisclosure(
        isDemo: value.demo.isDemo,
        observedAt: value.demo.observedAt.toUtc(),
        sourceLabel: value.demo.sourceLabel,
        limitations: List.unmodifiable(value.demo.limitations),
      ),
    );
  }
}

void _requireSimulationDemo(SimulationDemoDisclosure value) {
  if (!value.isDemo ||
      value.sourceLabel.trim().isEmpty ||
      value.limitations.isEmpty ||
      value.limitations.any((item) => item.trim().isEmpty)) {
    ApiFailureMapper.terminalContract();
  }
}

void _requireGeneratedUuid(String value) {
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value)) {
    ApiFailureMapper.terminalContract();
  }
}

DateTime _generatedDateOnly(DateTime value) {
  if (value.hour != 0 ||
      value.minute != 0 ||
      value.second != 0 ||
      value.millisecond != 0 ||
      value.microsecond != 0) {
    ApiFailureMapper.terminalContract();
  }
  return DateTime.utc(value.year, value.month, value.day);
}

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

int _expectedProgressBps(int progressMinor, int targetMinor) =>
    progressMinor >= targetMinor
    ? 10000
    : (progressMinor * 10000) ~/ targetMinor;
