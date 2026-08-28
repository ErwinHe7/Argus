import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/date_only_request_interceptor.dart';
import '../domain/member_scenario_model.dart' as domain;
import 'member_scenario_repository.dart';

/// Production adapter for member-entered, provider-neutral scenarios.
///
/// This boundary intentionally has no brokerage account, position, balance, or
/// order types. Monetary values remain exact decimal strings end to end.
class GeneratedMemberScenarioApiService implements MemberScenarioService {
  GeneratedMemberScenarioApiService(RitualInvestingApiClient client)
    : _intentions = IntentionsApi(client.dio),
      _futureMirror = FutureMirrorApi(client.dio) {
    ensureDateOnlyRequestSerialization(client.dio);
  }

  final IntentionsApi _intentions;
  final FutureMirrorApi _futureMirror;

  @override
  Future<List<domain.MemberIntentionScenario>> listIntentions() async {
    try {
      final page = (await _intentions.listIntentions()).data!.data;
      if (page.nextCursor != null) ApiFailureMapper.terminalContract();
      final result = page.items.map(_intention).toList(growable: false);
      if (result.map((item) => item.id).toSet().length != result.length) {
        ApiFailureMapper.terminalContract();
      }
      return result;
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<domain.MemberIntentionScenario> getIntention(
    String intentionId,
  ) async {
    try {
      final value = (await _intentions.getIntention(intentionId: intentionId))
          .data!
          .data;
      if (value.id != intentionId) ApiFailureMapper.terminalContract();
      return _intention(value);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<domain.MemberIntentionScenario> createIntention(
    domain.MemberIntentionInput input,
    String idempotencyKey,
  ) async {
    try {
      final value = (await _intentions.createIntention(
        idempotencyKey: idempotencyKey,
        createMemberIntention: CreateMemberIntention(
          title: input.title.trim(),
          target: _requestMoney(input.target),
          targetDate: _dateOnly(input.targetDate),
        ),
      )).data!.data;
      final result = _intention(value);
      if (!_matchesIntentionInput(result, input)) {
        ApiFailureMapper.terminalContract();
      }
      return result;
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const domain.ScenarioAmbiguousFailure();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<domain.MemberIntentionScenario> patchIntention(
    String intentionId,
    domain.MemberIntentionInput input,
    int expectedVersion,
  ) async {
    try {
      final value = (await _intentions.patchIntention(
        intentionId: intentionId,
        ifMatch: '"v$expectedVersion"',
        patchMemberIntention: PatchMemberIntention(
          title: input.title.trim(),
          target: _requestMoney(input.target),
          targetDate: _dateOnly(input.targetDate),
        ),
      )).data!.data;
      final result = _intention(value);
      if (result.id != intentionId || !_matchesIntentionInput(result, input)) {
        ApiFailureMapper.terminalContract();
      }
      return result;
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const domain.ScenarioAmbiguousFailure();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<domain.MemberIntentionScenario> archiveIntention(
    String intentionId,
    int expectedVersion,
  ) async {
    try {
      final value = (await _intentions.archiveIntention(
        intentionId: intentionId,
        ifMatch: '"v$expectedVersion"',
      )).data!.data;
      final result = _intention(value);
      if (result.id != intentionId ||
          result.status != domain.MemberIntentionStatus.archived) {
        ApiFailureMapper.terminalContract();
      }
      return result;
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const domain.ScenarioAmbiguousFailure();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<domain.HypotheticalFutureScenario?> getLatestFutureMirror(
    String intentionId,
  ) async {
    try {
      final value = (await _futureMirror.getLatestFutureMirror(
        intentionId: intentionId,
      )).data!.data;
      return _mirror(value, intentionId);
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
  Future<domain.HypotheticalFutureScenario> getFutureMirror(
    String intentionId,
    String runId,
  ) async {
    try {
      final value = (await _futureMirror.getFutureMirror(
        intentionId: intentionId,
        runId: runId,
      )).data!.data;
      final result = _mirror(value, intentionId);
      if (result.id != runId) ApiFailureMapper.terminalContract();
      return result;
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<domain.HypotheticalFutureScenario> createFutureMirror(
    String intentionId,
    domain.HypotheticalScenarioInput input,
    String idempotencyKey,
  ) async {
    try {
      final value = (await _futureMirror.createFutureMirror(
        intentionId: intentionId,
        idempotencyKey: idempotencyKey,
        createHypotheticalFutureMirror: CreateHypotheticalFutureMirror(
          name: input.name.trim(),
          baseline: _requestMoney(input.baseline),
          monthlyContribution: _requestMoney(input.monthlyContribution),
          annualReturnBps: CreateHypotheticalFutureMirrorAnnualReturnBps(
            low: input.lowReturnBps,
            mid: input.midReturnBps,
            high: input.highReturnBps,
          ),
          asOfDate: _dateOnly(input.asOfDate),
        ),
      )).data!.data;
      final result = _mirror(value, intentionId);
      if (!_matchesMirrorInput(result.input, input)) {
        ApiFailureMapper.terminalContract();
      }
      return result;
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const domain.ScenarioAmbiguousFailure();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }
}

domain.MemberIntentionScenario _intention(MemberIntention value) {
  _requireUuid(value.id);
  final status = switch (value.status) {
    MemberIntentionStatusEnum.active => domain.MemberIntentionStatus.active,
    MemberIntentionStatusEnum.archived => domain.MemberIntentionStatus.archived,
    MemberIntentionStatusEnum.unknownDefaultOpenApi =>
      ApiFailureMapper.terminalContract(),
  };
  if (value.title.trim().isEmpty || value.version < 1) {
    ApiFailureMapper.terminalContract();
  }
  return domain.MemberIntentionScenario(
    id: value.id,
    title: value.title,
    target: _money(value.target),
    targetDate: _responseDateOnly(value.targetDate),
    status: status,
    version: value.version,
    createdAt: value.createdAt.toUtc(),
  );
}

domain.HypotheticalFutureScenario _mirror(
  HypotheticalFutureMirror value,
  String expectedIntentionId,
) {
  _requireUuid(value.id);
  _requireUuid(value.intentionId);
  final asOfDate = _responseDateOnly(value.asOfDate);
  final targetDate = _responseDateOnly(value.targetDate);
  if (value.intentionId != expectedIntentionId ||
      value.name.trim().isEmpty ||
      value.name.length > 80 ||
      !_validVersion(value.modelVersion) ||
      !_validVersion(value.assumptionVersion) ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(value.inputHash) ||
      value.uncertaintyDisclosure.length < 40 ||
      value.uncertaintyDisclosure.length > 400 ||
      !_validReturnBands(
        value.annualReturnBps.low,
        value.annualReturnBps.mid,
        value.annualReturnBps.high,
      ) ||
      value.points.isEmpty ||
      value.points.length > 121 ||
      !targetDate.isAfter(asOfDate)) {
    ApiFailureMapper.terminalContract();
  }
  final baseline = _money(value.baseline);
  final contribution = _money(value.monthlyContribution);
  if (baseline.currency != contribution.currency) {
    ApiFailureMapper.terminalContract();
  }
  final points = <domain.HypotheticalScenarioPoint>[];
  DateTime? previous;
  for (final point in value.points) {
    final date = _responseDateOnly(point.projectedDate);
    if (point.ordinal != points.length + 1 ||
        !date.isAfter(asOfDate) ||
        date.isAfter(targetDate) ||
        (previous != null && !date.isAfter(previous))) {
      ApiFailureMapper.terminalContract();
    }
    previous = date;
    final low = _storedMinor(point.lowAmountMinor);
    final mid = _storedMinor(point.midAmountMinor);
    final high = _storedMinor(point.highAmountMinor);
    if (!_nonDecreasingUnsigned(low, mid, high)) {
      ApiFailureMapper.terminalContract();
    }
    points.add(
      domain.HypotheticalScenarioPoint(
        date: date,
        lowMinor: low,
        midMinor: mid,
        highMinor: high,
      ),
    );
  }
  if (!_sameDate(points.last.date, targetDate)) {
    ApiFailureMapper.terminalContract();
  }
  return domain.HypotheticalFutureScenario(
    id: value.id,
    intentionId: value.intentionId,
    input: domain.HypotheticalScenarioInput(
      name: value.name,
      baseline: baseline,
      monthlyContribution: contribution,
      lowReturnBps: value.annualReturnBps.low,
      midReturnBps: value.annualReturnBps.mid,
      highReturnBps: value.annualReturnBps.high,
      asOfDate: asOfDate,
    ),
    targetDate: targetDate,
    points: List.unmodifiable(points),
    modelVersion: value.modelVersion,
    assumptionVersion: value.assumptionVersion,
    generatedAt: value.generatedAt.toUtc(),
    uncertaintyDisclosure: value.uncertaintyDisclosure,
  );
}

ScenarioMoney _requestMoney(domain.ExactScenarioMoney value) => ScenarioMoney(
  minorUnits: _reviewedMinor(value.minorUnits),
  currency: _currency(value.currency),
);

domain.ExactScenarioMoney _money(ScenarioMoney value) =>
    domain.ExactScenarioMoney(
      minorUnits: _reviewedMinor(value.minorUnits),
      currency: _currency(value.currency),
    );

String _reviewedMinor(String value) => _boundedMinor(value, '9007199254740991');

String _storedMinor(String value) =>
    _boundedMinor(value, '9223372036854775807');

String _boundedMinor(String value, String maximum) {
  if (!RegExp(r'^(0|[1-9][0-9]{0,18})$').hasMatch(value) ||
      value.length > maximum.length ||
      (value.length == maximum.length && value.compareTo(maximum) > 0)) {
    ApiFailureMapper.terminalContract();
  }
  return value;
}

String _currency(String value) {
  if (!RegExp(r'^[A-Z]{3}$').hasMatch(value)) {
    ApiFailureMapper.terminalContract();
  }
  return value;
}

DateTime _dateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

DateTime _responseDateOnly(DateTime value) {
  if (value.hour != 0 ||
      value.minute != 0 ||
      value.second != 0 ||
      value.millisecond != 0 ||
      value.microsecond != 0) {
    ApiFailureMapper.terminalContract();
  }
  return DateTime.utc(value.year, value.month, value.day);
}

void _requireUuid(String value) {
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value)) {
    ApiFailureMapper.terminalContract();
  }
}

bool _validReturnBands(int low, int mid, int high) =>
    low >= -5000 && high <= 5000 && low <= mid && mid <= high;

bool _validVersion(String value) =>
    RegExp(r'^[a-z][a-z0-9.-]{0,63}$').hasMatch(value);

bool _matchesIntentionInput(
  domain.MemberIntentionScenario value,
  domain.MemberIntentionInput input,
) =>
    value.title == input.title.trim() &&
    value.target.minorUnits == input.target.minorUnits &&
    value.target.currency == input.target.currency &&
    _sameDate(value.targetDate, input.targetDate);

bool _matchesMirrorInput(
  domain.HypotheticalScenarioInput value,
  domain.HypotheticalScenarioInput input,
) =>
    value.name == input.name.trim() &&
    value.baseline.minorUnits == input.baseline.minorUnits &&
    value.baseline.currency == input.baseline.currency &&
    value.monthlyContribution.minorUnits ==
        input.monthlyContribution.minorUnits &&
    value.monthlyContribution.currency == input.monthlyContribution.currency &&
    value.lowReturnBps == input.lowReturnBps &&
    value.midReturnBps == input.midReturnBps &&
    value.highReturnBps == input.highReturnBps &&
    _sameDate(value.asOfDate, input.asOfDate);

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

bool _nonDecreasingUnsigned(String low, String mid, String high) {
  final lowValue = BigInt.parse(low);
  final midValue = BigInt.parse(mid);
  final highValue = BigInt.parse(high);
  return lowValue <= midValue && midValue <= highValue;
}
