import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/view_state.dart';
import '../domain/model.dart' as mirror_domain;
import 'repository.dart';

class GeneratedFutureMirrorApiService implements FutureMirrorService {
  GeneratedFutureMirrorApiService(RitualInvestingApiClient client)
    : _api = FutureMirrorApi(client.dio);

  final FutureMirrorApi _api;

  @override
  Future<mirror_domain.FutureMirror> generate(
    mirror_domain.FutureMirrorGenerate command,
  ) async {
    try {
      final value = (await _api.createFutureMirror(
        intentionId: command.intentionId,
        idempotencyKey: command.idempotencyKey,
        createFutureMirrorRequest: _request(command.draft),
      )).data!.data;
      final result = _mirror(value, expectedIntentionId: command.intentionId);
      if (!result.assumptions.exactlyMatches(command.draft)) {
        ApiFailureMapper.terminalContract();
      }
      return result;
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const mirror_domain.AmbiguousFutureMirrorGeneration();
      }
      final fieldErrors = _futureMirrorFieldErrors(error.response?.data);
      if (fieldErrors.isNotEmpty) {
        throw mirror_domain.FutureMirrorValidationFailure(fieldErrors);
      }
      if (ApiFailureMapper.errorCode(error.response?.data) ==
          'projection_requires_demo_activity') {
        throw const LoadFailure(
          LoadPhase.conflict,
          message: 'Add provider-free Demo activity before generating.',
        );
      }
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<mirror_domain.FutureMirror?> getLatest(String intentionId) async {
    try {
      final value = (await _api.getLatestFutureMirror(intentionId: intentionId))
          .data!
          .data;
      return _mirror(value, expectedIntentionId: intentionId);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404 ||
          ApiFailureMapper.errorCode(error.response?.data) == 'not_found' ||
          ApiFailureMapper.errorCode(error.response?.data) ==
              'resource_not_found') {
        return null;
      }
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<mirror_domain.FutureMirror> get(
    String intentionId,
    String runId,
  ) async {
    try {
      final value = (await _api.getFutureMirror(
        intentionId: intentionId,
        runId: runId,
      )).data!.data;
      if (value.id != runId) ApiFailureMapper.terminalContract();
      return _mirror(value, expectedIntentionId: intentionId);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  CreateFutureMirrorRequest _request(mirror_domain.FutureMirrorDraft draft) =>
      CreateFutureMirrorRequest(
        name: draft.name.trim(),
        monthlyContribution: InputMoney(
          currency: InputMoneyCurrencyEnum.USD,
          minorUnits: draft.monthlyContributionMinor,
        ),
        annualReturnBps: CreateFutureMirrorRequestAnnualReturnBps(
          low: draft.lowReturnBps,
          mid: draft.midReturnBps,
          high: draft.highReturnBps,
        ),
      );

  mirror_domain.FutureMirror _mirror(
    FutureMirrorView value, {
    required String expectedIntentionId,
  }) {
    _requireSimulationDemo(value.demo);
    _requireGeneratedUuid(value.id);
    _requireGeneratedUuid(value.intentionId);
    if (value.intentionId != expectedIntentionId ||
        value.modelVersion != FutureMirrorViewModelVersionEnum.ritualDemoV1 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(value.inputHash) ||
        value.ledgerWatermark < 1 ||
        value.uncertainty.trim().isEmpty ||
        value.points.isEmpty ||
        value.points.length > 120) {
      ApiFailureMapper.terminalContract();
    }
    final assumptions = value.assumptions;
    if (assumptions.name.trim().isEmpty ||
        assumptions.name.length > 80 ||
        assumptions.monthlyContribution.currency !=
            InputMoneyCurrencyEnum.USD ||
        assumptions.monthlyContribution.minorUnits < 0 ||
        assumptions.monthlyContribution.minorUnits > 1000000000 ||
        !_validReturnBands(
          assumptions.annualReturnBps.low,
          assumptions.annualReturnBps.mid,
          assumptions.annualReturnBps.high,
        )) {
      ApiFailureMapper.terminalContract();
    }
    final points = <mirror_domain.FutureMirrorPoint>[];
    DateTime? previousDate;
    for (final point in value.points) {
      final date = _generatedDateOnly(point.date);
      if (previousDate != null && !date.isAfter(previousDate)) {
        ApiFailureMapper.terminalContract();
      }
      previousDate = date;
      if (point.low.currency != MoneyCurrencyEnum.USD ||
          point.mid.currency != MoneyCurrencyEnum.USD ||
          point.high.currency != MoneyCurrencyEnum.USD ||
          point.low.minorUnits < 0 ||
          point.low.minorUnits > point.mid.minorUnits ||
          point.mid.minorUnits > point.high.minorUnits) {
        ApiFailureMapper.terminalContract();
      }
      points.add(
        mirror_domain.FutureMirrorPoint(
          date: date,
          lowMinor: point.low.minorUnits,
          midMinor: point.mid.minorUnits,
          highMinor: point.high.minorUnits,
        ),
      );
    }
    return mirror_domain.FutureMirror(
      id: value.id,
      intentionId: value.intentionId,
      assumptions: mirror_domain.FutureMirrorDraft(
        name: assumptions.name,
        monthlyContributionMinor: assumptions.monthlyContribution.minorUnits,
        lowReturnBps: assumptions.annualReturnBps.low,
        midReturnBps: assumptions.annualReturnBps.mid,
        highReturnBps: assumptions.annualReturnBps.high,
      ),
      points: List.unmodifiable(points),
      generatedAt: value.generatedAt.toUtc(),
      modelVersion: value.modelVersion.value,
      inputHash: value.inputHash,
      ledgerWatermark: value.ledgerWatermark,
      uncertainty: value.uncertainty,
      demo: mirror_domain.FutureMirrorDemoDisclosure(
        isDemo: value.demo.isDemo,
        observedAt: value.demo.observedAt.toUtc(),
        sourceLabel: value.demo.sourceLabel,
        limitations: List.unmodifiable(value.demo.limitations),
      ),
    );
  }
}

Map<mirror_domain.FutureMirrorField, String> _futureMirrorFieldErrors(
  Object? data,
) {
  if (data is! Map || data['error'] is! Map) return const {};
  final values = (data['error']! as Map)['field_errors'];
  if (values is! List) return const {};
  final result = <mirror_domain.FutureMirrorField, String>{};
  const paths = <String, mirror_domain.FutureMirrorField>{
    'name': mirror_domain.FutureMirrorField.name,
    'monthly_contribution': mirror_domain.FutureMirrorField.monthlyContribution,
    'monthly_contribution.minor_units':
        mirror_domain.FutureMirrorField.monthlyContribution,
    'annual_return_bps.low': mirror_domain.FutureMirrorField.lowReturn,
    'annual_return_bps.mid': mirror_domain.FutureMirrorField.midReturn,
    'annual_return_bps.high': mirror_domain.FutureMirrorField.highReturn,
  };
  for (final raw in values) {
    if (raw is! Map || raw['path'] is! String || raw['code'] is! String) {
      continue;
    }
    final field = paths[raw['path']];
    final code = raw['code']! as String;
    if (field != null && code.trim().isNotEmpty) result[field] = code;
  }
  return result;
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

bool _validReturnBands(int low, int mid, int high) =>
    low >= -5000 && high <= 5000 && low <= mid && mid <= high;
